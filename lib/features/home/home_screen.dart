import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crisis/crisis_router.dart';
import '../../ui/widgets/crisis_header.dart';
import 'home_state.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(homeProvider).situationText,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onContinue() {
    final situation = ref.read(homeProvider).situationText;
    switch (ref.read(crisisRouterProvider)(situation)) {
      case GoSession():
        context.go('/session');
      case GoCrisis():
        context.go('/crisis');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText =
        ref.watch(homeProvider).situationText.trim().isNotEmpty;
    final notifier = ref.read(homeProvider.notifier);

    return Scaffold(
      body: Column(
        children: [
          const CrisisHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: TextField(
                controller: _controller,
                onChanged: notifier.setSituation,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: theme.textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText:
                      "Write what you're sitting with. As long or as short as you need.",
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              onPressed: hasText ? _onContinue : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
