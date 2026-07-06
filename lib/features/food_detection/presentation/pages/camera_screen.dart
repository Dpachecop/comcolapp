import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import '../../../../core/injection/injection.dart';
import '../bloc/camera_bloc.dart';
import '../bloc/camera_event.dart';
import '../bloc/camera_state.dart';
import '../../domain/entities/detection_result.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CameraBloc>()..add(InitializeCamera()),
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
  String? currentFood;
  int frameCount = 0;
  bool isModalOpen = false;



  void _handleDetection(CameraDetectionSuccess state) {
    if (isModalOpen || state.detections.isEmpty) return;

    final bestDetection = state.detections.reduce((a, b) => a.confidence > b.confidence ? a : b);

    if (bestDetection.label == currentFood) {
      frameCount++;
    } else {
      currentFood = bestDetection.label;
      frameCount = 1;
    }

    if (frameCount >= 10 && !isModalOpen) {
      isModalOpen = true;
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fastfood, size: 80, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  currentFood!.toUpperCase(),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Confianza: ${(bestDetection.confidence * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 18, color: Colors.black54),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ).then((_) {
        isModalOpen = false;
        frameCount = 0;
        currentFood = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ComColApp'),
      ),
      body: BlocListener<CameraBloc, CameraState>(
        listener: (context, state) {
          if (state is CameraDetectionSuccess) {
            _handleDetection(state);
          }
        },
        child: BlocBuilder<CameraBloc, CameraState>(
          builder: (context, state) {
            if (state is CameraLoading || state is CameraInitial) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is CameraError) {
              return Center(child: Text('Error: ${state.message}'));
            } else if (state is CameraReady || state is CameraDetectionSuccess) {
              final controller = state is CameraReady 
                  ? state.controller 
                  : (state as CameraDetectionSuccess).controller;
              final detections = state is CameraDetectionSuccess 
                  ? state.detections 
                  : <DetectionResult>[];
                  
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: CameraPreview(controller),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BoundingBoxPainter(
                        detections: detections,
                        screenSize: MediaQuery.of(context).size,
                      ),
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _BoundingBoxPainter extends CustomPainter {
  final List<DetectionResult> results;
  final Size screenSize;

  _BoundingBoxPainter({required List<DetectionResult> detections, required this.screenSize}) : results = detections;

  @override
  void paint(Canvas canvas, Size size) {
    for (var result in results) {
      // MULTIPLICACIÓN ABSOLUTA GARANTIZADA
      final left = result.boundingBox.left * screenSize.width;
      final top = result.boundingBox.top * screenSize.height;
      final right = result.boundingBox.right * screenSize.width;
      final bottom = result.boundingBox.bottom * screenSize.height;
      
      final scaledRect = Rect.fromLTRB(left, top, right, bottom);
      print('DIBUJANDO RECT ESCALADO REAL: $scaledRect');

      final paint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;

      canvas.drawRect(scaledRect, paint);
      
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );
      
      textPainter.text = TextSpan(
        text: '${result.label} ${(result.confidence * 100).toStringAsFixed(1)}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.green,
        ),
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(scaledRect.left, scaledRect.top - 20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) {
    return true;
  }
}
