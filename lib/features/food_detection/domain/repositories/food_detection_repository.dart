import 'package:camera/camera.dart';
import '../entities/detection_result.dart';

abstract class FoodDetectionRepository {
  Future<List<DetectionResult>> detectFood(CameraImage image);
}
