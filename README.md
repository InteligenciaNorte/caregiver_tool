# KindNow

An **offline, on-device** Flutter app for family caregivers of people with
dementia. (Package / repo id: `caregiver_tool`.) It runs one short, evidence-based exercise — *Witnessing Hard
Moments with Compassion* — when a caregiver is sitting with a shame-laden
moment (snapped at a parent, felt relief at a hospitalization, a dark
thought they can't say out loud).

A fine-tuned **Gemma 4 E2B** runs entirely on the phone. There is no
network, no account, no telemetry, and **nothing is saved between
sessions** — the typed situation and the conversation live in memory only
and are gone when the session ends.

> Hackathon submission. The ~3.4 GB model is **not** bundled in the APK
> (it exceeds store limits); on first launch the app offers a one-time,
> user-initiated download (see *Model* below), after which everything
> runs offline.

## How it works

1. **Onboarding** (once) — what it is, example disclosures, the privacy
   posture, then *Begin*.
2. **Home** — a single calm screen: write what you're sitting with.
3. A deterministic, on-device **crisis classifier** (pure Dart, no model)
   triages the text. HIGH/ACUTE routes to a full-screen crisis screen with
   helpline numbers and never starts a model session; MEDIUM runs the
   session with a pinned helpline card.
4. **Session** — the model produces four short reflections in one ChatML
   conversation: Mirror → Normalize → Self-compassion → Close. The app
   drives the steps; the model only produces language. *Done* returns to a
   clean Home.

The single source of truth for behavior is
[`docs/architecture.md`](docs/architecture.md); safety/classifier rationale
is in [`docs/classifier_research.md`](docs/classifier_research.md).

## Tech

Flutter 3.24+ / Dart 3, `flutter_riverpod` (`StateNotifierProvider`,
sealed states, no codegen), `go_router`, `llamadart` (llama.cpp) for
on-device GGUF inference, `shared_preferences` (one boolean only). Android
is the primary target; iOS is cross-platform validation.

## Build & run

```bash
flutter pub get
flutter analyze          # must be clean
flutter test             # full flow incl. the 4-step session + safety

# Emulator / CI: runs with a deterministic MockGemmaClient (no model)
flutter run

# Real on-device model (physical device, 8 GB+ RAM):
flutter build apk --release --dart-define=USE_REAL_MODEL=true \
  --target-platform android-arm64
```

`USE_REAL_MODEL=true` switches the LLM provider to the real
`llamadart`-backed client; unset (emulator, tests, CI) keeps the mock, so
the whole app and its 42 tests run with no model.

## Model

The fine-tuned Gemma 4 E2B GGUF (`gemma4-e2b_r32-q4_k_m.gguf`, ~3.4 GB,
Q4_K_M) is **not** in this repo (size + licensing live with the model
card). On first launch the real-model build shows a consent screen and,
once the user taps **Download**, fetches the GGUF over HTTPS into the
app's private storage and verifies its SHA-256. It is downloaded **once**
and reused across app updates; nothing else uses the network. Dev builds
can side-load via `--dart-define=DEV_MODEL_PATH=…`.

Model card / weights (public, not gated):
**https://huggingface.co/Serjio42/gemma4-e2b-finetuned-caregivers**

For reproducible downloads, pin the commit rather than `main`:

```
https://huggingface.co/Serjio42/gemma4-e2b-finetuned-caregivers/resolve/2e94bc80e5c7745d63ed96a1c44b4c57139af56f/gemma4-e2b_r32-q4_k_m.gguf
```

`sha256(gemma4-e2b_r32-q4_k_m.gguf)` =
`81ce0ae4a3fb37040faf37c6eedc0985f0d7fa291e8d17a9820937ccdab4158b`.

## Why this inference stack

Running a **fine-tuned** Gemma 4 E2B on a phone in May 2026 is more
constrained than the marketing suggests, and the choices below are forced,
not preferred. Recording the reasoning here so the trade-offs are explicit.

**GGUF + llama.cpp (via `llamadart`) is the only path that actually works
for our weights.** Google's own on-device runtime, LiteRT-LM (the
`.litertlm` format), produces better-quality output for Gemma 4 — but there
is **no public way to convert a fine-tuned Gemma 4 into `.litertlm`**:

- the MediaPipe converter exposes no `GEMMA_4_E2B` model type (only
  `GEMMA3N` / `GEMMA3` / `QWEN*` as of late 2025);
- Gemma 4's Per-Layer Embeddings (PLE) live in a separate
  `tf_lite_per_layer_embedder` sub-model that Google generates with an
  unreleased internal tool — third parties can only reuse the **base
  model's** PLE section, which discards part of any fine-tuning.

So LiteRT-LM can run *Google's* Gemma 4, but not *our* fine-tuned one. The
LoRA → merge → `safetensors` half of the pipeline works; the
`safetensors → .litertlm` half is a dead end today (tracked below as
`#6852` / `#998`). GGUF is what's left, and it runs.

