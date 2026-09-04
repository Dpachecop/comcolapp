import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:comcolapp/core/errors/failures.dart';
import 'package:comcolapp/core/services/camera_service.dart';
import 'package:comcolapp/features/food_detection/domain/entities/camera_frame.dart';
import 'package:comcolapp/features/food_detection/domain/entities/detection_result.dart';
import 'package:comcolapp/features/food_detection/domain/entities/nutrition_info.dart';
import 'package:comcolapp/features/food_detection/domain/repositories/food_detection_repository.dart';
import 'package:comcolapp/features/food_detection/domain/repositories/nutrition_repository.dart';
import 'package:comcolapp/features/food_detection/presentation/bloc/camera_bloc.dart';
import 'package:comcolapp/features/food_detection/presentation/bloc/camera_event.dart';
import 'package:comcolapp/features/food_detection/presentation/bloc/camera_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFoodDetectionRepository extends Mock implements FoodDetectionRepository {}

class MockNutritionRepository extends Mock implements NutritionRepository {}

class MockCameraService extends Mock implements CameraService {}

final _frame = CameraFrame(
  planes: [Uint8List(4), Uint8List(2), Uint8List(2)],
  rowStrides: const [2, 2, 2],
  pixelStrides: const [1, 2, 2],
  width: 2,
  height: 2,
);

const _arepa = DetectionResult(
  label: 'arepa',
  confidence: 0.91,
  boundingBox: Rect.fromLTRB(0, 0, 1, 1),
);

const _patacon = DetectionResult(
  label: 'patacon',
  confidence: 0.62,
  boundingBox: Rect.fromLTRB(0, 0, 1, 1),
);

const _arepaInfo = NutritionInfo(
  title: 'Arepa de maíz amarillo',
  description: 'Torta circular de maíz.',
  portion: '100g',
  calories: 170,
  carbs: 40.5,
  protein: 4.3,
  fat: 0.6,
);

