class Score {
  const Score({
    required this.id,
    required this.sessionId,
    required this.roundId,
    required this.userId,
    required this.chosenOption,
    required this.responseTimeMs,
    this.pointsEarned = 0,
    this.answeredAt,
  });

  final String id;
  final String sessionId;
  final String roundId;
  final String userId;
  final String chosenOption;
  final int responseTimeMs;
  final int pointsEarned;
  final DateTime? answeredAt;

  factory Score.fromJson(Map<String, dynamic> json) {
    return Score(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      roundId: json['round_id'] as String,
      userId: json['user_id'] as String,
      chosenOption: json['chosen_option'] as String,
      responseTimeMs: json['response_time_ms'] as int,
      pointsEarned: json['points_earned'] as int? ?? 0,
      answeredAt: json['answered_at'] != null
          ? DateTime.parse(json['answered_at'] as String)
          : null,
    );
  }
}

class PlayerScore {
  const PlayerScore({
    required this.userId,
    required this.username,
    required this.totalPoints,
    required this.roundsAnswered,
  });

  final String userId;
  final String username;
  final int totalPoints;
  final int roundsAnswered;
}
