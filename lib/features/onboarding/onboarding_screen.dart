import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/widgets/crisis_header.dart';
import 'onboarding_state.dart';

// Lead-owned copy. Approved 2026-05-17 (paged onboarding redesign);
// examples list + heading revised 2026-05-17 per project lead.
// Do not reword without asking the project lead.
const _whatHeading = 'For the moments no one prepared you for';
const _whatBody =
    'Caring for someone with dementia brings thoughts that are hard to say '
    'out loud. Write one down here and be met with understanding — not '
    'advice, not fixing. About five minutes.';

const _examplesHeading = "You're not the only one who's thought these";
const _examples = [
  'secretly glad the ambulance came',
  'dreading the day they discharge him',
  'prayed for an excuse to stay in bed',
  'felt absolutely nothing when she cried',
  'he looked at me like a complete stranger',
  'called me a thief again today',
  "so jealous of my sibling's normal life",
  'realized no one is coming to help',
  'terrified of my own anger today',
  'just waiting for it to be over',
  'i just want my life back',
];

const _privacyHeading = 'What you write stays with you';
const _privacyBody =
    'It runs entirely on your phone, with no internet. Nothing is sent '
    'anywhere, no account, no cloud.';
const _privacyLine =
    'Nothing leaves your phone. Nothing is saved between sessions.';

const _readyHeading = 'Ready when you are';

const _pageCount = 4;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _pageCount - 1;

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _begin() async {
    await ref.read(onboardedProvider.notifier).markComplete();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Stack(
            children: [
              const CrisisHeader(),
              if (_page > 0)
                Positioned.directional(
                  textDirection: Directionality.of(context),
                  start: 4,
                  top: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: IconButton(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back',
                        iconSize: 24,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                const _WhatPage(),
                const _ExamplesPage(),
                const _PrivacyPage(),
                _ReadyPage(onBegin: _begin),
              ],
            ),
          ),
          if (!_isLast)
            // SafeArea(bottom) keeps the Next bar clear of the Android
            // system navigation (gesture pill / 3-button). Without it the
            // button sat under the nav bar and overlapped it.
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Dots(count: _pageCount, active: _page),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _next,
                        child: const Text('Next'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Vertically centres a page's content in the available space, but lets it
/// scroll if it would overflow (large text scale / short screens).
class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _WhatPage extends StatelessWidget {
  const _WhatPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PageScroll(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_whatHeading, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 20),
          Text(_whatBody, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _ExamplesPage extends StatelessWidget {
  const _ExamplesPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PageScroll(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_examplesHeading, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: [
              for (final example in _examples) _ExampleBubble(example),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExampleBubble extends StatelessWidget {
  const _ExampleBubble(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PageScroll(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_privacyHeading, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 20),
          Text(_privacyBody, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 22,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _privacyLine,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyPage extends StatelessWidget {
  const _ReadyPage({required this.onBegin});

  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PageScroll(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _readyHeading,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onBegin,
              child: const Text('Begin'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 8,
            width: i == active ? 24 : 8,
            decoration: BoxDecoration(
              color: i == active ? scheme.primary : scheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
