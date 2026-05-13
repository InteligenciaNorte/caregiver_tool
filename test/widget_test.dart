import 'package:caregiver_tool/app.dart';
import 'package:caregiver_tool/core/data/prefs_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App boots into onboarding privacy card', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const CaregiverApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('stays on this phone'), findsOneWidget);
  });
}
