# Crisis Classifier — Research Summary (Phase 1)

Status: **research only — no Dart written yet.** This document is the
evidence base and design proposal for `lib/core/crisis/classifier.dart`.
It is meant to be reviewed by the project lead (copy/safety owner) and the
ML engineer (classifier-rules owner) before any code is written.

## 1. Purpose, scope, and what the levels actually do

The classifier is the **deterministic safety pre-filter** that runs once,
synchronously, on the caregiver's typed situation before a session starts.
It is intentionally simple, auditable, and conservative — it is *not* a
diagnostic instrument and not a model. It is backstopped by (a) the
language model's own behavior during the session and (b) the always-visible
"I need help right now" link.

What each level causes (from `crisis_router.dart` `routeFor`, unchangeable
here — quoted only to calibrate bias):

| Level    | Routed to    | Consequence for the user |
|----------|--------------|--------------------------|
| `none`   | `GoSession`  | Session runs normally |
| `low`    | `GoSession`  | Session runs normally |
| `medium` | `GoSession`  | Session runs **+ persistent helpline card** pinned every step |
| `high`   | `GoCrisis`   | **Session never starts**; full-screen crisis overlay |
| `acute`  | `GoCrisis`   | **Session never starts**; full-screen crisis overlay |

This table drives the **bias calibration**:

- An L1 false positive costs the user a session and shows a crisis screen.
  An L1 false negative can miss someone with a method/plan. Per the task
  brief, **L1 is deliberately over-inclusive on method/means language** —
  the failure we refuse is the missed plan.
- L3 → `medium` does **not** block the session; it only pins a helpline
  card. So an L3 false positive is *cheap*. We still avoid it (it dilutes
  the signal and could feel surveilling), but the asymmetry means L3 can
  paraphrase generously without much downside.
- L2 → `high` **does** block the session. An L2 false positive is the most
  expensive non-acute error: a venting caregiver gets a crisis wall instead
  of the support module. **L2 must be the most precise layer**, and the
  self-vs-other subject test exists specifically to keep normal caregiver
  death-wish/burden talk out of `high`.

Net bias, as the brief specifies: **over-flag method/means (L1); under-flag
rather than over-flag normal venting (L2/L3).**

## 2. Evaluation model

- **All matching is case-insensitive** (`(?i)` / lowercased input).
- **Scan all three layers and return the maximum severity**, not
  first-match-wins. Rationale: "*she's a burden and honestly I wish I
  weren't here either*" contains a patient-directed clause (L2→low) and a
  self-directed passive clause (L3→medium); the user must get the higher
  level. Severity order: `acute > high > medium > low > none`.
- **Self-reference gate.** L1 method/plan and L3 passive-ideation matches
  require a first-person self-referent in scope (`I`, `I'm`, `myself`,
  `my own`, `me`). This single rule removes the largest class of false
  positives (caregiver hyperbole aimed at the patient or the situation).
- **Empty / whitespace-only input → `none`** (explicit early return).
- Input is the raw situation string; we normalize curly apostrophes
  (`’`→`'`) so contractions match, and collapse internal whitespace.

## 3. L1 — Keyword detection → ACUTE

Any L1 hit returns `acute`. L1 looks for the *act, the means, the plan,
the timeline, or the preparation* of self-directed suicide. Five groups.

### L1.a — Direct self-kill statements

Explicit naming of the suicidal act, self-directed.

> Fragments (self-referent required in the same clause):
> `kill myself`, `killing myself`, `end my life`, `ending my life`,
> `take my (own )?life`, `end it all`, `commit suicide`, `suicide`/
> `suicidal` (as self-statement: "I'm suicidal", "I feel suicidal"),
> `don'?t want to (be alive|live anymore|exist)` *(borderline — see note)*.

**Citation.** Mirrors C-SSRS active-ideation items Q2–Q5 ("*Have you
actually had any thoughts of killing yourself?*"; "*…how you might do
this?*"; "*…some intention of acting on them?*"; "*…worked out the
details of how to kill yourself?*") and ASQ Q3 ("*…thoughts about
killing yourself?*"). C-SSRS Risk Assessment, Lifeline/SAMHSA version,
2008/2014; ASQ, NIMH.

**Negative control (must NOT fire):** "*she's killing me*", "*this job is
killing me*", "*he'll be the death of me*", "*I could kill him*" (anger at
patient, not self — and explicitly **out of scope**: this tool does not do
homicide classification; treat as venting), "*killing time*", "*dressed to
kill*". Defense: self-referent gate + an idiom denylist (§6).

### L1.b — Method / means words

The means of a suicide attempt, self-directed.

