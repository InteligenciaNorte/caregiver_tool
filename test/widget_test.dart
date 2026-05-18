import 'package:caregiver_tool/app.dart';
import 'package:caregiver_tool/core/data/prefs_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Onboarding is a 4-page PageView; the privacy guarantee lives on
  // page 3 and is covered there by flow_smoke_test's _advanceOnboarding.
  // This stays a minimal boot check: a fresh launch lands on onboarding
  // page 1 (its "Next" affordance present), not Home.
  testWidgets('App boots into onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const CaregiverApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
    expect(
      find.textContaining("Write what you're sitting with"),
      findsNothing,
    );
  });
}
