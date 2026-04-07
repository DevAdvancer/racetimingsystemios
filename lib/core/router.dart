import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:race_timer/core/constants.dart';
import 'package:race_timer/providers/admin_access_provider.dart';
import 'package:race_timer/screens/export_screen.dart';
import 'package:race_timer/screens/home_screen.dart';
import 'package:race_timer/screens/overall_points_screen.dart';
import 'package:race_timer/screens/race_dashboard_screen.dart';
import 'package:race_timer/screens/race_control_screen.dart';
import 'package:race_timer/screens/registration_screen.dart';
import 'package:race_timer/screens/results_screen.dart';
import 'package:race_timer/screens/scanner_screen.dart';
import 'package:race_timer/screens/setup_screen.dart';
import 'package:race_timer/screens/start_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final adminUnlocked = ref.watch(adminAccessProvider);
  const publicRoutes = <String>{AppRoutes.home, AppRoutes.registration};

  return GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      final path = state.uri.path;
      if (!adminUnlocked && !publicRoutes.contains(path)) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const StartScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminHome,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.raceDashboard,
        builder: (context, state) => const RaceDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.registration,
        builder: (context, state) => const RegistrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.raceControl,
        builder: (context, state) => const RaceControlScreen(),
      ),
      GoRoute(
        path: AppRoutes.scanner,
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.results,
        builder: (context, state) => const ResultsScreen(),
      ),
      GoRoute(
        path: AppRoutes.export,
        builder: (context, state) => const ExportScreen(),
      ),
      GoRoute(
        path: AppRoutes.overallPoints,
        builder: (context, state) => const OverallPointsScreen(),
      ),
      GoRoute(
        path: AppRoutes.setup,
        builder: (context, state) => const SetupScreen(),
      ),
    ],
  );
});
