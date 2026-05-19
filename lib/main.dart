import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/data/prefs_provider.dart';
import 'core/llm/gemma_client.dart';
import 'core/llm/model_store.dart';
import 'core/llm/real_gemma_client.dart';

/// Dev switch: `--dart-define=USE_REAL_MODEL=true` runs the real on-device
/// Gemma GGUF (a physical-device build) and gates startup on the
/// download-on-first-launch screen. Unset — emulator, tests, CI — keeps
/// the default `MockGemmaClient` (see `gemmaClientProvider`) and no gate,
/// so nothing model-bound changes there.
///
/// Fast dev iteration without re-downloading 3.4 GB: also pass
/// `--dart-define=DEV_MODEL_PATH=/abs/path.gguf` (a side-loaded file);
/// `ModelStore` uses it directly and skips the download.
const bool _useRealModel = bool.fromEnvironment('USE_REAL_MODEL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        if (_useRealModel) ...[
          realModelEnabledProvider.overrideWithValue(true),
          // The gate guarantees ModelReady before any session starts, so
          // this resolves to the downloaded (or dev side-loaded) path.
          modelPathProvider.overrideWith((ref) {
            final s = ref.watch(modelStoreProvider);
            if (s is ModelReady) return s.path;
            throw StateError('model path read before the model was ready');
          }),
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
