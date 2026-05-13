# CLAUDE.md — Project Memory for caregiver_tool

## Project Context

Flutter app (Android + iOS) for family caregivers of people with dementia.
Runs Gemma 4 E2B on-device (no network) via llama.cpp through the llamadart Flutter plugin.
Hackathon submission, deadline May 18, 2026.

I (the developer) am working with an ML engineer in parallel.
I own the Flutter app; they own the model, training data, and crisis classifier rules.

## Hard Rules (NEVER violate)

1. **NO code generation packages.** Do NOT add `build_runner`, `freezed`,
   `freezed_annotation`, `drift`, `drift_dev`, `riverpod_generator`,
   `json_serializable`, or `auto_route`. If a solution requires one of these,
   stop and find a no-codegen alternative.
2. **NO network calls except `tel:` URIs.** The app is offline-first.
   Do not add `dio`, `http`, `firebase_*`, `sentry_*`, `crashlytics`,
   `posthog`, `mixpanel`, or any telemetry/analytics package.
3. **NO login, account, email field, or share buttons.**
4. **Crisis classifier rules are owned by the ML engineer.** Do not edit
   logic in `lib/core/crisis/classifier.dart`. You wire it; you don't tune it.
5. **Calibrated copy is owned by the project lead.** Do not change wording
   on Onboarding cards, the Crisis Overlay, or the "I need to stop" buttons
   without asking. Layout/spacing/colors are fair game; words are not.

## Tech Stack (locked)

- Flutter 3.24+, Dart 3.5+
- **Platforms: Android (primary) + iOS (cross-platform validation).** iOS deployment target 16.4+.
- State: `flutter_riverpod` with `StateNotifierProvider` (NOT `@riverpod` codegen)
- Sealed states: native Dart 3 `sealed class` (NOT Freezed)
- Routing: `go_router` with string paths (NOT typed routes / codegen)
- DB: raw `sqflite` with manual repositories (NOT Drift)
- JSON: `dart:convert` with manual `fromJson`/`toJson` (NOT json_serializable)
- Settings: `shared_preferences`
- **LLM runtime: `llamadart` (Flutter plugin wrapping llama.cpp). Loads GGUF models.**
- **Model artifact: single `gemma-4-E2B-it-Q4_K_M.gguf` (~3 GB), produced by ML engineer via Unsloth → GGUF export.**
- **Inference config: `contextSize: 2048`, single quantization (Q4_K_M).** Both values lock-in for the hackathon; can be changed later if eval warrants.

## Build Commands

- Install deps: `flutter pub get`
- Run on connected device: `flutter run`
- Build debug APK: `flutter build apk --debug`
- Build release APK (Day 6+): `flutter build apk --release`
- Build iOS for testing: `flutter build ios --debug --no-codesign`
- Static analysis: `flutter analyze` (must pass with zero errors)
- Format: `dart format lib/`

## Directory Ownership

- `lib/core/llm/` — me (Flutter dev). Owns `GemmaClient` interface, `MockGemmaClient`, `RealGemmaClient` (llamadart-backed).
- `lib/core/crisis/classifier.dart` — ML engineer; do not edit
- `lib/core/crisis/crisis_router.dart` — me (Flutter dev)
- `lib/core/data/` — me
- `lib/core/modules/` — me, but `assets/prompts/*.json` arrives from ML engineer
- `lib/features/` — me
- `lib/ui/` — me
- `assets/model/*.gguf` — ML engineer drops files; do not generate or modify
- `assets/prompts/*.json` — ML engineer files; do not edit content, only load

## Workflow Conventions

- Ask before adding any new dependency.
- Ask before changing any user-facing copy.
- Run `flutter analyze` after every meaningful change. Zero errors required.
- Run on a real Android device daily, not just emulator.
- Commit at end of each day.

## What to do when stuck

- Compile errors: paste the FULL error including stack trace before guessing.
- Architectural question: re-read the directory ownership section above.
- Safety / model / classifier question: tell me to ask the ML engineer.
- Codegen suggestion appears: reject it, find no-codegen alternative.

## External docs in this repo

- `vibe-coder-brief.md` — full daily plan, Claude Code prompts (§6). **Note: §4 (tech stack) and §9 (handoff dependencies) still reference `flutter_gemma` and `.litertlm` from v1. The authoritative source is this CLAUDE.md.** Brief gets updated later.
- `module-system-doc-v2.md` — ModuleConfig/ModuleManifest contract with ML. Still accurate.
- `PHASE_1_DECISIONS.md` (if present) — log of pivots since v1 brief.

## Project Decisions Log (since v1 brief)

These decisions supersede anything older in `vibe-coder-brief.md`:

1. **LLM runtime: `flutter_gemma` → `llamadart`.** Reason: Unsloth fine-tuning exports to GGUF, not `.litertlm`. `.litertlm` export pipeline for fine-tuned models is not supported. Also unlocks iOS as a side benefit.
2. **Model format: `.litertlm` → GGUF.** Pairs with the runtime change. ML engineer exports merged LoRA model as a single GGUF artifact.
3. **Quantization: locked to Q4_K_M.** ~3 GB on disk. Q8_0 was the original suggestion but doesn't fit on 8 GB mobile devices (especially iPhone where Apple's per-app memory cap is ~3-4 GB on 8 GB hardware). LoRA quality compensates for the slightly lower base precision.
4. **Context window: `contextSize: 2048`.** Tight but sufficient for the longest module (Dichotomy sort: ~1940 tokens worst case). System-prompt-first truncation policy applies when overflow is approached: drop the oldest turn pair, never the system prompt.
5. **Platforms: Android + iOS** (was Android-only). iOS deployment target 16.4+. Demo recording: Samsung S23 (8 GB Android) as primary device; iPhone 16 Pro Max (8 GB iOS) as cross-platform validation.
6. **No analytics, no codegen, no network** — unchanged from v1.

## Test Devices

- **Samsung S23** (Android, 8 GB RAM) — primary test target, demo recording device
- **iPhone 16 Pro Max** (iOS, 8 GB RAM) — cross-platform validation
- Both devices have hard memory constraints. Watch for OOM kills, especially on iOS where they're silent.
