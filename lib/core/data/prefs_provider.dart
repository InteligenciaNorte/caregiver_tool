import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'prefsProvider must be overridden in main.dart with an eager '
    'SharedPreferences.getInstance() value.',
  );
});
