import '../entities/nutrition_info.dart';

abstract class NutritionRepository {
  /// Retorna la ficha nutricional asociada a una etiqueta del modelo,
  /// o `null` si el alimento no tiene datos registrados.
  NutritionInfo? getNutritionFor(String label);
}
