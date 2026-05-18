/// Deterministic suicide-risk pre-filter for the caregiver situation text.
///
/// Pure, synchronous, lexical. NOT a diagnostic instrument: it is one of
/// three safety surfaces (this filter, the in-session model behavior, and
/// the always-visible crisis link). It is intentionally simple, auditable,
/// and conservative. English-only; lexical, not semantic.
///
/// Evidence base, citations, the negative-case catalogue, and the documented
/// limitations live in `docs/classifier_research.md`. The five project-lead
/// resolutions folded in here are referenced inline as DECISION 1..5.
///
/// API is locked (see `risk_level.dart`): `RiskLevel classify(String)`.
/// Changing the logic, regex tables, thresholds, or suppression rules
/// requires explicit project-lead domain review (CLAUDE.md Hard Rule #5).
library;

import 'risk_level.dart';

/// Returns the maximum risk level across all layers. Evaluation is
/// scan-all / return-max (`acute > high > medium > low > none`), so the
/// most severe signal in mixed text always wins. Empty / whitespace-only
/// input returns [RiskLevel.none].
RiskLevel classify(String situation) {
  final s = _normalize(situation);
  if (s.isEmpty) return RiskLevel.none;

  var r = RiskLevel.none;
  r = _max(r, _scanL1(s)); // method / means / plan / timeline / prep
  r = _max(r, _scanThirdParty(s)); // reported active method (DECISION 3)
  r = _max(r, _scanL2(s)); // IPTS burden discriminator (DECISION 5 split)
  r = _max(r, _scanL3(s)); // passive ideation
  r = _max(r, _scanObfuscation(s)); // online-native forms (DECISION 4)
  return r;
}

// ── Severity ────────────────────────────────────────────────────────────
// Relies on the RiskLevel enum declaration order
// (none < low < medium < high < acute). A reorder of the locked enum must
// be caught in review.
RiskLevel _max(RiskLevel a, RiskLevel b) => a.index >= b.index ? a : b;

// ── 1. Input normalization ──────────────────────────────────────────────
final RegExp _smartApos = RegExp('[‘’‛′]');
final RegExp _smartQuote = RegExp('[“”″]');
final RegExp _uniDash = RegExp('[‐‑‒–—]');
final RegExp _ws = RegExp(r'\s+');

String _normalize(String raw) {
  if (raw.trim().isEmpty) return '';
  var s = raw
      .replaceAll(_smartApos, "'")
      .replaceAll(_smartQuote, '"')
      .replaceAll(_uniDash, '-')
      .toLowerCase();
  s = s.replaceAll(_ws, ' ').trim();
  // Length cap is a ReDoS guard, not a product limit. A genuine situation
  // is a few sentences; 4000 chars is generous.
  if (s.length > 4000) s = s.substring(0, 4000);
  return s;
}

// ── 2. Span-scoped suppressors ──────────────────────────────────────────
// Suppression is per-match (span overlap / bounded lookbehind), never a
// global text-deletion pre-pass. This is the central correctness
// constraint: in "this job is killing me but I want to kill myself" the
// idiom "killing me" must veto only its own span, leaving the real
// "kill myself" match intact -> ACUTE. (research doc §7)

// Idiom denylist (research doc §7.1). Defense-in-depth: detector patterns
// are already self/reflexive-anchored, so idioms rarely reach them.
final List<RegExp> _idioms = [
  RegExp(r'killing me'),
  RegExp(r'kill(?:ing)? time'),
  RegExp(r'dressed to kill'),
  RegExp(r'\bto death\b'),
  RegExp(r'dead tired'),
  RegExp(r'dead on (?:my|your|his|her) feet'),
  RegExp(r'death of me'),
  RegExp(r'drowning in'),
  RegExp(r'suffocating in'),
  RegExp(r'buried in'),
  RegExp(r'scared to death'),
  RegExp(r'bored to death'),
  RegExp(r'worried to death'),
  RegExp(r'sick to death'),
  RegExp(r'to die for'),
  RegExp(r'dying to'),
];

bool _overlapsIdiom(String s, int start, int end) {
  for (final idiom in _idioms) {
    for (final m in idiom.allMatches(s)) {
      if (m.start < end && start < m.end) return true;
    }
  }
  return false;
}

