import 'package:flutter/material.dart';
import '../../domain/entities/detection_result.dart';

/// Barra inferior con los alimentos detectados en el frame actual.
class DetectionChips extends StatelessWidget {
  const DetectionChips({super.key, required this.detections});

  final List<DetectionResult> detections;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      decoration: const BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: detections
              .map((detection) => _DetectionChip(label: detection.label))
              .toList(),
        ),
      ),
    );
  }
}

class _DetectionChip extends StatelessWidget {
  const _DetectionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fastfood, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
