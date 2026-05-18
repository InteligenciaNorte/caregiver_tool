import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crisis/crisis_router.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/crisis_header.dart';
import '../session/session_state.dart';
import 'home_state.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(homeProvider).situationText,
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  // Drop the hint the moment the field is focused (cursor in), not only on
  // the first keystroke; it returns if the user leaves without writing.
  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onContinue() {
    final situation = ref.read(homeProvider).situationText;
    switch (ref.read(crisisRouterProvider)(situation)) {
      case GoSession(:final level):
        // NONE/LOW/MEDIUM all run the session; the level decides whether
        // the MEDIUM helpline card is pinned (read in SessionScreen).
        ref.read(sessionProvider.notifier).start(level);
        context.go('/session');
      case GoCrisis():
        context.go('/crisis');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = ref.watch(homeProvider).situationText.trim().isNotEmpty;
    final notifier = ref.read(homeProvider.notifier);

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const CrisisHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Container(
                  decoration: BoxDecoration(
                    // Shared neutral surface (see kSurfacePanel): a faint
                    // light edge + soft drop shadow lift it off the darker
                    // background as a calm raised card.
                    color: kSurfacePanel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 28,
                        spreadRadius: -4,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: notifier.setSituation,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: _focusNode.hasFocus
                          ? null
                          : "Write what you're sitting with. As long or as short as you need.",
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: hasText ? _onContinue : null,
                  child: const Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
