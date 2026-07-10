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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ComColApp'),
      ),
      body: BlocBuilder<CameraBloc, CameraState>(
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
                if (detections.isNotEmpty)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                      decoration: const BoxDecoration(
                        color: Colors.white70,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: detections.map((detection) {
                            return Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.fastfood, color: Colors.white, size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${detection.label} ${(detection.confidence * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
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
