import 'dart:isolate';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:yaml/yaml.dart';
import 'package:injectable/injectable.dart';
import 'package:image/image.dart' as img;
import '../../domain/entities/detection_result.dart';

abstract class TfliteLocalDataSource {
  Future<void> initialize();
  Future<List<DetectionResult>> processImage(CameraImage image);
  void dispose();
}

class IsolateParams {
  final int address;
  final List<String> labels;
  final List<Uint8List> planes;
  final List<int> rowStrides;
  final List<int> pixelStrides;
  final int width;
  final int height;

  IsolateParams({
    required this.address,
    required this.labels,
    required this.planes,
    required this.rowStrides,
    required this.pixelStrides,
    required this.width,
    required this.height,
  });
}

@LazySingleton(as: TfliteLocalDataSource)
class TfliteLocalDataSourceImpl implements TfliteLocalDataSource {
  Interpreter? _interpreter;
  List<String>? _labels;
  static const double _confidenceThreshold = 0.5;
  static const double _iouThreshold = 0.45;

  @override
  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/best.tflite');
      final yamlString = await rootBundle.loadString('assets/models/data.yaml');
      final yamlMap = loadYaml(yamlString);
      if (yamlMap['names'] != null) {
        final names = yamlMap['names'];
        if (names is YamlList || names is List) {
          _labels = (names as Iterable).map((e) => e.toString()).toList();
        } else if (names is YamlMap || names is Map) {
          final entries = (names as Map).entries.toList()
            ..sort((a, b) => (a.key as int).compareTo(b.key as int));
          _labels = entries.map((e) => e.value.toString()).toList();
        }
      } else {
        _labels = [];
      }
    } catch (e) {
      // Ignorar error si los archivos no existen aún
    }
  }

  @override
  Future<List<DetectionResult>> processImage(CameraImage image) async {
    if (_interpreter == null || _labels == null || _labels!.isEmpty) return [];

    final planes = image.planes.map((p) => p.bytes).toList();
    final rowStrides = image.planes.map((p) => p.bytesPerRow).toList();
    final pixelStrides = image.planes.map((p) => p.bytesPerPixel ?? 1).toList();

    final params = IsolateParams(
      address: _interpreter!.address,
      labels: _labels!,
      planes: planes,
      rowStrides: rowStrides,
      pixelStrides: pixelStrides,
      width: image.width,
      height: image.height,
    );

    return await Isolate.run(() {
      return _runInferenceInIsolate(params);
    });
  }

  static List<DetectionResult> _runInferenceInIsolate(IsolateParams params) {
    final isolateInterpreter = Interpreter.fromAddress(params.address);
    isolateInterpreter.allocateTensors();

    // 1. YUV420 to RGB garantizado
    img.Image rgbImage = _convertYUV420ToImage(
      params.width,
      params.height,
      params.planes,
      params.rowStrides,
      params.pixelStrides,
    );

    // 2. Resize a 640x640 (tamaño estándar YOLOv8)
    const int inputSize = 640;
    img.Image resizedImage = img.copyResize(rgbImage, width: inputSize, height: inputSize);

    // 3. Crear tensor de entrada [1, 3, 640, 640] (NCHW) en Float32List
    final inputBuffer = Float32List(1 * 3 * inputSize * inputSize);
    int bufferIndex = 0;
    
    // NCHW: Primero todos los Rojos (c=0), luego Verdes (c=1), luego Azules (c=2)
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < inputSize; y++) {
        for (int x = 0; x < inputSize; x++) {
          final pixel = resizedImage.getPixel(x, y);
          final val = c == 0 ? pixel.r : (c == 1 ? pixel.g : pixel.b);
          // Normalización / 255.0 garantizada
          inputBuffer[bufferIndex++] = val / 255.0;
        }
      }
    }

    final Object inputObj = (inputBuffer as List).reshape([1, 3, inputSize, inputSize]);

    // 4. Crear tensor de salida [1, 9, 8400]
    final int numClasses = params.labels.length;
    final int numRows = 4 + numClasses; // Ej: 4 + 5 = 9
    const int numColumns = 8400; // Anclajes YOLOv8
    
    final outputBuffer = Float32List(1 * numRows * numColumns);
    final Object outputObj = (outputBuffer as List).reshape([1, numRows, numColumns]);

    // 5. Run Inference
    isolateInterpreter.run(inputObj, outputObj);

    // 6. Post-procesamiento Estricto de YOLOv8
    final outputList = (outputObj as List)[0]; // List de tamaño numRows
    List<DetectionResult> results = [];
    
    double absoluteMaxConf = 0.0;

    // Iterar estrictamente por las 8400 columnas
    for (int i = 0; i < numColumns; i++) {
      double maxConf = 0.0;
      int maxClass = -1;

      // Extraer las probabilidades desde la fila 4 hasta numRows - 1
      for (int c = 0; c < numClasses; c++) {
        final conf = outputList[4 + c][i];
        if (conf > maxConf) {
          maxConf = conf;
          maxClass = c;
        }
      }

      if (maxConf > absoluteMaxConf) {
        absoluteMaxConf = maxConf;
      }

      if (maxConf > _confidenceThreshold && maxClass != -1) {
        // ERROR DETECTADO: El modelo TFLite de YOLOv8 está retornando coordenadas 
        // ya normalizadas (0.0 a 1.0), por lo que dividirlas entre 640 (inputSize) 
        // las convertía en valores microscópicos (ej: 0.5 / 640 = 0.0007)
        final xCenter = outputList[0][i];
        final yCenter = outputList[1][i];
        final w = outputList[2][i];
        final h = outputList[3][i];

        final left = (xCenter - w / 2).clamp(0.0, 1.0);
        final top = (yCenter - h / 2).clamp(0.0, 1.0);
        final right = (xCenter + w / 2).clamp(0.0, 1.0);
        final bottom = (yCenter + h / 2).clamp(0.0, 1.0);
        
        final label = params.labels[maxClass];

        results.add(DetectionResult(
          label: label,
          confidence: maxConf,
          boundingBox: Rect.fromLTRB(left, top, right, bottom),
        ));
      }
    }

    // 1. Logging crítico para diagnosticar la red
    print('MAX CONFIDENCE IN FRAME: $absoluteMaxConf');

    return _applyNMS(results, _iouThreshold);
  }

  static img.Image _convertYUV420ToImage(int width, int height, List<Uint8List> planes, List<int> rowStrides, List<int> pixelStrides) {
    final img.Image image = img.Image(width: width, height: height);

    final yPlane = planes[0];
    final uPlane = planes[1];
    final vPlane = planes[2];

    final yRowStride = rowStrides[0];
    final uvRowStride = rowStrides[1];
    final uvPixelStride = pixelStrides[1];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
        final indexY = y * yRowStride + x;

        final yp = yPlane[indexY];
        final up = uPlane[uvIndex];
        final vp = vPlane[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).round();
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round();
        int b = (yp + up * 1814 / 1024 - 227).round();

        image.setPixelRgb(x, y, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
      }
    }
    return image;
  }

  static List<DetectionResult> _applyNMS(List<DetectionResult> boxes, double iouThreshold) {
    if (boxes.isEmpty) return [];

    // Filtro suave: solo la detección con mayor confianza por cada clase
    Map<String, DetectionResult> bestPerClass = {};

    for (var box in boxes) {
      if (!bestPerClass.containsKey(box.label) || bestPerClass[box.label]!.confidence < box.confidence) {
        bestPerClass[box.label] = box;
      }
    }

    return bestPerClass.values.toList();
  }

  static double _calculateIoU(Rect a, Rect b) {
    final double areaA = a.width * a.height;
    final double areaB = b.width * b.height;

    final double intersectionLeft = math.max(a.left, b.left);
    final double intersectionTop = math.max(a.top, b.top);
    final double intersectionRight = math.min(a.right, b.right);
    final double intersectionBottom = math.min(a.bottom, b.bottom);

    final double intersectionWidth = math.max(0.0, intersectionRight - intersectionLeft);
    final double intersectionHeight = math.max(0.0, intersectionBottom - intersectionTop);
    
    final double intersectionArea = intersectionWidth * intersectionHeight;
    final double unionArea = areaA + areaB - intersectionArea;

    return unionArea > 0 ? intersectionArea / unionArea : 0.0;
  }

  @override
  void dispose() {
    _interpreter?.close();
  }
}
