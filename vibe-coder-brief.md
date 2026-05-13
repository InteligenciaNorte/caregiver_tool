# Vibe Coder Brief — Caregiver Decompression Tool
**Hackathon submission deadline: May 18, 2026, 23:59 UTC. Today is May 12.**

> Paste this entire document as the first message of a new Claude Code session. Everything you need is in here.

---

## 1. Context (read first, 60 seconds)

You're building an **Android-only Flutter app** for family caregivers of people with dementia. It runs a small language model (Gemma 4 E2B) **fully on-device** — no internet, no account, no analytics. Users open it during short breaks (3-15 minutes) to do structured decompression exercises.

It is **NOT** a chatbot, therapy app, or wellness app. It's a tool with **3 structured modules** that each have a fixed step-by-step flow. The model only fills in the human-sounding reflection at each step.

**Your teammate is an ML engineer.** They are training a fine-tuned model, building training data, and writing the crisis-detection rules. **You build the app around their work.** They will hand you two things:
- **Day 3:** a Dart file `crisis_classifier.dart` with the rules implemented. You wire it in.
- **Day 5:** a `.litertlm` model file. You drop it in and swap from mock to real.

Until those arrive, you build against **mock data and stub interfaces** (provided below). You will not be blocked.

---

## 2. Design philosophy: every file you see is the file that runs

This project deliberately avoids **all code generation** (no Freezed, no Drift, no `@riverpod` annotation, no `json_serializable`, no `build_runner`). The reason: when something breaks, you want the error to point at code you can read and paste back to Claude. Codegen breaks that loop — Claude generates source, a tool transforms it, and when the transformed output is stale or version-mismatched, the error messages stop matching the code you see.

In exchange for slightly more boilerplate (a manual `copyWith`, a manual `fromJson`), you get:
- Zero `build_runner` commands. Ever.
- No `part 'foo.g.dart'` directives.
- No version-mismatch issues between `freezed`, `freezed_annotation`, `riverpod_generator`, etc.
- Stack traces that point to your own code.
- Faster recovery when Claude needs to fix something.

If a future package suggests you "just add `build_runner` to dev_dependencies," **don't**. Ask first.

---

## 3. Scope — what you own / what you don't

