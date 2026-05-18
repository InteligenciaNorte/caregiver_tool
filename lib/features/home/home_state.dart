import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeState {
  final String situationText;
  const HomeState({this.situationText = ''});
  HomeState copyWith({String? situationText}) =>
      HomeState(situationText: situationText ?? this.situationText);
}

class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier() : super(const HomeState());

  void setSituation(String text) => state = state.copyWith(situationText: text);

  /// Wipe the typed situation. Called when a session ends so returning to
  /// Home is a fresh start — architecture.md §Privacy: the typed situation
  /// "is gone when the session ends or the app closes". (Nothing was ever
  /// persisted; this just clears the in-memory field — Hard Rule #3.)
  void reset() => state = const HomeState();
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>(
  (ref) => HomeNotifier(),
);
