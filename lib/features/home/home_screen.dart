import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'home_state.dart';

const _placeholders = [
  'Snapped at her. Now guilty.',
  "Can't sleep. Listening.",
  'Got the bill.',
];

const _durations = [3, 5, 10, 15];

String _greetingGlyph(DateTime now) {
  final h = now.hour;
  if (h >= 22 || h < 5) return '🌙';
  if (h < 11) return '🌅';
  if (h < 17) return '☀️';
  return '🌆';
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _controller;
  Timer? _placeholderTimer;
  int _placeholderIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _placeholderTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      setState(() {
        _placeholderIndex = (_placeholderIndex + 1) % _placeholders.length;
      });
    });
  }

  @override
  void dispose() {
    _placeholderTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeProvider);
    final notifier = ref.read(homeProvider.notifier);
    final theme = Theme.of(context);

    // TODO(copy): confirm glyph set + hour boundaries with project lead
    final greeting = '${_greetingGlyph(DateTime.now())}  Glad you came';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    Text(greeting, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 40),
                    Text(
                      'How long do you have?',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: [
                        for (final m in _durations)
                          ChoiceChip(
                            label: Text(m == 15 ? '15+ min' : '$m min'),
                            selected: state.selectedDurationMin == m,
                            onSelected: (_) => notifier.setDuration(m),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      "What's the moment?",
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      onChanged: notifier.setSituation,
                      maxLines: 1,
                      decoration: InputDecoration(
                        hintText: _placeholders[_placeholderIndex],
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 40),
                    FilledButton(
                      onPressed: state.selectedDurationMin == null
                          ? null
                          : () => context.go('/module/self_compassion'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: const Text('Begin'),
                    ),
                    const SizedBox(height: 24),
                    // TODO(day2): list last 3 sessions from sqflite
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextButton(
                // TODO(day3): open CrisisOverlay
                onPressed: () {},
                child: const Text('I need help right now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
