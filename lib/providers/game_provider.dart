import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/models/challenge.dart';
import '../shared/services/firestore_service.dart';
import 'firestore_provider.dart';

enum SoloPhase { loading, playing, completed, error }

class SoloGameState {
  const SoloGameState({
    this.phase = SoloPhase.loading,
    this.challenges = const [],
    this.currentRoundIndex = 0,
    this.totalRounds = 10,
    this.totalScore = 0,
    this.roundScores = const [],
    this.roundChoices = const [],
    this.roundStartTime,
    this.hasAnswered = false,
    this.lastPointsEarned = 0,
    this.sessionId,
    this.roundIds = const [],
    this.error,
  });

  final SoloPhase phase;
  final List<Challenge> challenges;
  final int currentRoundIndex;
  final int totalRounds;
  final int totalScore;
  final List<int> roundScores;
  final List<String> roundChoices;
  final DateTime? roundStartTime;
  final bool hasAnswered;
  final int lastPointsEarned;
  final String? sessionId;
  final List<String> roundIds;
  final String? error;

  Challenge? get currentChallenge =>
      currentRoundIndex < challenges.length ? challenges[currentRoundIndex] : null;
  int get currentRound => currentRoundIndex + 1;
  bool get isLastRound => currentRound >= totalRounds;

  SoloGameState copyWith({
    SoloPhase? phase,
    List<Challenge>? challenges,
    int? currentRoundIndex,
    int? totalRounds,
    int? totalScore,
    List<int>? roundScores,
    List<String>? roundChoices,
    DateTime? roundStartTime,
    bool? hasAnswered,
    int? lastPointsEarned,
    String? sessionId,
    List<String>? roundIds,
    String? error,
  }) {
    return SoloGameState(
      phase: phase ?? this.phase,
      challenges: challenges ?? this.challenges,
      currentRoundIndex: currentRoundIndex ?? this.currentRoundIndex,
      totalRounds: totalRounds ?? this.totalRounds,
      totalScore: totalScore ?? this.totalScore,
      roundScores: roundScores ?? this.roundScores,
      roundChoices: roundChoices ?? this.roundChoices,
      roundStartTime: roundStartTime ?? this.roundStartTime,
      hasAnswered: hasAnswered ?? this.hasAnswered,
      lastPointsEarned: lastPointsEarned ?? this.lastPointsEarned,
      sessionId: sessionId ?? this.sessionId,
      roundIds: roundIds ?? this.roundIds,
      error: error ?? this.error,
    );
  }
}

class SoloGameNotifier extends Notifier<SoloGameState> {
  late FirestoreService _service;

  @override
  SoloGameState build() {
    _service = ref.watch(firestoreServiceProvider);
    return const SoloGameState();
  }

  Future<void> startGame() async {
    state = const SoloGameState(phase: SoloPhase.loading);

    try {
      const totalRounds = 10;
      final challenges = await _service.getRandomChallenges(totalRounds);

      if (challenges.length < totalRounds) {
        state = state.copyWith(
          phase: SoloPhase.error,
          error: 'Not enough challenges available',
        );
        return;
      }

      final session = await _service.createSoloSession(totalRounds: totalRounds);

      final roundIds = <String>[];
      for (var i = 0; i < challenges.length; i++) {
        final roundId = await _service.createSoloRound(
          sessionId: session.id,
          challengeId: challenges[i].id,
          roundNumber: i + 1,
        );
        roundIds.add(roundId);
      }

      state = SoloGameState(
        phase: SoloPhase.playing,
        challenges: challenges,
        totalRounds: totalRounds,
        sessionId: session.id,
        roundIds: roundIds,
        roundStartTime: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        phase: SoloPhase.error,
        error: e.toString(),
      );
    }
  }

  Future<void> submitAnswer(String option) async {
    if (state.hasAnswered || state.phase != SoloPhase.playing) return;

    final responseTimeMs = state.roundStartTime != null
        ? DateTime.now().difference(state.roundStartTime!).inMilliseconds
        : 5000;

    final points = _calculatePoints(responseTimeMs);

    state = state.copyWith(
      hasAnswered: true,
      lastPointsEarned: points,
      totalScore: state.totalScore + points,
      roundScores: [...state.roundScores, points],
      roundChoices: [...state.roundChoices, option],
    );

    if (state.sessionId != null &&
        state.currentRoundIndex < state.roundIds.length) {
      await _service.submitAnswer(
        sessionId: state.sessionId!,
        roundId: state.roundIds[state.currentRoundIndex],
        chosenOption: option,
        responseTimeMs: responseTimeMs,
      );
    }
  }

  Future<void> nextRound() async {
    if (state.isLastRound) {
      if (state.sessionId != null) {
        await _service.completeSoloSession(state.sessionId!);
      }
      state = state.copyWith(phase: SoloPhase.completed);
      return;
    }

    state = state.copyWith(
      currentRoundIndex: state.currentRoundIndex + 1,
      hasAnswered: false,
      lastPointsEarned: 0,
      roundStartTime: DateTime.now(),
    );
  }

  int _calculatePoints(int responseTimeMs) {
    if (responseTimeMs < 2000) return 100;
    if (responseTimeMs < 5000) return 75;
    if (responseTimeMs < 10000) return 50;
    return 25;
  }

  void reset() {
    state = const SoloGameState();
  }
}

final gameProvider = NotifierProvider<SoloGameNotifier, SoloGameState>(
  SoloGameNotifier.new,
);
