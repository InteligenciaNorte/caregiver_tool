import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crisis/risk_level.dart';

/// In-memory state for the current witness session. Intentionally tiny:
/// the only thing it needs today is the risk the situation was classified
/// at, so the session shell can pin the MEDIUM helpline card on every step
/// (architecture.md §Safety). This is the seam the later step state
/// machine extends; nothing here is persisted (Hard Rule #3).
class SessionState {
  const SessionState({this.risk = RiskLevel.none});

  final RiskLevel risk;

  /// MEDIUM runs a normal session but with the helpline card pinned.
  bool get showHelplineCard => risk == RiskLevel.medium;

  SessionState copyWith({RiskLevel? risk}) =>
      SessionState(risk: risk ?? this.risk);
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(const SessionState());

  /// Called once at the Home → session transition with the classified
  /// level. Always set (not merged) so a prior session can't leak its
  /// risk into the next one.
  void start(RiskLevel risk) => state = SessionState(risk: risk);
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>(
  (ref) => SessionNotifier(),
);
