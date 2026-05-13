# Module System

This document describes how exercise modules are defined and added to the application. The system is intentionally minimal: most of what makes a module unique lives in a JSON manifest, not in code.

## Two-layer split

Modules are defined across two complementary layers:

- **Code layer** (`lib/core/modules/module_registry.dart`) — visual identity (icon, accent color), prompt-file path, registration in the module map. Static, hardcoded Dart.

- **Asset layer** (`assets/prompts/<module_id>.json`) — display name, description, system prompt for the language model, max turn count, summary template, evidence citation, optional function-call schema.

This split lets module content (prompts, copy, evidence base) evolve independently from code, and lets a new module of the same shape be added by writing one JSON file plus a single-line registry entry.

## Code-side classes

```dart
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

class ModuleManifest {
  final String id;
  final String displayName;
  final String shortDescription;
  final int maxTurns;
  final int estimatedMinutes;
  final int minDurationMin;
  final String systemPrompt;
  final SummaryTemplate summaryTemplate;
  final String? evidenceCitation;
  final Map<String, dynamic>? functionCallSchema;
  // ... fromJson factory using dart:convert (no codegen)
}

class SummaryTemplate {
  final String themeTemplate;
  final String whatTried;
  // ... fromJson factory
}
```

`ModuleConfig` is hardcoded at compile time. `ModuleManifest` is loaded at runtime from JSON via `rootBundle.loadString` and `jsonDecode`.

## Registry

```dart
const Map<String, ModuleConfig> moduleRegistry = {
  'self_compassion': ModuleConfig(
    id: 'self_compassion',
    promptPath: 'assets/prompts/self_compassion.json',
    icon: Icons.favorite_border,
    accentColor: Color(0xFFE8B4D8),
  ),
  'act_defusion': ModuleConfig(
    id: 'act_defusion',
    promptPath: 'assets/prompts/act_defusion.json',
    icon: Icons.cloud_outlined,
    accentColor: Color(0xFFB4D8E8),
  ),
  'dichotomy_sort': ModuleConfig(
    id: 'dichotomy_sort',
    promptPath: 'assets/prompts/dichotomy_sort.json',
    icon: Icons.category_outlined,
    accentColor: Color(0xFFD8E8B4),
  ),
};
```

## JSON manifest schema

Every `assets/prompts/<module_id>.json` follows this structure:

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

### Field semantics

| Field | Type | Meaning |
|---|---|---|
| `id` | string | Must match filename and the key in the Dart registry. |
| `display_name` | string | Title on the selection card. ≤ 30 characters. |
| `short_description` | string | Subtitle on the card. ≤ 80 characters. |
| `max_turns` | int | Number of turns the state machine runs before automatic close. |
| `estimated_minutes` | int | Typical session length, used in UI hints. |
| `min_duration_min` | int | Below this duration the module is shown but not highlighted. Not a gatekeeper. |
| `system_prompt` | string | Full system prompt for the language model. May include the `{current_risk_level}` placeholder; see substitution rules below. |
| `evidence_citation` | string \| null | Short academic citation displayed in the long-press "What is this module?" overlay. |
| `function_call_schema` | object \| null | Optional JSON schema for native function calling. |
| `summary_template` | object | Used to generate the session-close summary. |
| `summary_template.theme_template` | string | Supports `{time_of_day}` placeholder substitution. |
| `summary_template.what_tried` | string | Static descriptive sentence. |

### Placeholder substitution

**Time of day.** The application substitutes `{time_of_day}` in summary templates with one of: `Late night`, `Early morning`, `Morning`, `Afternoon`, `Evening`, `Night`, based on the local hour at session start.

**Risk level.** If a `system_prompt` contains the literal placeholder `{current_risk_level}`, the application substitutes it with one of `none`, `low`, `medium` before sending to the model. High and acute risk levels never reach the model — they route directly to the crisis overlay before inference is invoked. Prompts can use this placeholder to adjust behavior at MEDIUM risk (typically: stay in witness mode, do not invite a practice this turn).

If the placeholder is absent from a prompt, no substitution occurs and the prompt is sent verbatim.

### Error handling

`ModuleManifest.fromJson` throws on malformed input. The application does not wrap this in a try/catch with silent fallback. A loud crash at startup with the exact parse error is recoverable in 30 seconds; a silent fallback to placeholder content is recoverable only by reviewing every screen for incorrect output.

## Adding a new module of the same shape

1. Author a new `assets/prompts/<new_id>.json` following the schema above.
2. Add one line to `moduleRegistry` in `module_registry.dart` with the new ID, prompt path, Material icon, and accent color.
3. Optionally: add keyword routing rules so the module suggester offers the new module when relevant phrases appear.

No changes to the state machine, the module runner, the database schema, or the routing layer are required.

## Limits

The minimal-effort addition path holds only for modules of the same structural shape: N turns of `model reflection → user reply → next reflection`. Modules with different interaction shapes require code changes:

- **Breathing exercises** would need a visual timer widget and per-turn animation
- **Body scans** would need audio playback infrastructure
- **Multi-field journaling** would need a richer turn-state schema with multiple input fields per turn

Such modules require widget polymorphism in the module runner and an extended turn-state model.
