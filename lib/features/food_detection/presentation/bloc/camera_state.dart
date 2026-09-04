import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/detection_result.dart';
import '../../domain/entities/nutrition_info.dart';

/// Estados de la pantalla de cámara.
///
/// Es `sealed` para que los `switch` en la UI sean exhaustivos: agregar un
/// estado nuevo rompe la compilación hasta que la vista lo contemple.
///
/// Nota: ningún estado guarda el `CameraController`. El preview se obtiene del
/// `CameraService`, de modo que la presentación no depende del plugin y los
/// estados se pueden comparar por valor de verdad con Equatable.
sealed class CameraState extends Equatable {
  const CameraState();

  @override
  List<Object?> get props => [];
}

class CameraInitial extends CameraState {
  const CameraInitial();
}

class CameraLoading extends CameraState {
  const CameraLoading();
}

/// Cámara activa. `detections` está vacío hasta la primera inferencia.
class CameraReady extends CameraState {
  const CameraReady({
    this.detections = const [],
    this.nutrition,
  });

  final List<DetectionResult> detections;

  /// Ficha nutricional de la detección con mayor confianza, o `null` si no hay
  /// detecciones o el alimento no tiene datos registrados.
  final NutritionInfo? nutrition;

  @override
  List<Object?> get props => [detections, nutrition];
}

class CameraError extends CameraState {
  const CameraError(this.failure);

  final Failure failure;

  String get message => failure.message;

  @override
  List<Object?> get props => [failure];
}
