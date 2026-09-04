import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:yaml/yaml.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/camera_frame.dart';
import '../../domain/entities/detection_result.dart';

abstract class TfliteLocalDataSource {
  Future<void> initialize();
  Future<List<DetectionResult>> processFrame(CameraFrame frame);
  Future<void> dispose();
}

/// Metadatos estructurales de tensores extraídos dinámicamente del modelo TFLite.
///
/// Permite desacoplar el pipeline de valores fijos (como resolución 640x640,
/// 8400 columnas fijas o formatos NCHW/NHWC exclusivos), permitiendo actualizar
/// el modelo reentrenado de YOLOv8 sin romper la aplicación.
class ModelMetadata {
  final int inputWidth;
  final int inputHeight;
  final int inputChannels;
  final bool isNCHW;
  final int outputRows;
  final int outputColumns;
  final int numClasses;
  final bool isOutputTransposed;

  const ModelMetadata({
    required this.inputWidth,
    required this.inputHeight,
    required this.inputChannels,
    required this.isNCHW,
    required this.outputRows,
    required this.outputColumns,
    required this.numClasses,
    required this.isOutputTransposed,
  });
}

class IsolateParams {
  final int address;
  final List<String> labels;
  final ModelMetadata metadata;
  final List<Uint8List> planes;
  final List<int> rowStrides;
  final List<int> pixelStrides;
  final int width;
  final int height;