// Negation guard (research doc §7.2): a negator within ~15 non-boundary
// chars immediately before the match. Coarse proximity heuristic, not real
// scope analysis (documented limitation §8). Does NOT scope L2-self
// (DECISION 5 / §4.1 carve-out) — see _scanL2.
final RegExp _negBefore = RegExp(
  r"\b(?:not|never|no|cannot|wouldn'?t|won'?t|don'?t|doesn'?t|didn'?t|"
  r"isn'?t|wasn'?t|aren'?t|n'?t)\b[^.!?;]{0,15}$",
);

bool _negatedBefore(String s, int start) {
  final from = start - 28 < 0 ? 0 : start - 28;
  return _negBefore.hasMatch(s.substring(from, start));
}

// In-span negation (for obfuscation, where the negator sits between the
// self token and the term, e.g. "i would never kms").
final RegExp _negInSpan = RegExp(r"\b(?:never|not|no|wouldn'?t|don'?t|n'?t)\b");

// ── 3. Self / patient reference ─────────────────────────────────────────
final RegExp _selfRef =
    RegExp(r"\b(?:i|i'?m|im|i'?ve|ive|i'?d|i'?ll|myself|my own|me)\b");

bool _hasSelf(String s) => _selfRef.hasMatch(s);

// Accept a detector match only if it is not idiom-overlapped and not
// negated. [needsSelf] additionally requires a first-person referent
// somewhere in the text (for patterns that do not embed a reflexive).
bool _accept(String s, Match m, {bool needsSelf = false}) {
  if (_overlapsIdiom(s, m.start, m.end)) return false;
  if (_negatedBefore(s, m.start)) return false;
  if (needsSelf && !_hasSelf(s)) return false;
  return true;
}

bool _anyAccepted(String s, RegExp re, {bool needsSelf = false}) {
  for (final m in re.allMatches(s)) {
    if (_accept(s, m, needsSelf: needsSelf)) return true;
  }
  return false;
}

// ── 4. L1 — method / means / plan / timeline / prep -> ACUTE ────────────

// L1.a direct self-kill. C-SSRS Q2–Q5 / ASQ Q3 active-ideation items.
// These embed a reflexive object, so reported third-party speech
// ("kill herself") does not match them — only the user's own act does.
final RegExp _l1aDirect = RegExp(
  r"\b(?:"
  r"kill(?:ing)? my ?self"
  r"|end(?:ing)? (?:my life|my own life|it all)"
  r"|tak(?:e|ing) my (?:own )?life"
  r"|commit(?:ting)? suicide"
  r"|hurt(?:ing)? my ?self"
  r")\b",
);

// L1.a "suicidal" needs tight first-person governance: the bare word
// must not fire on reported third-party speech ("she was suicidal").
// In-span / before negation is checked in _scanL1 ("I'm not suicidal").
final RegExp _l1Suicidal = RegExp(
  r"\b(?:i'?m|i am|i feel|i'?ve been|i'?ve felt|i felt|feeling|i get|"
  r"makes me feel)\b[^\n]{0,10}?suicidal\b",
);

// L1.a' "don't want to be alive" family -> ACUTE (DECISION 2,
// unconditional self-frame).
final RegExp _l1DontWantAlive = RegExp(
  r"don'?t want to (?:be alive|live anymore|exist|be here anymore)\b",
);

// L1.b method / means. Lethal-means taxonomy: Harvard Means Matter / CALM,
// SAMHSA SAFE-T, C-SSRS Q3 ("how you might do this").
final RegExp _l1bMethod = RegExp(
  r"\b(?:"
  r"shoot(?:ing)? my ?self|put a bullet|blow my (?:head|brains)"
  r"|overdos(?:e|ing)|poison(?:ing)? my ?self"
  r"|tak(?:e|ing) (?:all|a bunch of|the whole bottle of|too many|all of |all )"
  r"my? ?(?:pills|meds|medication|painkillers)"
  r"|swallow(?:ing)? [^\n]{0,12}?pills"
  r"|hang(?:ing)? my ?self|noose"
  r"|suffocate my ?self|asphyxiat"
  r"|slit(?:ting)? (?:my )?wrists|cut my wrists"
  r"|jump(?:ing)? (?:off|in front of)|throw(?:ing)? my ?self (?:off|in front of|under)"
  r"|carbon monoxide|car (?:running )?in the garage|exhaust fumes"
  r"|drown(?:ing)? my ?self"
  r")\b",
);

