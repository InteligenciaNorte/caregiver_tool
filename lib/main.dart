import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/data/prefs_provider.dart';
import 'core/llm/gemma_client.dart';
import 'core/llm/real_gemma_client.dart';

/// Dev switch: `--dart-define=USE_REAL_MODEL=true` runs the real on-device
/// Gemma GGUF (a physical-device build). Unset — emulator, tests, CI —
/// keeps the default `MockGemmaClient` (see `gemmaClientProvider`), so
/// nothing model-bound changes there.
const bool _useRealModel = bool.fromEnvironment('USE_REAL_MODEL');

/// Where the GGUF is side-loaded for the dev real-model test: the app's
/// own *internal* files dir. The external (`Android/data/<pkg>`) dir is not
/// usable here — on Android 11+ a file `adb push`ed there is not visible to
/// the app (isolated FUSE view); the internal dir is read directly by the
/// app with no permission. Populated via `adb exec-out run-as` (debug
/// build is debuggable). Production resolves a downloaded path instead
/// (hosting-guide / path_provider) — deferred, a separate decision.
const String _devModelPath =
    '/data/user/0/dev.inteligencianorte.caregiver_tool/files/'
    'gemma4-e2b_r32-q4_k_m.gguf';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        if (_useRealModel) ...[
          modelPathProvider.overrideWithValue(_devModelPath),
          gemmaClientProvider.overrideWith((ref) {
            final client = RealGemmaClient(ref.watch(modelPathProvider));
            ref.onDispose(client.shutdown);
            return client;
          }),
        ],
      ],
      child: const CaregiverApp(),
    ),
  );
}
