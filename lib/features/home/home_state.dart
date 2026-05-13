import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeState {
  final int? selectedDurationMin;
  final String situationText;
  const HomeState({this.selectedDurationMin, this.situationText = ''});
  HomeState copyWith({int? selectedDurationMin, String? situationText}) =>
      HomeState(
        selectedDurationMin: selectedDurationMin ?? this.selectedDurationMin,
        situationText: situationText ?? this.situationText,
      );
}

class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier() : super(const HomeState());

  void setDuration(int min) => state = state.copyWith(selectedDurationMin: min);

  void setSituation(String text) => state = state.copyWith(situationText: text);
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>(
  (ref) => HomeNotifier(),
);
