import 'package:equatable/equatable.dart';
import '../../domain/entities/camera_frame.dart';

sealed class CameraEvent extends Equatable {
  const CameraEvent();

  @override
  List<Object?> get props => [];
}

/// Carga el modelo y abre la cámara.
class InitializeCamera extends CameraEvent {
  const InitializeCamera();
}

/// Un frame seleccionado para inferencia (ya pasó el filtro de throttling).
class FrameCaptured extends CameraEvent {
  const FrameCaptured(this.frame);

  final CameraFrame frame;

  @override
  List<Object?> get props => [frame];
}
