import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'classifier.dart';
import 'risk_level.dart';

/// The locked classifier signature. The ML engineer's future
/// `lib/core/crisis/classifier.dart` will expose a top-level
/// `RiskLevel classify(String situation)` matching this exactly.
typedef Classify = RiskLevel Function(String situation);

/// Where the app should go after classifying the user's situation.
/// Risk-to-route policy is a UI decision and lives here, not in the
/// classifier (per architecture.md "routing is purely a UI decision").
sealed class CrisisRoute {}

final class GoSession extends CrisisRoute {}

final class GoCrisis extends CrisisRoute {}

CrisisRoute routeFor(RiskLevel level) => switch (level) {
      RiskLevel.none || RiskLevel.low || RiskLevel.medium => GoSession(),
      RiskLevel.high || RiskLevel.acute => GoCrisis(),
    };

/// The classifier seam. `classifier.dart` is now authored; this binds the
/// real `classify`. The [Classify] typedef documents the locked signature.
final classifyProvider = Provider<Classify>((ref) => classify);

/// Call sites use this: `ref.read(crisisRouterProvider)(situationText)`
/// returns a [CrisisRoute] to switch on.
final crisisRouterProvider = Provider<CrisisRoute Function(String)>((ref) {
  final classify = ref.watch(classifyProvider);
  return (situation) => routeFor(classify(situation));
});