// L1.b firearm in self-harm context (gun within reach of a self-referent).
final RegExp _l1bGunSelf =
    RegExp(r'\bgun\b[^\n]{0,40}?\b(?:on|at|to) my ?self\b');

// L1.b' "cut myself" actuality marker (DECISION 2). The bare phrase,
// historical, and accidental forms MUST NOT fire.
final RegExp _l1CutContinuous = RegExp(
  r"(?:i'?m |i am |i'?ve |ive |been )?cutting my ?(?:self|wrists?|arms?|legs?)",
);
final RegExp _l1CutRecent = RegExp(
  r"cut my ?(?:self|wrists?|arms?|legs?) "
  r"(?:tonight|today|just now|right now|this morning|this afternoon|"
  r"this evening|earlier|again)",
);
final RegExp _l1CutHistAccident = RegExp(
  r"(?:when i was \d+|years? ago|back (?:in|when)|as a (?:teen|kid|child)|"
  r"used to|in (?:high school|college)|shaving|chopping|cooking|"
  r"on (?:a|the|some) \w+|with a knife|in the kitchen|by accident|accidentally)",
);

// L1.c plan, only in co-occurrence with a self-harm object. C-SSRS Q5.
final RegExp _l1cPlan = RegExp(
  r"\b(?:i have a plan|my plan is|i'?ve worked out (?:how|the details)|"
  r"i figured out how|i'?ve decided how|"
  r"i (?:know|decided) (?:how|when) i(?:'?ll| will| would| am going to))\b",
);
final RegExp _l1cSelfHarmObject = RegExp(
  r"\b(?:kill (?:my ?self|me)|suicide|overdose|hang my ?self|shoot my ?self|"
  r"jump off|end (?:my life|it all)|i(?:'?ll| will| am going to|'?m going to) "
  r"end it|take all my pills)\b",
);

// L1.d timeline / imminence, only in co-occurrence with self-harm. SAFE-T
// "plan's imminence (plan to act in the near future)".
final RegExp _l1dTimeline = RegExp(
  r"\b(?:tonight|today|right now|this (?:morning|afternoon|evening|weekend)|"
  r"by (?:tonight|tomorrow|friday|the weekend|then)|"
  r"after (?:she|he|they|mom|mum|dad) (?:falls?|are|is) asleep|"
  r"before (?:she|he|they|mom|mum|dad) (?:wakes|gets|comes))\b",
);
final RegExp _l1dSelfHarm = RegExp(
  r"\b(?:kill my ?self|end (?:my life|it all|it)|ending it|overdose|"
  r"hang my ?self|shoot my ?self|suicide|jump off)\b",
);

// L1.e preparatory acts. C-SSRS Q6 ("collecting/buying pills, purchasing a
// gun, saying goodbye, writing a will or suicide note"). DECISION 1:
// "getting my affairs in order" and "giving away my things/possessions"
// are REMOVED — in a dementia-caregiver population these describe normal
// anticipatory-grief administration (handling the parent's affairs,
// sorting their belongings); false-positive rate is unacceptable and the
// cost (a crisis wall instead of the support module) is the most
// expensive non-acute error.
final RegExp _l1eSuicideNote = RegExp(r"wrote (?:a |my )?suicide note");
final RegExp _l1eCollectPills = RegExp(
  r"(?:been )?(?:collect\w+|saving(?: up)?|stockpil\w+|hoard\w+) "
  r"[^\n]{0,20}?(?:pills|meds|medication|painkillers)",
);
final RegExp _l1eGun = RegExp(r"(?:bought|got|have|own|purchas\w+) (?:a )?gun");
final RegExp _l1eWill = RegExp(r"wrote (?:a |my )?will");
final RegExp _l1eGoodbye = RegExp(r"saying goodbye");
final RegExp _l1eSelfHarmCtx = RegExp(
  r"\b(?:my ?self|kill|suicide|end my life|overdose|my own life|"
  r"don'?t want to (?:live|be alive))\b",
);

