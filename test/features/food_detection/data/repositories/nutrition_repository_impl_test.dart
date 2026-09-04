import 'package:comcolapp/features/food_detection/data/datasources/local_nutrition_data.dart';
import 'package:comcolapp/features/food_detection/data/repositories/nutrition_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NutritionRepositoryImpl repository;

  setUp(() => repository = NutritionRepositoryImpl());

  test('encuentra la ficha de una etiqueta conocida', () {
    final info = repository.getNutritionFor('empanada');

    expect(info, isNotNull);
    expect(info!.title, 'Empanada de maíz amarillo');
    expect(info.calories, 280);
  });

  test('normaliza la etiqueta a minúsculas', () {
    expect(repository.getNutritionFor('AREPA'), isNotNull);
    expect(repository.getNutritionFor('Arepa'), isNotNull);
    expect(
      repository.getNutritionFor('Arepa'),
      repository.getNutritionFor('arepa'),
    );
  });

  test('retorna null para un alimento sin datos', () {
    expect(repository.getNutritionFor('pizza'), isNull);
  });

  test(
    'todas las etiquetas del modelo tienen ficha nutricional',
    () {
      // Las etiquetas están declaradas en assets/models/data.yaml. Si se
      // entrena el modelo con una clase nueva, este test falla hasta que se
      // agregue su ficha en LocalNutritionData.
      const modelLabels = ['arepa', 'bunuelo', 'dedito', 'empanada', 'patacon'];

      for (final label in modelLabels) {
        expect(
          repository.getNutritionFor(label),
          isNotNull,
          reason: 'Falta la ficha nutricional de "$label"',
        );
      }
    },
  );

  test('no hay fichas huérfanas sin etiqueta en el modelo', () {
    const modelLabels = {'arepa', 'bunuelo', 'dedito', 'empanada', 'patacon'};

    expect(LocalNutritionData.data.keys.toSet(), modelLabels);
  });
}
