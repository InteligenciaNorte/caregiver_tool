# Architecture

## Overview

A Flutter mobile application for family caregivers of people with dementia. Runs a fine-tuned Gemma 4 E2B model entirely on-device. No network, no accounts, no telemetry, nothing written to disk between sessions.

The app offers one short evidence-based exercise — **Witnessing Hard Moments with Compassion** (4 steps, ~5 minutes) — for moments when a caregiver is sitting with a shame-laden disclosure (snapped at parent, felt relief at hospitalization, dissociated during care, etc.). The fine-tuned model provides empathic witness-mode reflections within a flow the app controls; the app drives the steps, the model produces language.

Cross-platform: Android and iOS.

## Three layers

1. **UI and state** (Flutter, Dart 3, Riverpod) — screens, session state, navigation
2. **Inference** (llamadart wrapping llama.cpp) — GGUF model loading, ChatML conversation, streaming
3. **Safety classifier** (pure Dart, deterministic) — crisis triage rules, runs synchronously on the user's initial input

## Flow

### Onboarding (first launch only)

Three goals:

- Show the caregiver they're not alone — other people bring similarly hard things here
- Show what kinds of things people typically share, so the input field doesn't feel intimidating
- Make the privacy posture explicit so they trust they can write what they actually feel

Layout is a **paged flow of four pages**, each with a clear forward button — `Next` on pages 1–3, `Begin` on a dedicated final page. The user can swipe or tap to advance. There is no skip button, no close button, no "I'll do this later." The pages:

1. **What it is** — names who this is for and how it works, so the app explains itself rather than leaving the user to infer it. Heading along the lines of *"For the moments no one prepared you for"*, with a short body that says it's for caregivers of someone with dementia, that they write what they're carrying and are met with understanding (not advice), in about five minutes.
2. **Examples** — a short heading followed by several very short example fragments rendered together as chips/pills. They match the disclosure style the model was trained on — concrete, first-person, shame-adjacent — but trimmed to a phrase so they read at a glance rather than as a wall of text. The exact lead-approved heading and fragment list are the source of truth in code, not duplicated here: `_examplesHeading` and `_examples` in `lib/features/onboarding/onboarding_screen.dart` (the lead iterates this copy independently of this doc; it was last revised 2026-05-17). Showing all fragments together on this one page preserves the cumulative *"many people come here with hard things"* effect — the reason the examples are not spread one-per-page.
3. **Privacy** — makes the offline/on-device posture explicit and credible: a heading (*"What you write stays with you"*), a short body explaining it runs entirely on the phone with no internet, no account, no cloud, and the existing one-line assurance verbatim: *"Nothing leaves your phone. Nothing is saved between sessions."*
4. **Ready** — a brief closing line (*"Ready when you are"*) whose only action is the `Begin` button.

Exact copy is lead-owned and was approved for this design (2026-05-17); wording can still be iterated with the lead. The goal of the examples page remains *"yes, that's the kind of thing this is for."*

The persistent "I need help right now" link in the header is visible on **every** onboarding page from the first moment, before any interaction. Someone in acute distress on first launch must never have to read examples first.

Onboarding shows once. A single boolean flag in SharedPreferences (`onboarding_seen`) gates it. This is the only thing the app persists between launches.

### Home

A single calm screen:

- A multi-line text field with no length limit
- Hint text below or inside the field: *"Write what you're sitting with. As long or as short as you need."*
- A Continue button, disabled while the field is empty
- An always-visible **"I need help right now"** link in the header that opens the crisis screen

No module selection, no time-budget question, no greeting, no module branding.

### Session

After the user taps Continue from Home:

1. The typed text passes through the crisis classifier synchronously (~milliseconds)
2. If risk is HIGH or ACUTE, the crisis overlay takes over and no model call happens
3. Otherwise, the session screen opens and step 0 generation begins immediately
4. Each step renders one at a time as the user taps Continue. Step 3's button is **Done**, which returns to Home.

The session screen shows the current step's reflection text and a single button. No header, no progress bar, no module name. Calm.

### Generation strategy

All four step outputs come from the same ChatML conversation, but the user shouldn't wait more than once. So:

- Step 0 starts generating immediately when the session screen opens. A short spinner is shown until it's ready (typically a few seconds on target hardware).
- The moment step 0 is rendered, generation of step 1 starts in the background — the same conversation extended with a continue-marker user turn.
- The moment the user taps Continue and step 1 is shown, step 2 starts generating. And so on.
- If a step is already ready by the time the user taps Continue (the common case, since reading is slower than generation), the next reflection appears instantly. If not, a small inline spinner replaces the button until generation completes, then the reflection slides in.

Implementation note: llama.cpp holds one model instance; generations are sequential under the hood. Background generation just means kicking off the next request on a future right after rendering the current step, so it overlaps with the user's reading time rather than their tap-and-wait time.

### The four steps

| Step | Role | What the model produces |
|---|---|---|
| 0 | `name_it` | Reflects the specific moment back. Stays with what the user wrote. Does not generalize, does not invite a practice, does not say "you're not alone" yet. ~40–70 words. |
| 1 | `common_humanity` | "What you're feeling, others feel too — you're inside this experience, not outside it." ~30–50 words. |
| 2 | `self_kindness` | A small invitation to receive something for themselves — a breath, a moment of tenderness, an acknowledgment of having come here. No counted breathing, no homework. ~30–50 words. |
| 3 | `close` | A short closing line. No question, no praise, no "remember to". ~15–30 words. |

The model has been fine-tuned to produce these step types in order within a single conversation. The app does not select variants, pass tone hints, or condition on risk level — the conversation is the entire input.

### ChatML conversation shape

The conversation sent to the model:

