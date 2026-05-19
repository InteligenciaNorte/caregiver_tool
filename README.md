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
slow (GPU offload is under investigation).

## License

Licensed under the **Apache License 2.0** — see [`LICENSE`](LICENSE).

The on-device model is a fine-tuned derivative of **Google Gemma 4 E2B**,
released by Google under the Apache License 2.0
(<https://ai.google.dev/gemma/docs/gemma_4_license>). Fine-tuned with LoRA
(rank 32), merged and quantized to Q4_K_M via llama.cpp. The derivative
weights are distributed under Apache 2.0 on the model card linked above.
