import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/llm/gemma_client.dart';
import '../core/llm/model_store.dart';
import '../features/crisis/crisis_screen.dart';
import '../features/home/home_screen.dart';
import '../features/model/model_download_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/onboarding_state.dart';
import '../features/session/session_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (context, state) {
      // ref.read (not watch) — watching would recreate the GoRouter on a
      // flag flip and drop navigation state. The screens drive transitions
      // (markComplete()/ModelReady → context.go), each of which triggers a
      // fresh redirect pass that re-reads here.

      // Real-device builds gate everything behind the one-time model
      // download. Mock builds (emulator/tests/CI) skip this entirely.
      if (ref.read(realModelEnabledProvider)) {
        final ready = ref.read(modelStoreProvider) is ModelReady;
        final atModel = state.matchedLocation == '/model';
        if (!ready && !atModel) return '/model';
        if (ready && atModel) return '/onboarding';
      }

      final onboarded = ref.read(onboardedProvider);
      if (onboarded && state.matchedLocation == '/onboarding') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/model',
        builder: (_, __) => const ModelDownloadScreen(),
      ),
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
