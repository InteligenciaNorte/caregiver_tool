import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caregiver_tool/app.dart';

void main() {
  testWidgets('App boots into the Onboarding placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CaregiverApp()));
    await tester.pumpAndSettle();

    expect(find.text('Onboarding'), findsWidgets);
  });
}
