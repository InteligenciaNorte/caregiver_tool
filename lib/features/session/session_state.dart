import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crisis/risk_level.dart';
import '../../core/llm/gemma_client.dart';

/// The 4-step witness session state machine (architecture.md §Flow,
/// §Generation strategy). The app drives the steps; the model produces the
/// language. Nothing here is persisted (CLAUDE.md Hard Rule #3) — it lives
/// in memory and is gone on app close.
///
/// State of one of the four steps. Native Dart 3 `sealed class`, no Freezed
/// / codegen (CLAUDE.md Hard Rule #1, Tech choices).
sealed class StepState {
  const StepState();
}

/// Not requested yet (later step, before pre-generation reaches it).
class StepPending extends StepState {
  const StepPending();
}

/// Request in flight — covers the first attempt and the one silent retry.
class StepGenerating extends StepState {
  const StepGenerating();
}

/// The model produced this step's reflection.
class StepReady extends StepState {
  const StepReady(this.text);
  final String text;
}

/// Generation failed twice (first failure was retried silently). The screen
/// shows a calm inline message + Try again / Close for now — never a faked
/// reflection (CLAUDE.md §Session failure behavior).
class StepFailed extends StepState {
  const StepFailed();
}

class SessionState {
  const SessionState({
    this.risk = RiskLevel.none,
    this.situation = '',
    this.steps = const [
      StepPending(),
      StepPending(),
      StepPending(),
      StepPending(),
    ],
    this.visibleStep = 0,
  });

  final RiskLevel risk;
  final String situation;

  /// Length [kWitnessStepCount]; index == step number (0 = Mirror …
  /// 3 = Close).
  final List<StepState> steps;

  /// The step the user is currently on (0..3).
  final int visibleStep;

  /// MEDIUM runs a normal session but with the helpline card pinned on
  /// every step (architecture.md §Safety). NONE/LOW never see it.
  bool get showHelplineCard => risk == RiskLevel.medium;

  StepState get current => steps[visibleStep];

  bool get isLastStep => visibleStep == kWitnessStepCount - 1;

  SessionState copyWith({
    RiskLevel? risk,
    String? situation,
    List<StepState>? steps,
    int? visibleStep,
  }) =>
      SessionState(
        risk: risk ?? this.risk,
        situation: situation ?? this.situation,
        steps: steps ?? this.steps,
        visibleStep: visibleStep ?? this.visibleStep,
      );
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(this._client, this._loadSystemPrompt)
      : super(const SessionState());

  final GemmaClient _client;
  final Future<String> Function() _loadSystemPrompt;
  String? _systemPrompt;

  /// Called once at the Home → session transition with the classified
  /// level and the caregiver's typed situation. Always builds fresh state
  /// (set, never merged) so a prior session can't leak its risk or
  /// conversation into the next one.
  Future<void> start(RiskLevel risk, String situation) async {
    state = SessionState(risk: risk, situation: situation);
    try {
      _systemPrompt = await _loadSystemPrompt();
      await _client.warmUp();
    } catch (_) {
      // Couldn't load the trained system prompt or warm the backend.
      // Never run the model without its prompt and never fake step 0 —
      // surface it as an honest failure.
      _setStep(0, const StepFailed());
      return;
    }
    await _generate(0);
  }

  /// The ChatML sent to produce [step]: the system prompt once, the
  /// caregiver's situation, then each prior assistant step followed by a
  /// literal "Continue" user turn (architecture.md §ChatML conversation
  /// shape; marker resolved in [kContinueMarker]).
  List<ChatMessage> _conversationFor(int step) {
    final msgs = <ChatMessage>[
      ChatMessage.system(_systemPrompt ?? ''),
      ChatMessage.user(state.situation),
    ];
    for (var i = 0; i < step; i++) {
      final prior = state.steps[i];
      if (prior is! StepReady) {
        throw StateError('step $step requested before step $i was ready');
      }
      msgs
        ..add(ChatMessage.assistant(prior.text))
        ..add(const ChatMessage.user(kContinueMarker));
    }
    return msgs;
  }

  void _setStep(int i, StepState s) {
    final next = [...state.steps];
    next[i] = s;
    state = state.copyWith(steps: next);
  }

  /// Generate [step]. One silent retry on failure, no UI change; a second
  /// failure surfaces [StepFailed] (CLAUDE.md §Session failure behavior).
  /// On success, kicks background pre-generation of the next step so it
  /// overlaps the user's reading time, not their tap-and-wait time
  /// (architecture.md §Generation strategy).
  Future<void> _generate(int step) async {
    if (step < 0 || step >= kWitnessStepCount) return;
    _setStep(step, const StepGenerating());

    String? text;
    for (var attempt = 0; attempt < 2 && text == null; attempt++) {
      try {
        text = await _client.reply(_conversationFor(step));
      } catch (_) {
        // First failure: retry once silently. Second: fall through.
      }
    }

    if (text == null) {
      _setStep(step, const StepFailed());
      return;
    }
    _setStep(step, StepReady(text));

    final next = step + 1;
    if (next < kWitnessStepCount && state.steps[next] is StepPending) {
      unawaited(_generate(next));
    }
  }

  /// User tapped Continue on a ready, non-last step. If pre-generation
  /// already finished the next step (the common case — reading is slower
  /// than generation) it appears instantly; otherwise the screen shows an
  /// inline spinner until it lands.
  void advance() {
    if (state.current is! StepReady || state.isLastStep) return;
    final next = state.visibleStep + 1;
    state = state.copyWith(visibleStep: next);
    if (state.steps[next] is StepPending) {
      unawaited(_generate(next));
    }
  }

  /// "Try again" after a surfaced failure: fresh attempts for that step.
  void retry() {
    if (state.current is StepFailed) {
      unawaited(_generate(state.visibleStep));
    }
  }

  /// Session ended (Done or Close for now). Drop the whole conversation so
  /// nothing leaks into the next session — architecture.md §Privacy: it is
  /// "gone when the session ends". `start` rebuilds fresh anyway; this
  /// makes the end explicit and frees the held step text immediately.
  void reset() => state = const SessionState();
}

/// Holds the in-memory session. Plain (not autoDispose): Home calls
/// [SessionNotifier.start] before navigating, and `start` resets state, so
/// each session begins clean without leaking the previous one.
final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>(
  (ref) => SessionNotifier(
    ref.watch(gemmaClientProvider),
    ref.watch(systemPromptProvider),
  ),
);
