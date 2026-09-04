import 'dart:typed_data';

/// Un frame crudo en formato YUV420, independiente del plugin de cámara.
///
/// Existe para que el dominio y el pipeline de inferencia no dependan de
/// `CameraImage` del paquete `camera`. La conversión desde el plugin ocurre
/// una sola vez, en `CameraServiceImpl`.
class CameraFrame {
  const CameraFrame({
    required this.planes,
    required this.rowStrides,
    required this.pixelStrides,
    required this.width,
    required this.height,
  });

  final List<Uint8List> planes;
  final List<int> rowStrides;
  final List<int> pixelStrides;
  final int width;
  final int height;
}