> Fragments (self-referent or reflexive object required):
> firearm — `shoot myself`, `gun` + self, `put a bullet`,
> `blow my (head|brains) (off|out)`;
> poisoning/overdose — `overdose`, `\bOD\b`, `take (all|a bunch of|the
> whole bottle of|too many) (the )?(pills|meds|medication)`,
> `swallow .* pills`, `poison myself`;
> hanging/asphyxiation — `hang myself`, `noose`, `suffocate myself`,
> `asphyxiat`;
> sharp/cutting — `cut my wrists`, `slit my wrists`, `cutting myself` /
> `cut myself (tonight|today|just now|right now|this morning|earlier|
> again)` *(actuality marker required — DECISION 2; see note)*;
> jumping — `jump off`, `jump in front of`, `throw myself (off|in front)`;
> gas — `carbon monoxide`, `car (running )?in the garage`, `exhaust fumes`;
> drowning — `drown myself`.

**Citation.** Method taxonomy follows the established lethal-means
categories used in suicide-prevention practice: firearms, poisoning/
medication, hanging/suffocation, jumping, gas (Harvard T.H. Chan *Means
Matter* / CALM "Counseling on Access to Lethal Means"; SAMHSA SAFE-T,
which lists "*firearms, pills or ingestible poisons, sharps, high places…
materials/opportunity for hanging or asphyxiation*"). C-SSRS Q3
("*…how you might do this?*") is the method probe.

**Negative control:** "*the noise is killing me*", "*shoot, I forgot*",
"*I jumped when the phone rang*", "*she takes a lot of pills*" (the
*patient's* medication — no self-referent), "*I could just scream*".
Defense: self-referent/reflexive-object gate.

**Note — DECISION 2 (FINAL).** `don't want to be alive` family →
**ACUTE**, unconditional self-frame. `cut myself` → **ACUTE only with an
actuality marker**: present-continuous (`cutting myself`) or a recent-time
marker (`cut myself (tonight|today|just now|right now|this morning|
earlier|again)`). The **bare phrase alone never fires**; historical
(`when I was 17 I cut myself`, `used to`, `in high school`) and accidental
(`cut myself shaving`, `chopping`, `on a can`, `by accident`) are rejected
by an acceptor + historical/accidental vetoer. Both positive and negative
cases are in the test suite. Clinically these can be self-injury-without-
suicidal-intent; the actuality gate is the agreed precision/recall point.

### L1.c — Plan words

A worked-out plan for self-harm.

> Fragments: `I have a plan`, `my plan is`, `I'?ve worked out (how|the
> details)`, `I figured out how`, `I (know|decided) (how|when) I('?ll| will|
> would) (do it|end it|kill myself)`, `planning to (kill myself|end (it|my
> life))`, `I'?ve decided`.

**Citation.** C-SSRS Q5 "*Have you started to work or worked out the
details of how to kill yourself? Do you intend to carry out this plan?*"
and the C-SSRS Risk Assessment checklist item "*Suicidal intent with
specific plan*". 2008 C-SSRS / SAMHSA Lifeline version.

**Negative control:** "*my plan is to get her to daycare by 9*",
"*I worked out a schedule*", "*I have a plan for respite*" — no self-harm
object. Defense: plan fragments only fire when the plan's object is a
self-kill phrase from L1.a/L1.b (co-occurrence required, not bare "plan").

### L1.d — Timeline / imminence words

Imminence attached to self-harm. Timeline words alone are meaningless;
they only count **in co-occurrence with an L1.a/L1.b self-harm phrase**.

> Fragments: `tonight`, `today`, `right now`, `this (morning|afternoon|
> evening|weekend)`, `by (tonight|tomorrow|friday|the weekend|then)`,
> `before (she|he|they|mom|dad) (wakes|gets|comes) (up|back|home)`,
> `after (she|he|they) (fall|falls|are) asleep`, `when (it's|its) over`,
> `as soon as`.

**Citation.** SAMHSA SAFE-T / NYS CPI "*plan's imminence (plan to act in
the near future)*" and C-SSRS Risk Assessment weighting of acute/proximal
risk. SAFE-T pocket card; NYS Comprehensive Suicide Risk Assessment
template §7 ("Level of Care Determination").

**Negative control:** "*I have to get her to the doctor tonight*",
"*I'll lose my mind by Friday*", "*the weekend is going to be brutal*" —
no self-harm co-occurrence → no fire.

### L1.e — Means-access / preparatory acts

Concrete preparation, self-directed. C-SSRS Q6 preparatory-behavior set.

> Fragments: `(bought|got|have|own|purchas\w+) a gun` *(in self-harm
> context)*, `(been )?(collecting|saving( up)?|stockpil\w+|hoard\w+)
> [^\n]{0,20}? (pills|meds|medication|painkillers)`,
> `wrote (a|my) suicide note`, `wrote (a|my) will` *(in context)*,
> `saying goodbye` *(in context)*.
> **DECISION 1 (FINAL): `giving away my things/possessions` and `getting
> my affairs in order` are REMOVED entirely** — see population-specific
> reasoning below.

**Citation.** C-SSRS Q6 preparatory behaviors, verbatim: "*Actions to
prepare for taking one's life, such as collecting/buying pills,
purchasing a gun, saying goodbye, or writing a will or suicide note.*"
Also SAMHSA SAFE-T preparatory examples ("collected pills, obtained a
gun, gave away valuables, wrote a will or suicide note") and the C-SSRS
Lifeline checklist items "*Other preparatory acts to kill self*" and
"*Method for suicide available (gun, pills, etc.)*".

**Population-specific removal (DECISION 1, FINAL).** `getting my affairs
in order` and `giving away my things/possessions` are REMOVED from L1.
Caregivers doing anticipatory-grief work for a parent with dementia are
literally handling the parent's affairs and sorting their belongings; in
this population the false-positive rate is unacceptably high and the cost
(a crisis wall instead of the support module) is the most expensive
non-acute error. The rest of L1.e (gun in self-harm context, collecting/
stockpiling pills, suicide note / will in context, saying goodbye in
context) is retained.

**Negative control (must classify `none`):** "*I'm getting my affairs in
order*", "*I need to get my affairs in order before the surgery*",
"*I'm giving away her old clothes*", "*I gave away mom's things to the
church*", "*I've been sorting through dad's possessions*", "*we bought a
gun safe years ago*" (no self-harm context, no second prep signal).

## 4. L2 — IPTS discriminator → patient = LOW, bare self = MEDIUM, self+elimination = HIGH

> **DECISION 5 (FINAL) — L2-self split (operational triage).** The INQ
> perceived-burdensomeness construct is empirically linked to suicidality
> in clinical populations, but in a dementia-caregiver population the base
> rate of *non-suicidal* burdensomeness cognition (caregiver guilt,
> anticipatory anxiety about aging, comparative empathy with the patient)
> is high. Routing bare burdensomeness to HIGH means a caregiver
> expressing normal caregiver guilt gets the crisis wall instead of the
> support module they came for — the most disproportionate non-acute
> error in this app. Therefore L2-self splits into **bare
> burdensomeness → MEDIUM** (session continues, helpline pinned — same
> tier as L3) and **burdensomeness + explicit self-elimination → HIGH**
> (crisis wall). Patient-directed framing stays **LOW**. The
> MEDIUM-bare / HIGH-with-elimination distinction is the operational
> triage. The §4.1 negation carve-out applies to **both** self arms.

L2 handles burden / "better-off-gone" / death-wish framing that did **not**
hit L1. The entire layer turns on one linguistic question, taken straight
from Joiner's Interpersonal Theory of Suicide:

> **Who is the subject of the burden / whose absence is framed as a
> benefit — the caregiver (self) or the care recipient (other)?**

### Why this is the right discriminator

In the Interpersonal Theory of Suicide (Joiner; Van Orden et al. 2010,
2012 INQ validation), **perceived burdensomeness** is a *self-directed*
cognition — defined as "*the view that one's existence burdens family,
friends, and/or society*", producing the belief that "*my death will be
worth more than my life to family, friends, society, etc.*" (Van Orden
et al., PMC2846517). The Interpersonal Needs Questionnaire operationalizes
it with **first-person self-as-burden items**: "*I think I am a burden on
society*", "*The people in my life would be better off if I were gone*",
"*…better off if I were dead*", "*…would be happier without me*", "*my
death would be a relief to others*" (INQ, Van Orden et al. PMC3377972;
Suicide Probability Scale burdensomeness items, PMC2846517: "*I feel
people would be better off if I were dead*", "*no one will miss me when I
am gone*"). The grammatical subject of the burden in every validated item
is **the respondent themselves**.

The mirror image — the *caregiver wishing the patient's suffering or the
patient would end* — is a **separate, well-documented, non-suicidal
construct**: anticipatory / pre-death grief and caregiver ambivalence in
dementia care. The literature explicitly frames "*a wish for the illness
to end*", relief, and wishing the loved one would pass as **normal
caregiver responses, distinct from depression and not indicators of
suicidal ideation** (HopeHealth; Lindauer & Harvath PMC3251637; Oxford
*The Gerontologist* 49(3):388 on anticipatory grief and caregiver burden;
PMC8392352). Routing these to a crisis wall would be both clinically wrong
and a betrayal of what this module is for.

### MEDIUM — bare self-burdensomeness, no elimination link (→ session runs)

Pattern: a **first-person subject** is the burden, with NO explicit
self-elimination complement.

> Markers:
> `I('?m| am) (a |such a |just a |nothing but a )?burden`
> (optionally `to/on` + family terms),
> `I feel (like )?(I'?m )?(a )?burden`,
> `I (can'?t|don'?t want to|hate) (be|being) (a )?burden`,
> `I('?m| am) (dragging|weighing|holding) (them|everyone|my family) down`.

**Citation:** IPTS perceived burdensomeness (INQ self-as-burden items).
Tier set by DECISION 5: in this population bare burdensomeness is most
often non-suicidal caregiver guilt; MEDIUM keeps the support module open
while still surfacing the pinned helpline.

### HIGH — self-burdensomeness + explicit self-elimination (→ blocks session)

Pattern: the caregiver's own death / absence is explicitly framed as a
benefit to others (elimination complement present).

> Markers:
> `(they|everyone|my (kids|children|family|husband|wife)|he|she)
>  (would|'?d| would all) be better off (without me|if I (was|were|
>  weren't|didn't) (gone|dead|not here|not around|exist))`,
> `(they|everyone) (wouldn'?t|would not) miss me`,
> `no one (would|'?d) miss me`,
> `my death would be a relief to (them|everyone|my family)`,
> `the world would be better (off )?without me`,
> `(they|my family) (deserve|deserves) better than me`,
> `I'?m worth more (to them )?(gone|dead)`.
> Family terms: `kids|children|son|daughter|family|husband|wife|spouse|
> partner|mom|dad|parents|them|everyone`.

**Citation:** IPTS perceived burdensomeness, self-directed with the
fatal-misperception complement — INQ & Suicide Probability Scale item
phrasings ("*the people in my life would be better off if I were gone*",
"*my death would be a relief to others*"); also PHQ-9 item 9 and ASQ Q2
when the beneficiary is **the caregiver's own absence**.

### LOW — patient-directed burden / caregiver death-wish (→ session runs)

Pattern: the **care recipient** is the subject of the burden, or the
death/relief wish is directed at the patient or the situation.

> Markers (subject is a patient/third-person referent):
> `(she|he|mom|dad|mum|my (mother|father|husband|wife|mom|dad)|grandma|
>  grandpa|the patient|<name>) (is|'?s|has become|'?s such) a burden`,
> `taking care of (her|him|them) is (a burden|too much)`,
> `caring for (her|him) is killing me` *(idiom — see §6)*,
> `I (wish|hope|sometimes wish|just want) (she|he|they|it|this|mom|dad)
>  (would |to )?(die|pass|go|be over|end|was gone|were gone)
>  (in (her|his) sleep|peacefully|soon)?`,
> `it would be a relief when (she|he|they)('?s| is| are) gone`,
> `(she|he)('?d| would) be better off (dead|gone|at peace)`,
> `I just want (this|her suffering|his pain) to (be over|end|stop)`.

**Citation:** anticipatory grief / caregiver ambivalence literature
(HopeHealth; PMC3251637; Oxford *Gerontologist* 49(3):388; PMC8392352) —
patient-directed relief/death wishes are normal, non-suicidal, and the
exact thing this module exists to witness. Routing them to `low` keeps
the session running.

### Acknowledged ambiguous / hard cases

These are explicitly *not* cleanly separable by lexical rules. We state
the chosen disposition and the residual risk:

1. **"*I can't be a burden to them*" / "*I don't want to be a burden*".**
   Self-subject + burden, no elimination complement. **Disposition:
   MEDIUM** (DECISION 5 — bare burdensomeness arm; was HIGH pre-Decision-5).
   The §4.1 negation carve-out applies: the negation guard does **not**
   scope L2-self, so "I don't want to be a burden" / "I can't be a burden"
   / "I don't think I'm a burden to my kids" still match and stay MEDIUM —
   negation does not change tier and does not suppress. Residual risk:
   flags some non-suicidal guilt at MEDIUM (cheap — session continues).
2. **"*we'd all be better off*" / "*everyone would be better off*"** with
   no explicit `without me` / `if I were gone`. Subject ambiguous.
   **Disposition: do not infer self-direction** → falls through (not HIGH).
   Residual risk: misses elliptical self-reference. Accepted (brief: don't
   over-flag at L2).
3. **Pronoun-ambiguous "*he'd be better off*"** with no elimination
   complement (`without me` / `if I were gone/dead`). HIGH requires the
   complement, so bare "*he'd be better off*" → **falls through to NONE**
   (do not guess). "*she'd be better off at peace/dead/gone*" → LOW
   (patient arm). Only an explicit self-elimination complement → HIGH.
4. **"*she'd be better off without me [to mess things up]*"** — surface
   `without me` but about relational guilt, not death. Lexically
   indistinguishable from the HIGH pattern. **Will mis-fire to HIGH.**
   Documented limitation (§8), not solvable without semantics.
5. **Mixed text** (patient-directed clause + self-directed clause) →
   max-severity rule (§2) takes HIGH/MEDIUM as appropriate.

## 5. L3 — Passive ideation (C-SSRS Q1 concept) → MEDIUM

L3 catches **self-directed passive death wish without active intent,
method, or plan** — the concept behind C-SSRS Q1 / ASQ Q1 / PHQ-9 item 9.
Self-referent gate (§2) applies. Returns `medium` (session still runs,
helpline card pinned), so this layer can paraphrase generously.

> Phrasings (self-referent required):
> C-SSRS Q1 / ASQ Q1 family —
> `wish I (was|were) dead`, `wish I (was|were)n'?t (here|alive)`,
> `wish I could (go to sleep and not wake up|not wake up|just not wake up|
>  disappear|vanish|not exist|stop existing)`,
> `(I )?(hope|wish) I don'?t wake up`,
> `don'?t want to wake up`;
> PHQ-9 item 9 family —
> `(I'?d|I would) be better off dead`, `better off not (here|alive)`;
> common passive paraphrases consistent with the Q1 construct —
> `(I'?m )?tired of (living|being alive|life)`,
> `don'?t want to (be here|live|keep going|go on) anymore`,
> `what'?s the point of (living|going on|me being here)`,
> `I (just )?want it (all )?to (be over|end|stop)` *(self-directed only)*,
> `I can'?t see the point anymore`.

**Citation, verbatim screener wording this paraphrases:**

- **C-SSRS Q1 ("Wish to be dead"):** "*Have you ever wished you were dead
  or wished you could go to sleep and not wake up?*" (C-SSRS Risk
  Assessment, 2008 / SAMHSA Lifeline 2014; NYS CPI template Q1).
