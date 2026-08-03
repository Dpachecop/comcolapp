import 'package:injectable/injectable.dart';
import '../../domain/entities/nutrition_info.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../datasources/local_nutrition_data.dart';

@Injectable(as: NutritionRepository)
class NutritionRepositoryImpl implements NutritionRepository {
  @override
  NutritionInfo? getNutritionFor(String label) {
    // Las llaves del mapa local están en minúscula, igual que las etiquetas
    // declaradas en assets/models/data.yaml.
    return LocalNutritionData.data[label.toLowerCase()];
  }
}
