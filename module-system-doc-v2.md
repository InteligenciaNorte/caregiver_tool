# Module System — Day 1 Architecture & ML Contract

> Reference document for the caregiver_tool Flutter side. Share with ML engineer.
> **v2 changes:** added `evidence_citation` field, risk-level substitution spec, and JSON error-handling policy.

## Two-layer design

The module system splits cleanly along the team boundary:

- **Flutter side** (frontend dev owns): visual identity (icon, accent color), routing, the registry listing which modules exist.
- **ML side** (ML engineer owns): all copy, system prompt, max_turns, summary template — everything in `assets/prompts/<id>.json`.

Adding a new module = ML drops a JSON + sends icon name and accent color, frontend dev adds one line to the registry. No state machine changes, no DB migrations, no UI rework (for modules of the same shape — see "Limits" at bottom).

## Flutter-side classes

### `ModuleConfig` — visual + structural, hardcoded in Dart

```dart
// lib/core/modules/module_config.dart
import 'package:flutter/material.dart';

class ModuleConfig {
  final String id;
  final String promptPath;
  final IconData icon;
  final Color accentColor;

  const ModuleConfig({
    required this.id,
    required this.promptPath,
    required this.icon,
    required this.accentColor,
  });
}
```

### `ModuleManifest` — copy + behavior, loaded from JSON

```dart
// lib/core/modules/module_manifest.dart

class ModuleManifest {
  final String id;
  final String displayName;
  final String shortDescription;
  final int maxTurns;
  final int estimatedMinutes;
  final int minDurationMin;
  final String systemPrompt;
  final SummaryTemplate summaryTemplate;
  final String? evidenceCitation;                   // nullable; shown in "what is this module?" overlay
  final Map<String, dynamic>? functionCallSchema;   // optional, used Day 5+

  const ModuleManifest({
    required this.id,
    required this.displayName,
    required this.shortDescription,
    required this.maxTurns,
    required this.estimatedMinutes,
    required this.minDurationMin,
    required this.systemPrompt,
    required this.summaryTemplate,
    this.evidenceCitation,
    this.functionCallSchema,
  });

  factory ModuleManifest.fromJson(Map<String, dynamic> json) => ModuleManifest(
    id: json['id'] as String,
    displayName: json['display_name'] as String,
    shortDescription: json['short_description'] as String,
    maxTurns: json['max_turns'] as int,
    estimatedMinutes: json['estimated_minutes'] as int,
    minDurationMin: json['min_duration_min'] as int,
    systemPrompt: json['system_prompt'] as String,
    summaryTemplate: SummaryTemplate.fromJson(
      json['summary_template'] as Map<String, dynamic>,
    ),
    evidenceCitation: json['evidence_citation'] as String?,
    functionCallSchema: json['function_call_schema'] as Map<String, dynamic>?,
  );
}

class SummaryTemplate {
  final String themeTemplate; // e.g., "{time_of_day}, after a hard moment."
  final String whatTried;

  const SummaryTemplate({
    required this.themeTemplate,
    required this.whatTried,
  });

  factory SummaryTemplate.fromJson(Map<String, dynamic> json) => SummaryTemplate(
    themeTemplate: json['theme_template'] as String,
    whatTried: json['what_tried'] as String,
  );
}
```

### Registry

```dart
// lib/core/modules/module_registry.dart
import 'package:flutter/material.dart';
import 'module_config.dart';

const Map<String, ModuleConfig> moduleRegistry = {
  'self_compassion': ModuleConfig(
    id: 'self_compassion',
    promptPath: 'assets/prompts/self_compassion.json',
    icon: Icons.favorite_border,
    accentColor: Color(0xFFE8B4D8), // soft pink — placeholder
  ),
  'act_defusion': ModuleConfig(
    id: 'act_defusion',
    promptPath: 'assets/prompts/act_defusion.json',
    icon: Icons.cloud_outlined,
    accentColor: Color(0xFFB4D8E8), // soft blue — placeholder
  ),
  'dichotomy_sort': ModuleConfig(
    id: 'dichotomy_sort',
    promptPath: 'assets/prompts/dichotomy_sort.json',
    icon: Icons.category_outlined,
    accentColor: Color(0xFFD8E8B4), // soft green — placeholder
  ),
};
```

Colors are placeholders — ML/design can swap. Icons are Material icons; substitutes are one-line changes.

## JSON contract for ML engineer

Every `assets/prompts/<module_id>.json` must contain the following structure:

```json
{
  "id": "self_compassion",
  "display_name": "Self-Compassion Break",
  "short_description": "Name the moment. Give yourself one small permission.",
  "max_turns": 3,
  "estimated_minutes": 3,
  "min_duration_min": 3,
  "system_prompt": "You are a witness, not a coach. ...",
  "evidence_citation": "Wiita et al. 2024, JMIR Aging",
  "function_call_schema": null,
  "summary_template": {
    "theme_template": "{time_of_day}, after a hard moment.",
    "what_tried": "Self-Compassion Break. You named the moment and gave yourself one small kindness."
  }
}
```

### Field reference

