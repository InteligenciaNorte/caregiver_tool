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

- `docs/ARCHITECTURE.md` — public technical overview (on-device deployment, function calling, safety classifier, data model, privacy posture)
- `docs/module_system.md` — module configuration contract (ModuleConfig + ModuleManifest, JSON schema, error handling)

## Test Devices

- **Samsung S23** (Android, 8 GB RAM) — primary test target, demo recording device
- **iPhone 16 Pro Max** (iOS, 8 GB RAM) — cross-platform validation
- Both devices have hard memory constraints. Watch for OOM kills, especially on iOS where they're silent.
