import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/services/camera_service.dart';
import '../../domain/entities/camera_frame.dart';
import '../../domain/entities/detection_result.dart';
import '../../domain/entities/nutrition_info.dart';
import '../../domain/repositories/food_detection_repository.dart';
import '../../domain/repositories/nutrition_repository.dart';
import 'camera_event.dart';
import 'camera_state.dart';

@injectable
class CameraBloc extends Bloc<CameraEvent, CameraState> {
  CameraBloc(
    this._detectionRepository,
    this._nutritionRepository,
    this._cameraService,
  ) : super(const CameraInitial()) {
    on<InitializeCamera>(_onInitializeCamera);
    on<FrameCaptured>(_onFrameCaptured);
  }

  final FoodDetectionRepository _detectionRepository;
  final NutritionRepository _nutritionRepository;
  final CameraService _cameraService;

  /// Se procesa 1 de cada [_frameSkip] frames. Sin este filtro la inferencia
  /// satura CPU y memoria.
  static const int _frameSkip = 10;

  StreamSubscription<CameraFrame>? _frameSubscription;
  bool _isProcessing = false;
  int _frameCount = 0;

  Future<void> _onInitializeCamera(
    InitializeCamera event,
    Emitter<CameraState> emit,
  ) async {
    emit(const CameraLoading());
    try {
      await _detectionRepository.initialize();
      await _cameraService.initialize();

      _frameSubscription = _cameraService.frames.listen(_onServiceFrame);
      emit(const CameraReady());
    } on Failure catch (failure) {
      emit(CameraError(failure));
    } catch (e) {
      emit(CameraError(UnknownFailure(e.toString())));
    }
  }

  /// Filtra los frames del servicio antes de convertirlos en eventos.
  void _onServiceFrame(CameraFrame frame) {
    _frameCount++;
    if (_frameCount % _frameSkip != 0 || _isProcessing) return;
    if (isClosed) return;
    add(FrameCaptured(frame));
  }

  Future<void> _onFrameCaptured(
    FrameCaptured event,
    Emitter<CameraState> emit,
  ) async {
    if (state is! CameraReady) return;
    _isProcessing = true;

    try {
      final results = await _detectionRepository.detectFood(event.frame);
      emit(CameraReady(
        detections: results,
        nutrition: _resolveNutrition(results),
      ));
    } on InferenceFailure {
      // Un frame que falla es transitorio: se descarta y se sigue con el
      // siguiente en lugar de tumbar la sesión de cámara.
    } on Failure catch (failure) {
      emit(CameraError(failure));
    } finally {
      _isProcessing = false;
    }
  }

  /// Busca la ficha nutricional de la detección con mayor confianza.
  NutritionInfo? _resolveNutrition(List<DetectionResult> detections) {
    if (detections.isEmpty) return null;

    final best = detections.reduce((a, b) => a.confidence > b.confidence ? a : b);
    return _nutritionRepository.getNutritionFor(best.label);
  }

  @override
  Future<void> close() async {
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    await _cameraService.dispose();
    await _detectionRepository.dispose();
    return super.close();
  }
}