  IsolateParams({
    required this.address,
    required this.labels,
    required this.metadata,
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
  ModelMetadata? _metadata;
  static const double _confidenceThreshold = 0.5;

  Future<List<DetectionResult>>? _activeInference;
  bool _isDisposed = false;

  @override
  Future<void> initialize() async {
    _isDisposed = false;
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/best.tflite');
      
      // Inspección dinámica de los tensores del modelo cargado
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      if (inputTensors.isEmpty || outputTensors.isEmpty) {
        throw const ModelLoadFailure(
          'El modelo no contiene tensores de entrada y salida válidos.',
        );
      }

      final inputShape = inputTensors[0].shape;
      final outputShape = outputTensors[0].shape;

      int inputWidth = 640;
      int inputHeight = 640;
      int inputChannels = 3;
      bool isNCHW = true;

      if (inputShape.length == 4) {
        if (inputShape[1] == 3) {
          // Formato NCHW: [1, 3, H, W]
          isNCHW = true;
          inputChannels = 3;
          inputHeight = inputShape[2];
          inputWidth = inputShape[3];
        } else if (inputShape[3] == 3) {
          // Formato NHWC: [1, H, W, 3]
          isNCHW = false;
          inputChannels = 3;
          inputHeight = inputShape[1];
          inputWidth = inputShape[2];
        }
      }

      int outputRows = 9;
      int outputColumns = 8400;
      bool isOutputTransposed = false;

      if (outputShape.length == 3) {
        final dim1 = outputShape[1];
        final dim2 = outputShape[2];
        // En YOLOv8, la dimensión de anclajes (ej. 8400 para 640x640, 2100 para 320x320)
        // es significativamente mayor que la dimensión de coordenadas y clases (4 + numClases).
        if (dim1 < dim2) {
          outputRows = dim1;
          outputColumns = dim2;
          isOutputTransposed = false;
        } else {
          outputRows = dim2;
          outputColumns = dim1;
          isOutputTransposed = true;
        }
      }

      _metadata = ModelMetadata(
        inputWidth: inputWidth,
        inputHeight: inputHeight,
        inputChannels: inputChannels,
        isNCHW: isNCHW,
        outputRows: outputRows,
        outputColumns: outputColumns,
        numClasses: outputRows - 4,
        isOutputTransposed: isOutputTransposed,
      );

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
      throw ModelLoadFailure('No se pudo cargar el modelo de detección: $e');
    }

    if (_labels == null || _labels!.isEmpty) {
      throw const ModelLoadFailure(
        'El archivo data.yaml no contiene etiquetas válidas.',
      );
    }
  }

  @override
  Future<List<DetectionResult>> processFrame(CameraFrame frame) async {
    if (_isDisposed ||
        _interpreter == null ||
        _metadata == null ||
        _labels == null ||
        _labels!.isEmpty) {
      return [];
    }

    final params = IsolateParams(
      address: _interpreter!.address,
      labels: _labels!,
      metadata: _metadata!,
      planes: frame.planes,
      rowStrides: frame.rowStrides,
      pixelStrides: frame.pixelStrides,
      width: frame.width,
      height: frame.height,
    );

    _activeInference = Isolate.run(() {
      return _runInferenceInIsolate(params);
    });

    try {
      return await _activeInference!;
    } on Failure {
      rethrow;
    } catch (e) {
      throw InferenceFailure('Falló la inferencia sobre el frame: $e');
    } finally {
      _activeInference = null;
    }
  }

  static List<DetectionResult> _runInferenceInIsolate(IsolateParams params) {
    final isolateInterpreter = Interpreter.fromAddress(params.address);

    // 1. Conversión directa y submuestreo YUV420 -> Float32List (0.0 a 1.0)
    final inputBuffer = _convertYUV420DirectToFloat32(
      planes: params.planes,
      rowStrides: params.rowStrides,
      pixelStrides: params.pixelStrides,
      srcWidth: params.width,
      srcHeight: params.height,
      targetWidth: params.metadata.inputWidth,
      targetHeight: params.metadata.inputHeight,
      isNCHW: params.metadata.isNCHW,
    );

    final Object inputObj = params.metadata.isNCHW
        ? (inputBuffer as List).reshape([
            1,
            params.metadata.inputChannels,
            params.metadata.inputHeight,
            params.metadata.inputWidth,
          ])
        : (inputBuffer as List).reshape([
            1,
            params.metadata.inputHeight,
            params.metadata.inputWidth,
            params.metadata.inputChannels,
          ]);

    // 2. Creación del tensor de salida dinámico según la estructura del modelo
    final int numRows = params.metadata.outputRows;
    final int numCols = params.metadata.outputColumns;
    final outputBuffer = Float32List(1 * numRows * numCols);

    final Object outputObj = params.metadata.isOutputTransposed
        ? (outputBuffer as List).reshape([1, numCols, numRows])
        : (outputBuffer as List).reshape([1, numRows, numCols]);

    // 3. Ejecutar inferencia en el hilo del isolate
    isolateInterpreter.run(inputObj, outputObj);

    // 4. Decodificación flexible de predicciones YOLOv8
    final outputList = (outputObj as List)[0];
    final List<DetectionResult> results = [];
    final int numAnchors = params.metadata.outputColumns;
    final int numClasses = math.min(params.metadata.numClasses, params.labels.length);
    final bool isTransposed = params.metadata.isOutputTransposed;

    for (int i = 0; i < numAnchors; i++) {
      double maxConf = 0.0;
      int maxClass = -1;

      for (int c = 0; c < numClasses; c++) {
        final double conf = isTransposed
            ? (outputList[i][4 + c] as num).toDouble()
            : (outputList[4 + c][i] as num).toDouble();
        if (conf > maxConf) {
          maxConf = conf;
          maxClass = c;
        }
      }

      if (maxConf > _confidenceThreshold && maxClass != -1) {
        final double xCenterRaw = isTransposed
            ? (outputList[i][0] as num).toDouble()
            : (outputList[0][i] as num).toDouble();
        final double yCenterRaw = isTransposed
            ? (outputList[i][1] as num).toDouble()
            : (outputList[1][i] as num).toDouble();
        final double wRaw = isTransposed
            ? (outputList[i][2] as num).toDouble()
            : (outputList[2][i] as num).toDouble();
        final double hRaw = isTransposed
            ? (outputList[i][3] as num).toDouble()
            : (outputList[3][i] as num).toDouble();

        // Detección automática: si las coordenadas superan 1.5, el modelo entrega píxeles absolutos [0..inputSize].
        // Si son <= 1.5, ya están normalizadas [0.0..1.0].
        final bool isNormalized =
            (xCenterRaw <= 1.5 && yCenterRaw <= 1.5 && wRaw <= 1.5 && hRaw <= 1.5);
        final double xCenter =
            isNormalized ? xCenterRaw : xCenterRaw / params.metadata.inputWidth;
        final double yCenter =
            isNormalized ? yCenterRaw : yCenterRaw / params.metadata.inputHeight;
        final double w =
            isNormalized ? wRaw : wRaw / params.metadata.inputWidth;
        final double h =
            isNormalized ? hRaw : hRaw / params.metadata.inputHeight;

        final double left = (xCenter - w / 2).clamp(0.0, 1.0);
        final double top = (yCenter - h / 2).clamp(0.0, 1.0);
        final double right = (xCenter + w / 2).clamp(0.0, 1.0);
        final double bottom = (yCenter + h / 2).clamp(0.0, 1.0);

        results.add(DetectionResult(
          label: params.labels[maxClass],
          confidence: maxConf,
          boundingBox: Rect.fromLTRB(left, top, right, bottom),
        ));
      }
    }

    return _applyNMS(results);
  }

  static const double _inv255 = 1.0 / 255.0;

  /// Conversión directa y eficiente de YUV420 a Float32List.
  ///
  /// Submuestrea las coordenadas de la cámara a la resolución requerida por el
  /// modelo en una sola pasada, sin instanciar mapas de bits intermedios (Image)
  /// ni ejecutar transformaciones de resize posteriores.
  static Float32List _convertYUV420DirectToFloat32({
    required List<Uint8List> planes,
    required List<int> rowStrides,
    required List<int> pixelStrides,
    required int srcWidth,
    required int srcHeight,
    required int targetWidth,
    required int targetHeight,
    required bool isNCHW,
  }) {
    final inputBuffer = Float32List(1 * 3 * targetWidth * targetHeight);

    final yPlane = planes[0];
    final uPlane = planes[1];
    final vPlane = planes[2];

    final int yRowStride = rowStrides[0];
    final int yPixelStride = pixelStrides[0];
    final int uvRowStride = rowStrides[1];
    final int uvPixelStride = pixelStrides[1];

    if (isNCHW) {
      final int channelSize = targetWidth * targetHeight;
      final int gOffset = channelSize;
      final int bOffset = channelSize * 2;

      for (int dy = 0; dy < targetHeight; dy++) {
        final int sy = (dy * srcHeight) ~/ targetHeight;
        final int yRowIndex = sy * yRowStride;
        final int uvRowIndex = (sy >> 1) * uvRowStride;
        final int rowPixelIndex = dy * targetWidth;

        for (int dx = 0; dx < targetWidth; dx++) {
          final int sx = (dx * srcWidth) ~/ targetWidth;
          final int yIndex = yRowIndex + sx * yPixelStride;
          final int uvIndex = uvRowIndex + (sx >> 1) * uvPixelStride;

          final int yp = yPlane[yIndex];
          final int up = uPlane[uvIndex];
          final int vp = vPlane[uvIndex];

          final int d = up - 128;
          final int e = vp - 128;

          final int r = (yp + ((1436 * e) >> 10)).clamp(0, 255);
          final int g = (yp - ((46549 * d + 93604 * e) >> 17)).clamp(0, 255);
          final int b = (yp + ((1814 * d) >> 10)).clamp(0, 255);

          final int pixelPos = rowPixelIndex + dx;
          inputBuffer[pixelPos] = r * _inv255;
          inputBuffer[gOffset + pixelPos] = g * _inv255;
          inputBuffer[bOffset + pixelPos] = b * _inv255;
        }
      }
    } else {
      int bufferIndex = 0;

      for (int dy = 0; dy < targetHeight; dy++) {
        final int sy = (dy * srcHeight) ~/ targetHeight;
        final int yRowIndex = sy * yRowStride;
        final int uvRowIndex = (sy >> 1) * uvRowStride;

        for (int dx = 0; dx < targetWidth; dx++) {
          final int sx = (dx * srcWidth) ~/ targetWidth;
          final int yIndex = yRowIndex + sx * yPixelStride;
          final int uvIndex = uvRowIndex + (sx >> 1) * uvPixelStride;

          final int yp = yPlane[yIndex];
          final int up = uPlane[uvIndex];
          final int vp = vPlane[uvIndex];

          final int d = up - 128;
          final int e = vp - 128;

          final int r = (yp + ((1436 * e) >> 10)).clamp(0, 255);
          final int g = (yp - ((46549 * d + 93604 * e) >> 17)).clamp(0, 255);
          final int b = (yp + ((1814 * d) >> 10)).clamp(0, 255);

          inputBuffer[bufferIndex++] = r * _inv255;
          inputBuffer[bufferIndex++] = g * _inv255;
          inputBuffer[bufferIndex++] = b * _inv255;
        }
      }
    }

    return inputBuffer;
  }

  /// Supresión de no máximos (NMS) con cálculo de IoU real.
  ///
  /// Descarta falsos positivos y duplicados fuertemente solapados para la misma clase,
  /// permitiendo reconocer múltiples porciones separadas del mismo alimento.
  static List<DetectionResult> _applyNMS(
    List<DetectionResult> boxes, {
    double iouThreshold = 0.45,
  }) {
    if (boxes.isEmpty) return [];

    final sorted = List<DetectionResult>.from(boxes)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final List<DetectionResult> selected = [];

    for (final candidate in sorted) {
      bool shouldSelect = true;

      for (final accepted in selected) {
        if (candidate.label == accepted.label) {
          final double iou = _calculateIoU(candidate.boundingBox, accepted.boundingBox);
          if (iou > iouThreshold) {
            shouldSelect = false;
            break;
          }
        }
      }

      if (shouldSelect) {
        selected.add(candidate);
      }
    }

    return selected;
  }

  /// Calcula el índice IoU (Intersection over Union) entre dos rectángulos delimitadores.
  static double _calculateIoU(Rect a, Rect b) {
    final double left = math.max(a.left, b.left);
    final double top = math.max(a.top, b.top);
    final double right = math.min(a.right, b.right);
    final double bottom = math.min(a.bottom, b.bottom);

    final double width = right - left;
    final double height = bottom - top;

    if (width <= 0.0 || height <= 0.0) {
      return 0.0;
    }

    final double intersectionArea = width * height;
    final double areaA = a.width * a.height;
    final double areaB = b.width * b.height;
    final double unionArea = areaA + areaB - intersectionArea;

    if (unionArea <= 0.0) return 0.0;
    return intersectionArea / unionArea;
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    if (_activeInference != null) {
      try {
        await _activeInference;
      } catch (_) {
        // Ignorar errores del isolate al cerrar
      }
    }
    _interpreter?.close();
    _interpreter = null;
    _metadata = null;
  }
}

