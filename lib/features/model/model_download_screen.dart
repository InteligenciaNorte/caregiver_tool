import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/llm/model_store.dart';

/// One-time setup screen: the ~3.4 GB model is fetched on first launch
/// (it can't be bundled). Shown only on real-device builds before
/// onboarding (the emulator/tests use the mock and never reach this).
/// After this, everything runs on-device with no network.
///
/// The download is **user-initiated**: nothing is fetched until the person
/// taps "Download". Before that there is no network call, no progress, no
/// spinner — only the explanation and the choice. This is the product
/// owner's requirement (don't spend ~3.4 GB of someone's data without an
/// explicit yes).
///
/// ⚠️ NEW COPY + ONE BEHAVIOUR for project-lead review:
///  - the consent strings here (calm, non-clinical, sets the one-time
///    expectation; consistent with the flagging of `_supportLine` /
///    `_Failed._message` / `_Generating._label`);
///  - "Not now" closes the app (`SystemNavigator.pop`) — honest, since
///    nothing in the app works without the model, but it is a UX call the
///    owner should confirm. Easy to change to "stay on this screen".
/// NOTE for the lead: the consent copy now states the download is the only
/// network use and that nothing written ever leaves the phone — this also
/// answers the earlier concern that shipping a download muddied the
/// onboarding "nothing leaves your phone" line. Owner's call on final copy.
class ModelDownloadScreen extends ConsumerStatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  ConsumerState<ModelDownloadScreen> createState() =>
      _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends ConsumerState<ModelDownloadScreen> {
  /// True while the one network-free presence check runs. Until it resolves
  /// we show a neutral spinner, not the consent prompt — so an already-
  /// downloaded model (or a dev side-load) goes straight through without
  /// asking, and offline launches still work.
  bool _checking = true;

  /// False until the person opts in. Gates the download UI so no network
  /// fetch happens before consent (only reached when the model is absent).
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Already on disk? hasLocalModel flips to ModelReady → the listener
    // below navigates on. Absent → drop the spinner and show consent.
    Future.microtask(() async {
      await ref.read(modelStoreProvider.notifier).hasLocalModel();
      if (mounted) setState(() => _checking = false);
    });
  }

  void _startDownload() {
    setState(() => _started = true);
    ref.read(modelStoreProvider.notifier).ensure();
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

    final (String title, String blurb, Widget body) = _checking
        ? (
            'Getting things ready',
            '',
            const CircularProgressIndicator(),
          )
        : !_started
        ? (
            'One-time setup',
            'KindNow runs a private AI model entirely on your phone — '
                'nothing you write ever leaves the device. The model is '
                'about 3.4 GB and is downloaded once. Wi-Fi recommended.',
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _startDownload,
                    child: const Text('Download (~3.4 GB)'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: const Text('Not now'),
                ),
                const SizedBox(height: 2),
                Text(
                  'Not now will close the app,\n'
                  'as the model presence is sufficient',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          )
        : switch (status) {
            ModelError(:final message) => (
                'Setting up',
                'This happens once. The app downloads what it needs to run '
                    'entirely on your phone — about 3.4 GB. Best on Wi-Fi.',
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
            ModelDownloading(:final received, :final total, :final fraction) =>
              (
                'Getting things ready',
                'This happens once. The app downloads what it needs to run '
                    'entirely on your phone — about 3.4 GB. Best on Wi-Fi.',
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
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            _ => (
                'Getting things ready',
                'This happens once. The app downloads what it needs to run '
                    'entirely on your phone — about 3.4 GB. Best on Wi-Fi.',
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
              if (blurb.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  blurb,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              body,
            ],
          ),
        ),
      ),
    );
  }
}
