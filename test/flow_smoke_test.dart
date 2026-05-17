import 'package:caregiver_tool/app.dart';
import 'package:caregiver_tool/core/data/prefs_provider.dart';
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

void main() {
  testWidgets('onboarding -> home -> session -> home', (tester) async {
    await _pumpApp(tester);

    // Onboarding renders: privacy line + an example card + Begin.
    expect(find.textContaining('Nothing leaves your phone'), findsOneWidget);
    expect(find.textContaining("She just wanted her sweater"), findsOneWidget);
    final begin = find.widgetWithText(FilledButton, 'Begin');
    await tester.scrollUntilVisible(begin, 250,
        scrollable: find.byType(Scrollable).first);

    await tester.tap(begin);
    await tester.pumpAndSettle();

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

    // Stub classifier returns none -> GoSession.
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('session flow is not built yet'),
        findsOneWidget);

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

    final begin = find.widgetWithText(FilledButton, 'Begin');
    await tester.scrollUntilVisible(begin, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(begin);
    await tester.pumpAndSettle();

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
}