**The cost of GGUF: quality is capped by an upstream bug.** In llama.cpp the
Gemma 4 PLE tensors are read from the GGUF metadata but the per-layer
residual signal is **not yet injected into the decoder layers** (issue
`#22243`). The model therefore runs without part of its per-layer
representational capacity: output is coherent but reasoning and
instruction-following are visibly weaker than the same weights deserve. This
is an upstream limitation, not a defect in the fine-tune. (Gemma **3n**'s PLE
*is* implemented correctly in llama.cpp — a possible fallback if quality
proves unacceptable, at the cost of Gemma 4's improvements.)

**Inference is CPU-only, deliberately.** Two independent reasons:

1. `llamadart` 0.6.x has no working Android GPU path for this model, so
   today there is no GPU lever to pull regardless.
2. Even where a GPU delegate exists (e.g. base Gemma 4 in LiteRT-LM /
   Edge Gallery), the Android GPU path repacks weights into pinned
   OpenCL/ION buffers and never frees the source `mmap`, roughly **doubling
   peak memory** at graph-compile time. On an 8 GB device that overflows for
   **E4B** (~6.5–7 GB peak → killed by `lmkd`); **E2B fits**, and E4B runs
   fine on CPU. PLE itself stays CPU-resident (`mmap`) and is not the part
   that overflows.

CPU-only shares the model's `mmap` pages, stays well within memory, and is
stable under pressure — at ~10–14 tok/s for E2B on a Snapdragon 8 Gen 2.
GPU is **not abandoned**: it's a backlog option for E2B / a smaller variant,
or for if/when a no-double-allocation path appears (see issues below).

### Upstream issues we track

These gate how production-ready the on-device stack is. Re-check roughly
every two weeks; after any relevant fix, rebuild the stack and re-benchmark
the fine-tuned model before/after.

| Issue | Repo | Status | Why it matters |
|---|---|---|---|
| [llama.cpp #22243](https://github.com/ggml-org/llama.cpp/issues/22243) | ggml-org/llama.cpp | OPEN | Gemma 4 PLE not injected into the forward graph → our capped quality. The key unlock: when fixed, rebuild + re-benchmark, possibly retrain. |
| [LiteRT #6852](https://github.com/google-ai-edge/LiteRT/issues/6852) | google-ai-edge/LiteRT | OPEN | No documented path to convert a fine-tuned Gemma 4 → `.litertlm`. A fix would unblock migrating to LiteRT-LM (correct PLE, GPU). |
| [litert-torch #998](https://github.com/google-ai-edge/litert-torch/issues/998) | google-ai-edge/litert-torch | OPEN | Same conversion question in the sibling repo; watch both. |
| [LiteRT-LM #1864](https://github.com/google-ai-edge/LiteRT-LM/issues/1864) | google-ai-edge/LiteRT-LM | OPEN | Gemma 4 E4B fails to create an engine on Exynos 2600 — would block some Samsung devices if we move to LiteRT-LM. |
| [gallery #701](https://github.com/google-ai-edge/gallery/issues/701) | google-ai-edge/gallery | OPEN | Android 17 `MemoryLimiter` kills E4B — recheck our memory profile once Android 17 ships stable. |
| [transformers #45207](https://github.com/huggingface/transformers/pull/45207) | huggingface/transformers | MERGED | Reference PLE implementation — the correctness baseline for any third-party PLE work. |

## Status

- Verified end-to-end on a Pixel 9 emulator (mock) and a physical Galaxy
  S23 (real model): full onboarding → session → crisis flow, the
  user-initiated model download (resumable, SHA-256 verified), real
  reflections generated on-device, no OOM.
- `flutter analyze` clean; 42 tests green.
- Release APKs are signed with a dedicated release keystore (kept
  outside the repo).

### Platforms / roadmap

- **Android — done.** The primary, fully working target: real on-device
  model, user-initiated one-time download, release-signed APK.
- **iOS — TODO.** Cross-platform validation only; not built or verified
  this cycle.

Known minor issues, deferred: bottom action buttons can overlap the
Android system navigation bar; on-device generation runs on CPU and is
slow, and output quality is capped by an upstream llama.cpp bug — see
[*Why this inference stack*](#why-this-inference-stack) for the full
reasoning and the issues we track.

## License

Licensed under the **Apache License 2.0** — see [`LICENSE`](LICENSE).

The on-device model is a fine-tuned derivative of **Google Gemma 4 E2B**,
released by Google under the Apache License 2.0
(<https://ai.google.dev/gemma/docs/gemma_4_license>). Fine-tuned with LoRA
(rank 32), merged and quantized to Q4_K_M via llama.cpp. The derivative
weights are distributed under Apache 2.0 on the model card linked above.
