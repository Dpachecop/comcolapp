import 'package:equatable/equatable.dart';
import 'package:camera/camera.dart';

abstract class CameraEvent extends Equatable {
  const CameraEvent();

  @override
  List<Object?> get props => [];
}

class InitializeCamera extends CameraEvent {}

class FrameCaptured extends CameraEvent {
  final CameraImage image;

  const FrameCaptured(this.image);

  @override
  List<Object?> get props => [image];
}

class DisposeCamera extends CameraEvent {}