void main() {
  late MockFoodDetectionRepository detectionRepository;
  late MockNutritionRepository nutritionRepository;
  late MockCameraService cameraService;
  late StreamController<CameraFrame> frameController;

  setUpAll(() {
    registerFallbackValue(_frame);
  });

  setUp(() {
    detectionRepository = MockFoodDetectionRepository();
    nutritionRepository = MockNutritionRepository();
    cameraService = MockCameraService();
    frameController = StreamController<CameraFrame>.broadcast();

    when(() => detectionRepository.initialize()).thenAnswer((_) async {});
    when(() => detectionRepository.dispose()).thenAnswer((_) async {});
    when(() => cameraService.initialize()).thenAnswer((_) async {});
    when(() => cameraService.dispose()).thenAnswer((_) async {});
    when(() => cameraService.frames).thenAnswer((_) => frameController.stream);
  });

  tearDown(() => frameController.close());

  CameraBloc buildBloc() => CameraBloc(
        detectionRepository,
        nutritionRepository,
        cameraService,
      );

  group('InitializeCamera', () {
    blocTest<CameraBloc, CameraState>(
      'carga el modelo y abre la cámara',
      build: buildBloc,
      act: (bloc) => bloc.add(const InitializeCamera()),
      expect: () => const [CameraLoading(), CameraReady()],
      verify: (_) {
        verify(() => detectionRepository.initialize()).called(1);
        verify(() => cameraService.initialize()).called(1);
      },
    );

    blocTest<CameraBloc, CameraState>(
      'emite CameraError cuando el modelo no carga',
      build: () {
        when(() => detectionRepository.initialize())
            .thenThrow(const ModelLoadFailure());
        return buildBloc();
      },
      act: (bloc) => bloc.add(const InitializeCamera()),
      expect: () => const [CameraLoading(), CameraError(ModelLoadFailure())],
      verify: (_) {
        // La cámara no debe abrirse si el modelo falló.
        verifyNever(() => cameraService.initialize());
      },
    );

    blocTest<CameraBloc, CameraState>(
      'emite CameraError cuando se niega el permiso de cámara',
      build: () {
        when(() => cameraService.initialize())
            .thenThrow(const CameraPermissionFailure());
        return buildBloc();
      },
      act: (bloc) => bloc.add(const InitializeCamera()),
      expect: () =>
          const [CameraLoading(), CameraError(CameraPermissionFailure())],
    );

    blocTest<CameraBloc, CameraState>(
      'envuelve excepciones inesperadas en UnknownFailure',
      build: () {
        when(() => cameraService.initialize()).thenThrow(StateError('boom'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const InitializeCamera()),
      expect: () => [
        const CameraLoading(),
        isA<CameraError>().having(
          (s) => s.failure,
          'failure',
          isA<UnknownFailure>(),
        ),
      ],
    );
  });

  group('FrameCaptured', () {
    blocTest<CameraBloc, CameraState>(
      'emite las detecciones con la ficha nutricional resuelta',
      build: () {
        when(() => detectionRepository.detectFood(any()))
            .thenAnswer((_) async => const [_arepa]);
        when(() => nutritionRepository.getNutritionFor('arepa'))
            .thenReturn(_arepaInfo);
        return buildBloc();
      },
      seed: () => const CameraReady(),
      act: (bloc) => bloc.add(FrameCaptured(_frame)),
      expect: () => const [
        CameraReady(detections: [_arepa], nutrition: _arepaInfo),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'resuelve la nutrición de la detección con mayor confianza',
      build: () {
        when(() => detectionRepository.detectFood(any()))
            .thenAnswer((_) async => const [_patacon, _arepa]);
        when(() => nutritionRepository.getNutritionFor(any()))
            .thenReturn(_arepaInfo);
        return buildBloc();
      },
      seed: () => const CameraReady(),
      act: (bloc) => bloc.add(FrameCaptured(_frame)),
      verify: (_) {
        // 'arepa' tiene 0.91 contra 0.62 de 'patacon'.
        verify(() => nutritionRepository.getNutritionFor('arepa')).called(1);
        verifyNever(() => nutritionRepository.getNutritionFor('patacon'));
      },
    );

    blocTest<CameraBloc, CameraState>(
      'deja nutrition en null cuando el alimento no tiene datos',
      build: () {
        when(() => detectionRepository.detectFood(any()))
            .thenAnswer((_) async => const [_arepa]);
        when(() => nutritionRepository.getNutritionFor(any())).thenReturn(null);
        return buildBloc();
      },
      seed: () => const CameraReady(),
      act: (bloc) => bloc.add(FrameCaptured(_frame)),
      expect: () => const [CameraReady(detections: [_arepa])],
    );

    blocTest<CameraBloc, CameraState>(
      'ignora un InferenceFailure puntual sin tumbar la sesión',
      build: () {
        when(() => detectionRepository.detectFood(any()))
            .thenThrow(const InferenceFailure());
        return buildBloc();
      },
      seed: () => const CameraReady(),
      act: (bloc) => bloc.add(FrameCaptured(_frame)),
      expect: () => const <CameraState>[],
    );

    blocTest<CameraBloc, CameraState>(
      'propaga un Failure no transitorio como CameraError',
      build: () {
        when(() => detectionRepository.detectFood(any()))
            .thenThrow(const ModelLoadFailure());
        return buildBloc();
      },
      seed: () => const CameraReady(),
      act: (bloc) => bloc.add(FrameCaptured(_frame)),
      expect: () => const [CameraError(ModelLoadFailure())],
    );

    blocTest<CameraBloc, CameraState>(
      'ignora frames si la cámara no está lista',
      build: buildBloc,
      act: (bloc) => bloc.add(FrameCaptured(_frame)),
      expect: () => const <CameraState>[],
      verify: (_) {
        verifyNever(() => detectionRepository.detectFood(any()));
      },
    );
  });

  group('ciclo de vida', () {
    test('close() libera la cámara y el intérprete', () async {
      final bloc = buildBloc();
      bloc.add(const InitializeCamera());
      await bloc.stream.firstWhere((s) => s is CameraReady);

      await bloc.close();

      verify(() => cameraService.dispose()).called(1);
      verify(() => detectionRepository.dispose()).called(1);
    });

    test('procesa 1 de cada 10 frames del servicio', () async {
      when(() => detectionRepository.detectFood(any()))
          .thenAnswer((_) async => const [_arepa]);
      when(() => nutritionRepository.getNutritionFor(any()))
          .thenReturn(_arepaInfo);

      final bloc = buildBloc();
      bloc.add(const InitializeCamera());
      await bloc.stream.firstWhere((s) => s is CameraReady);

      for (var i = 0; i < 20; i++) {
        frameController.add(_frame);
      }
      await Future<void>.delayed(Duration.zero);

      verify(() => detectionRepository.detectFood(any())).called(2);
      await bloc.close();
    });
  });
}