| Field | Type | Meaning |
|---|---|---|
| `id` | string | Must match filename and the key in Dart registry. |
| `display_name` | string | Title on the selection card. Keep ≤ 30 chars. |
| `short_description` | string | Subtitle on the card. Keep ≤ 80 chars. |
| `max_turns` | int | Number of turns the state machine runs. |
| `estimated_minutes` | int | Typical session length. Drives "fits in your window" hint. |
| `min_duration_min` | int | Below this duration, module is shown but not highlighted. **Not a gatekeeper** — user can still tap. |
| `system_prompt` | string | Full system prompt for Gemma 4. May include `{current_risk_level}` placeholder — see substitution rules below. |
| `evidence_citation` | string \| null | Short citation shown in the "What is this module doing?" overlay (long-press on a running module). E.g. `"Wiita et al. 2024, JMIR Aging"` or `"Losada et al. 2015, RCT"`. Nullable, but **recommended** — part of the Health-track narrative. |
| `function_call_schema` | object \| null | JSON schema for native function calling. Day 5+. `null` until then. |
| `summary_template` | object | Used by Day 2 mock summary; fallback for Day 4+ if model summary fails. |
| `summary_template.theme_template` | string | Supports `{time_of_day}` placeholder. |
| `summary_template.what_tried` | string | Fixed sentence. |

### Time-of-day buckets used in templating

The Flutter side substitutes `{time_of_day}` with one of:
`Late night` / `Early morning` / `Morning` / `Afternoon` / `Evening` / `Night`.

### Risk level placeholder substitution

If the `system_prompt` contains the literal placeholder `{current_risk_level}`, the Flutter side substitutes it via simple `String.replaceAll` with one of:

- `none` — classifier returned no risk signals
- `low` — caregiver-situational venting (patient-directed "she is a burden", "wish she'd die in her sleep", exhaustion metaphors)
- `medium` — passive ideation, persistent hopelessness, burdensomeness with ambiguous referent

**`high` and `acute` never reach the model.** Those levels route directly to the crisis overlay before the model is invoked, so the system prompt does not need to handle them. ML engineer can author prompts assuming the placeholder will only ever be `none`, `low`, or `medium`.

If the placeholder is absent from the prompt, no substitution happens — the prompt is sent as-is. Recommended pattern in the prompt: a short conditional like *"If `{current_risk_level}` is `medium`, do not invite a practice this turn; remain in witness/normalize mode."*

## Day 1–2 placeholder strategy

ML's JSONs land on Day 3. Until then, the Flutter side carries hardcoded `ModuleManifest` values in a const map next to `moduleRegistry`. On Day 3, swap to `rootBundle.loadString(...)` + `jsonDecode` + `ModuleManifest.fromJson`. The rest of the codebase reads `ModuleManifest` objects through a single provider — nothing else changes.

```dart
// Day 1-2 (hardcoded):
final manifestProvider = Provider.family<ModuleManifest, String>(
  (ref, id) => _hardcodedManifests[id]!,
);

// Day 3 (one line swap):
final manifestProvider = FutureProvider.family<ModuleManifest, String>(
  (ref, id) async {
    final path = moduleRegistry[id]!.promptPath;
    final raw = await rootBundle.loadString(path);
    return ModuleManifest.fromJson(jsonDecode(raw));
  },
);
```

## Error handling for malformed JSON (Day 3+)

When loading manifests from disk, `ModuleManifest.fromJson` will throw on missing fields, wrong types, or invalid JSON. **Let it crash loudly. Do not wrap in try/catch with a silent fallback to hardcoded manifests.**

The reason: a silent fallback means the demo (or worse, the submitted APK) runs with a Day-1 placeholder prompt instead of the ML engineer's tuned LoRA prompt, and nobody notices until a judge plays with it. A loud crash on app start is recoverable in 30 seconds (ML engineer fixes the JSON); a silent fallback is recoverable only by reviewing every screen of the demo video frame-by-frame.

Same policy in release builds: crash loudly. The submission ships with known-good JSON; a parse error in production indicates corruption, which a silent fallback would mask.

Implementation: no `try`/`catch` around `ModuleManifest.fromJson`. Let the `FutureProvider` surface the error naturally; a top-level error screen with the exception message is sufficient.

## Adding a new module (post-hackathon)

1. **ML** writes `assets/prompts/<new_id>.json` per the schema above.
2. **ML** sends frontend dev the icon name (any Material icon) and accent color.
3. **Frontend dev** adds one line to `moduleRegistry` in `module_registry.dart`.
4. **(Optional)** ML adds a keyword bucket to `assets/keyword_rules.json` for the module suggester.
5. **(Optional)** ML adds canned responses to `mock_responses.json` for offline testing.
6. Done. No changes to state machine, `ModuleRunner`, DB, routing, or selection screen.

## Limits — when this gets harder

The cheap-to-add path holds only for modules of **the same shape**: N turns of `model reflection → user reply → next reflection`. Examples that break this:

- **Breathing module** — needs a visual timer and animation per turn.
- **Body scan** — needs audio playback.
- **Journaling** — multiple input fields per turn.

These would require widget polymorphism in `ModuleRunner` and a richer `TurnState` schema. Estimated work: 1–2 days, not 30 minutes. Out of scope for this hackathon; flagged for post-hackathon roadmap.
