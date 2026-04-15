class GameSession {
  const GameSession({
    required this.id,
    required this.hostId,
    this.mode = 'versus',
    this.status = 'waiting',
    this.maxPlayers = 2,
    this.currentRound = 0,
    this.totalRounds = 10,
    this.inviteCode,
    this.startedAt,
    this.completedAt,
  });

  final String id;
  final String hostId;
  final String mode;
  final String status;
  final int maxPlayers;
  final int currentRound;
  final int totalRounds;
  final String? inviteCode;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isWaiting => status == 'waiting';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      id: json['id'] as String,
      hostId: json['host_id'] as String,
      mode: json['mode'] as String? ?? 'versus',
      status: json['status'] as String? ?? 'waiting',
      maxPlayers: json['max_players'] as int? ?? 2,
      currentRound: json['current_round'] as int? ?? 0,
      totalRounds: json['total_rounds'] as int? ?? 10,
      inviteCode: json['invite_code'] as String?,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  GameSession copyWith({
    String? status,
    int? currentRound,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return GameSession(
      id: id,
      hostId: hostId,
      mode: mode,
      status: status ?? this.status,
      maxPlayers: maxPlayers,
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds,
      inviteCode: inviteCode,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class SessionParticipant {
  const SessionParticipant({
    required this.sessionId,
    required this.userId,
    this.isReady = false,
    this.joinedAt,
    this.username,
    this.displayName,
  });

  final String sessionId;
  final String userId;
  final bool isReady;
  final DateTime? joinedAt;
  final String? username;
  final String? displayName;

  factory SessionParticipant.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    return SessionParticipant(
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      isReady: json['is_ready'] as bool? ?? false,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : null,
      username: user?['username'] as String?,
      displayName: user?['display_name'] as String?,
    );
  }
}

class SessionRound {
  const SessionRound({
    required this.id,
    required this.sessionId,
    required this.challengeId,
    required this.roundNumber,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String sessionId;
  final String challengeId;
  final int roundNumber;
  final DateTime? startedAt;
  final DateTime? endedAt;

  factory SessionRound.fromJson(Map<String, dynamic> json) {
    return SessionRound(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      challengeId: json['challenge_id'] as String,
      roundNumber: json['round_number'] as int,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
    );
  }
}