```
system:    <module system prompt>
user:      <the caregiver's typed situation>
assistant: <step 0 — generated>
user:      <continue marker>
assistant: <step 1 — generated>
user:      <continue marker>
assistant: <step 2 — generated>
user:      <continue marker>
assistant: <step 3 — generated>
```

Each generation appends the previous assistant output plus one continue-marker user turn to the conversation, then calls the model. The system message is sent once. Nothing about the risk level or any other runtime state is injected into the prompt — the model sees the conversation and only the conversation.

The exact string used as the continue marker matches the format used in fine-tuning — plug it into a single constant in the codebase once known.

## Safety

The crisis classifier is deterministic Dart code, not the language model. Two reasons: deterministic rules are testable and auditable with no inference latency, and language models in caregiver-mental-health contexts have documented failure modes around over-flagging normal venting and under-flagging genuine risk.

Three layers run in order on the user's typed situation:

- **L1 — keyword detection.** Regex for method words, plan words, timeline words, means-access. Any L1 hit elevates to ACUTE.
- **L2 — IPTS discriminator.** Subject-of-burden parsing distinguishes patient-directed framing (LOW: *"she is a burden"*, *"wish she'd die in her sleep"*) from self-directed framing (HIGH: *"I am a burden to my children"*, *"they would be better off without me"*). Grounded in Joiner's Interpersonal Theory of Suicide (perceived burdensomeness construct).
- **L3 — passive ideation.** Phrasings paraphrasing the C-SSRS Q1 concept (wish to be dead without active intent) map to MEDIUM.

Routing is purely a UI decision — the model behaves identically regardless of risk level:

- **NONE / LOW** — session proceeds normally.
- **MEDIUM** — session proceeds normally, with a helpline affordance pinned on every step of the session. The model is unaware; this is a UI reminder only. **Implemented 2026-05-18** (`lib/ui/widgets/helpline_card.dart`, shown by `SessionScreen` when the session's classified `RiskLevel` is `medium`; classifier untouched). It is **collapsible but never removable**: a slim one-line bar by default, tap to reveal a single 988 call action, collapse back to the bar — never a closed/dismissed state. It does not duplicate the full resource list; 988 + Alzheimer's remain reachable on every step via the always-present "I need help right now" header link. New copy (`_supportLine`) is pending project-lead review; the 988 button reuses the crisis screen's approved copy verbatim. Default-collapsed and single-action are project-owner UX decisions pending safety-owner confirmation. Re-confirm the card stays pinned on every step once the real step state machine replaces the placeholder session.
- **HIGH / ACUTE** — the session never starts. A full-screen crisis overlay replaces the screen, with helpline call buttons (`tel:` URIs). Never auto-dismisses; the user must explicitly return. No model call happens.

The classifier runs **once per session**, on the initial situation typed at Home. The four steps after that are Continue taps with no new user text, so no re-classification is needed.

The always-visible **"I need help right now"** link in the header surfaces the crisis screen regardless of classifier state, on every screen.

## On-device inference

The app ships with one GGUF model artifact, `gemma-4-E2B-it-Q4_K_M.gguf` (~3 GB), loaded via the `llamadart` Flutter plugin which wraps llama.cpp.

```dart
await engine.loadModel(
  path: 'gemma-4-E2B-it-Q4_K_M.gguf',
  contextSize: 2048,
  gpuLayers: -1,
);
```

Context 2048 is sufficient for the full 4-step ChatML conversation including the system prompt. Q4_K_M is the single deployment quantization for both Android and iOS, sized for 8 GB devices (Samsung S23, iPhone 16 Pro Max) including KV cache and runtime overhead.

Generation parameters are fixed by the ML engineer in `inference_config.json` (the authoritative source — the runtime must be wired against that file, not these hardcoded values, when the LLM layer lands): `temperature` 1.0, `top_p` 0.95, `top_k` 64, `repeat_penalty` 1.0, `max_new_tokens` 400, and stop token `<turn|>`. These are tuning outputs of the fine-tune, not app-level choices — do not change them in app code. (The same file also restates `context_size: 2048`; LoRA rank 8, model file ~3.4 GB.)

The model loads once at app startup behind a splash screen and stays resident for the rest of the launch.

## Privacy posture

- No network access. The `INTERNET` Android permission is not requested. The only external handoff is `tel:` URIs through the system dialer, for crisis-resource buttons.
- No analytics, no crash reporting, no remote logging.
- No account, no login, no share buttons, no "rate this session" prompts.
- **Nothing is persisted between sessions.** The typed situation, the conversation, classifier output, every step — all of it lives in memory only and is gone when the session ends or the app closes.
- No SQLite, no turn log, no session history, no summaries, no cross-session continuity.
- The only thing in SharedPreferences is the `onboarding_seen` boolean.

There are no "wipe data" or "export data" features because there is no stored user data to wipe or export.

## Tech choices

No code generation. No `build_runner`, `freezed`, `drift`, `riverpod_generator`, `json_serializable`, or `auto_route`. State unions use Dart 3 native `sealed class`. Immutable types use manual `copyWith`. JSON parsing (only for loading the system prompt asset, if structured) uses `dart:convert`. Routing uses `go_router` with string paths.

The system prompt for the module lives at `assets/prompts/witnessing_hard_moments.txt`. It contains the witness-mode instructions and the no-AI-tells rules. Nothing is substituted at runtime — the prompt is loaded once at startup and sent verbatim as the system message of every session.

## Test devices and benchmarks

[FILL IN — model load time, first-token latency, tokens/sec, peak RAM on Samsung S23 and iPhone 16 Pro Max]

## Evaluation

[FILL IN — link to evaluation document with the rubric comparing base Gemma 4 E2B vs fine-tuned model]