### You own
- Flutter project setup (Android target only — iOS doesn't work yet for this model)
- All UI screens: Onboarding, Home, ModuleRunner, SessionClose, CrisisOverlay, Settings
- Local database (sqflite raw): sessions, turns, summaries
- State management (Riverpod `StateNotifierProvider`): module state machine, session lifecycle, crisis overlay routing
- Navigation (go_router with string paths)
- `GemmaClient` abstraction with two implementations: `MockGemmaClient` (yours, Day 1-2) and `RealGemmaClient` (you wire on Day 4-5 when model is ready)
- Wiring the function-call schema into the UI
- Theme, typography, accessibility (large text, high contrast)
- APK build and signing for the demo

### You DO NOT own
- The crisis classifier rules — ML engineer delivers Day 3
- The LoRA model, training data, synthesis pipeline, evaluation rubric
- The system prompts for the three modules — delivered Day 3 in `assets/prompts/`
- The corpus sources document and licensing

### Boundaries that matter
- **No Firebase, no Sentry, no analytics, no telemetry of any kind.**
- **No login, no account, no email field, no share buttons.**
- **No copy changes to calibrated phrases** without asking.

---

## 4. Tech stack (lock these versions Day 1)

```yaml
environment:
  sdk: ">=3.5.0 <4.0.0"
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_gemma: ^0.13.1            # required for on-device model
  flutter_riverpod: ^2.5.1          # state management (no codegen API)
  go_router: ^14.6.0                # routing (string paths)
  sqflite: ^2.3.3                   # local DB (raw SQL)
  path: ^1.9.0
  path_provider: ^2.1.4
  url_launcher: ^6.3.0              # for tel: URIs (crisis buttons)
  shared_preferences: ^2.3.2        # simple kv settings

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

That's the entire dependency list. If any package fails to resolve, ask the ML engineer before downgrading Flutter — they may be pinned to a specific version for `flutter_gemma` compatibility.

---

## 5. Day-by-day plan

### Day 1 (May 12) — Project skeleton + Onboarding + Home
- Create the Flutter project, lock dependencies, build the directory structure (§7).
- Implement Onboarding (3 cards, skippable).
- Implement Home screen (decompression-window picker + situation input).
- Set up Riverpod and go_router with string paths.
- **End of day:** runs on Android, navigates Onboarding → Home, taps a duration chip. No model yet.

### Day 2 (May 13) — Module runner with mock model + Session close + DB
- Build `MockGemmaClient` returning canned responses (§8).
- Build the ModuleRunner state machine for Self-Compassion Break (the other two modules use the same scaffold).
- Build the SessionClose screen with mock summary.
- Set up sqflite schema with raw SQL and write/read session + turn records.
- **End of day:** full mock flow works end-to-end. Data persists across app restarts.

### Day 3 (May 14) — Crisis overlay + Settings + the other two modules
- Build CrisisOverlay (full-screen takeover, two big call buttons, "I'm okay" return).
- Wire it to `CrisisRouter` that listens to risk-level state.
- **ML engineer hands you `crisis_classifier.dart` today.** Drop into `lib/core/crisis/`, wire to the message-send flow.
- Implement ACT defusion and Dichotomy sort modules — same state machine, different prompts and turn counts.
- Build Settings (model status, wipe data, optional emergency contact, export).
- **End of day:** three modules work with mock model, crisis overlay triggers on test inputs, wipe button actually wipes the DB.

### Day 4 (May 15) — Real model integration (base model)
- ML engineer hands you `gemma-4-E2B-it.litertlm`. Drop into `assets/model/`, update `pubspec.yaml`.
- Build `RealGemmaClient` against `flutter_gemma`. Mirror the `MockGemmaClient` interface exactly.
- Test on real Android device. Measure cold-load, first-token latency, tokens/sec.
- Add "model warming up" loader on first inference per session.
- **End of day:** real base model runs in app, three modules complete with real output.

### Day 5 (May 16) — LoRA model swap + function calling + polish
- ML engineer hands you LoRA-adapted `.litertlm`. Swap path. Interface identical.
- Wire native function calling: `start_practice` advances UI; `flag_for_safety_review` logs silently (classifier is source of truth for routing).
- Tune UI gaps: loading states, error states, "I need to stop" exits from every screen.
- **End of day:** v0.9 build. Submission-ready except video and write-up.

### Day 6 (May 17) — Video + APK polish
- Help record 2-min demo. You operate the phone; ML engineer narrates.
- Build signed release APK. Upload to GitHub Releases.
- Update README with install instructions.
- **End of day:** v1.0-rc on GitHub.

### Day 7 (May 18) — Buffer + submit
- Test APK on freshly-wiped Android profile.
- Submit by 18:00 UTC. Not later.

---

## 6. Initial Claude Code prompts (paste these verbatim)

### Prompt 1 — Project initialization (Day 1, first 30 minutes)

> Create a new Flutter project named `caregiver_tool` targeting Android only. Use Flutter 3.24+ and Dart 3.5+. Then:
>
> 1. Update `pubspec.yaml` with exactly the dependencies in §4 of the brief I just gave you. Pin all versions. No `any`, no open ranges. Do NOT add `build_runner`, `freezed`, `drift`, `json_serializable`, or `riverpod_generator` — this project intentionally avoids codegen.
> 2. Create the directory structure shown in §7. Make every directory, even if empty (add a `.gitkeep` file).
> 3. Create `lib/main.dart` and `lib/app.dart` with a Riverpod `ProviderScope` wrapping a `MaterialApp.router` using `go_router`.
> 4. Define a `GoRouter` config in `lib/routing/router.dart` using string paths (not typed routes). Routes: `/onboarding` (default), `/home`, `/module/:moduleId`, `/session/:sessionId/close`, `/settings`. The crisis overlay is NOT a route — it's a top-level overlay handled in `app.dart`.
> 5. Set up the Material 3 theme in `lib/ui/theme.dart` with a calm dark-mode-default palette using `ColorScheme.fromSeed`. 18pt body text minimum. Line height 1.5. WCAG AA contrast.
> 6. Add a `.gitignore` excluding `assets/model/*.litertlm`, `assets/model/*.task`, `.env`, `train/`.
> 7. Create an empty `README.md` placeholder.
>
> Run `flutter pub get` and confirm the project builds with `flutter build apk --debug`. Report any errors.

### Prompt 2 — Onboarding screen (Day 1, after Prompt 1)

> Build `lib/features/onboarding/onboarding_screen.dart`. Three cards in a horizontal `PageView`. On the third card, tapping "Continue to app" navigates to `/home` and writes `onboarded=true` to `SharedPreferences` (key: `caregiver_tool_v1.onboarded`).
>
> Card 1 copy (do not change wording):
> > Everything you type stays on this phone. There is no account, no email, no upload. You can wipe it any time.
>
> Card 2 copy:
> > This is not therapy and not a chatbot. It's a structured tool for short decompression moments. 3 to 15 minutes.
>
> Card 3 copy and layout:
> > If you're in crisis, here are people who can help right now.
> > [Button: tel: link] Call Alzheimer's Association: 1-800-272-3900
> > [Button: tel: link] Call 988 (US Suicide & Crisis Lifeline)
> > [Smaller text link] Continue to app
>
> Use `url_launcher` with `tel:` URIs for the call buttons.
>
> In `lib/routing/router.dart`, add a redirect: if `onboarded == true` in SharedPreferences, redirect `/onboarding` to `/home`.

### Prompt 3 — Home screen (Day 1, after Prompt 2)

> Build `lib/features/home/home_screen.dart` and `lib/features/home/home_state.dart`.
>
> In `home_state.dart`, create a plain `HomeState` class (immutable, with const constructor and a manual `copyWith`):
> ```dart
> class HomeState {
>   final int? selectedDurationMin;
>   final String situationText;
>   const HomeState({this.selectedDurationMin, this.situationText = ''});
>   HomeState copyWith({int? selectedDurationMin, String? situationText}) =>
>     HomeState(
>       selectedDurationMin: selectedDurationMin ?? this.selectedDurationMin,
>       situationText: situationText ?? this.situationText,
>     );
> }
> ```
> Expose it via a `StateNotifierProvider<HomeNotifier, HomeState>`. The notifier has `setDuration(int)` and `setSituation(String)` methods.
>
> Layout top to bottom:
> 1. Time-of-day greeting (Late night / Early morning / Morning / Afternoon / Evening / Night), no name, no comma, no exclamation.
> 2. "How long do you have?" — four chip buttons in a row: 3, 5, 10, 15+ min. One-at-a-time selection, visually highlighted.
> 3. "What's the moment?" — single-line `TextField`, optional. Placeholder rotates every 8 seconds between: "Snapped at her. Now guilty.", "Can't sleep. Listening.", "Got the bill."
> 4. "Begin" button at the bottom — disabled until duration is selected. On tap, navigate to `/module/self_compassion` (we'll add module routing logic Day 2).
> 5. Small "I need help right now" link in the AppBar action area. For now, TODO no-op (we build CrisisOverlay Day 3).
> 6. Below the Begin button: list of recent sessions (read from DB on Day 2 — for now, render nothing).

### Prompt 4 — Mock GemmaClient (Day 2, first thing)

> Create `lib/core/llm/gemma_client.dart` with this abstract interface:
> ```dart
> abstract class GemmaClient {
>   Future<String> generate({
>     required String systemPrompt,
>     required List<TurnRecord> history,
>     required String userMessage,
>     int maxTokens = 200,
>   });
>   Future<void> warmUp();
>   Future<bool> isReady();
> }
> ```
> `TurnRecord` is a plain class with `final String role`, `final String text`, const constructor.
>
> Create `lib/core/llm/mock_gemma_client.dart` implementing this interface by reading `assets/mock_responses.json` (content I'll paste next). The mock:
> - Loads JSON once on first call, caches in memory.
> - Matches on `(moduleId from systemPrompt, turnIndex from history.length)`.
> - Picks randomly from the matching array.
> - Adds 600-1200ms artificial delay.
> - Logs each call with `debugPrint`.
>
> Register as the default `Provider<GemmaClient>` in `lib/core/llm/providers.dart`. On Day 4 we swap to `RealGemmaClient` by changing one line.

### Prompt 5 — Module state machine (Day 2)

> Create `lib/core/modules/module_state.dart` using Dart 3 native sealed classes (no codegen, no Freezed):
> ```dart
> sealed class ModuleState {
>   const ModuleState();
> }
>
> class NotStarted extends ModuleState {
>   const NotStarted();
> }
>
> class WaitingForModel extends ModuleState {
>   final int turnIndex;
>   const WaitingForModel(this.turnIndex);
> }
>
> class ShowingReflection extends ModuleState {
>   final int turnIndex;
>   final String text;
>   const ShowingReflection({required this.turnIndex, required this.text});
> }
>
> class AwaitingUserInput extends ModuleState {
>   final int turnIndex;
>   const AwaitingUserInput(this.turnIndex);
> }
>
> class Complete extends ModuleState {
>   final int sessionId;
>   const Complete(this.sessionId);
> }
>
> class UserStopped extends ModuleState {
>   const UserStopped();
> }
>
> class EscalatedToSafety extends ModuleState {
>   const EscalatedToSafety();
> }
> ```
>
> Create `lib/core/modules/module_runner_notifier.dart`:
> ```dart
> class ModuleRunnerNotifier extends StateNotifier<ModuleState> {
>   ModuleRunnerNotifier(this._client, this._sessionRepo, this._moduleId)
>     : super(const NotStarted());
>
>   final GemmaClient _client;
>   final SessionRepository _sessionRepo;
>   final String _moduleId;
>   int? _sessionId;
>   final List<TurnRecord> _history = [];
>
>   Future<void> start({required String situation, required int durationMin}) async { ... }
>   Future<void> continueToNextTurn() async { ... }
>   Future<void> submitUserInput(String text) async { ... }
>   Future<void> stop() async { ... }
>   void escalate() { ... }
> }
>
> final moduleRunnerProvider = StateNotifierProvider.autoDispose
>   .family<ModuleRunnerNotifier, ModuleState, String>(
>     (ref, moduleId) => ModuleRunnerNotifier(
>       ref.read(gemmaClientProvider),
>       ref.read(sessionRepositoryProvider),
>       moduleId,
>     ),
>   );
> ```
>
> Build `lib/features/module_runner/module_runner_screen.dart`. Use switch expressions for exhaustive state rendering:
> ```dart
> Widget build(BuildContext context, WidgetRef ref) {
>   final state = ref.watch(moduleRunnerProvider(widget.moduleId));
>   return switch (state) {
>     NotStarted() => const _StartingIndicator(),
>     WaitingForModel(:final turnIndex) => _LoadingTurn(index: turnIndex),
>     ShowingReflection(:final text, :final turnIndex) =>
>       _ReflectionCard(text: text, turnIndex: turnIndex, onContinue: ..., onStop: ..., onEscalate: ...),
>     AwaitingUserInput(:final turnIndex) => _InputField(turnIndex: turnIndex, onSubmit: ...),
>     Complete(:final sessionId) => _NavigateToClose(sessionId: sessionId),
>     UserStopped() => _NavigateHome(message: 'Saved. You can come back any time.'),
>     EscalatedToSafety() => _ShowCrisisOverlay(),
>   };
> }
> ```
> The Dart compiler will tell you if you forget a case. That's exhaustiveness without codegen.
>
> Self-Compassion Break has 3 turns max. Hardcode `_maxTurns = 3` for now; on Day 4 we load it from `assets/prompts/self_compassion.json`.

### Prompt 6 — sqflite database (Day 2, after Prompt 5)

> Create `lib/core/data/database.dart` using raw `sqflite` (no Drift, no codegen):
> ```dart
> class AppDatabase {
>   static Database? _db;
>
>   static Future<Database> get instance async {
>     if (_db != null) return _db!;
>     final path = join(await getDatabasesPath(), 'caregiver_tool.db');
>     _db = await openDatabase(path, version: 1, onCreate: _onCreate);
>     return _db!;
>   }
>
>   static Future<void> _onCreate(Database db, int version) async {
>     await db.execute('''
>       CREATE TABLE sessions (
>         id INTEGER PRIMARY KEY AUTOINCREMENT,
>         started_at TEXT NOT NULL,
>         ended_at TEXT,
>         module_id TEXT NOT NULL,
>         situation_tag TEXT,
>         time_budget_min INTEGER NOT NULL,
>         end_reason TEXT
>       )
>     ''');
>     await db.execute('''
>       CREATE TABLE turns (
>         id INTEGER PRIMARY KEY AUTOINCREMENT,
>         session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
>         ts TEXT NOT NULL,
>         role TEXT NOT NULL,
>         text TEXT NOT NULL,
>         tokens INTEGER,
>         risk_label TEXT,
>         risk_signals TEXT
>       )
>     ''');
>     await db.execute('''
>       CREATE TABLE summaries (
>         id INTEGER PRIMARY KEY AUTOINCREMENT,
>         session_id INTEGER NOT NULL UNIQUE REFERENCES sessions(id) ON DELETE CASCADE,
>         theme TEXT NOT NULL,
>         what_tried TEXT NOT NULL,
>         thread_for_next_time TEXT
>       )
>     ''');
>     await db.execute('CREATE INDEX idx_turns_session ON turns(session_id)');
>     await db.execute('PRAGMA foreign_keys = ON');
>   }
>
>   static Future<void> wipeAll() async {
>     final db = await instance;
>     await db.delete('turns');
>     await db.delete('summaries');
>     await db.delete('sessions');
>   }
> }
> ```
>
> Then create thin repositories — `lib/core/data/session_repo.dart`, `lib/core/data/turn_repo.dart`, `lib/core/data/summary_repo.dart` — each with plain DTOs (no Freezed) and manual `fromMap`/`toMap` methods. Example DTO:
> ```dart
> class Session {
>   final int? id;
>   final DateTime startedAt;
>   final DateTime? endedAt;
>   final String moduleId;
>   final String? situationTag;
>   final int timeBudgetMin;
>   final String? endReason;
>
>   const Session({
>     this.id, required this.startedAt, this.endedAt,
>     required this.moduleId, this.situationTag,
>     required this.timeBudgetMin, this.endReason,
>   });
>
>   Map<String, dynamic> toMap() => {
>     if (id != null) 'id': id,
>     'started_at': startedAt.toIso8601String(),
>     'ended_at': endedAt?.toIso8601String(),
>     'module_id': moduleId,
>     'situation_tag': situationTag,
>     'time_budget_min': timeBudgetMin,
>     'end_reason': endReason,
>   };
>
>   factory Session.fromMap(Map<String, dynamic> m) => Session(
>     id: m['id'] as int?,
>     startedAt: DateTime.parse(m['started_at'] as String),
>     endedAt: m['ended_at'] != null ? DateTime.parse(m['ended_at'] as String) : null,
>     moduleId: m['module_id'] as String,
>     situationTag: m['situation_tag'] as String?,
>     timeBudgetMin: m['time_budget_min'] as int,
>     endReason: m['end_reason'] as String?,
>   );
> }
> ```
> Expose each repository through a `Provider` in `lib/core/data/providers.dart`.

### Prompt 7 — Crisis overlay (Day 3)

> Build `lib/features/crisis_overlay/crisis_overlay.dart` as a top-level overlay (NOT a route). Use a `Provider<RiskLevel>` that the rest of the app reads.
>
> Create `lib/core/crisis/crisis_router.dart`:
> ```dart
> enum RiskLevel { none, low, medium, high, acute }
>
> class CrisisRouter extends StateNotifier<RiskLevel> {
>   CrisisRouter() : super(RiskLevel.none);
>   void setLevel(RiskLevel level) => state = level;
>   void dismiss() => state = RiskLevel.none;
> }
> final crisisRouterProvider = StateNotifierProvider<CrisisRouter, RiskLevel>((ref) => CrisisRouter());
> ```
>
> In `app.dart`, wrap the `MaterialApp.router` in a `Stack` overlay that shows the CrisisOverlay above everything when `RiskLevel.high` or `RiskLevel.acute` is active.
>
> Overlay layout for HIGH:
> - Top: single short line: "I'm right here. If you want to tell me what's happening before you call, I'm listening."
> - Two large buttons (tel: URIs): "Call Alzheimer's Association (1-800-272-3900)", "Call 988"
> - Bottom: small "I'm okay, take me back" — dismisses the overlay, returns to Home.
>
> Overlay layout for ACUTE: identical buttons; top line replaced with: "Are you safe right now? If there's a way to hurt yourself nearby, can you put distance between you and it while we talk?"
>
> The overlay never auto-dismisses. User must explicitly tap.

(Days 4-5 prompts to be written when you reach them — interfaces are stable above.)

---

## 7. Directory structure (create on Day 1)

```
caregiver_tool/
├── pubspec.yaml
├── README.md
├── LICENSE                            # ML engineer adds Apache 2.0
├── .gitignore
│
├── lib/
│   ├── main.dart
│   ├── app.dart                       # ProviderScope + MaterialApp.router + Crisis overlay stack
│   │
│   ├── core/
│   │   ├── llm/
│   │   │   ├── gemma_client.dart      # abstract interface + TurnRecord
│   │   │   ├── mock_gemma_client.dart # Day 2
│   │   │   ├── real_gemma_client.dart # Day 4 (flutter_gemma)
│   │   │   ├── providers.dart         # the single Provider<GemmaClient>
│   │   │   └── chat_template.dart     # Gemma 4 turn format helpers
│   │   │
│   │   ├── crisis/
│   │   │   ├── classifier.dart        # ML ENGINEER FILE — Day 3
│   │   │   ├── crisis_router.dart     # yours
│   │   │   └── resources.dart         # helpline numbers + url_launcher
│   │   │
│   │   ├── data/
│   │   │   ├── database.dart          # raw sqflite schema
│   │   │   ├── session_repo.dart
│   │   │   ├── turn_repo.dart
│   │   │   ├── summary_repo.dart
│   │   │   └── providers.dart
│   │   │
│   │   └── modules/
│   │       ├── module_state.dart      # sealed classes, no codegen
│   │       ├── module_runner_notifier.dart
│   │       └── module_registry.dart   # maps moduleId -> max_turns, prompt_path
│   │
│   ├── features/
│   │   ├── onboarding/onboarding_screen.dart
│   │   ├── home/
│   │   │   ├── home_screen.dart
│   │   │   └── home_state.dart
│   │   ├── module_runner/
│   │   │   ├── module_runner_screen.dart
│   │   │   └── turn_card.dart
│   │   ├── crisis_overlay/crisis_overlay.dart
│   │   ├── session_close/session_close_screen.dart
│   │   └── settings/settings_screen.dart
│   │
│   ├── ui/
│   │   ├── widgets/
│   │   │   ├── primary_button.dart
│   │   │   ├── help_button.dart       # always-visible "I need help right now"
│   │   │   └── duration_chip.dart
│   │   ├── theme.dart
│   │   └── typography.dart
│   │
│   └── routing/router.dart            # go_router config, string paths
│
├── assets/
│   ├── mock_responses.json            # yours, Day 2
│   ├── model/                         # ML engineer drops .litertlm here Day 4
│   └── prompts/                       # ML engineer drops module prompts Day 3
│       ├── self_compassion.json
│       ├── act_defusion.json
│       └── dichotomy_sort.json
│
└── test/
    └── (widget tests per screen)
```

No `.g.dart` files. No `.freezed.dart` files. No `database.g.dart`. If you see any of these appear, something pulled in codegen — investigate before continuing.

---

## 8. Mock responses (paste into `assets/mock_responses.json` on Day 2)

```json
{
  "self_compassion": {
    "0": [
      "You yelled. She looked scared. That's the picture in front of you right now. Loving someone and wishing their suffering would end are not opposites. They sit in the same place.",
      "Third time tonight she didn't know your name. You're still here, in the room, doing it. The grief of being unrecognized by someone who knew you your whole life is real grief."
    ],
    "1": [
      "Try this: hand flat on your chest. Five seconds. Say once, quietly, 'this is hard, and I'm still here.' That's the whole practice.",
      "Permission for the next ten minutes: you can put the laundry down. The dishes can wait. Sit in one chair without doing anything productive."
    ],
    "2": [
      "The night will still be long. You named it. That counts.",
      "Nothing got fixed. You showed up to it anyway. See you when you come back."
    ]
  },
  "act_defusion": {
    "0": ["The thought that came up was: 'I'm a terrible daughter.' That thought has weight. It's also a thought."],
    "1": ["Try saying it like this: 'I'm having the thought that I'm a terrible daughter.' Same words. Slight distance."],
    "2": ["What's different when you say it that way? No right answer."],
    "3": ["Sometimes nothing. Sometimes a little. Both are okay."],
    "4": ["The thought will probably come back. You can do this again when it does."]
  },
  "dichotomy_sort": {
    "0": ["All of it feels like it's on you right now. Let's try sorting. Three piles. What's one piece of this that feels like it's all on you?"],
    "1": ["If you did nothing about that for one week, would anything change?"],
    "2": ["Whose hands would have to move for that to change?"],
    "3": ["Two things in the middle column. One on your side. Two that aren't yours at all."],
    "4": ["The pile didn't shrink. The shape changed. You can come back to this."]
  },
  "summary": {
    "default": {
      "theme": "Late night, after a hard moment.",
      "what_tried": "Self-Compassion Break. You named the moment and gave yourself one small kindness.",
      "thread": "The thought 'I'm a terrible daughter' came up twice. ACT defusion might fit if it returns."
    }
  }
}
```

Parse with `dart:convert` (`jsonDecode`). No codegen.

---

## 9. Handoff dependencies

| Day | What you receive | Where it goes | What you do |
|-----|------------------|---------------|-------------|
| Day 3 | `crisis_classifier.dart` | `lib/core/crisis/classifier.dart` | Wire to `CrisisRouter`; do not edit rules |
| Day 3 | `assets/prompts/*.json` (3 module prompts) | `assets/prompts/` | Replace hardcoded prompts in `module_registry.dart` |
| Day 4 | `gemma-4-E2B-it.litertlm` (base, ~1.5 GB) | `assets/model/` | Build `RealGemmaClient`, swap from mock |
| Day 5 | `gemma-4-E2B-it-LoRA.litertlm` (fine-tuned) | `assets/model/` (replaces base) | One-line model path change |
| Day 6 | Final eval chart, write-up paragraphs | `docs/` and README | Embed in README |

If by 5pm on the handoff day you don't have the file, ping the ML engineer. Don't sit on it.

---

## 10. Hard rules — do not violate

1. **No codegen.** Don't add `build_runner`, `freezed`, `drift`, `riverpod_generator`, `json_serializable`, `auto_route`, or any other code-generating package. If Claude suggests it, refuse.
2. **No network calls except `tel:` URIs via `url_launcher`.** If a package wants `INTERNET` permission, ask the ML engineer first.
3. **No analytics, no crash reporting, no telemetry.** Not even Firebase Analytics with all events disabled.
4. **No copy changes to calibrated phrases.** Onboarding card text, crisis overlay text, button labels — calibrated. Layout/spacing/colors are yours; words are not.
5. **The crisis classifier is safety code — don't touch its logic.** You wire it; you don't tune the regex.
6. **The wipe button must actually wipe.** Single tap, 5-second undo snackbar, then permanent. No multi-step "are you sure?" dialog.
7. **No share / invite / review prompts.** Ever.
8. **Always-visible help button on every screen.** Onboarding, Home, ModuleRunner, SessionClose, Settings. Never more than one tap to crisis resources.
9. **Test on a real Android device every day.** Emulator latency lies. Pixel 6+ or equivalent.

---

## 11. When you get stuck

- **Flutter/Dart compile errors:** paste the FULL error (including stack trace) to Claude Code. The first three lines aren't always the cause.
- **"Type 'X' isn't defined" or "Undefined name":** check imports first. Claude sometimes forgets to add an import after generating new code.
- **Architecture questions ("should this be in core or features?"):** anything talking to the model, DB, or classifier → `core/`. Any Screen or screen-specific widget → `features/`. Shared widgets → `ui/widgets/`.
- **Anything safety-related or model-related:** ask the ML engineer, not Claude Code.
- **Anything about copy:** ask the ML engineer. Don't rewrite.
- **If Claude suggests adding a codegen package to fix something:** stop, re-read §2, find a no-codegen alternative. There always is one for the scale of this app.

---

## 12. End-of-day checklist (every day)

- [ ] App builds and runs on the test Android device
- [ ] `flutter analyze` produces zero errors (warnings OK)
- [ ] No new `INTERNET` permission, no analytics, no tracking, no codegen packages
- [ ] Today's checkpoint from §5 is met
- [ ] Code committed and pushed to GitHub
- [ ] Short note to ML engineer: "Today I shipped X. Tomorrow Y. I need Z from you by W."

---

That's it. Start with Prompt 1 in §6. Good luck.