- **ASQ Q1 (NIMH):** "*In the past few weeks, have you wished you were
  dead?*" (NIMH Ask Suicide-Screening Questions toolkit).
- **PHQ-9 item 9:** "*Over the last two weeks, how often have you been
  bothered by thoughts that you would be better off dead or of hurting
  yourself in some way?*" (PHQ-9, Kroenke/Spitzer; widely published).

**Negative control (must NOT reach MEDIUM):**

- Fatigue, not death wish: "*I'm so tired*", "*I'm exhausted*", "*I need a
  break*", "*I'm running on empty*", "*I'm burnt out*". (Only `tired of
  living`/`tired of being alive` triggers — bare `tired` never does.)
- Distress without a death referent: "*I can't do this anymore*", "*I
  can't keep going like this*", "*I can't take it*". These are precisely
  the caregiver distress the **session is designed to hold** — not
  crisis-route. → `none`.
- Situation/patient-directed "end" wishes: "*I wish this would end*",
  "*I wish it was over*", "*I just want this to be over*" where "this/it"
  is the disease or caregiving, not the caregiver's life. The
  `want it to be over/end` phrasing is **genuinely ambiguous**; L3 only
  fires it when a self-life referent is co-present, and otherwise leaves
  it to L2-LOW / NONE. Documented limitation (§8).
- "*I wish she'd go peacefully*" — patient-directed → handled at L2-LOW,
  never L3.

## 5a. Obfuscation / online-native forms → MEDIUM (DECISION 4)

TikTok-era / online-native self-harm euphemisms, **INCLUDED at MEDIUM**
(DECISION 4, FINAL). MEDIUM (not ACUTE): the session continues with the
helpline pinned, so hyperbolic/online-native use is not walled off while
genuine disclosures still surface help.

> Phrasings: first-person + `kms` (`i (want to|wanna|gonna|going to|
> might) … kms`), and `unalive (myself|me)` (self-evident reflexive).

Demographic rationale: these forms are native to the younger adult
caregiver demographic (~35–50) and are easy to miss with clinical-only
lexicons. Negation (`i would never kms`) and the reported-speech /
generic vetoes suppress them (treated as L2/L3-class for suppression).
**`sewerslide` and leetspeak remain out of scope** for this version
(limitation §8).

## 6. Negative-case catalogue — caregiver venting lookalikes

Per the brief, these matter as much as the positive cases. This is the
explicit denylist / suppression set. Every entry below must classify as
**`none`** (or, where IPTS-patient-directed, `low`) — never `medium`,
`high`, or `acute`. These are the documented "normal venting" failure
mode the architecture warns about (architecture.md §Safety).

| Utterance | Why it looks risky | Correct level | Defense |
|---|---|---|---|
| "she's killing me" / "this is killing me" | contains *kill* | none | self-referent gate (patient/situation is the agent) + idiom denylist |
| "he'll be the death of me" / "the death of me" | contains *death* | none | idiom denylist |
| "I'm exhausted to death" / "tired to death" / "worried to death" / "bored to death" / "scared to death" / "sick to death of this" | *…to death* | none | idiom denylist (`\bto death\b` as intensifier) |
| "dead tired" / "dead on my feet" / "I'm dead" (= exhausted) | contains *dead* | none | idiom denylist |
| "I could kill him" / "I could kill her" / "I could strangle her" | contains *kill* | none (out of scope; not homicide classifier) | object is patient, not self; no self-referent |
| "I can't do this anymore" / "I can't take it anymore" / "I've had it" / "I'm at my breaking point" / "I'm at the end of my rope" | despair register | none | no death/method/burden token at all |
| "I'm losing my mind" / "I'm going crazy" / "I could scream" / "I could just cry" | distress | none | no matched token |
| "I'm drowning" / "I'm suffocating" / "I'm buried" (metaphor) | method-adjacent words | none | requires reflexive self-harm construction ("drown myself"), not metaphor |
| "killing time" / "kill time" / "dressed to kill" / "kill the lights" | *kill* | none | idiom denylist |
| "the doctor said she's dying" / "he's at the end of life" / "she's terminal" | *dying/death* | none | subject is patient; no self-referent |
| "I wish she'd pass peacefully" / "I hope he goes in his sleep" / "I just want her suffering to end" | death wish | **low** (L2 patient-directed) | subject-of-wish is patient → IPTS LOW, session runs |
| "she's such a burden" / "caring for him is a burden" | *burden* | **low** (L2 patient-directed) | subject of burden is patient → IPTS LOW |
| "I would never hurt myself" / "I'm not suicidal" / "it's not like I want to die, I just need rest" | contains the exact risk phrase, negated | none | negation handling (§7) |
| "my sister said she wants to kill herself" | active method, third party | **acute** | DECISION 3: reported speech does NOT demote L1 active method/plan — specific named relation + active method → ACUTE (corrected from "none") |
| "Friends are saying things have gotten worse" | reported, plural | none | generic/plural veto (§7.3); no specific named relation, no active-method token |
| "I read about a man who shot himself" | active method | none | media/news veto (§7.3); not first-person knowledge of a specific person |
| "A character on the show last night said something dark" | reported speech | none | media veto (§7.3); fictional/media source |

Citation for the "patient-directed wishes are normal" rows: anticipatory
grief / caregiver ambivalence literature (HopeHealth; PMC3251637; Oxford
*Gerontologist* 49(3):388; PMC8392352).

## 7. Cross-cutting suppression rules

1. **Idiom denylist (highest precedence).** A small set of fixed idioms
   — `killing me`, `to death`, `dead tired`, `death of me`, `killing
   time`, `kill time`, `dressed to kill`, `scared/bored/worried/sick to
   death`, `drop dead gorgeous`, `dead on my feet` — suppress any L1/L3
   match they overlap. Checked **before** L1.
2. **Negation guard.** A first-person risk phrase immediately preceded
   (within ~3 tokens) by `not`, `n't`, `never`, `wouldn't`, `don't`,
   `isn't`, or `not like` → suppressed. Catches "*I'm not suicidal*",
   "*I would never hurt myself*", "*it's not that I want to die*". This is
   a coarse heuristic, not real negation scope analysis — limitation §8.
