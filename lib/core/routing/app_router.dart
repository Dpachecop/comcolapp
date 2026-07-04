import 'package:go_router/go_router.dart';
import '../../features/food_detection/presentation/pages/camera_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const CameraScreen(),
    ),
  ],
);