RiskLevel _scanL1(String s) {
  // a / a' / b — patterns embed a reflexive; the self gate is a safety net.
  if (_anyAccepted(s, _l1aDirect, needsSelf: true)) return RiskLevel.acute;
  // "suicidal": first-person governed; in-span negation guards
  // "I'm not suicidal" (the negator sits inside the matched span).
  for (final m in _l1Suicidal.allMatches(s)) {
    final span = s.substring(m.start, m.end);
    if (_negInSpan.hasMatch(span)) continue;
    if (_negatedBefore(s, m.start)) continue;
    return RiskLevel.acute;
  }
  if (_anyAccepted(s, _l1DontWantAlive)) return RiskLevel.acute;
  if (_anyAccepted(s, _l1bMethod, needsSelf: true)) return RiskLevel.acute;
  if (_anyAccepted(s, _l1bGunSelf)) return RiskLevel.acute;

  // b' cut-myself: acceptor + historical/accidental veto (DECISION 2).
  final hist = _l1CutHistAccident.hasMatch(s);
  for (final m in _l1CutContinuous.allMatches(s)) {
    if (_accept(s, m) && !hist) return RiskLevel.acute;
  }
  for (final m in _l1CutRecent.allMatches(s)) {
    if (_accept(s, m) && !hist) return RiskLevel.acute;
  }

  // c plan + self-harm object co-occurrence.
  if (_l1cPlan.hasMatch(s) && _l1cSelfHarmObject.hasMatch(s)) {
    return RiskLevel.acute;
  }

  // d timeline + self-harm co-occurrence.
  if (_l1dTimeline.hasMatch(s) && _l1dSelfHarm.hasMatch(s)) {
    return RiskLevel.acute;
  }

  // e preparatory acts.
  if (_anyAccepted(s, _l1eSuicideNote)) return RiskLevel.acute;
  if (_anyAccepted(s, _l1eCollectPills)) return RiskLevel.acute;
  final ctx = _l1eSelfHarmCtx.hasMatch(s);
  // gun / will / goodbye need a self-harm context OR a second distinct
  // preparatory signal (two prep acts co-occurring).
  final prep = <bool>[
    _l1eGun.hasMatch(s),
    _l1eWill.hasMatch(s),
    _l1eGoodbye.hasMatch(s),
  ];
  final prepCount = prep.where((b) => b).length;
  if ((prep[0] || prep[1] || prep[2]) && (ctx || prepCount >= 2)) {
    return RiskLevel.acute;
  }
  return RiskLevel.none;
}

// ── 5. Reported third-party active method -> ACUTE (DECISION 3) ──────────
// Structural signal: first-person knowledge of a SPECIFIC NAMED third
// party's active method/plan/intent. Possessive is OPTIONAL. The crisis
// screen routes to 988-class helplines that explicitly serve concerned
// family members, so this is NOT demoted like passive reported speech.
// Passive third-party content ("my mother keeps saying she wishes she
// were dead") carries no active-method token T and falls through.

// relation_noun (possessive optional) and active third-party
// method/plan/intent (third-person reflexive) are inlined into each
// pattern below to keep them single raw strings.

// (a) [det?] relation (said|told|...) ... active method
final RegExp _tpReported = RegExp(
  r'(?:my |our |a |the )?'
  r'(?:friend|brother|sister|mom|mum|dad|mother|father|husband|wife|'
  r'partner|son|daughter|parent|sibling|child|kid|boyfriend|girlfriend|'
  r'spouse|family member|cousin|aunt|uncle)'
  r' (?:said|told|wrote|texted|messaged|called|sent) [^\n]{0,40}?'
  r'(?:kill (?:himself|herself|themsel\w+|themself)|'
  r'shoot (?:himself|herself|themsel\w+)|'
  r'hang (?:himself|herself|themsel\w+)|overdos\w+|'
  r'end (?:his|her|their) (?:own )?life|hurt (?:himself|herself)|'
  r'suicid\w+|jump off|take (?:his|her|their) (?:own )?life)',
);
// (b) [det?] relation (wants to|going to|...) active method
final RegExp _tpIntent = RegExp(
  r'(?:my |our |a |the )?'
  r'(?:friend|brother|sister|mom|mum|dad|mother|father|husband|wife|'
  r'partner|son|daughter|parent|sibling|child|kid|boyfriend|girlfriend|'
  r'spouse|family member|cousin|aunt|uncle)'
  r" (?:wants? to|wanna|going to|gonna|planning to|threatened to|"
  r"tried to|about to|keeps saying (?:he|she)(?:'?ll| will)) [^\n]{0,30}?"
  r'(?:kill (?:himself|herself|themsel\w+|themself)|'
  r'shoot (?:himself|herself|themsel\w+)|'
  r'hang (?:himself|herself|themsel\w+)|overdos\w+|'
  r'end (?:his|her|their) (?:own )?life|hurt (?:himself|herself)|'
  r'suicid\w+|jump off|take (?:his|her|their) (?:own )?life)',
);

