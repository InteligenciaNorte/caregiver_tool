/// Deterministic stand-in for the on-device model.
///
/// Lets the entire app — onboarding, Home, classifier routing, the 4-step
/// session, background generation, the MEDIUM helpline card, failure
/// handling — be exercised with no GGUF, on an emulator, and in CI. It is
/// NOT a fallback shown to users in production: the real client throws on
/// failure and the session layer surfaces an honest inline message rather
/// than a faked reflection (CLAUDE.md §Session failure behavior).
///
/// The step is inferred from the conversation, not passed in, so the
/// session layer talks to the mock and the real client through the exact
/// same [GemmaClient.reply] contract.
library;

import 'gemma_client.dart';

class MockGemmaClient implements GemmaClient {
  MockGemmaClient({
    this.latency = const Duration(milliseconds: 700),
    Set<int> failSteps = const {},
  }) : _failSteps = failSteps;

  /// Simulated generation time, so the session UX (step-0 spinner,
  /// background pre-gen overlapping the user's reading) is real-feeling in
  /// dev. ~700 ms ≈ a fast on-device first step.
  final Duration latency;

  /// Step indices (0..3) to throw on, for exercising the session layer's
  /// retry-once-then-honest-inline-message path. Empty by default.
  final Set<int> _failSteps;

  // One canned line per step, in the model's voice per the system prompt:
  // plain language, 1–3 sentences, no markdown, no clinical framing. Generic
  // by necessity (a mock can't truly mirror the input) and obviously not a
  // real reflection — that is the point.
  static const List<String> _byStep = [
    // 0 — Mirror
    "You snapped, and now you're sitting with how that felt. That moment is "
        "heavy, and you brought it here instead of carrying it alone.",
    // 1 — Normalize
    "What came up in you is what comes up in almost everyone doing this, "
        "under this much strain, for this long. It is exhaustion speaking, "
        "not who you are.",
    // 2 — Self-compassion
    "See if your shoulders can drop, just a little. The patience you would "
        "offer a friend in your place — some of that is yours to keep too.",
    // 3 — Close
    "You moved through something hard just now. That is enough for now.",
  ];

  @override
  Future<void> warmUp() async {}

  @override
  Future<String> reply(List<ChatMessage> conversation) async {
    // Step = how many assistant turns already exist. Turn 0 is produced
    // when none exist yet, turn 3 when three do.
    final step =
        conversation.where((m) => m.role == ChatRole.assistant).length;

    // Only schedule a real timer when a latency is actually wanted. With
    // zero latency (tests/CI) resolve on a microtask instead: a
    // Duration.zero timer depends on the fake clock being elapsed, which
    // makes widget tests timing-fragile across a suite.
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    } else {
      await Future<void>.value();
    }

    if (_failSteps.contains(step)) {
      throw StateError('MockGemmaClient: injected failure at step $step');
    }
    if (step < 0 || step >= _byStep.length) {
      throw StateError('MockGemmaClient: no step $step '
          '(expected 0..${kWitnessStepCount - 1})');
    }
    return _byStep[step];
  }

  @override
  Future<void> shutdown() async {}
}
