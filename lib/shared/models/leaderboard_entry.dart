class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.totalScore,
    required this.gamesPlayed,
    required this.gamesWon,
  });

  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int totalScore;
  final int gamesPlayed;
  final int gamesWon;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: (json['user_id'] ?? json['id']) as String,
      username: json['username'] as String? ?? 'player',
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      gamesPlayed: (json['games_played'] as num?)?.toInt() ?? 0,
      gamesWon: (json['games_won'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    required this.level,
    required this.totalScore,
    required this.gamesPlayed,
    required this.gamesWon,
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
  });

  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final int level;
  final int totalScore;
  final int gamesPlayed;
  final int gamesWon;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String,
      username: json['username'] as String? ?? 'player',
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 1,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      gamesPlayed: (json['games_played'] as num?)?.toInt() ?? 0,
      gamesWon: (json['games_won'] as num?)?.toInt() ?? 0,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      isFollowing: json['is_following'] as bool? ?? false,
    );
  }

  UserProfile copyWith({
    bool? isFollowing,
    int? followersCount,
  }) {
    return UserProfile(
      userId: userId,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      bio: bio,
      level: level,
      totalScore: totalScore,
      gamesPlayed: gamesPlayed,
      gamesWon: gamesWon,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

class UserSearchResult {
  const UserSearchResult({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.totalScore,
    required this.isFollowing,
  });

  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int totalScore;
  final bool isFollowing;

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      userId: json['user_id'] as String,
      username: json['username'] as String? ?? 'player',
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      isFollowing: json['is_following'] as bool? ?? false,
    );
  }

  UserSearchResult copyWith({bool? isFollowing}) {
    return UserSearchResult(
      userId: userId,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      totalScore: totalScore,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

class HistoryEntry {
  const HistoryEntry({
    required this.sessionId,
    required this.mode,
    required this.status,
    this.completedAt,
    required this.totalRounds,
    required this.userPoints,
    required this.userRank,
    required this.playerCount,
    required this.won,
  });

  final String sessionId;
  final String mode;
  final String status;
  final DateTime? completedAt;
  final int totalRounds;
  final int userPoints;
  final int userRank;
  final int playerCount;
  final bool won;

  bool get isSolo => mode == 'solo';

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      sessionId: json['session_id'] as String,
      mode: json['mode'] as String? ?? 'versus',
      status: json['status'] as String? ?? 'completed',
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      totalRounds: (json['total_rounds'] as num?)?.toInt() ?? 0,
      userPoints: (json['user_points'] as num?)?.toInt() ?? 0,
      userRank: (json['user_rank'] as num?)?.toInt() ?? 0,
      playerCount: (json['player_count'] as num?)?.toInt() ?? 0,
      won: json['won'] as bool? ?? false,
    );
  }
}
