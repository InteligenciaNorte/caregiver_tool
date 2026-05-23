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

The app runs a fine-tuned **Gemma 4 E2B** on-device as **GGUF via llama.cpp**
(the `llamadart` plugin), on **CPU**. Recording the reasoning so the
trade-offs are explicit. (Issue statuses below verified against GitHub on
2026-05-23.)

**GGUF + llama.cpp works and is architecturally correct today.** Gemma 4's
Per-Layer Embeddings (PLE) *are* implemented in llama.cpp's forward graph
(`src/models/gemma4-iswa.cpp`; follow the `inp_per_layer` tensor), and the
PLE tensors are kept at a safe quantization (≥`Q4_K`), so our `Q4_K_M` model
runs with its full architecture — there is **no PLE quality penalty**. (This
was questioned in llama.cpp `#22243`, which a maintainer closed by confirming
the pipeline is wired in correctly.)

**LiteRT-LM is a future option, not a blocked path.** Google's on-device
runtime (the `.litertlm` format) can use the OpenCL/ML Drift GPU backend,
which is the one accelerator that reliably beats CPU on Android. Converting a
**fine-tuned** Gemma 4 to `.litertlm` is now possible via `litert-torch`
(`main` / 0.9.0, `hf_export.export(task="text_generation", …)`). The catch is
**on-device runtime**, not conversion: the public export currently produces
bundles whose tensor signatures don't match Google's prebuilt models
(float32 vs int8 KV-cache, float32 vs bool masks, a missing `param_tensor`
input), and several people hit `SIGSEGV` at prefill (`litert-torch #998`).
Vision-encoder export is also not yet publicly supported. So LiteRT-LM is
worth re-evaluating for E2B once the exported model runs reliably — it isn't
there yet.

**Inference is CPU-only, deliberately.** A GPU path *does* exist in our stack
— `llamadart` exposes llama.cpp's **Vulkan** backend (`GGML_VULKAN`), via
`n_gpu_layers` (0 = CPU, 99/-1 = all on GPU) — but we don't use it:

1. **On mobile, Vulkan is often *slower* than CPU.** Adreno/Mali have no
   dedicated VRAM — it's shared LPDDR — so weights are still copied into
   Vulkan buffers (double-allocation), memory bandwidth is split between CPU
   and GPU, and the mobile Vulkan-compute drivers aren't tuned for LLM
   inference. Long-standing in llama.cpp
   ([discussion #9464](https://github.com/ggml-org/llama.cpp/discussions/9464));
   on many Android devices GGUF on CPU (XNNPACK/NEON) beats the same GGUF on
   Vulkan. The Android GPU that reliably *wins* is Google's OpenCL/ML Drift —
   and that lives in LiteRT-LM, not in llama.cpp.
2. **Memory: GPU load roughly doubles peak memory.** On an 8 GB device that's
   fatal for the larger **E4B** (~6.5–7 GB peak → killed by `lmkd`, observed
   with base Gemma 4 in Edge Gallery), while **E2B fits**.

CPU shares the model's `mmap` pages, stays well within memory, and is stable
under pressure — at ~10–14 tok/s for E2B on a Snapdragon 8 Gen 2. So for our
GGUF build CPU is both faster-in-practice and more stable. A GPU win would
require the LiteRT-LM path above (ML Drift, not Vulkan), and even then only
for E2B.

### Upstream issues for context

Verified against GitHub on 2026-05-23. Re-check periodically; after any
relevant change, rebuild and re-benchmark before/after.

| Issue | Repo | State | What it actually says |
|---|---|---|---|
| [llama.cpp #22243](https://github.com/ggml-org/llama.cpp/issues/22243) | ggml-org/llama.cpp | **CLOSED** (completed) | Asked whether Gemma 4 PLE was wired into the forward graph; the maintainer confirmed it **is** (`gemma4-iswa.cpp`). No PLE bug. |
| [litert-torch #998](https://github.com/google-ai-edge/litert-torch/issues/998) | google-ai-edge/litert-torch | OPEN | Fine-tuned Gemma 4 → `.litertlm` text export works on `main`; the open problem is the exported model **crashing on-device** (signature mismatch vs prebuilt). Vision export unsupported. |
| [LiteRT #6852](https://github.com/google-ai-edge/LiteRT/issues/6852) | google-ai-edge/LiteRT | CLOSED (duplicate of #998) | Same conversion question; redirected to #998. |
| [LiteRT-LM #1864](https://github.com/google-ai-edge/LiteRT-LM/issues/1864) | google-ai-edge/LiteRT-LM | OPEN | Gemma 4 E4B/E2B fail to initialize the LiteRT engine on Samsung Exynos 2600 (S26). |
| [gallery #701](https://github.com/google-ai-edge/gallery/issues/701) | google-ai-edge/gallery | OPEN | Gemma 4 E4B crashes on a Pixel 6a after the Android 17 Beta 4 `MemoryLimiter` change. |
| [transformers #45207](https://github.com/huggingface/transformers/pull/45207) | huggingface/transformers | MERGED | Adds docstrings for the reference PLE pipeline (documentation, not the implementation). |

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
slow — see [*Why this inference stack*](#why-this-inference-stack) for why
CPU, the LiteRT-LM/GPU outlook, and the upstream issues we track.

## License

Licensed under the **Apache License 2.0** — see [`LICENSE`](LICENSE).

The on-device model is a fine-tuned derivative of **Google Gemma 4 E2B**,
released by Google under the Apache License 2.0
(<https://ai.google.dev/gemma/docs/gemma_4_license>). Fine-tuned with LoRA
(rank 32), merged and quantized to Q4_K_M via llama.cpp. The derivative
weights are distributed under Apache 2.0 on the model card linked above.
