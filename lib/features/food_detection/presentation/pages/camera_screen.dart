import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import '../../../../core/injection/injection.dart';
import '../bloc/camera_bloc.dart';
import '../bloc/camera_event.dart';
import '../bloc/camera_state.dart';
import '../../domain/entities/detection_result.dart';
import '../../domain/entities/nutrition_info.dart';

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
  bool isModalOpen = false;

  void _handleDetection(CameraDetectionSuccess state) {
    final nutritionInfo = state.nutrition;
    if (isModalOpen || nutritionInfo == null) return;

    isModalOpen = true;
    _showNutritionModal(nutritionInfo);
  }

  void _showNutritionModal(NutritionInfo nutritionInfo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Icon(Icons.restaurant_menu, size: 64, color: Colors.green),
              ),
              const SizedBox(height: 16),
              Text(
                nutritionInfo.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                nutritionInfo.description,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 24),
              Text(
                'Porción sugerida: ${nutritionInfo.portion}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _buildMacroCard('Calorías', '${nutritionInfo.calories} kcal', Colors.orange),
                  _buildMacroCard('Carbs', '${nutritionInfo.carbs}g', Colors.blue),
                  _buildMacroCard('Proteínas', '${nutritionInfo.protein}g', Colors.red),
                  _buildMacroCard('Grasas', '${nutritionInfo.fat}g', Colors.yellow.shade800),
                  if (nutritionInfo.sodium != null)
                    _buildMacroCard('Sodio', nutritionInfo.sodium!, Colors.grey.shade600),
                  if (nutritionInfo.fiber != null)
                    _buildMacroCard('Fibra', nutritionInfo.fiber!, Colors.green.shade700),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                "Esta es una estimación, puede variar dependiendo del peso final de su alimento y su preparación.",
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    ).then((_) {
      isModalOpen = false;
    });
  }

  Widget _buildMacroCard(String label, String value, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
                  if (detections.isNotEmpty && !isModalOpen)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
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
                                      detection.label.toUpperCase(),
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
      ),
    );
  }
}
