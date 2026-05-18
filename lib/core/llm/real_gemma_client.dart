/// The production [GemmaClient]: the fine-tuned Gemma 4 E2B GGUF running
/// on-device via `llamadart` (llama.cpp). No network (CLAUDE.md Hard Rule
/// #2) — the model file is already on the device (side-loaded for dev;
/// downloaded once on first launch for production — see hosting-guide).
///
/// Wiring is unchanged from the mock: the session layer builds the ChatML
/// conversation and calls [reply]; only `gemmaClientProvider` is overridden
/// to return this instead of [MockGemmaClient] on a real device build.
///
/// Sampling/runtime are taken verbatim from the ML engineer's
/// `inference_config.json` (the authoritative source per
/// architecture.md §On-device inference) — these are fine-tune outputs, not
/// app choices, and must not be changed in app code.
library;

import 'package:llamadart/llamadart.dart';

import 'gemma_client.dart';

/// Runtime + sampling, from `inference_config.json`:
/// context_size 2048; temperature 1.0, top_p 0.95, top_k 64,
/// repeat_penalty 1.0, max_new_tokens 300. Stop tokens are baked into the
/// GGUF metadata ([1,106,50]) — "No need to configure in app code" — so
/// `stopSequences` stays empty and llama.cpp stops on them automatically.
const int _kContextSize = 2048;

const GenerationParams _kGenerationParams = GenerationParams(
  maxTokens: 300,
  temp: 1.0,
  topP: 0.95,
  topK: 64,
  penalty: 1.0,
);

class RealGemmaClient implements GemmaClient {
  RealGemmaClient(this._modelPath);

  /// Absolute path to `gemma4-e2b_r32-q4_k_m.gguf` on the device. Injected
  /// (via [modelPathProvider]) so this class owns inference, not storage.
  final String _modelPath;

  LlamaEngine? _engine;
  bool _loading = false;

  @override
  Future<void> warmUp() async {
    if (_engine != null || _loading) return;
    _loading = true;
    try {
      final engine = LlamaEngine(LlamaBackend());
      // gpuLayers is left at the llamadart default (all): on Android the
      // backend is CPU by default so it is a no-op; on devices with a
      // bundled GPU backend it offloads, matching architecture.md's intent.
      await engine.loadModel(
        _modelPath,
        modelParams: const ModelParams(contextSize: _kContextSize),
      );
      _engine = engine;
    } finally {
      _loading = false;
    }
  }

  @override
  Future<String> reply(List<ChatMessage> conversation) async {
    await warmUp();
    final engine = _engine;
    if (engine == null) {
      throw StateError('RealGemmaClient: model failed to load');
    }

    final messages = [
      for (final m in conversation)
        LlamaChatMessage.fromText(role: _role(m.role), text: m.text),
    ];

    // llamadart applies the GGUF's own chat template (the format the model
    // was fine-tuned on). Gemma E2B is not a reasoning model — disable the
    // thinking scaffolding so the template stays the trained shape.
    final buffer = StringBuffer();
    await for (final chunk in engine.create(
      messages,
      params: _kGenerationParams,
      enableThinking: false,
    )) {
      if (chunk.choices.isEmpty) continue;
      final content = chunk.choices.first.delta.content;
      if (content != null) buffer.write(content);
    }

    final text = buffer.toString().trim();
    if (text.isEmpty) {
      // Never fake a reflection — let the session layer surface an honest
      // failure (CLAUDE.md §Session failure behavior).
      throw StateError('RealGemmaClient: empty generation');
    }
    return text;
  }

  @override
  Future<void> shutdown() async {
    final engine = _engine;
    _engine = null;
    await engine?.dispose();
  }

  LlamaChatRole _role(ChatRole r) => switch (r) {
        ChatRole.system => LlamaChatRole.system,
        ChatRole.user => LlamaChatRole.user,
        ChatRole.assistant => LlamaChatRole.assistant,
      };
}
