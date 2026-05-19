import 'package:caregiver_tool/core/llm/model_store.dart';
import 'package:caregiver_tool/features/model/model_download_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The point under test is the consent gate: the ~3.4 GB fetch must not
// start until the person explicitly taps Download. This ModelStore never
// touches the network — it only records that ensure() was called and
// moves to a benign downloading state so the gated UI can be asserted.
class _FakeModelStore extends ModelStore {
  int ensureCalls = 0;

  @override
  Future<void> ensure() async {
    ensureCalls++;
    state = const ModelDownloading(0, 100);
  }
}

Future<void> _pump(WidgetTester tester, _FakeModelStore store) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [modelStoreProvider.overrideWith((ref) => store)],
      child: const MaterialApp(home: ModelDownloadScreen()),
    ),
  );
}

void main() {
  testWidgets('shows consent and fetches nothing until Download is tapped',
      (tester) async {
    final store = _FakeModelStore();
    await _pump(tester, store);
    await tester.pump();

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
}
