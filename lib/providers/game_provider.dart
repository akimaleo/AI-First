import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Choice { a, b }

class GameState {
  const GameState({
    this.round = 1,
    this.currentPrompt = 'Would you rather...',
    this.optionA = 'Always be 10 min early',
    this.optionB = 'Always be 10 min late',
    this.score = 0,
  });

  final int round;
  final String currentPrompt;
  final String optionA;
  final String optionB;
  final int score;

  GameState copyWith({
    int? round,
    String? currentPrompt,
    String? optionA,
    String? optionB,
    int? score,
  }) {
    return GameState(
      round: round ?? this.round,
      currentPrompt: currentPrompt ?? this.currentPrompt,
      optionA: optionA ?? this.optionA,
      optionB: optionB ?? this.optionB,
      score: score ?? this.score,
    );
  }
}

class GameNotifier extends Notifier<GameState> {
  @override
  GameState build() => const GameState();

  void choose(Choice choice) {
    state = state.copyWith(
      round: state.round + 1,
      score: state.score + 1,
    );
  }

  void reset() {
    state = const GameState();
  }
}

final gameProvider = NotifierProvider<GameNotifier, GameState>(
  GameNotifier.new,
);
