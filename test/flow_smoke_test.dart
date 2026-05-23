import 'package:caregiver_tool/app.dart';
import 'package:caregiver_tool/core/data/prefs_provider.dart';
import 'package:caregiver_tool/core/llm/gemma_client.dart';
import 'package:caregiver_tool/core/llm/mock_gemma_client.dart';
import 'package:caregiver_tool/ui/widgets/helpline_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Drives the full structural flow in-memory: onboarding -> Home -> the
// real 4-step session -> Home, and Home -> crisis screen -> Home.
// Complements the on-device run, which can only confirm build/launch.
//
// The session runs against a zero-latency MockGemmaClient so the step
// machine, background pre-generation and pinned helpline card are
// exercised deterministically with no GGUF (the real model is unusable on
// an emulator/CI anyway — see MockGemmaClient).
Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        gemmaClientProvider
            .overrideWithValue(MockGemmaClient(latency: Duration.zero)),
        // Stub the prompt loader: never touch the global rootBundle cache
        // (a Future cached in one test's zone hangs when awaited in
        // another's — the cross-test failure this test suite hit).
        systemPromptProvider
            .overrideWithValue(() async => 'TEST SYSTEM PROMPT'),
      ],
      child: const CaregiverApp(),
    ),
  );
  await tester.pumpAndSettle();
}

