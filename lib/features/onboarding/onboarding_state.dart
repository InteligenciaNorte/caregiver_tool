import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/prefs_provider.dart';

/// The app build the user last finished onboarding on (e.g. "0.4.0+4").
/// Stored instead of a bare boolean so onboarding re-shows after an app
/// update — see [OnboardedNotifier].
const onboardedBuildKey = 'onboarded_build';

/// Current app build identifier ("version+buildNumber"), resolved eagerly in
/// main.dart via package_info_plus and injected here. Defaults to empty
/// (tests / emulator), which reads as "not onboarded" so onboarding shows.
final appBuildProvider = Provider<String>((ref) => '');

/// Onboarding is shown once **per app build**: completing it records the
/// current build; a later build (any update that bumps pubspec `version:`)
/// won't match, so onboarding runs again. Within a session, [markComplete]
/// flips the flag immediately.
class OnboardedNotifier extends StateNotifier<bool> {
  OnboardedNotifier(this._prefs, this._build)
      : super(_build.isNotEmpty &&
            _prefs.getString(onboardedBuildKey) == _build);

  final SharedPreferences _prefs;
  final String _build;

  Future<void> markComplete() async {
    await _prefs.setString(onboardedBuildKey, _build);
    state = true;
  }
}

final onboardedProvider = StateNotifierProvider<OnboardedNotifier, bool>((ref) {
  return OnboardedNotifier(
    ref.watch(prefsProvider),
    ref.watch(appBuildProvider),
  );
});
