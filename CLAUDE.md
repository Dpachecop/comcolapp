# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ComColApp — Flutter app that detects Colombian street foods in real time from the camera feed using an on-device YOLOv8 TFLite model, then shows nutritional info for the detected dish. UI copy, comments, and commit messages are in Spanish (conventional-commit prefixes: `feat(ux):`, `fix(tflite):`, `refactor:`).

The model recognizes exactly 5 classes, defined in `assets/models/data.yaml`: `arepa`, `bunuelo`, `dedito`, `empanada`, `patacon`.

## Commands

```bash
flutter pub get
flutter run                          # device/emulator required — camera + TFLite do not work on web/desktop
flutter analyze                      # lint (flutter_lints via analysis_options.yaml)
flutter build apk

# Regenerate DI after adding/changing @injectable / @LazySingleton annotations:
dart run build_runner build --delete-conflicting-outputs
```

There is no `test/` directory yet. If tests are added, run them with `flutter test` and a single test with `flutter test test/path_test.dart --plain-name "test name"`.

## Architecture

Clean Architecture, feature-first. Single feature: `lib/features/food_detection/{data,domain,presentation}`, plus `lib/core/{injection,routing}`.

**DI (get_it + injectable):** `configureDependencies()` in `main.dart` calls the generated `injection.config.dart`. `TfliteLocalDataSource` is a **lazy singleton** (holds the native interpreter); `FoodDetectionRepository`, `NutritionRepository` and `CameraBloc` are factories. Never edit `injection.config.dart` by hand — re-run build_runner.

**Routing:** `go_router` with two routes in `lib/core/routing/app_router.dart` — `/` (HomeScreen) and `/camera` (CameraScreen).

**Detection pipeline** (the part that requires reading several files to understand):

1. `CameraBloc._onInitializeCamera` initializes the TFLite data source, opens the first camera at `ResolutionPreset.medium`, and starts an image stream.
2. The stream callback throttles hard: only **1 in every 10 frames** is dispatched as `FrameCaptured`, and only if `_isProcessing` is false. Both guards matter — removing either saturates CPU/memory and crashes the isolate.
3. `FoodDetectionRepositoryImpl` delegates to `TfliteLocalDataSourceImpl.processImage`, which packs the raw YUV planes, strides, and the interpreter's **native address** into `IsolateParams` and runs inference in a background isolate via `Isolate.run`. The interpreter is rebuilt inside the isolate with `Interpreter.fromAddress`.
4. Inside the isolate: YUV420 → RGB conversion, resize to 640×640, build an **NCHW** `[1, 3, 640, 640]` Float32 tensor normalized by `/255.0`, run, then decode the `[1, 4+numClasses, 8400]` output.
5. The bloc resolves the nutrition card for the highest-confidence detection via `NutritionRepository` and emits it inside `CameraDetectionSuccess.nutrition`. `CameraScreen`'s `BlocListener` just opens the bottom sheet when that field is non-null, guarded by the `isModalOpen` flag so it fires once.

### Gotchas in the detection code

- **Isolate lifecycle / SIGSEGV:** `dispose()` awaits `_activeInference` before calling `_interpreter?.close()`, and `_isDisposed` short-circuits new work. A past crash (`SIGSEGV`, commit `0b48d80`) came from closing the interpreter while an isolate still held its address. Preserve this ordering when touching lifecycle code.
- **Model output coordinates are already normalized (0–1)** — do *not* divide box values by 640. See the comment at `tflite_local_data_source.dart:172`.
- `_applyNMS` is not real NMS: it keeps only the single highest-confidence detection per class. `_calculateIoU` and `_iouThreshold` are currently unused leftovers.
- Bounding boxes are computed into `DetectionResult.boundingBox` but deliberately **not rendered** — commit `9c38b04` removed the overlay in favor of chips + the nutrition sheet.
- `initialize()` swallows asset-loading errors silently; if labels fail to load, `processImage` just returns `[]` and detection appears broken with no error state.

### Nutrition data

`data/datasources/local_nutrition_data.dart` is a hardcoded `Map<String, NutritionInfo>`, reached only through `NutritionRepository` (impl in `data/repositories/nutrition_repository_impl.dart`, which owns the `label.toLowerCase()` normalization). Keys must be the **lowercase label strings from `data.yaml`**; a missing key yields `null` and no modal is shown. Adding a model class means adding both a label in `data.yaml` and an entry here.

`NutritionInfo` lives in `domain/entities/`, so the presentation layer never imports from `data/`.

## Platform notes

- Android: `minSdk 21`, `compileSdk 36`, NDK `27.0.12077973`; `aaptOptions { noCompress("tflite") }` is required — without it the model asset can't be memory-mapped.
- iOS: `Info.plist` has **no** `NSCameraUsageDescription`, so the camera will fail on iOS until it is added.
- Swapping the model means replacing both `assets/models/best.tflite` and `assets/models/data.yaml`, and checking the hardcoded `inputSize = 640` / `numColumns = 8400` assumptions.