// Bounded fixed pumping — never `pumpAndSettle`. Used for finite session
// animations (the helpline AnimatedSize) where there is no spinner.
Future<void> _pumpFor(WidgetTester tester, {int ms = 400}) async {
  for (var t = 0; t < ms; t += 16) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

// `pumpAndSettle` can't be used around the session: a generating step
// shows a perpetual CircularProgressIndicator, and background pre-gen is
// fire-and-forget, so "settled" is undefined and it would hang. Instead
// pump until the generating step actually resolves (the spinner is gone),
// after enough frames to also cover the finite go_router page transition
// (so the old route's duplicate 'Continue' button is gone). Bounded so a
// genuine stall fails fast rather than hanging.
Future<void> _settleSession(WidgetTester tester) async {
  await tester.pump(); // kick off start()/generation
  final spinner = find.byType(CircularProgressIndicator);
  for (var i = 0; i < 240; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (i >= 30 && tester.widgetList(spinner).isEmpty) return;
  }
}

// Onboarding is an intentional 4-page PageView (what / examples / privacy
// / ready). A user reaches "Begin" by tapping "Next" three times, so the
// smoke test drives it the same way. Assertions stay structural (the Next
// button, the privacy guarantee, Begin) so lead-owned example-copy
// revisions don't re-break this test.
Future<void> _advanceOnboarding(WidgetTester tester) async {
  final next = find.widgetWithText(FilledButton, 'Next');
  expect(next, findsOneWidget);

  // Page 1 -> 2.
  await tester.tap(next);
  await tester.pumpAndSettle();
  await tester.tap(next);
  await tester.pumpAndSettle();

  // Page 3 (privacy): the offline guarantee is on this page.
  expect(find.textContaining('Nothing leaves your phone'), findsOneWidget);

  // Page 3 -> 4 (ready). The external Next button disappears on the
  // last page; "Begin" lives inside the PageView.
  await tester.tap(next);
  await tester.pumpAndSettle();

  final begin = find.widgetWithText(FilledButton, 'Begin');
  expect(begin, findsOneWidget);
  await tester.tap(begin);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('onboarding -> home -> 4-step session -> home',
      (tester) async {
    await _pumpApp(tester);
    await _advanceOnboarding(tester);

    // Home: hint shown, Continue disabled until text entered.
    expect(
      find.textContaining("Write what you're sitting with"),
      findsOneWidget,
    );
    final continueBtn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(continueBtn.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'I snapped at mom today.');
    await tester.pumpAndSettle();
    final continueBtn2 = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(continueBtn2.onPressed, isNotNull);

    // 'I snapped at mom today.' classifies NONE -> GoSession: a plain
    // session, no crisis overlay, no helpline card.
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await _settleSession(tester);
    expect(find.textContaining('people who can help right now'), findsNothing);

    // The caregiver's own words are anchored on the session screen, so they
    // don't "disappear" once the session starts (the move away from a chat
    // layout — they stay visible alongside the reflection).
    expect(find.text('I snapped at mom today.'), findsOneWidget);

    // Walk all four steps: Continue x3 (steps 0->1->2->3), then the last
    // step's button is Done and returns Home. The helpline card is absent
    // on every step (NONE, not MEDIUM); the situation anchor stays put.
    for (var i = 0; i < kWitnessStepCount - 1; i++) {
      expect(find.byType(HelplineCard), findsNothing);
      expect(find.text('I snapped at mom today.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await _settleSession(tester);
    }
    expect(find.byType(HelplineCard), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("Write what you're sitting with"),
      findsOneWidget,
    );
    // The anchored situation is cleared with the session (architecture.md
    // §Privacy) — it doesn't linger into the fresh Home.
    expect(find.text('I snapped at mom today.'), findsNothing);
    // Fresh start after a session ends: the typed situation is gone
    // (architecture.md §Privacy), so Home's Continue is disabled again —
    // no re-running a session on the previous text.
    final homeContinue = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(homeContinue.onPressed, isNull);
  });

  testWidgets('home -> crisis screen -> home', (tester) async {
    await _pumpApp(tester);
    await _advanceOnboarding(tester);

    // Crisis link in the header on Home.
    await tester.tap(find.text('I need help right now'));
    await tester.pumpAndSettle();
    expect(find.textContaining("people who can help right now"),
        findsOneWidget);
    expect(
      find.widgetWithText(
          FilledButton, 'Call 988 (US Suicide & Crisis Lifeline)'),
      findsOneWidget,
    );

    // Return -> Home.
    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("Write what you're sitting with"),
      findsOneWidget,
    );
  });

  // Closes the known MEDIUM gap: a passive-ideation disclosure must run
  // the session (not the crisis overlay) but with the helpline card
  // pinned. 'I wish I was dead' is a fixed L3 MEDIUM case in
  // classifier_test.dart.
  testWidgets('MEDIUM situation -> session with pinned helpline card',
      (tester) async {
    await _pumpApp(tester);
    await _advanceOnboarding(tester);

    await tester.enterText(find.byType(TextField), 'I wish I was dead');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await _settleSession(tester);

    // Session runs (not the crisis overlay)...
    expect(find.textContaining("people who can help right now"), findsNothing);
    // ...with the helpline card pinned, collapsed by default (slim bar,
    // resource one tap away, never auto-dismissed).
    expect(find.byType(HelplineCard), findsOneWidget);
    expect(
      find.widgetWithText(
          FilledButton, 'Call 988 (US Suicide & Crisis Lifeline)'),
      findsNothing,
    );

    // Tapping the bar reveals the call action; it can never be removed.
    await tester.tap(find.byKey(const Key('helplineExpand')));
    await _pumpFor(tester); // AnimatedSize, finite — no spinner here
    expect(
      find.widgetWithText(
          FilledButton, 'Call 988 (US Suicide & Crisis Lifeline)'),
      findsOneWidget,
    );

    // Collapse returns to the slim bar — still pinned, not gone.
    await tester.tap(find.byKey(const Key('helplineCollapse')));
    await _pumpFor(tester);
    expect(find.byType(HelplineCard), findsOneWidget);
    expect(
      find.widgetWithText(
          FilledButton, 'Call 988 (US Suicide & Crisis Lifeline)'),
      findsNothing,
    );

    // Pinned across step changes: advancing a step keeps the card present
    // (architecture.md §Safety — re-confirmed now the real step machine
    // replaced the placeholder).
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await _settleSession(tester);
    expect(find.byType(HelplineCard), findsOneWidget);
  });
}