// Vetoes: media/news, generic/plural, no-personal-connection / distance.
final RegExp _tpVeto = RegExp(
  r'\b(?:'
  r'i (?:read|saw|heard) (?:about|in|on)|in the (?:news|paper)|'
  r'on (?:the )?(?:show|tv|radio|news|tiktok|youtube|the internet)|'
  r'the (?:radio|news|tv|paper) said|\barticle\b|story about|'
  r'a (?:character|man|woman|guy|girl|lady|person)\b|'
  r'(?:friends|people|everyone|they all|folks|relatives) '
  r'(?:are |keep )?(?:saying|talking|say)\b|'
  r'someone i (?:worked with|knew|met|used to)|'
  r'a (?:guy|man|woman|person|girl|lady) (?:at|from|i (?:used to|once))'
  r')',
);

RiskLevel _scanThirdParty(String s) {
  if (_tpVeto.hasMatch(s)) return RiskLevel.none;
  if (_tpReported.hasMatch(s) || _tpIntent.hasMatch(s)) {
    return RiskLevel.acute;
  }
  return RiskLevel.none;
}

// ── 6. L2 — IPTS subject-of-burden discriminator (DECISION 5 split) ──────
// Grounded in Joiner's Interpersonal Theory of Suicide (perceived
// burdensomeness; INQ / Suicide Probability Scale item phrasings) and the
// dementia-caregiver anticipatory-grief literature.
//
// DECISION 5: bare perceived-burdensomeness cognition (high base rate of
// NON-suicidal caregiver guilt / anticipatory anxiety in this population)
// -> MEDIUM (session continues, helpline pinned). Burdensomeness PLUS an
// explicit first-person self-elimination link -> HIGH (crisis wall).
// Patient-directed framing -> LOW (anticipatory grief; session runs).
// §4.1 carve-out: the negation guard does NOT scope either L2-self arm
// ("I don't want to be a burden" stays MEDIUM — negation does not change
// tier and does not suppress).

// HIGH — burdensomeness + explicit self-elimination.
final RegExp _l2Elimination = RegExp(
  r"\b(?:"
  r"(?:they|everyone|my (?:kids|children|family|husband|wife|son|daughter|"
  r"parents)|he|she|the kids)(?:'?d| would| will| would all)(?: all)? be "
  r"better off (?:without me|if i (?:was|were|wasn'?t|weren'?t|didn'?t)? ?"
  r"(?:gone|dead|not here|not around|here|exist)|when i'?m gone)"
  r"|(?:no one|nobody) (?:would|'?d) (?:miss me|even notice|care if i)"
  r"|(?:they|everyone|my family) (?:wouldn'?t|would not) miss me"
  r"|my death would be (?:a relief|better) (?:to|for) "
  r"(?:them|everyone|my family|my kids)"
  r"|the world would be better(?: off)? without me"
  r"|(?:they|my family|everyone) deserves? better than me"
  r"|i'?m worth more (?:to them )?(?:gone|dead)"
  r")\b",
);

// MEDIUM — bare perceived burdensomeness, no elimination link.
final RegExp _l2BareBurden = RegExp(
  r"\b(?:"
  r"i'?m (?:a |such a |just a |nothing but a )?burden"
  r"|i am (?:a |such a |just a )?burden"
  r"|i feel (?:like )?(?:i'?m )?(?:a )?burden"
  r"|i (?:can'?t|cannot|don'?t want to|hate) (?:be|being) (?:a |such a )?burden"
  r"|i'?m (?:dragging|weighing|holding) (?:them|everyone|my family|my kids) down"
  r")\b",
);

