import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:injectable/injectable.dart';
import '../../domain/repositories/food_detection_repository.dart';
import '../../data/datasources/tflite_local_data_source.dart';
import 'camera_event.dart';
import 'camera_state.dart';

@injectable
class CameraBloc extends Bloc<CameraEvent, CameraState> {
  final FoodDetectionRepository _repository;
  final TfliteLocalDataSource _tfliteDataSource;
  
  CameraController? _controller;
  bool _isProcessing = false;
  int _frameCount = 0;

  CameraBloc(this._repository, this._tfliteDataSource) : super(CameraInitial()) {
    on<InitializeCamera>(_onInitializeCamera);
    on<FrameCaptured>(_onFrameCaptured);
    on<DisposeCamera>(_onDisposeCamera);
  }

  Future<void> _onInitializeCamera(InitializeCamera event, Emitter<CameraState> emit) async {
    emit(CameraLoading());
    try {
      await _tfliteDataSource.initialize();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        emit(const CameraError('No cameras available'));
        return;
      }

      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      
      _controller!.startImageStream((image) {
        // Procesar 1 de cada 10 frames para no saturar memoria/CPU
        _frameCount++;
        if (_frameCount % 10 == 0 && !_isProcessing) {
          add(FrameCaptured(image));
        }
      });

      emit(CameraReady(controller: _controller!));
    } catch (e) {
      emit(CameraError(e.toString()));
    }
  }

  Future<void> _onFrameCaptured(FrameCaptured event, Emitter<CameraState> emit) async {
    if (state is! CameraReady && state is! CameraDetectionSuccess) return;
    _isProcessing = true;

    try {
      final results = await _repository.detectFood(event.image);
      
      // Emitimos el nuevo estado con las detecciones si el controlador sigue activo
      if (_controller != null && _controller!.value.isInitialized) {
        final currentController = (state is CameraReady) 
            ? (state as CameraReady).controller 
            : (state is CameraDetectionSuccess ? (state as CameraDetectionSuccess).controller : _controller!);

        emit(CameraDetectionSuccess(
          controller: currentController,
          detections: results,
        ));
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _onDisposeCamera(DisposeCamera event, Emitter<CameraState> emit) async {
    if (_controller != null) {
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
      await _controller!.dispose();
      _controller = null;
    }
    _tfliteDataSource.dispose();
    emit(CameraInitial());
  }
}
