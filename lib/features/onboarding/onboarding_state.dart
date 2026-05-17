import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/prefs_provider.dart';

const onboardedPrefsKey = 'onboarding_seen';

class OnboardedNotifier extends StateNotifier<bool> {
  OnboardedNotifier(this._prefs)
      : super(_prefs.getBool(onboardedPrefsKey) ?? false);

  final SharedPreferences _prefs;

  Future<void> markComplete() async {
    await _prefs.setBool(onboardedPrefsKey, true);
    state = true;
  }
}

final onboardedProvider = StateNotifierProvider<OnboardedNotifier, bool>((ref) {
  return OnboardedNotifier(ref.watch(prefsProvider));
});
