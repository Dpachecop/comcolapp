import 'package:equatable/equatable.dart';

class NutritionInfo extends Equatable {
  final String title;
  final String description;
  final String portion;
  final int calories;
  final double carbs;
  final double protein;
  final double fat;
  final String? sodium;
  final String? fiber;

  const NutritionInfo({
    required this.title,
    required this.description,
    required this.portion,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    this.sodium,
    this.fiber,
  });

  @override
  List<Object?> get props => [
        title,
        description,
        portion,
        calories,
        carbs,
        protein,
        fat,
        sodium,
        fiber,
      ];
}
