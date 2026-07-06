import 'package:camera/camera.dart';
import 'package:injectable/injectable.dart';
import '../../domain/entities/detection_result.dart';
import '../../domain/repositories/food_detection_repository.dart';
import '../datasources/tflite_local_data_source.dart';

@Injectable(as: FoodDetectionRepository)
class FoodDetectionRepositoryImpl implements FoodDetectionRepository {
  final TfliteLocalDataSource _dataSource;

  FoodDetectionRepositoryImpl(this._dataSource);

  @override
  Future<List<DetectionResult>> detectFood(CameraImage image) async {
    return _dataSource.processImage(image);
  }
}
