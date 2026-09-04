import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';

import '../../features/food_detection/domain/entities/camera_frame.dart';
import '../errors/failures.dart';
import 'camera_service.dart';

/// Implementación de [CameraService] sobre el plugin `camera`.
///
/// Es el único punto de la app que conoce `CameraController`.
@LazySingleton(as: CameraService)
class CameraServiceImpl implements CameraService {
  CameraController? _controller;
  StreamController<CameraFrame>? _frames;

  @override
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  @override
  Stream<CameraFrame> get frames =>
      (_frames ??= StreamController<CameraFrame>.broadcast()).stream;

  @override
  Future<void> initialize() async {
    if (isInitialized) return;

    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException catch (e) {
      throw _mapCameraException(e);
    }

    if (cameras.isEmpty) throw const NoCameraAvailableFailure();

    final controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      throw _mapCameraException(e);
    }

    _controller = controller;
    _frames ??= StreamController<CameraFrame>.broadcast();

    await controller.startImageStream((image) {
      if (_frames?.isClosed ?? true) return;
      _frames!.add(_toCameraFrame(image));
    });
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controller);
  }

  @override
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;

    if (controller != null) {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    }

    await _frames?.close();
    _frames = null;
  }

  static CameraFrame _toCameraFrame(CameraImage image) => CameraFrame(
        planes: image.planes.map((p) => p.bytes).toList(),
        rowStrides: image.planes.map((p) => p.bytesPerRow).toList(),
        pixelStrides: image.planes.map((p) => p.bytesPerPixel ?? 1).toList(),
        width: image.width,
        height: image.height,
      );

  static Failure _mapCameraException(CameraException e) {
    // Códigos del plugin `camera` para permiso denegado en Android e iOS.
    const deniedCodes = {
      'CameraAccessDenied',
      'CameraAccessDeniedWithoutPrompt',
      'CameraAccessRestricted',
      'AudioAccessDenied',
    };
    if (deniedCodes.contains(e.code)) return const CameraPermissionFailure();
    return CameraFailure(e.description ?? 'No se pudo iniciar la cámara.');
  }
}
