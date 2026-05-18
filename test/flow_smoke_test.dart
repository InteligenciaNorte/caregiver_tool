import 'package:caregiver_tool/app.dart';
import 'package:caregiver_tool/core/data/prefs_provider.dart';
import 'package:caregiver_tool/ui/widgets/helpline_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Drives the full structural flow in-memory: onboarding -> Home ->
// session placeholder -> Home, and Home -> crisis screen -> Home.
// Complements the on-device run, which can only confirm build/launch.
Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const CaregiverApp(),
    ),
  );
  await tester.pumpAndSettle();
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
  testWidgets('onboarding -> home -> session -> home', (tester) async {
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

    // 'I snapped at mom today.' classifies NONE -> GoSession; a plain
    // session with NO helpline card.
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('session flow is not built yet'),
        findsOneWidget);
    expect(find.byType(HelplineCard), findsNothing);

    // Session Done -> Home.
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("Write what you're sitting with"),
      findsOneWidget,
    );
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
      find.widgetWithText(FilledButton, 'Call 988 (US Suicide & Crisis Lifeline)'),
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
    await tester.pumpAndSettle();

    // Session runs (not the crisis overlay)...
    expect(find.textContaining('session flow is not built yet'),
        findsOneWidget);
    expect(find.textContaining("people who can help right now"), findsNothing);
    // ...with the helpline card pinned, collapsed by default (slim bar,
    // resource one tap away, never auto-dismissed).
    expect(find.byType(HelplineCard), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Call 988 (US Suicide & Crisis Lifeline)'),
      findsNothing,
    );

    // Tapping the bar reveals the call action; it can never be removed.
    await tester.tap(find.byKey(const Key('helplineExpand')));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FilledButton, 'Call 988 (US Suicide & Crisis Lifeline)'),
      findsOneWidget,
    );

    // Collapse returns to the slim bar — still pinned, not gone.
    await tester.tap(find.byKey(const Key('helplineCollapse')));
    await tester.pumpAndSettle();
    expect(find.byType(HelplineCard), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Call 988 (US Suicide & Crisis Lifeline)'),
      findsNothing,
    );
  });
}
