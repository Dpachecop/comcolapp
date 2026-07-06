import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class DetectionResult extends Equatable {
  final String label;
  final double confidence;
  final Rect boundingBox;

  const DetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });

  @override
  List<Object?> get props => [label, confidence, boundingBox];
}
