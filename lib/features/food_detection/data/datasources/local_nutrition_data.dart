class NutritionInfo {
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
}

class LocalNutritionData {
  static const Map<String, NutritionInfo> data = {
    'empanada': NutritionInfo(
      title: 'Empanada de maíz amarillo',
      description:
          'Preparación tradicional elaborada con masa de maíz amarillo y rellena generalmente con carne, pollo o queso. Se fríe hasta obtener una textura crujiente y es una de las comidas callejeras más populares de la región Caribe.',
      portion: '120g',
      calories: 280,
      carbs: 28.0,
      protein: 9.0,
      fat: 15.0,
      sodium: '380mg',
    ),
    'arepa': NutritionInfo(
      title: 'Arepa de maíz amarillo',
      description:
          'Torta circular elaborada con masa de maíz amarillo, cocinada a la plancha, asada o frita. En la costa colombiana suele acompañar desayunos y comidas, sola o con queso costeño.',
      portion: '100g',
      calories: 170,
      carbs: 40.5,
      protein: 4.3,
      fat: 0.6,
      fiber: '3.6g',
    ),
    'patacon': NutritionInfo(
      title: 'Patacón',
      description:
          'Rodajas de plátano verde aplastadas y fritas dos veces hasta quedar crujientes. Se consumen como acompañamiento o base para preparaciones con carne, pollo, mariscos o queso.',
      portion: '100g',
      calories: 220,
      carbs: 36.0,
      protein: 2.0,
      fat: 9.0,
      fiber: '3g',
    ),
    'bunuelo': NutritionInfo(
      title: 'Buñuelo',
      description:
          'Bolita de masa preparada principalmente con almidón de yuca, queso costeño y harina de maíz. Se fríe hasta quedar dorada por fuera y suave por dentro. Es muy tradicional en celebraciones y festividades.',
      portion: '50g',
      calories: 150,
      carbs: 15.0,
      protein: 5.0,
      fat: 8.0,
    ),
    'dedito': NutritionInfo(
      title: 'Deditos de queso (tequeños)',
      description:
          'Bastones de queso envueltos en una masa de harina de trigo y fritos hasta quedar dorados. Son un aperitivo muy popular en la costa Caribe colombiana.',
      portion: '1 dedito',
      calories: 120,
      carbs: 10.0,
      protein: 4.0,
      fat: 7.0,
      sodium: '160mg',
    ),
  };
}