// LOW — patient-directed burden / death wish (anticipatory grief).
// Situation-directed phrasing ("I just want this to be over", "I wish
// this would end") is deliberately NOT here — it stays NONE (research
// doc §5): only a patient subject or a patient-suffering object qualifies.
final RegExp _l2Patient = RegExp(
  r"(?:she|he|mom|mum|dad|mother|father|grandma|grandpa|the patient|"
  r"my (?:mother|father|husband|wife|mom|mum|dad|parent|loved one))"
  r"(?:'?s| is| has become| is such|'?s such)? (?:a |such a )?burden"
  r"|(?:taking care of|caring for) (?:her|him|them|mom|mum|dad|my \w+) "
  r"is (?:a burden|too much|killing me)"
  r"|i (?:just )?(?:wish|hope|sometimes wish|just want) "
  r"(?:she|he|they|mom|mum|dad|her|him)(?:'?d| would| to)? "
  r"(?:would |to |would just |to just |just )?"
  r"(?:die|pass(?: away| peacefully| in (?:her|his) sleep)?|go(?:es)?|"
  r"were gone|was gone|be at peace)"
  r"|it would be a relief when (?:she|he|they)(?:'?s| is| are)? "
  r"(?:gone|at peace)"
  r"|(?:she|he)(?:'?d| would) be better off (?:dead|gone|at peace|not suffering)"
  r"|i just want (?:her suffering|his pain|the suffering|her pain|"
  r"his suffering) to (?:be over|end|stop)",
);

RiskLevel _scanL2(String s) {
  // No negation/idiom suppression on L2-self (DECISION 5 / §4.1 carve-out).
  var r = RiskLevel.none;
  if (_l2Elimination.hasMatch(s)) r = _max(r, RiskLevel.high);
  if (_l2BareBurden.hasMatch(s)) r = _max(r, RiskLevel.medium);
  if (_l2Patient.hasMatch(s)) r = _max(r, RiskLevel.low);
  return r;
}

// ── 7. L3 — passive ideation -> MEDIUM ──────────────────────────────────
// Paraphrases the C-SSRS Q1 / ASQ Q1 / PHQ-9 item 9 concept (wish to be
// dead, without active intent or method). Self-referent gated; negation
// and idiom suppression apply (MEDIUM is cheap — session still runs).
final RegExp _l3Passive = RegExp(
  r"\b(?:"
  r"i wish i (?:was|were) dead"
  r"|i wish i (?:wasn'?t|weren'?t) (?:here|alive)"
  r"|i wish i (?:could |would )?(?:just )?(?:go to sleep and not wake up|"
  r"not wake up|never wake up|disappear|vanish|not exist|stop existing)"
  r"|i (?:hope|wish) i (?:don'?t|do not|never) wake up"
  r"|i don'?t want to wake up"
  r"|(?:i'?d|i would) be better off dead"
  r"|i'?m better off (?:not alive|dead|not here)"
  r"|i'?m (?:so )?tired of (?:living|being alive|life)"
  r"|i don'?t want to (?:be here|go on|keep going|live) anymore"
  r"|what'?s the point of (?:living|going on|me being here|me)"
  r"|i can'?t see the point anymore"
  r")\b",
);

RiskLevel _scanL3(String s) =>
    _anyAccepted(s, _l3Passive) ? RiskLevel.medium : RiskLevel.none;

// ── 8. Obfuscation / online-native forms -> MEDIUM (DECISION 4) ──────────
// TikTok-era / online-native self-harm euphemisms, included for the
// younger adult caregiver demographic (~35–50). MEDIUM (not ACUTE): the
// session continues with the helpline pinned, so hyperbolic/online-native
// use is not walled off while genuine disclosures still surface help.
// "sewerslide" / leetspeak remain out of scope (limitation §8).
final RegExp _obfKms =
    RegExp(r"\bi(?:'?m|'?ll| am| will)?\b[^\n]{0,18}?\bkms\b");
final RegExp _obfUnalive = RegExp(r'\bunalive (?:myself|me)\b');

RiskLevel _scanObfuscation(String s) {
  for (final m in _obfKms.allMatches(s)) {
    final span = s.substring(m.start, m.end);
    if (_negInSpan.hasMatch(span)) continue; // "i would never kms"
    if (_negatedBefore(s, m.start)) continue;
    return RiskLevel.medium;
  }
  for (final m in _obfUnalive.allMatches(s)) {
    if (_negatedBefore(s, m.start)) continue;
    return RiskLevel.medium;
  }
  return RiskLevel.none;
}
