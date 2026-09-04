import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/injection/injection.dart';
import '../../../../core/services/camera_service.dart';
import '../../domain/entities/nutrition_info.dart';
import '../bloc/camera_bloc.dart';
import '../bloc/camera_event.dart';
import '../bloc/camera_state.dart';
import '../widgets/detection_chips.dart';
import '../widgets/nutrition_sheet.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CameraBloc>()..add(const InitializeCamera()),
      child: const _CameraScreenContent(),
    );
  }
}

class _CameraScreenContent extends StatefulWidget {
  const _CameraScreenContent();

  @override
  State<_CameraScreenContent> createState() => _CameraScreenContentState();
}

class _CameraScreenContentState extends State<_CameraScreenContent> {
  final CameraService _cameraService = getIt<CameraService>();

  bool _isModalOpen = false;

  void _onStateChanged(CameraState state) {
    if (state is! CameraReady) return;

    final nutrition = state.nutrition;
    if (_isModalOpen || nutrition == null) return;

    _isModalOpen = true;
    _showNutritionModal(nutrition);
  }

  void _showNutritionModal(NutritionInfo info) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NutritionSheet(info: info),
    ).then((_) {
      _isModalOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ComColApp')),
      body: BlocConsumer<CameraBloc, CameraState>(
        listener: (context, state) => _onStateChanged(state),
        builder: (context, state) => switch (state) {
          CameraInitial() ||
          CameraLoading() =>
            const Center(child: CircularProgressIndicator()),
          CameraError(:final message) => _ErrorView(message: message),
          CameraReady(:final detections) => Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: _cameraService.buildPreview()),
                if (detections.isNotEmpty && !_isModalOpen)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: DetectionChips(detections: detections),
                  ),
              ],
            ),
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  context.read<CameraBloc>().add(const InitializeCamera()),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
