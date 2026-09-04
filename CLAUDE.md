# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ComColApp — Flutter app that detects Colombian street foods in real time from the camera feed using an on-device YOLOv8 TFLite model, then shows nutritional info for the detected dish. UI copy, comments, and commit messages are in Spanish (conventional-commit prefixes: `feat(ux):`, `fix(tflite):`, `refactor:`).

The model recognizes exactly 5 classes, defined in `assets/models/data.yaml`: `arepa`, `bunuelo`, `dedito`, `empanada`, `patacon`.

## Commands

```bash
flutter pub get
flutter run                          # device/emulator required — camera + TFLite do not work on web/desktop
flutter analyze                      # lint (flutter_lints via analysis_options.yaml); must stay clean, CI gates on it
flutter test
flutter test test/path_test.dart --plain-name "nombre del test"   # single test
flutter build apk

# Regenerate DI after adding/changing @injectable / @LazySingleton annotations:
dart run build_runner build --delete-conflicting-outputs
```

CI (`.github/workflows/ci.yml`) runs on every PR: `pub get` → verifies `injection.config.dart` is up to date → `analyze` → `test`. Commit the regenerated `injection.config.dart` or CI fails.

## Architecture

Clean Architecture, feature-first. Single feature: `lib/features/food_detection/{data,domain,presentation}`, plus `lib/core/{errors,injection,routing,services}`.

**DI (get_it + injectable):** `configureDependencies()` in `main.dart` calls the generated `injection.config.dart`. `TfliteLocalDataSource` and `CameraService` are **lazy singletons** (they hold native resources); `FoodDetectionRepository`, `NutritionRepository` and `CameraBloc` are factories. Never edit `injection.config.dart` by hand — re-run build_runner.

**Routing:** `go_router` with two routes in `lib/core/routing/app_router.dart` — `/` (HomeScreen) and `/camera` (CameraScreen).

**Error handling:** `lib/core/errors/failures.dart` defines a `sealed class Failure implements Exception`. Data-layer code throws these; `CameraBloc` catches `on Failure` and emits `CameraError(failure)`, wrapping anything else in `UnknownFailure`. Because `Failure` is sealed, adding a case makes non-exhaustive `switch`es fail to compile. **Do not swallow errors in `catch` blocks** — that was the original bug this replaced.

**Camera access:** the `camera` plugin is reachable only through `CameraService` (contract in `lib/core/services/camera_service.dart`, impl in `camera_service_impl.dart`). `CameraServiceImpl` is the only file in the app that knows `CameraController`. It exposes frames as `Stream<CameraFrame>` and the preview as `buildPreview()` — deliberately a `Widget`, so presentation never touches the plugin either. This exists to make `CameraBloc` testable: `availableCameras()` is a plugin global that cannot be stubbed.

**Detection pipeline** (the part that requires reading several files to understand):

1. `CameraBloc._onInitializeCamera` initializes the detection repository (loads model + labels), then `CameraService.initialize()`, then subscribes to `CameraService.frames`.
2. `_onServiceFrame` throttles hard: only **1 in every 10 frames** (`_frameSkip`) becomes a `FrameCaptured` event, and only if `_isProcessing` is false. Both guards matter — removing either saturates CPU/memory and crashes the isolate.
3. `FoodDetectionRepositoryImpl` delegates to `TfliteLocalDataSourceImpl.processFrame`, which packs the YUV planes, strides, and the interpreter's **native address** into `IsolateParams` and runs inference in a background isolate via `Isolate.run`. The interpreter is rebuilt inside the isolate with `Interpreter.fromAddress`.
4. Inside the isolate: YUV420 → RGB conversion, resize to 640×640, build an **NCHW** `[1, 3, 640, 640]` Float32 tensor normalized by `/255.0`, run, then decode the `[1, 4+numClasses, 8400]` output.
5. The bloc resolves the nutrition card for the highest-confidence detection via `NutritionRepository` and emits `CameraReady(detections, nutrition)`. `CameraScreen`'s `BlocConsumer` opens the bottom sheet when `nutrition != null`, guarded by `_isModalOpen` so it fires once.

`CameraFrame` (`domain/entities/camera_frame.dart`) is a plugin-free representation of a YUV420 frame. The conversion from `CameraImage` happens once, in `CameraServiceImpl`; everything downstream is pure Dart and unit-testable.

### Gotchas in the detection code

- **Isolate lifecycle / SIGSEGV:** `dispose()` awaits `_activeInference` before calling `_interpreter?.close()`, and `_isDisposed` short-circuits new work. A past crash (`SIGSEGV`, commit `0b48d80`) came from closing the interpreter while an isolate still held its address. Preserve this ordering when touching lifecycle code.
- **Model output coordinates are already normalized (0–1)** — do *not* divide box values by 640. See the comment in `_runInferenceInIsolate`.
- `_applyNMS` is not real NMS: it keeps only the single highest-confidence detection per class, so two portions of the same food cannot be represented. Real IoU suppression is still pending (`TODO` in the file).
- Bounding boxes are computed into `DetectionResult.boundingBox` but deliberately **not rendered** — commit `9c38b04` removed the overlay in favor of chips + the nutrition sheet.
- Per-frame `InferenceFailure` is intentionally swallowed in `_onFrameCaptured`: one bad frame shouldn't kill the camera session. Every other `Failure` surfaces as `CameraError`.

### Tests

`test/` mirrors `lib/`. Uses `bloc_test` + `mocktail` (no codegen — mocks are hand-declared `class MockX extends Mock implements X {}`). `camera_bloc_test.dart` covers init success/failure paths, nutrition resolution, error classification, throttling and disposal by injecting mock `CameraService` / repositories, plus a fake frame stream. `nutrition_repository_impl_test.dart` asserts that the model's 5 labels and the nutrition map stay in sync — it fails if you add a class to `data.yaml` without a nutrition card.

### Nutrition data

`data/datasources/local_nutrition_data.dart` is a hardcoded `Map<String, NutritionInfo>`, reached only through `NutritionRepository` (impl in `data/repositories/nutrition_repository_impl.dart`, which owns the `label.toLowerCase()` normalization). Keys must be the **lowercase label strings from `data.yaml`**; a missing key yields `null` and no modal is shown. Adding a model class means adding both a label in `data.yaml` and an entry here.

`NutritionInfo` lives in `domain/entities/`, so the presentation layer never imports from `data/`.

## Platform notes

- Android: `minSdk 21`, `compileSdk 36`, NDK `27.0.12077973`; `aaptOptions { noCompress("tflite") }` is required — without it the model asset can't be memory-mapped.
- iOS: `Info.plist` has **no** `NSCameraUsageDescription`, so the camera will fail on iOS until it is added. Runtime permission denial is mapped to `CameraPermissionFailure` and the error view offers a retry, but the OS-level prompt still needs the plist entry.
- `applicationId` is still `com.example.comcolapp` and release builds are signed with debug keys — both block publishing.
- Swapping the model means replacing both `assets/models/best.tflite` and `assets/models/data.yaml`, and checking the hardcoded `inputSize = 640` / `numColumns = 8400` assumptions.
