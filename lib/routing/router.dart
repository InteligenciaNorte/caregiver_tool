import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/onboarding_state.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (context, state) {
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
        builder: (_, __) => const _Placeholder('Home'),
      ),
      GoRoute(
        path: '/module/:moduleId',
        builder: (_, state) =>
            _Placeholder('Module: ${state.pathParameters['moduleId']}'),
      ),
      GoRoute(
        path: '/session/:sessionId/close',
        builder: (_, state) =>
            _Placeholder('Close session ${state.pathParameters['sessionId']}'),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const _Placeholder('Settings'),
      ),
    ],
  );
});

class _Placeholder extends StatelessWidget {
  final String label;
  const _Placeholder(this.label);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(child: Text(label)),
    );
  }
}
