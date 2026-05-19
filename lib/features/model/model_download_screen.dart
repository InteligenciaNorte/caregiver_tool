import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/llm/model_store.dart';

/// One-time setup screen: the ~3.4 GB model is fetched on first launch
/// (it can't be bundled). Shown only on real-device builds before
/// onboarding (the emulator/tests use the mock and never reach this).
/// After this, everything runs on-device with no network.
///
/// ⚠️ NEW COPY for project-lead review: the strings here. Calm,
/// non-clinical, sets the one-time-wait expectation; consistent with the
/// flagging of `_supportLine` / `_Failed._message` / `_Generating._label`.
/// NOTE for the lead: shipping a download also makes the onboarding
/// privacy line ("Nothing leaves your phone") read as network-free — that
/// calibrated copy may need a one-time-download caveat. Owner's call;
/// not changed here.
class ModelDownloadScreen extends ConsumerStatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  ConsumerState<ModelDownloadScreen> createState() =>
      _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends ConsumerState<ModelDownloadScreen> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget; the screen renders state as it progresses.
    Future.microtask(() => ref.read(modelStoreProvider.notifier).ensure());
  }

  String _mb(int b) => '${(b / (1 << 20)).toStringAsFixed(0)} MB';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = ref.watch(modelStoreProvider);

    // Leave setup the moment the model is ready; onboarding takes over.
    ref.listen<ModelStatus>(modelStoreProvider, (_, next) {
      if (next is ModelReady && context.mounted) context.go('/onboarding');
    });

    final (String title, Widget body) = switch (status) {
      ModelError(:final message) => (
          'Setting up',
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      ref.read(modelStoreProvider.notifier).retry(),
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
        ),
      ModelDownloading(:final received, :final total, :final fraction) => (
          'Getting things ready',
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: fraction == 0 ? null : fraction,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                total > 0
                    ? '${_mb(received)} of ${_mb(total)}'
                    : _mb(received),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      _ => (
          'Getting things ready',
          const CircularProgressIndicator(),
        ),
    };

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'This happens once. The app downloads what it needs to run '
                'entirely on your phone — about 3.4 GB. Best on Wi-Fi.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 40),
              body,
            ],
          ),
        ),
      ),
    );
  }
}
