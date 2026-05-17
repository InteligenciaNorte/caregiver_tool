import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reached two ways: the manual "I need help right now" link (any screen),
/// and — once the classifier is wired — an automatic HIGH/ACUTE route.
/// Does not mount [CrisisHeader] (a self-routing link here would be a dead
/// link); it has its own explicit return control instead.
class CrisisScreen extends StatelessWidget {
  const CrisisScreen({super.key});

  Future<void> _call(String number) async {
    await launchUrl(
      Uri(scheme: 'tel', path: number),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "If you're in crisis, here are people who can help right now.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              Semantics(
                button: true,
                label: "Call Alzheimer's Association, 1-800-272-3900",
                child: FilledButton(
                  onPressed: () => _call('18002723900'),
                  child: const Text(
                      "Call Alzheimer's Association: 1-800-272-3900"),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                label: 'Call 988, U S Suicide and Crisis Lifeline',
                child: FilledButton(
                  onPressed: () => _call('988'),
                  child: const Text('Call 988 (US Suicide & Crisis Lifeline)'),
                ),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text(
                  'Return',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
