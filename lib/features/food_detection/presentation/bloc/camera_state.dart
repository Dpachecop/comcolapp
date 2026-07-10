import 'package:equatable/equatable.dart';
import 'package:camera/camera.dart';
import '../../domain/entities/detection_result.dart';

abstract class CameraState extends Equatable {
  const CameraState();

  @override
  List<Object?> get props => [];
}

class CameraInitial extends CameraState {}

class CameraLoading extends CameraState {}

class CameraReady extends CameraState {
  final CameraController controller;
  final List<DetectionResult> detections;

  const CameraReady({
    required this.controller,
    this.detections = const [],
  });

  @override
  List<Object?> get props => [controller, detections];
}

class CameraDetectionSuccess extends CameraState {
  final CameraController controller;
  final List<DetectionResult> detections;

  const CameraDetectionSuccess({
    required this.controller,
    required this.detections,
  });

  @override
  List<Object?> get props => [controller, detections];
}

class CameraError extends CameraState {
  final String message;

  const CameraError(this.message);

  @override
  List<Object?> get props => [message];
}
