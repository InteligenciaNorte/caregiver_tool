/// The on-device language-model seam.
///
/// The app drives the four-step witness flow; the model only produces
/// language (architecture.md §Flow). Everything above this interface — the
/// step state machine, background generation, ChatML assembly — is
/// developer-owned and lives in `lib/features/session/`. Everything below
/// it is a single concern: "given the conversation so far, produce the next
/// assistant turn."
///
/// Two implementations:
/// - [MockGemmaClient] — deterministic, no model, used for tests/dev and
///   for verifying the whole flow on an emulator (the 3.4 GB GGUF is
///   unusable on an x86_64 emulator: no GPU offload, RAM, slow).
/// - `RealGemmaClient` (later) — `llamadart` / llama.cpp backed, loads the
///   GGUF on a physical 8 GB device.
///
/// No codegen, no network (CLAUDE.md Hard Rules #1, #2): a plain interface.
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mock_gemma_client.dart';

/// ChatML roles. The conversation is `system` once, then strictly
/// alternating `user` / `assistant` (architecture.md §ChatML conversation
/// shape).
enum ChatRole { system, user, assistant }

/// One ChatML turn. Immutable, no codegen (CLAUDE.md Hard Rule #1).
class ChatMessage {
  const ChatMessage(this.role, this.text);

  const ChatMessage.system(String text) : this(ChatRole.system, text);
  const ChatMessage.user(String text) : this(ChatRole.user, text);
  const ChatMessage.assistant(String text) : this(ChatRole.assistant, text);

  final ChatRole role;
  final String text;
}

/// The literal string sent as every user turn after the opening situation.
///
/// RESOLVED: the model card (`final_version/README.md`, the authoritative
/// source per the project owner) specifies the literal string `"Continue"`,
/// sent three times. This supersedes CLAUDE.md's stale `"<continue>"`
/// placeholder note (kept there as UNRESOLVED before the model landed).
const String kContinueMarker = 'Continue';

/// The fine-tuned model expects exactly four assistant turns:
/// Mirror → Normalize → Self-compassion → Close (architecture.md §The four
/// steps; model card §conversation_protocol).
const int kWitnessStepCount = 4;

/// Loaded once at startup and sent verbatim as the single system message
/// (architecture.md §Tech choices). Byte-identical to the ML engineer's
/// delivered `system_prompt.txt` (verified).
const String kWitnessSystemPromptAsset =
    'assets/prompts/witnessing_hard_moments.txt';

/// "Given the conversation so far, produce the next assistant turn."
///
/// The session layer owns the conversation list and the step logic; this
/// stays a thin, mockable boundary so the same step machine runs unchanged
/// on the mock and on the real llama.cpp backend.
abstract interface class GemmaClient {
  /// Load / warm the backend. Idempotent. Mock: a no-op. Real: loads the
  /// GGUF (slow, do it once behind the splash). Safe to await repeatedly.
  Future<void> warmUp();

  /// Produce the next assistant message for [conversation], which is the
  /// full ChatML so far (system first, then alternating user/assistant,
  /// ending on a user turn). Returns the assistant text only — the caller
  /// appends it. Throws on generation failure; the session layer handles
  /// retry/fallback (CLAUDE.md §Session failure behavior — never fake a
  /// model response).
  Future<String> reply(List<ChatMessage> conversation);

  /// Release native resources. Mock: a no-op.
  Future<void> shutdown();
}

/// The client seam. Defaults to the mock so the whole app runs with no
/// model (emulator, tests, CI). `RealGemmaClient` overrides this provider
/// in `main.dart` once it lands — no call-site changes (mirrors the
/// `classifyProvider` seam pattern in `crisis_router.dart`).
final gemmaClientProvider = Provider<GemmaClient>((ref) {
  final client = MockGemmaClient();
  ref.onDispose(client.shutdown);
  return client;
});

/// System-prompt loader seam. Production loads the bundled asset verbatim
/// (architecture.md §Tech choices). Tests override this with a stub so the
/// global `rootBundle` (a `CachingAssetBundle`) is never touched: it caches
/// load Futures across tests, and a Future resolved in one widget test's
/// zone hangs when awaited in another's — a real cross-test failure we hit.
final systemPromptProvider = Provider<Future<String> Function()>(
  (ref) => () => rootBundle.loadString(kWitnessSystemPromptAsset),
);
