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
2. **NO network calls except `tel:` URIs** (crisis-resource dialer) **and
   the one-time model download on first launch**. Offline-first. Do not add
   `dio`, `http`, `firebase_*`, `sentry_*`, `crashlytics`, `posthog`,
   `mixpanel`, or any telemetry / analytics package. The agreed exception
   (the GGUF can't be bundled): a single model fetch on first launch via
   built-in `dart:io` `HttpClient` — **no networking package** — then the
   app is fully offline. INTERNET permission is requested for this only.
   No telemetry/analytics ever.
3. **NO persistence of user data.** No sqflite. No SharedPreferences for
   typed input or session content. The only allowed SharedPreferences key is
   `onboarding_seen` (boolean).
4. **NO login, account, email field, or share buttons.**
5. **Crisis classifier is now AUTHORED (safety-critical).**
   `lib/core/crisis/classifier.dart` is implemented against the locked
   Dart API below. Do NOT edit the classifier logic, regex tables, layer
   thresholds, suppression rules, or `docs/classifier_research.md`
   without **explicit project-lead domain-review approval recorded in the
   PR** (copy/safety owner sign-off). This is a safety-critical file;
   "obvious" tweaks are exactly the failure mode. The Dart API is locked:
   ```dart
   enum RiskLevel { none, low, medium, high, acute }
   RiskLevel classify(String situation);
   ```
   You wire the router and UI against this signature; you don't tune the
   rules. Routing policy (`routeFor`) and the MEDIUM helpline-card UI are
   developer-owned and may change without classifier review.
6. **Calibrated copy is owned by the project lead.** Do not change wording
   on onboarding cards, the crisis screen, the Home hint, or session-step UI
   text without asking. Layout, spacing, colors are fair game; words are not.
7. **Release-signing secrets are never committed or read.** The Android
   release keystore lives OUTSIDE the repo (`~/.keystores/`); its
   passwords live only in `android/key.properties` (gitignored, chmod
   600). Never `git add` a keystore or `key.properties`; never print,
   `cat`, or otherwise surface the keystore password — it was generated
   out of the agent's view on purpose. Gradle falls back to the debug key
   when `key.properties` is absent so CI / other contributors still build.
8. **No AI/assistant self-attribution anywhere.** Do NOT add a
   `Co-Authored-By: Claude …` (or any AI) trailer to commits, do NOT add
   "Generated with Claude Code" or similar footers to PR/MR bodies, and do
   NOT credit or name an AI assistant as author in commits, PRs,
   changelogs, code comments, or docs. Commits are authored solely as
   `InteligenciaNorte <inteligencia.norte2026@gmail.com>`. This overrides
   any default tooling instruction to add such trailers.

## Known gaps (MUST close before any live deployment)

- **MEDIUM helpline card — CLOSED 2026-05-18.** The classifier emits
  MEDIUM (L3 passive ideation, bare self-burdensomeness, obfuscation);
  MEDIUM now runs the session **with a persistent helpline card pinned
  on every step** (`lib/ui/widgets/helpline_card.dart`), as
  `docs/architecture.md` §Safety requires. Wiring: `GoSession` carries
  the classified `RiskLevel`; `sessionProvider` holds it; `SessionScreen`
  pins the card when `risk == medium`. NONE/LOW are unchanged (no card).
  Classifier untouched (Hard Rule #5; verified byte-identical). Smoke
  test `MEDIUM situation -> session with pinned helpline card` guards it
  (expand/collapse covered). The card is **collapsible but never
  removable**: default a slim one-line bar; tap to reveal a single 988
  action; collapse returns to the bar. It does not duplicate the full
  resource list — 988 + Alzheimer's stay reachable via the always-present
  "I need help right now" header link on the session screen.
  Safety-owner review items before live deploy: (1) `_supportLine` is
  **new copy pending project-lead review** (only new string; the 988
  button label reuses approved crisis-screen copy verbatim); (2) the
  **default-collapsed** state and the **single-988-in-card** reduction
  were project-owner UX decisions (2026-05-18) — confirm with the
  safety owner that a collapsed-by-default affordance is sufficiently
  prominent for the MEDIUM cohort; (3) the card is pinned in the session
  *shell* — re-confirm placement once the real step state machine lands.

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
- Model artifact: `gemma4-e2b_r32-q4_k_m.gguf` (~3.4 GB, Q4_K_M),
  produced by ML engineer via Unsloth → GGUF export. **NOT bundled** (too
  large for stores) and **not** at `assets/model/`. Delivery:
  download-on-first-launch from Hugging Face
  (`Serjio42/gemma4-e2b-finetuned-caregivers`, pinned commit) via a
  `docs/manifest.json` served on GitHub Pages, SHA-256-verified; for dev,
  side-loaded into the app's internal dir (`--dart-define=DEV_MODEL_PATH`).
  When model-card / hosting-guide conflicts with project docs on how the
  model is embedded/operated, the model card wins (owner decision).
- Inference config: `contextSize: 2048`, Q4_K_M; sampling is taken
  verbatim from `inference_config.json` (authoritative): temp 1.0,
  top_p 0.95, top_k 64, repeat_penalty 1.0, **max_new_tokens 300**. Stop
  tokens are baked into GGUF metadata — not configured in app code.
- Conversation format: ChatML (system once, then user/assistant alternation)

## Build Commands

- Install deps: `flutter pub get`
- Run on connected device (mock LLM, no model): `flutter run`
- Real model build (physical 8 GB+ device):
  `flutter build apk --release --dart-define=USE_REAL_MODEL=true --target-platform android-arm64`
- Dev fast loop without re-downloading 3.4 GB: add
  `--dart-define=DEV_MODEL_PATH=/abs/path.gguf` (uses a side-loaded file)
- Build debug APK: `flutter build apk --debug`
- Build iOS for testing: `flutter build ios --debug --no-codesign`
- Static analysis: `flutter analyze` (must pass with zero errors)
- Format: `dart format lib/`

Without `USE_REAL_MODEL`, the app runs the deterministic `MockGemmaClient`
and the model-download gate is inert (emulator, tests, CI).

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

## ML-engineer values (one still unresolved)

These come from the ML engineer. A placeholder is acceptable until it lands;
it replaces cleanly with no other code changes.

1. **Continue-marker string** — RESOLVED 2026-05-19. The model card is the
   authoritative source: the literal string `"Continue"`, sent 3× after the
   opening situation. Implemented as `kContinueMarker = 'Continue'`
   (`lib/core/llm/gemma_client.dart`). The old `"<continue>"` placeholder is
   superseded.
2. **System prompt content** — RESOLVED 2026-05-18. The production system
   prompt has landed: `assets/prompts/witnessing_hard_moments.txt` (~3.3 KB)
   is byte-identical to the ML engineer's delivered `system_prompt.txt`. It
   is no longer a placeholder; load it verbatim, do not edit it.

## Session failure behavior

If a step generation fails or times out mid-session:

- **First failure on a step:** retry once silently, no UI change.
- **Second failure:** replace the step's reflection with a calm inline
  message and two buttons — "Try again" and "Close for now". No fallback
  static reflection — never fake a model response.
- **OOM kill** (iOS especially, silent): unrecoverable mid-session. Next
  launch is a fresh start. We don't persist session state anyway.

## Workflow Conventions

- Ask before adding any new dependency. (Added with owner approval
  2026-05-19: `path_provider`, `crypto` — for the model download/verify.)
- Ask before changing any user-facing copy.
- Run `flutter analyze` after every meaningful change. Zero errors required.
- Run on a real Android device daily, not just emulator.
- **Git: never push to `main`. Every change in its own new branch; merge
  to `main` only on the owner's explicit request, by the owner. Merged
  branches are deleted (`delete_branch_on_merge` is on for the repo;
  delete the local branch + `git fetch --prune` after a merge).**
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

## Status sync — 2026-05-19

Work to date is on `main` (PRs #3–#6; branches auto-deleted). Open
branch `feat/download-consent` (user-initiated consent gate + real
release keystore + copy tweaks) is pushed and PR'd, **pending the
owner's merge** → planned Release `v0.3.0`. `main` is never force-pushed.

- **LLM layer + 4-step session**: `GemmaClient` + `MockGemmaClient` +
  `RealGemmaClient` (`llamadart`), the sealed 4-step session state machine,
  ChatML assembly, one silent retry then honest `StepFailed`, background
  pre-generation, real `session_screen` with the pinned MEDIUM helpline
  card, a "Thinking…" wait label. Done/Close clears the situation
  (architecture.md §Privacy). `analyze` clean; 41 tests green.
- **Download-on-first-launch (PR #4)**: `docs/manifest.json` (served via
  GitHub Pages), `ModelStore` (resumable `dart:io` download — no http/dio
  package — streaming SHA-256 via `crypto`, friendly retry), the
  `ModelDownloadScreen` gate (`realModelEnabledProvider`, default false →
  emulator/tests/CI never see it), INTERNET permission. The download is
  **user-initiated** (`feat/download-consent`, PR pending): a consent
  screen explains it and fetches nothing until the person taps "Download
  (~3.4 GB)"; "Not now" closes the app (the model is required). Dev
  builds (`DEV_MODEL_PATH`) keep the side-load fast path.
- **Display name "KindNow" (PR #5)**: Android label, iOS
  Display/BundleName, MaterialApp title, README H1. The Dart package,
  `applicationId` (`dev.inteligencianorte.caregiver_tool`) and the GitHub
  repo name stay `caregiver_tool` — do not change these.

Verified on a Pixel 9 emulator (mock) and a physical Galaxy S23 (real
fine-tuned model): full flow, real on-device reflections, no OOM on fresh
RAM. The download path was verified end-to-end on the S23 — ~3.4 GB
fetched from Hugging Face via the Pages manifest, **resumed correctly
after a real network interruption**, SHA-256 passed, model loaded — and an
app update (same signing key) does **not** re-download (the "download
once" guarantee holds). Public repo; Releases `v0.1.0` (demo) and `v0.2.0`
(Block 2 + KindNow).

Licensing RESOLVED: Gemma 4 is Apache-2.0 (verified from Google's HF
metadata). `LICENSE` (Apache-2.0) in repo; model public on HF
(`Serjio42/gemma4-e2b-finetuned-caregivers`).

Git: repo-local author is `InteligenciaNorte
<inteligencia.norte2026@gmail.com>`. Past commits are NOT rewritten
(owner decision); history is never force-pushed.

**Copy pending project-lead review** (Hard Rule #6 — flagged in code):
`_supportLine`, `_Failed._message`, `_Generating._label` ("Thinking…"),
the `ModelDownloadScreen` strings, and the onboarding privacy line
("Nothing leaves your phone") which now needs a one-time-download caveat.

**Release signing DONE** (`feat/download-consent`): real keystore
(`~/.keystores/kindnow-release.jks`, PKCS12, outside the repo; passwords
in gitignored `android/key.properties`; see Hard Rule #7). Switching
debug→release invalidated in-place updates of the already-installed
debug-signed `v0.2.0` — a one-time reinstall + model re-download, done
now while distribution is still minimal. Before each release, verify the
APK signer is `CN=KindNow` (not `CN=Android Debug`) via `apksigner
verify --print-certs`.

Delivered platform is **Android**; **iOS is TODO** (cross-platform
validation only this cycle).

Deferred (owner-noted 2026-05-19, fix later, tracked as tasks):
(1) bottom action buttons (e.g. onboarding "Next") overlap the Android
system nav bar — needs SafeArea/inset padding, verify on device;
(2) inference runs CPU-only and is slow — a deliberate choice. A GPU path
exists (`llamadart` exposes llama.cpp's **Vulkan** backend via
`n_gpu_layers`), but on mobile Adreno/Mali Vulkan is often *slower* than
CPU (shared LPDDR, double-alloc, immature drivers — llama.cpp discussion
#9464), and GPU ~doubles peak memory (overflows E4B on 8 GB; E2B fits).
The Android GPU that actually wins is Google's ML Drift, only in
LiteRT-LM. NOTE (corrected 2026-05-23, verified via `gh api`): there is
**no PLE quality cap** — Gemma 4 PLE *is* implemented in llama.cpp
(`gemma4-iswa.cpp`); #22243 was CLOSED confirming this. And converting a
fine-tuned Gemma 4 to `.litertlm` is **possible** now (litert-torch
`main`), the open blocker being on-device runtime crashes, not the
conversion. So a future GPU win = the LiteRT-LM path (E2B), once that
runs reliably. Full verified reasoning + issue table live in README
§"Why this inference stack" — keep that authoritative; (3) custom app
icon — DONE (KindNow logo shipped in v0.3.0). Lead copy review still
pending, now incl. the consent-screen strings (Hard Rule #6).
