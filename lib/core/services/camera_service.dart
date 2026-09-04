import 'package:flutter/widgets.dart';

import '../../features/food_detection/domain/entities/camera_frame.dart';

/// Abstracción sobre la cámara del dispositivo.
///
/// Aísla al bloc de `CameraController` y de `availableCameras()`, que son
/// globales del plugin e imposibles de sustituir en tests. La implementación
/// real vive en [CameraServiceImpl]; en tests se inyecta un doble.
abstract class CameraService {
  /// `true` cuando [initialize] terminó correctamente y la cámara está viva.
  bool get isInitialized;

  /// Frames del preview, ya convertidos a un tipo propio del dominio.
  ///
  /// Emite a la tasa de la cámara: el consumidor decide cuáles procesar.
  Stream<CameraFrame> get frames;

  /// Abre la cámara y arranca el stream de frames.
  ///
  /// Lanza [NoCameraAvailableFailure], [CameraPermissionFailure] o
  /// [CameraFailure].
  Future<void> initialize();

  /// Widget de preview de la cámara.
  ///
  /// Devuelve el preview como widget en lugar de exponer el `CameraController`
  /// para que la capa de presentación no dependa del plugin. Debe llamarse solo
  /// cuando [isInitialized] es `true`.
  Widget buildPreview();

  /// Detiene el stream y libera la cámara. Es seguro llamarlo varias veces.
  Future<void> dispose();
}
