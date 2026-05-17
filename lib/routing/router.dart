import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/crisis/crisis_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/onboarding_state.dart';
import '../features/session/session_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (context, state) {
      // ref.read (not watch) — watching would recreate the GoRouter on the
      // onboarding flag flip and drop navigation state. markComplete() +
      // context.go already triggers a fresh redirect pass.
      final onboarded = ref.read(onboardedProvider);
      if (onboarded && state.matchedLocation == '/onboarding') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/session',
        builder: (_, __) => const SessionScreen(),
      ),
      GoRoute(
        path: '/crisis',
        builder: (_, __) => const CrisisScreen(),
      ),
    ],
  );
});
