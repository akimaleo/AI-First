import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Provider;

import '../shared/models/challenge.dart';
import '../shared/models/game_session.dart';
import '../shared/models/score.dart';
import '../shared/services/supabase_service.dart';
import 'supabase_provider.dart';

enum MultiplayerPhase {
  idle,
  waitingRoom,
  playing,
  roundResult,
  completed,
}

class MultiplayerState {
  const MultiplayerState({
    this.phase = MultiplayerPhase.idle,
    this.session,
    this.participants = const [],
    this.currentChallenge,
    this.currentRound,
    this.opponentScores = const {},
    this.myScore = 0,
    this.opponentScore = 0,
    this.hasAnsweredCurrentRound = false,
    this.opponentAnsweredCurrentRound = false,
    this.roundStartTime,
    this.error,
    this.playerScores = const [],
  });

  final MultiplayerPhase phase;
  final GameSession? session;
  final List<SessionParticipant> participants;
  final Challenge? currentChallenge;
  final SessionRound? currentRound;
  final Map<String, int> opponentScores;
  final int myScore;
  final int opponentScore;
  final bool hasAnsweredCurrentRound;
  final bool opponentAnsweredCurrentRound;
  final DateTime? roundStartTime;
  final String? error;
  final List<PlayerScore> playerScores;

  String get inviteCode => session?.inviteCode ?? '';
  bool get isHost => session != null &&
      Supabase.instance.client.auth.currentUser?.id == session!.hostId;
  bool get allReady => participants.isNotEmpty &&
      participants.every((p) => p.isReady);
  int get participantCount => participants.length;

  MultiplayerState copyWith({
    MultiplayerPhase? phase,
    GameSession? session,
    List<SessionParticipant>? participants,
    Challenge? currentChallenge,
    SessionRound? currentRound,
    Map<String, int>? opponentScores,
    int? myScore,
    int? opponentScore,
    bool? hasAnsweredCurrentRound,
    bool? opponentAnsweredCurrentRound,
    DateTime? roundStartTime,
    String? error,
    List<PlayerScore>? playerScores,
  }) {
    return MultiplayerState(
      phase: phase ?? this.phase,
      session: session ?? this.session,
      participants: participants ?? this.participants,
      currentChallenge: currentChallenge ?? this.currentChallenge,
      currentRound: currentRound ?? this.currentRound,
      opponentScores: opponentScores ?? this.opponentScores,
      myScore: myScore ?? this.myScore,
      opponentScore: opponentScore ?? this.opponentScore,
      hasAnsweredCurrentRound:
          hasAnsweredCurrentRound ?? this.hasAnsweredCurrentRound,
      opponentAnsweredCurrentRound:
          opponentAnsweredCurrentRound ?? this.opponentAnsweredCurrentRound,
      roundStartTime: roundStartTime ?? this.roundStartTime,
      error: error ?? this.error,
      playerScores: playerScores ?? this.playerScores,
    );
  }
}

class MultiplayerNotifier extends Notifier<MultiplayerState> {
  late SupabaseService _service;
  RealtimeChannel? _sessionChannel;
  RealtimeChannel? _participantChannel;
  RealtimeChannel? _scoreChannel;

  @override
  MultiplayerState build() {
    _service = ref.watch(supabaseServiceProvider);
    ref.onDispose(_cleanup);
    return const MultiplayerState();
  }

  void _cleanup() {
    if (_sessionChannel != null) _service.unsubscribe(_sessionChannel!);
    if (_participantChannel != null) _service.unsubscribe(_participantChannel!);
    if (_scoreChannel != null) _service.unsubscribe(_scoreChannel!);
  }

