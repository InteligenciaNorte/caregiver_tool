# Architecture

A Flutter mobile application for family caregivers of people with dementia, running a fine-tuned Gemma 4 E2B model entirely on-device. No network calls, no telemetry, no accounts. Cross-platform (Android and iOS).

## System overview

The application is a structured decompression tool, not a chatbot. It offers short evidence-based exercises (3–15 minutes) during the brief windows caregivers have between care tasks. The fine-tuned language model provides empathic witness-mode reflections within a state machine that the application owns; the model fills in human-sounding language, the state machine controls the flow.

Three core layers:

1. **UI and state layer** (Flutter, Dart 3, Riverpod) — screens, module state machines, persistence, navigation
2. **On-device inference layer** (llamadart wrapping llama.cpp) — GGUF model loading, inference, function calling
3. **Safety classifier layer** (pure Dart, deterministic) — crisis triage rules running synchronously on every user message

## On-device deployment

The application ships with a single GGUF model artifact (`gemma-4-E2B-it-Q4_K_M.gguf`, approximately 3 GB), loaded via the `llamadart` Flutter plugin which wraps llama.cpp. The model runs entirely on-device with no network connectivity required.

Runtime configuration:

```dart
await engine.loadModel(
  path: 'gemma-4-E2B-it-Q4_K_M.gguf',
  contextSize: 2048,
  gpuLayers: -1,
);
```

The 2048-token context window is sufficient for the longest module (Dichotomy sort, approximately 1940 tokens worst case including system prompt, function-call schema, conversation history, and cross-session continuity threads). The application implements a system-prompt-first truncation policy: when context approaches the limit, the oldest turn pair is dropped rather than the system prompt.

Q4_K_M quantization is chosen as the single deployment quantization for both Android and iOS, sized to fit within the per-app memory budgets on 8 GB devices (Samsung S23, iPhone 16 Pro Max) including KV cache and runtime overhead.

## Function calling

The application uses Gemma 4's native function-calling tokens, handled by llama.cpp's Jinja template engine through the `llamadart` runtime. Four tools are exposed to the model:

- **`assess_risk`** — schema-only; the application's deterministic classifier owns risk routing, not the model. The schema is exposed so the model learns to defer routing to the application layer.
- **`start_practice`** — model-emitted signal to advance from acknowledgment into a short structured practice. Gated on the application side: refused on the first turn of shame-laden disclosures.
- **`request_summary`** — model-emitted signal at the natural end of a session to generate the 3-line summary.
- **`flag_for_safety_review`** — model-side soft signal that logs to the audit trail without triggering UI routing. The deterministic classifier remains the source of truth.

## Safety architecture

Risk classification runs in a separate deterministic Dart layer, not the language model. This decision is grounded in two considerations: (1) deterministic rules are testable, auditable, and have no inference latency, and (2) language models in caregiver-mental-health contexts have documented failure modes around over-flagging normal venting and under-flagging genuine risk.

The classifier operates in three layers:

- **L1 — Keyword detection.** Regex-based detection of method words, plan words, timeline words, and means-access references. Any L1 hit elevates to ACUTE.

- **L2 — IPTS discriminator.** Subject-of-burden parsing distinguishes patient-directed framing (LOW: "she is a burden," "this is killing me," "wish she'd die in her sleep") from self-directed framing (HIGH: "I am a burden to my children," "they would be better off without me"). The discriminator is grounded in Joiner's Interpersonal Theory of Suicide (perceived burdensomeness construct).

- **L3 — Passive ideation patterns.** Phrasings paraphrasing the C-SSRS Q1 concept (wish to be dead without active intent) map to MEDIUM and trigger a soft in-screen suggestion of resources without taking over the UI.

Routing behavior by level:

- **NONE / LOW** — module flow proceeds normally
- **MEDIUM** — module continues; a non-intrusive in-screen card surfaces helpline information; model behavior shifts to witness-only mode (no practice invitations) via system-prompt flag
- **HIGH / ACUTE** — full-screen crisis overlay takes over the application, presenting helpline call buttons; never auto-dismisses; user must explicitly return

The application also surfaces an always-visible "I need help right now" link on every screen, providing one-tap access to crisis resources regardless of classifier state.

## Local data model

All session data lives in an on-device SQLite database via `sqflite`. Four tables:

- **`sessions`** — session start/end timestamps, module identifier, optional situation tag, time budget, end reason (`completed` | `user_stop` | `crisis_route`)
- **`turns`** — turn-by-turn conversation log with role, text, token count, risk label, and matched risk signals
- **`summaries`** — three-field per-session summary (theme, what was tried, thread for next time)
- **`settings`** — local key-value store

Cross-session continuity is achieved by injecting the last three summaries (not full transcripts) into the system prompt of the next session as `<previously_noted_threads>`. The model never re-reads raw past disclosures; only the structured summary lines.

The "wipe all data" function in settings drops all rows from all tables in a single transaction with no recovery option beyond a 5-second undo snackbar.

## Module system

The application ships three evidence-based exercise modules:

- **Self-Compassion Break** (3 turns, ~5 minutes) — for shame-laden disclosures. Based on the Neff and Germer paraphrased structure; original wording paraphrased to avoid copyrighted scripts. Evidence: Wiita et al. 2024, JMIR Aging.

- **ACT cognitive defusion** (5 turns, ~7 minutes) — for self-critical rumination using the "I'm having the thought that..." reframe. Evidence: Losada et al. 2015, randomized controlled trial.

- **Dichotomy-of-control sort** (6 turns, ~8 minutes) — for overwhelm using a yours/partly-yours/not-yours sorting exercise. Evidence base: ACT acceptance and problem-solving therapy literature; framing borrows accessible Stoic-adjacent language for cross-cultural accessibility.

Each module is defined by a JSON manifest (`assets/prompts/<module_id>.json`) containing the system prompt, max turn count, evidence citation, and summary template. The application's state machine is module-agnostic; adding a new module of the same "N turns of reflection / user reply" shape requires writing one JSON and adding one line to the module registry. See [`module_system.md`](module_system.md) for the contract details.

## Code generation policy

The project uses no code generation tooling: no `build_runner`, no Freezed, no Drift, no `riverpod_generator`, no `json_serializable`, no `auto_route`. State unions use Dart 3 native `sealed class`. Immutable types use manual `copyWith`. JSON parsing uses `dart:convert` with hand-written `fromMap` / `toMap`. The database layer uses raw `sqflite` with explicit SQL. Routing uses `go_router` with string paths.

This choice trades a small amount of boilerplate for the property that every file in the repository is the file that runs. There are no transformed companion files, no version-mismatch failures between codegen packages, and stack traces always point to readable source.

## Privacy posture

No network calls except `tel:` URIs through the system dialer (for crisis-resource buttons). No analytics. No crash reporting. No remote logging. No account or login. No share buttons. No "rate this session" prompts. The `INTERNET` Android permission is not requested.

The "wipe all data" function in settings performs a destructive deletion with a single tap (5-second undo) — no multi-step "are you sure" dialog, no recovery beyond the snackbar window. The application's local export feature opens a system share sheet to let the user place their own data wherever they choose; the data never passes through any service operated by the developers.

## Test devices and benchmarks

[FILL IN ON DAY 6 from BENCH.md — model load time, first-token latency, tokens/sec, peak RAM on Samsung S23 and iPhone 16 Pro Max]

## Evaluation

[FILL IN ON DAY 6 — link to EVAL.md with 25-scenario rubric chart comparing base Gemma 4 E2B vs LoRA-fine-tuned model]