3. **Reported-speech handling (DECISION 3, FINAL — structural, not
   household-only, not lexical-possessive).** The signal is *first-person
   knowledge of a SPECIFIC NAMED third party's active method/plan/intent*.
   Possessive (`my`/`our`) is **optional**. Two trigger families:
   - **(a)** `[det?] relation_noun (said|told|wrote|texted|messaged|
     called|sent) … (active method)` — fires for "my sister said she
     wants to kill herself" **and** "friend told me she wants to shoot
     herself".
   - **(b)** `[det?] relation_noun (wants to|going to|gonna|planning to|
     threatened to|tried to|about to|keeps saying he/she'll) (active
     method)` — fires for "boyfriend wants to shoot himself".
   - `relation_noun` ::= friend, brother, sister, mom/mum, dad, mother,
     father, husband, wife, partner, son, daughter, parent, sibling,
     child, kid, boyfriend, girlfriend, spouse, family member, cousin,
     aunt, uncle.
   - **Vetoes (→ none):** media/news (`I read/saw/heard about`, `in the
     news`, `on the show`, `the radio said`, `a character`, `a man/
     woman`), generic/plural (`friends/people/everyone are/keep saying`),
     no-personal-connection / distance (`a guy at the hospital said`,
     `someone I worked with once told me`).
   - **Carve-out:** reported speech **demotes only L2/L3-class content**
     (passive ideation, burden — "*my mother keeps saying she wishes she
     were dead*" → none, no active-method token). It does **NOT** demote
     L1 active method/plan/means: the crisis screen routes to 988-class
     helplines that explicitly serve concerned family members, so a
     specific named relation + active method → **ACUTE**. The §6 row
     "*my sister said she wants to kill herself*" is corrected to ACUTE.
   - Regex token scoping (relation list, verb sets, veto phrases) is an
     implementation detail; the principle is the structural rule above.

## 8. Limitations (explicit)

1. **English only.** All patterns, idioms, contractions, and the
   self-vs-other subject test are English. This version does **not**
   handle other languages, transliteration, or code-switching. A
   non-English situation will almost always fall through to `none`. This
   must be stated to reviewers as a scope boundary, not a bug.
2. **Lexical, not semantic.** Regex cannot do coreference, sarcasm,
   irony, conditional/hypothetical mood, or true negation scope.
   Documented consequences:
   - "*she'd be better off without me [around to nag her]*" → mis-fires
     HIGH (elimination arm; no way to tell death-framing from relational
     guilt lexically). Tracked by an explicit test asserting the
     intentional behavior.
   - "*if I were a worse person I'd have given up by now*" → may mis-fire.
   - Negation guard is proximity-based and, by the §4.1 carve-out
     (DECISION 5), deliberately does **not** scope L2-self. Consequence:
     "*I don't think anyone would say I'm a burden*" mis-fires — but now
     at **MEDIUM**, not HIGH (Decision 5 lowers this cost; session
     continues). Intentional and tracked by a test.
   - The §4.1 L2-self negation carve-out itself is a deliberate over-flag
     of non-suicidal guilt at MEDIUM (it keeps "I don't want to be a
     burden" as the canonical disclosure rather than a denial).
   - Reported speech: DECISION 3 makes active-method/plan content survive
     reported framing (specific named relation → ACUTE). Passive
     L2/L3-class reported content is still demoted via a small cue list;
     "*my mother keeps saying she wishes she were dead*" → none (patient's
     passive ideation surfaced through the caregiver — not the caregiver's
     own risk; documented accepted behavior). Pronoun-only reported speech
     with imminent active method (e.g. "*she said he's going to overdose
     tonight*") is caught by L1.d (timeline+method co-occurrence) → ACUTE,
     which is the conservative outcome.
3. **Screening pre-filter, not a diagnostic instrument.** It deliberately
   trades recall/precision for determinism, auditability, and zero
   latency (architecture.md §Safety). It is one of three safety surfaces;
   it is not the whole safety story.
4. **Misspellings / obfuscation.** `kms` and `unalive (myself)` ARE
   covered at MEDIUM (DECISION 4, §5a). `sewerslide`, leetspeak, and other
   misspellings remain **not** covered in this version.
5. **No severity within a layer.** L1 cannot distinguish "*I have a loaded
   gun and a time*" from "*sometimes I think about overdosing*"; both are
   ACUTE. That is acceptable given routing collapses HIGH/ACUTE to the
   same screen, but reviewers should know the layer is coarse.

## 9. Resolved decisions (was: open questions)

All §9 questions are RESOLVED by project-lead sign-off; two further
refinements (Decisions 3 & 5) were added during plan review.

1. **L1.e weak signals — RESOLVED → DECISION 1.** `getting my affairs in
   order` and `giving away my things/possessions` REMOVED entirely (§3
   L1.e; population-specific reasoning).
2. **`don't want to be alive` / `cut myself` — RESOLVED → DECISION 2.**
   `don't want to be alive` → ACUTE unconditionally; `cut myself` → ACUTE
   only with an actuality marker (§3 L1.b note).
3. **Reported speech with active method — RESOLVED → DECISION 3.**
   Structural first-person-knowledge-of-specific-named-relation rule;
   active method survives reported framing → ACUTE; media/generic/distance
   vetoed (§7.3). §6 "sister" row corrected to ACUTE.
4. **Obfuscation set — RESOLVED → DECISION 4.** `kms` / `unalive (myself)`
   INCLUDED at MEDIUM (§5a); `sewerslide` out of scope.
5. **Continue-marker / system-prompt placeholders** — confirmed no
   coupling (classifier runs before any model call).
6. **L2-self tiering — RESOLVED → DECISION 5.** Split into bare
   burdensomeness → MEDIUM and burdensomeness + self-elimination → HIGH
   (§4); population-specific reasoning; §4.1 negation carve-out on both
   self arms.

All §3–§7 / §9 items are signed off; the classifier is **authored**.
Further changes to classifier logic, regex tables, thresholds, or
suppression rules require **explicit project-lead domain-review approval
recorded in the PR** (CLAUDE.md Hard Rule #5).

## 10. Sources

Clinical instruments — primary:

- C-SSRS Risk Assessment (Posner, Brent, Lucas, Gould, Stanley, Brown,
  Fisher, Zelazny, Burke, Oquendo & Mann; © 2008 Research Foundation for
  Mental Hygiene), National Suicide Prevention Lifeline / SAMHSA version
  1/2014 — <https://988lifeline.org/wp-content/uploads/2016/09/Suicide-Risk-Assessment-C-SSRS-Lifeline-Version-2014.pdf>
- The Columbia Lighthouse Project (C-SSRS, about the scale) —
  <https://cssrs.columbia.edu/the-columbia-scale-c-ssrs/about-the-scale/>
- Comprehensive Suicide Risk Assessment Sample Template (CPI module;
  C-SSRS Q1–Q7 verbatim + preparatory-behavior examples), NYASSC /
  preventsuicideny — <https://www.preventsuicideny.org/wp-content/uploads/2021/08/Sample-Suicide-Risk-Assessment.pdf>
- NIMH Ask Suicide-Screening Questions (ASQ) Toolkit — screening tool —
  <https://www.nimh.nih.gov/research/research-conducted-at-nimh/asq-toolkit-materials/asq-tool/asq-screening-tool>
  ; item wording cross-checked at <https://fpnotebook.com/Psych/Exam/AskScdScrngQstns.htm>
- PHQ-9 (item 9 wording) — PHQ-9 calculator, MDCalc
  <https://www.mdcalc.com/calc/1725/phq9-patient-health-questionnaire9>
  ; BC Guidelines PHQ-9 <https://www2.gov.bc.ca/assets/gov/health/practitioner-pro/bc-guidelines/depression_patient_health_questionnaire.pdf>
- SAMHSA SAFE-T (Suicide Assessment Five-Step Evaluation and Triage),
  PEP24-01-036 — <https://library.samhsa.gov/product/safe-t-suicide-assessment-five-step-evaluation-and-triage/pep24-01-036>
- University of Washington Psychiatry Consultation Line — Suicide Risk
  Assessment — <https://pcl.psychiatry.uw.edu/suicide-risk-assessment/>

Lethal means:

- Harvard T.H. Chan School of Public Health — *Means Matter* / Lethal
  Means Counseling — <https://hsph.harvard.edu/research/means-matter/lethal-means-counseling/>
- CALM: Counseling on Access to Lethal Means — Suicide Prevention
  Resource Center — <https://sprc.org/resources/calm-counseling-on-access-to-lethal-means/>
- Lethal Means Safety — Zero Suicide —
  <https://zerosuicide.edc.org/toolkit/engage/lethal-means-safety>

Interpersonal Theory of Suicide / perceived burdensomeness (L2 basis):

- Van Orden, Witte, Gordon, Bender & Joiner — Main predictions of the
  interpersonal-psychological theory (perceived burdensomeness definition;
  Suicide Probability Scale burdensomeness items) —
  <https://pmc.ncbi.nlm.nih.gov/articles/PMC2846517/>
- Van Orden, Cukrowicz, Witte & Joiner — Interpersonal Needs
  Questionnaire: construct validity & psychometrics (INQ item wording) —
  <https://pmc.ncbi.nlm.nih.gov/articles/PMC3377972/>
- Chu et al. — The Interpersonal Theory of Suicide: systematic review &
  meta-analysis — <https://pmc.ncbi.nlm.nih.gov/articles/PMC5730496/>
- Interpersonal theory of suicide (overview) —
  <https://en.wikipedia.org/wiki/Interpersonal_theory_of_suicide>

Caregiver anticipatory grief / death-wish-toward-patient (L2 LOW basis,
negative-case catalogue):

- HopeHealth — Grieving before a death: anticipatory grief and dementia
  caregivers — <https://www.hopehealthco.org/blog/grieving-before-a-death-anticipatory-grief-and-dementia-caregivers/>
- Lindauer & Harvath — Anticipatory grief in new family caregivers of
  persons with MCI and dementia — <https://pmc.ncbi.nlm.nih.gov/articles/PMC3251637/>
- Holley & Mast — Impact of anticipatory grief on caregiver burden in
  dementia caregivers, *The Gerontologist* 49(3):388 —
  <https://academic.oup.com/gerontologist/article/49/3/388/753098>
- Alzheimer's disease caregiver characteristics & anticipatory grief —
  <https://pmc.ncbi.nlm.nih.gov/articles/PMC8392352/>
</content>
</invoke>