  Future<void> createSession() async {
    try {
      final session = await _service.createSession(totalRounds: 5);
      final participants = await _service.getParticipants(session.id);

      state = state.copyWith(
        phase: MultiplayerPhase.waitingRoom,
        session: session,
        participants: participants,
      );

      _subscribeToSession(session.id);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<bool> joinSession(String inviteCode) async {
    try {
      final session = await _service.joinSessionByCode(inviteCode);
      if (session == null) {
        state = state.copyWith(error: 'Invalid or expired invite code');
        return false;
      }

      final participants = await _service.getParticipants(session.id);

      state = state.copyWith(
        phase: MultiplayerPhase.waitingRoom,
        session: session,
        participants: participants,
      );

      _subscribeToSession(session.id);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<void> toggleReady() async {
    final session = state.session;
    if (session == null) return;

    final userId = _service.currentUserId;
    final currentlyReady = state.participants
        .where((p) => p.userId == userId)
        .firstOrNull
        ?.isReady ?? false;

    await _service.setReady(session.id, !currentlyReady);
    await _refreshParticipants();
  }

  Future<void> startGame() async {
    final session = state.session;
    if (session == null) return;

    await _service.startSession(session.id);
  }

  Future<void> submitAnswer(String option) async {
    final session = state.session;
    final round = state.currentRound;
    if (session == null || round == null) return;

    final responseTime = state.roundStartTime != null
        ? DateTime.now().difference(state.roundStartTime!).inMilliseconds
        : 5000;

    await _service.submitAnswer(
      sessionId: session.id,
      roundId: round.id,
      chosenOption: option,
      responseTimeMs: responseTime,
    );

    final points = _calculatePoints(responseTime);
    state = state.copyWith(
      hasAnsweredCurrentRound: true,
      myScore: state.myScore + points,
    );
  }

  int _calculatePoints(int responseTimeMs) {
    if (responseTimeMs < 2000) return 100;
    if (responseTimeMs < 5000) return 75;
    if (responseTimeMs < 10000) return 50;
    return 25;
  }

  void _subscribeToSession(String sessionId) {
    _sessionChannel = _service.subscribeToSession(
      sessionId,
      onSessionChange: _handleSessionChange,
    );
    _participantChannel = _service.subscribeToParticipants(
      sessionId,
      onParticipantChange: _refreshParticipants,
    );
    _scoreChannel = _service.subscribeToScores(
      sessionId,
      onScoreInserted: _handleScoreInserted,
    );
  }

  void _handleSessionChange(Map<String, dynamic> payload) async {
    final updatedSession = GameSession.fromJson(payload);

    if (updatedSession.isActive && (state.session?.isWaiting ?? false)) {
      await _loadRound(updatedSession, updatedSession.currentRound);
      state = state.copyWith(
        phase: MultiplayerPhase.playing,
        session: updatedSession,
        roundStartTime: DateTime.now(),
      );
    } else if (updatedSession.isActive &&
        updatedSession.currentRound != state.session?.currentRound) {
      await _loadRound(updatedSession, updatedSession.currentRound);
      state = state.copyWith(
        phase: MultiplayerPhase.playing,
        session: updatedSession,
        hasAnsweredCurrentRound: false,
        opponentAnsweredCurrentRound: false,
        roundStartTime: DateTime.now(),
      );
    } else if (updatedSession.isCompleted) {
      final playerScores = await _service.getPlayerScores(sessionId);
      state = state.copyWith(
        phase: MultiplayerPhase.completed,
        session: updatedSession,
        playerScores: playerScores,
      );
    } else {
      state = state.copyWith(session: updatedSession);
    }
  }

  Future<void> _loadRound(GameSession session, int roundNumber) async {
    final round = await _service.getCurrentRound(session.id, roundNumber);
    if (round == null) return;

    final challenge = await _service.getChallenge(round.challengeId);

    state = state.copyWith(
      currentRound: round,
      currentChallenge: challenge,
    );
  }

  Future<void> _refreshParticipants() async {
    final session = state.session;
    if (session == null) return;

    final participants = await _service.getParticipants(session.id);
    state = state.copyWith(participants: participants);
  }

  void _handleScoreInserted(Map<String, dynamic> payload) {
    final userId = payload['user_id'] as String?;
    final points = payload['points_earned'] as int? ?? 0;
    final myId = _service.currentUserId;

    if (userId != null && userId != myId) {
      state = state.copyWith(
        opponentScore: state.opponentScore + points,
        opponentAnsweredCurrentRound: true,
      );

      if (state.hasAnsweredCurrentRound && state.isHost) {
        _maybeAdvanceRound();
      }
    } else if (userId == myId &&
        state.opponentAnsweredCurrentRound &&
        state.isHost) {
      _maybeAdvanceRound();
    }
  }

  Future<void> _maybeAdvanceRound() async {
    final session = state.session;
    if (session == null) return;

    await Future.delayed(const Duration(seconds: 2));

    await _service.advanceRound(
      session.id,
      session.currentRound + 1,
      session.totalRounds,
    );
  }

  void reset() {
    _cleanup();
    state = const MultiplayerState();
  }
}

final multiplayerProvider =
    NotifierProvider<MultiplayerNotifier, MultiplayerState>(
  MultiplayerNotifier.new,
);
