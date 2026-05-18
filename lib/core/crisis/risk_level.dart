/// Risk levels produced by the deterministic crisis classifier.
///
/// This file intentionally has zero imports. Both the UI-side router
/// (`crisis_router.dart`) and the future ML-owned `classifier.dart` depend
/// on this leaf so neither depends on the other.
enum RiskLevel { none, low, medium, high, acute }
