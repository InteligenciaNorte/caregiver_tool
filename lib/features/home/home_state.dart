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
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>(
  (ref) => HomeNotifier(),
);
