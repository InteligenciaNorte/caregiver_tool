# CLAUDE.md — Project Memory for caregiver_tool

## Project Context

Flutter app (Android + iOS) for family caregivers of people with dementia.
Runs a fine-tuned Gemma 4 E2B on-device (no network) via llama.cpp through
the llamadart Flutter plugin. Hackathon submission, deadline May 18, 2026.

I (the developer) am working with an ML engineer in parallel. I own the
Flutter app; they own the model artifact, the fine-tuning data, the system
prompt, and the crisis classifier rules.

Single source of truth for what the app does: `docs/architecture.md`.
Read it first; this file complements it with project conventions.

## Scope

One module only: **Witnessing Hard Moments with Compassion** (4 steps,
~5 minutes). No module polymorphism, no module registry, no JSON manifests,
no module-selection UI. The module is the app.

No persistence between sessions. Nothing in SQLite. Nothing in
SharedPreferences except a single `onboarding_seen` boolean. Session state
lives in memory and is gone on app close.

## Hard Rules (NEVER violate)

1. **NO code generation packages.** Do NOT add `build_runner`, `freezed`,
   `freezed_annotation`, `drift`, `drift_dev`, `riverpod_generator`,
   `json_serializable`, or `auto_route`. If a solution seems to require one,
   stop and find a no-codegen alternative.
2. **NO network calls except `tel:` URIs** (crisis-resource dialer). Offline-
   first. Do not add `dio`, `http`, `firebase_*`, `sentry_*`, `crashlytics`,
   `posthog`, `mixpanel`, or any telemetry / analytics package.
3. **NO persistence of user data.** No sqflite. No SharedPreferences for
   typed input or session content. The only allowed SharedPreferences key is
   `onboarding_seen` (boolean).
4. **NO login, account, email field, or share buttons.**
5. **Crisis classifier rules are owned by the ML engineer.** Do not edit
   logic in `lib/core/crisis/classifier.dart`. The Dart API is locked:
   ```dart
   enum RiskLevel { none, low, medium, high, acute }
   RiskLevel classify(String situation);
   ```
   You wire the router and UI against this signature; you don't tune the rules.
6. **Calibrated copy is owned by the project lead.** Do not change wording
   on onboarding cards, the crisis screen, the Home hint, or session-step UI
   text without asking. Layout, spacing, colors are fair game; words are not.

## Tech Stack (locked)

- Flutter 3.24+, Dart 3.5+
- Platforms: Android (primary), iOS (cross-platform validation). iOS
  deployment target 16.4+.
- State: `flutter_riverpod` with `StateNotifierProvider` (NOT `@riverpod`)
- Sealed states: native Dart 3 `sealed class` (NOT Freezed)
- Routing: `go_router` with string paths
- JSON: `dart:convert` with manual `fromJson` (NOT json_serializable). Only
  the system prompt asset is loaded at startup; no JSON elsewhere.
- Settings: `shared_preferences` (one boolean only, see Hard Rule #3)
- LLM runtime: `llamadart` plugin wrapping llama.cpp
- Model artifact: single `assets/model/gemma-4-E2B-it-Q4_K_M.gguf` (~3 GB),
  produced by ML engineer via Unsloth → GGUF export
- Inference config: `contextSize: 2048`, `gpuLayers: -1`, Q4_K_M
- Conversation format: ChatML (system once, then user/assistant alternation)

## Build Commands

- Install deps: `flutter pub get`
- Run on connected device: `flutter run`
- Build debug APK: `flutter build apk --debug`
- Build release APK: `flutter build apk --release`
- Build iOS for testing: `flutter build ios --debug --no-codesign`
- Static analysis: `flutter analyze` (must pass with zero errors)
- Format: `dart format lib/`

## Directory Ownership

- `lib/core/llm/` — me. `GemmaClient` interface, `MockGemmaClient` for
  tests/dev, `RealGemmaClient` (llamadart-backed).
- `lib/core/crisis/classifier.dart` — ML engineer; do not edit.
- `lib/core/crisis/crisis_router.dart` — me.
- `lib/features/onboarding/` — me.
- `lib/features/home/` — me.
- `lib/features/session/` — me. The core of the app: step state machine,
  background generation, ChatML conversation assembly.
- `lib/features/crisis/` — me. A single crisis screen with two entry points
  (manual link from any screen + auto-route from HIGH/ACUTE classifier).
- `lib/ui/` — me. Shared widgets, theme.
- `assets/model/*.gguf` — ML engineer drops files; do not generate or modify.
- `assets/prompts/witnessing_hard_moments.txt` — ML engineer file; do not
  edit content, only load. A placeholder is fine for development.

## Two unresolved values (placeholders OK)

These come from the ML engineer. Placeholders are acceptable until they land;
both replace cleanly with no other code changes.

1. **Continue-marker string** — the user-turn content between assistant steps
   in ChatML. Use a `kContinueMarker` constant. Placeholder: `"<continue>"`.
2. **System prompt content** — `assets/prompts/witnessing_hard_moments.txt`
   exists with a short placeholder. Do not assume the placeholder content
   reflects production model behavior.

## Session failure behavior

If a step generation fails or times out mid-session:

- **First failure on a step:** retry once silently, no UI change.
- **Second failure:** replace the step's reflection with a calm inline
  message and two buttons — "Try again" and "Close for now". No fallback
  static reflection — never fake a model response.
- **OOM kill** (iOS especially, silent): unrecoverable mid-session. Next
  launch is a fresh start. We don't persist session state anyway.

## Workflow Conventions

- Ask before adding any new dependency.
- Ask before changing any user-facing copy.
- Run `flutter analyze` after every meaningful change. Zero errors required.
- Run on a real Android device daily, not just emulator.
- Commit at end of each day.

## What to do when stuck

- Compile errors: paste the FULL error including stack trace before guessing.
- Architectural question: re-read `docs/architecture.md` first; if still
  unclear, ask.
- Safety / model / classifier question: ask, do not improvise.
- Codegen suggestion appears: reject it, find a no-codegen alternative.

## External docs in this repo

- `docs/architecture.md` — single source of truth for app behavior. Read first.

(Previously this repo had `docs/module-system.md` and `docs/module-dataset-spec.md`.
Both are deleted; their content was specific to a multi-module design that
no longer exists.)

## Test Devices

- **Samsung S23** (Android, 8 GB RAM) — primary test target, demo recording device
- **iPhone 16 Pro Max** (iOS, 8 GB RAM) — cross-platform validation

Both devices have hard memory constraints. Watch for OOM kills, especially
on iOS where they are silent.
