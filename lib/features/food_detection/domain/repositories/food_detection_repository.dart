import '../entities/camera_frame.dart';
import '../entities/detection_result.dart';

abstract class FoodDetectionRepository {
  /// Carga el modelo y las etiquetas. Lanza `ModelLoadFailure` si falla.
  Future<void> initialize();

  /// Detecta alimentos en un frame. Lanza `InferenceFailure` si falla.
  Future<List<DetectionResult>> detectFood(CameraFrame frame);

  /// Libera el intérprete nativo.
  Future<void> dispose();
}
