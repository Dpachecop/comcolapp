import 'package:flutter/material.dart';
import '../../domain/entities/nutrition_info.dart';

/// Hoja inferior con la ficha nutricional de un alimento detectado.
class NutritionSheet extends StatelessWidget {
  const NutritionSheet({super.key, required this.info});

  final NutritionInfo info;

  @override
  Widget build(BuildContext context) {
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
            info.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            info.description,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 24),
          Text(
            'Porción sugerida: ${info.portion}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _MacroCard(label: 'Calorías', value: '${info.calories} kcal', color: Colors.orange),
              _MacroCard(label: 'Carbs', value: '${info.carbs}g', color: Colors.blue),
              _MacroCard(label: 'Proteínas', value: '${info.protein}g', color: Colors.red),
              _MacroCard(label: 'Grasas', value: '${info.fat}g', color: Colors.yellow.shade800),
              if (info.sodium != null)
                _MacroCard(label: 'Sodio', value: info.sodium!, color: Colors.grey.shade600),
              if (info.fiber != null)
                _MacroCard(label: 'Fibra', value: info.fiber!, color: Colors.green.shade700),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Esta es una estimación, puede variar dependiendo del peso final '
            'de su alimento y su preparación.',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
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
            style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
