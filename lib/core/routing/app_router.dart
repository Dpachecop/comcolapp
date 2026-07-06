import 'package:go_router/go_router.dart';
import '../../features/food_detection/presentation/pages/home_screen.dart';
import '../../features/food_detection/presentation/pages/camera_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/camera',
      builder: (context, state) => const CameraScreen(),
    ),
  ],
);
