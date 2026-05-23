import 'package:caregiver_tool/core/llm/model_store.dart';
import 'package:caregiver_tool/features/model/model_download_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// The point under test is the consent gate: the ~3.4 GB fetch must not
// start until the person explicitly taps Download. This ModelStore never
// touches the network — it only records that ensure() was called and
// moves to a benign downloading state so the gated UI can be asserted.
// hasLocalModel() returns false so the screen treats the model as absent
// (a download is actually needed) and shows the consent prompt.
class _AbsentModelStore extends ModelStore {
  int ensureCalls = 0;

  @override
  Future<bool> hasLocalModel() async => false;

  @override
  Future<void> ensure() async {
    ensureCalls++;
    state = const ModelDownloading(0, 100);
  }
}

// The model is already on disk: hasLocalModel() flips to ModelReady, so the
// screen must skip consent entirely and route onward — no nagging "Download"
// prompt on a launch where there is nothing to download.
class _PresentModelStore extends ModelStore {
  int ensureCalls = 0;

  @override
  Future<bool> hasLocalModel() async {
    state = const ModelReady('/data/model.gguf');
    return true;
  }

  @override
  Future<void> ensure() async {
    ensureCalls++;
    state = const ModelReady('/data/model.gguf');
  }
}

void main() {
  testWidgets('shows consent and fetches nothing until Download is tapped',
      (tester) async {
    final store = _AbsentModelStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [modelStoreProvider.overrideWith((ref) => store)],
        child: const MaterialApp(home: ModelDownloadScreen()),
      ),
    );
    // Let the one-time presence check resolve (absent → consent shown).
    await tester.pumpAndSettle();

    // Before consent: the choice is shown and nothing has been fetched.
    expect(find.text('Download (~3.4 GB)'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(store.ensureCalls, 0);

    await tester.tap(find.text('Download (~3.4 GB)'));
    await tester.pump();

    // The tap is the only thing that starts the download.
    expect(store.ensureCalls, 1);
    expect(find.text('Download (~3.4 GB)'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('skips consent and routes on when the model is already present',
      (tester) async {
    final store = _PresentModelStore();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const ModelDownloadScreen()),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const Scaffold(body: Text('ONBOARDING')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [modelStoreProvider.overrideWith((ref) => store)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // No consent prompt was ever shown; the app moved straight on.
    expect(find.text('Download (~3.4 GB)'), findsNothing);
    expect(find.text('ONBOARDING'), findsOneWidget);
    expect(store.ensureCalls, 0); // present → no download attempted
  });
}
