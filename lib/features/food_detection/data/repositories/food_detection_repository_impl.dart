import 'package:injectable/injectable.dart';
import '../../domain/entities/camera_frame.dart';
import '../../domain/entities/detection_result.dart';
import '../../domain/repositories/food_detection_repository.dart';
import '../datasources/tflite_local_data_source.dart';

@Injectable(as: FoodDetectionRepository)
class FoodDetectionRepositoryImpl implements FoodDetectionRepository {
  final TfliteLocalDataSource _dataSource;

  FoodDetectionRepositoryImpl(this._dataSource);

  @override
  Future<void> initialize() => _dataSource.initialize();

  @override
  Future<List<DetectionResult>> detectFood(CameraFrame frame) {
    return _dataSource.processFrame(frame);
  }

  @override
  Future<void> dispose() => _dataSource.dispose();
}
