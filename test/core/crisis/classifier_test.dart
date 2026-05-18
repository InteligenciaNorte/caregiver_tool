import 'package:caregiver_tool/core/crisis/classifier.dart';
import 'package:caregiver_tool/core/crisis/risk_level.dart';
import 'package:flutter_test/flutter_test.dart';

// Behavioral matrix for the deterministic crisis classifier. Grouped by
// layer. Negative-venting lookalikes matter as much as positives — they
// are the documented "normal caregiver venting" failure mode
// (docs/classifier_research.md §6). Decisions 1–5 are project-lead
// resolutions folded into the spec.
void _expect(String input, RiskLevel level) =>
    expect(classify(input), level, reason: input);

void main() {
  group('normalization & empty', () {
    test('empty / whitespace -> none', () {
      _expect('', RiskLevel.none);
      _expect('   ', RiskLevel.none);
      _expect('\n\t  \n', RiskLevel.none);
    });
    test('smart apostrophe normalizes', () {
      _expect('I’m exhausted', RiskLevel.none);
    });
    test('whitespace collapses; bare "tired" is not ideation', () {
      _expect('I    am   so   tired', RiskLevel.none);
    });
    test('smoke-test regression input stays none (keeps GoSession)', () {
      _expect('I snapped at mom today.', RiskLevel.none);
    });
    test('ReDoS guard: pathological long input returns fast', () {
      final long = 'spaghetti dinner and laundry ' * 250; // ~7250 chars
      _expect(long, RiskLevel.none);
    });
  });

  group('L1.a direct self-kill -> acute', () {
    test('positives', () {
      _expect('I want to kill myself', RiskLevel.acute);
      _expect('I’ve been thinking about killing myself', RiskLevel.acute);
      _expect('I just want to end my life', RiskLevel.acute);
      _expect('I’m going to take my own life', RiskLevel.acute);
      _expect('I want to end it all', RiskLevel.acute);
      _expect('I’m going to commit suicide', RiskLevel.acute);
      _expect('I feel suicidal', RiskLevel.acute);
      _expect('honestly I’m suicidal lately', RiskLevel.acute);
    });
    test('venting lookalikes -> none', () {
      _expect('this job is killing me', RiskLevel.none);
      _expect('she’s killing me', RiskLevel.none);
      _expect('he’ll be the death of me', RiskLevel.none);
      _expect('I could kill him', RiskLevel.none);
      _expect('I could just kill her sometimes', RiskLevel.none);
      _expect('killing time until the nurse comes', RiskLevel.none);
      _expect('dressed to kill', RiskLevel.none);
      _expect('I’m losing my mind', RiskLevel.none);
      _expect('I’m not suicidal', RiskLevel.none);
      _expect('I would never hurt myself', RiskLevel.none);
    });
  });

  group('L1.a′ don’t-want-to-be-alive -> acute (Decision 2)', () {
    test('positives', () {
      _expect('I don’t want to be alive', RiskLevel.acute);
      _expect('I don’t want to be alive anymore', RiskLevel.acute);
      _expect('sometimes I just don’t want to live anymore', RiskLevel.acute);
      _expect('I don’t want to exist', RiskLevel.acute);
    });
    test('circumstance / generic -> none', () {
      _expect('I don’t want to live like this', RiskLevel.none);
      _expect('I don’t want to do this anymore', RiskLevel.none);
    });
  });

  group('L1.b method / means -> acute', () {
    test('positives', () {
      _expect('I’m going to shoot myself', RiskLevel.acute);
      _expect(
          'I have a gun and I’m going to use it on myself', RiskLevel.acute);
      _expect('I could just overdose', RiskLevel.acute);
      _expect('I’ve been thinking about taking all my pills', RiskLevel.acute);
      _expect('I want to hang myself', RiskLevel.acute);
      _expect('I think about slitting my wrists', RiskLevel.acute);
      _expect('I could jump off the bridge', RiskLevel.acute);
      _expect('I think about driving with the car running in the garage',
          RiskLevel.acute);
      _expect('I want to drown myself', RiskLevel.acute);
    });
    test('method lookalikes -> none', () {
      _expect('the noise is killing me', RiskLevel.none);
      _expect('shoot, I forgot her meds', RiskLevel.none);
      _expect('I jumped when the phone rang', RiskLevel.none);
      _expect('she takes a lot of pills', RiskLevel.none);
      _expect('I could just scream', RiskLevel.none);
      _expect('I’m drowning in laundry', RiskLevel.none);
      _expect('I feel like I’m suffocating in this house', RiskLevel.none);
      _expect('I’m buried in paperwork', RiskLevel.none);
    });
  });

  group('L1.b′ cut-myself actuality marker (Decision 2)', () {
    test('actuality positives -> acute', () {
      _expect('I’m cutting myself', RiskLevel.acute);
      _expect('I’ve been cutting myself again', RiskLevel.acute);
      _expect('I cut myself tonight', RiskLevel.acute);
      _expect('I cut myself again', RiskLevel.acute);
      _expect('I cut myself just now', RiskLevel.acute);
      _expect('I cut myself this morning', RiskLevel.acute);
      _expect('I cut myself right now', RiskLevel.acute);
      _expect('I cut my wrists earlier', RiskLevel.acute);
    });
    test('historical / accidental / bare -> none', () {
      _expect('when I was 17 I cut myself', RiskLevel.none);
      _expect('I used to cut myself in high school', RiskLevel.none);
      _expect('I cut myself shaving', RiskLevel.none);
      _expect('I cut myself chopping onions', RiskLevel.none);
      _expect('I cut myself on a can', RiskLevel.none);
      _expect('I cut myself by accident in the kitchen', RiskLevel.none);
      _expect('I cut myself', RiskLevel.none);
    });
  });

  group('L1.c plan + L1.d timeline -> acute', () {
    test('plan positives', () {
      _expect('I have a plan to kill myself', RiskLevel.acute);
      _expect('I’ve worked out how I’ll end it', RiskLevel.acute);
      _expect('I’ve decided how I’ll end my life', RiskLevel.acute);
    });
    test('plan negatives -> none', () {
      _expect('my plan is to get her to daycare by 9', RiskLevel.none);
      _expect('I worked out a schedule for his meds', RiskLevel.none);
      _expect('I have a plan for respite this weekend', RiskLevel.none);
    });
    test('timeline positives', () {
      _expect('I’m going to kill myself tonight', RiskLevel.acute);
      _expect('I’m going to overdose after she falls asleep', RiskLevel.acute);
      _expect('I’m ending it this weekend', RiskLevel.acute);
    });
    test('timeline negatives -> none', () {
      _expect('I have to get her to the doctor tonight', RiskLevel.none);
      _expect('I’ll lose my mind by Friday', RiskLevel.none);
      _expect('this weekend is going to be brutal', RiskLevel.none);
      _expect('right now I just need a break', RiskLevel.none);
    });
  });

  group('L1.e preparatory -> acute (Decision 1 removals)', () {
    test('positives', () {
      _expect(
          'I bought a gun last week and I can’t stop thinking about '
          'using it on myself',
          RiskLevel.acute);
      _expect('I’ve been collecting my pills', RiskLevel.acute);
      _expect(
          'I’ve been stockpiling her painkillers for myself', RiskLevel.acute);
      _expect('I wrote a suicide note', RiskLevel.acute);
      _expect('I wrote my will and I’m saying goodbye to everyone',
          RiskLevel.acute);
    });
    test('Decision 1: caregiver admin -> none', () {
      _expect('I’m getting my affairs in order', RiskLevel.none);
      _expect('I need to get my affairs in order before the surgery',
          RiskLevel.none);
      _expect('I’m giving away her old clothes', RiskLevel.none);
      _expect('I gave away mom’s things to the church', RiskLevel.none);
      _expect('I’ve been sorting through dad’s possessions', RiskLevel.none);
      _expect('we bought a gun safe years ago', RiskLevel.none);
    });
  });

  group('L2 self bare-burden -> medium (Decision 5)', () {
    test('bare burdensomeness, negation does not change tier', () {
      _expect('I’m a burden to my kids', RiskLevel.medium);
      _expect('I’m a burden', RiskLevel.medium);
      _expect('I feel like a burden', RiskLevel.medium);
      _expect('I don’t want to be a burden', RiskLevel.medium);
      _expect('I can’t be a burden to them', RiskLevel.medium);
      _expect('I don’t think I’m a burden to my kids', RiskLevel.medium);
    });
  });

  group('L2 self elimination -> high (Decision 5)', () {
    test('burdensomeness + explicit self-elimination', () {
      _expect('they would be better off without me', RiskLevel.high);
      _expect('they’d be better off if I were gone', RiskLevel.high);
      _expect('they’d be better off if I weren’t here', RiskLevel.high);
      _expect('they’d be better off if I didn’t exist', RiskLevel.high);
      _expect('my death would be a relief to them', RiskLevel.high);
      _expect('the world would be better without me', RiskLevel.high);
    });
  });

  group('L2 patient-directed -> low (anticipatory grief)', () {
    test('positives', () {
      _expect('she’s such a burden', RiskLevel.low);
      _expect('caring for him is a burden', RiskLevel.low);
      _expect('taking care of her is too much', RiskLevel.low);
      _expect('I wish she would just die in her sleep', RiskLevel.low);
      _expect('I hope he goes peacefully', RiskLevel.low);
      _expect('I wish she’d pass peacefully', RiskLevel.low);
      _expect('I just want her suffering to end', RiskLevel.low);
      _expect('it would be a relief when she’s gone', RiskLevel.low);
      _expect('she’d be better off at peace', RiskLevel.low);
    });
  });

  group('L2 borderline / mixed', () {
    test('ambiguous -> none', () {
      _expect('we’d all be better off', RiskLevel.none);
      _expect('everyone would be better off', RiskLevel.none);
      _expect('he’d be better off', RiskLevel.none);
    });
    test('documented §8 mis-fire on elimination arm -> high', () {
      _expect('she’d be better off without me to nag her', RiskLevel.high);
    });
    test('mixed text takes the max severity', () {
      _expect('she’s a burden and honestly I wish I weren’t here',
          RiskLevel.medium);
      _expect('she’s a burden and I want to kill myself', RiskLevel.acute);
    });
  });

  group('L3 passive ideation -> medium', () {
    test('paraphrase positives (C-SSRS Q1 / ASQ Q1 / PHQ-9 i9)', () {
      _expect('I wish I was dead', RiskLevel.medium);
      _expect('I wish I were dead', RiskLevel.medium);
      _expect('I wish I wasn’t here', RiskLevel.medium);
      _expect('I wish I could go to sleep and not wake up', RiskLevel.medium);
      _expect('I wish I could just disappear', RiskLevel.medium);
      _expect('I hope I don’t wake up', RiskLevel.medium);
      _expect('I don’t want to wake up', RiskLevel.medium);
      _expect('I’d be better off dead', RiskLevel.medium);
      _expect('I’m better off not alive', RiskLevel.medium);
      _expect('I’m so tired of living', RiskLevel.medium);
      _expect('I’m tired of being alive', RiskLevel.medium);
      _expect('I don’t want to go on anymore', RiskLevel.medium);
      _expect('what’s the point of living', RiskLevel.medium);
      _expect('I can’t see the point anymore', RiskLevel.medium);
    });
    test('negatives -> none / low', () {
      _expect('I’m so tired', RiskLevel.none);
      _expect('I’m exhausted', RiskLevel.none);
      _expect('I need a break', RiskLevel.none);
      _expect('I’m running on empty', RiskLevel.none);
      _expect('I’m burnt out', RiskLevel.none);
      _expect('I can’t do this anymore', RiskLevel.none);
      _expect('I can’t keep going like this', RiskLevel.none);
      _expect('I can’t take it', RiskLevel.none);
      _expect('I wish this would end', RiskLevel.none);
      _expect('I wish it was over', RiskLevel.none);
      _expect('I just want this to be over', RiskLevel.none);
      _expect('I wish she’d go peacefully', RiskLevel.low);
    });
  });

  group('obfuscation -> medium (Decision 4)', () {
    test('online-native positives', () {
      _expect('i want to kms', RiskLevel.medium);
      _expect('wanna unalive myself', RiskLevel.medium);
      _expect('i’m gonna kms', RiskLevel.medium);
      _expect('going to unalive myself', RiskLevel.medium);
      _expect('honestly i might kms at this rate', RiskLevel.medium);
    });
    test('negatives -> none', () {
      _expect('kms is a unit of distance', RiskLevel.none);
      _expect('i would never kms', RiskLevel.none);
      _expect('she said she wants to kms', RiskLevel.none);
    });
  });

  group('negation guard', () {
    test('negated self-risk -> none', () {
      _expect('I would never hurt myself', RiskLevel.none);
      _expect('I’m not suicidal', RiskLevel.none);
      _expect('it’s not like I want to die, I just need rest', RiskLevel.none);
    });
    test('negation-scope limitation now costs only MEDIUM (Decision 5)', () {
      // Coarse proximity negation does not parse "I don't think anyone
      // would say ..."; the bare-burden arm catches "I'm a burden".
      // Tracked limitation, research doc §8 — MEDIUM, not HIGH.
      _expect('I don’t think anyone would say I’m a burden', RiskLevel.medium);
    });
  });

  group('reported speech with active method -> acute (Decision 3)', () {
    test('specific named third party + active method', () {
      _expect('my sister said she wants to kill herself', RiskLevel.acute);
      _expect('friend told me she wants to shoot herself', RiskLevel.acute);
      _expect('boyfriend wants to shoot himself', RiskLevel.acute);
      _expect('my son told me he wants to kill himself', RiskLevel.acute);
      _expect('my husband said he’s going to shoot himself', RiskLevel.acute);
      _expect('she said he’s going to overdose tonight', RiskLevel.acute);
    });
  });

  group('reported speech negatives -> none', () {
    test('media / generic-plural / distance / passive', () {
      _expect('Friends are saying things have gotten worse', RiskLevel.none);
      _expect('I read about a man who shot himself', RiskLevel.none);
      _expect('A character on the show last night said something dark',
          RiskLevel.none);
      _expect('a guy at the hospital said he’d kill himself', RiskLevel.none);
      _expect('someone I worked with once told me she was suicidal',
          RiskLevel.none);
      _expect(
          'my mother keeps saying she wishes she were dead', RiskLevel.none);
      _expect('the doctor said she’s dying', RiskLevel.none);
    });
  });

  group('§6 negative-case catalogue (regression backbone)', () {
    test('idiomatic / venting -> none', () {
      _expect('this is killing me', RiskLevel.none);
      _expect('the death of me', RiskLevel.none);
      _expect('I’m exhausted to death', RiskLevel.none);
      _expect('tired to death', RiskLevel.none);
      _expect('worried to death', RiskLevel.none);
      _expect('bored to death', RiskLevel.none);
      _expect('scared to death', RiskLevel.none);
      _expect('sick to death of this', RiskLevel.none);
      _expect('dead tired', RiskLevel.none);
      _expect('dead on my feet', RiskLevel.none);
      _expect('I could strangle her', RiskLevel.none);
      _expect('I can’t do this anymore', RiskLevel.none);
      _expect('I’ve had it', RiskLevel.none);
      _expect('I’m at my breaking point', RiskLevel.none);
      _expect('I’m at the end of my rope', RiskLevel.none);
      _expect('I’m going crazy', RiskLevel.none);
      _expect('I could just cry', RiskLevel.none);
      _expect('killing time', RiskLevel.none);
      _expect('kill the lights', RiskLevel.none);
      _expect('he’s at the end of life', RiskLevel.none);
      _expect('she’s terminal', RiskLevel.none);
    });
    test('patient-directed wishes -> low', () {
      _expect('I wish she’d pass peacefully', RiskLevel.low);
      _expect('I hope he goes in his sleep', RiskLevel.low);
      _expect('I just want her suffering to end', RiskLevel.low);
      _expect('caring for him is a burden', RiskLevel.low);
    });
  });
}
