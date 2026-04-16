import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/challenge.dart';
import '../models/game_session.dart';
import '../models/leaderboard_entry.dart';
import '../models/score.dart';

class SupabaseService {
  SupabaseService(this._client);

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<GameSession> createSession({int totalRounds = 5}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final inviteCode = _generateInviteCode();
    final response = await _client.from('sessions').insert({
      'host_id': userId,
      'mode': 'versus',
      'status': 'waiting',
      'max_players': 2,
      'total_rounds': totalRounds,
      'invite_code': inviteCode,
    }).select().single();

    await _client.from('session_participants').insert({
      'session_id': response['id'],
      'user_id': userId,
    });

    return GameSession.fromJson(response);
  }

  Future<GameSession?> joinSessionByCode(String inviteCode) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('sessions')
        .select()
        .eq('invite_code', inviteCode.toUpperCase())
        .eq('status', 'waiting')
        .maybeSingle();

    if (response == null) return null;

    final session = GameSession.fromJson(response);

    await _client.from('session_participants').upsert({
      'session_id': session.id,
      'user_id': userId,
    });

    return session;
  }

  Future<List<SessionParticipant>> getParticipants(String sessionId) async {
    final response = await _client
        .from('session_participants')
        .select('*, users(username, display_name)')
        .eq('session_id', sessionId);

    return (response as List)
        .map((e) => SessionParticipant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setReady(String sessionId, bool ready) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _client
        .from('session_participants')
        .update({'is_ready': ready})
        .eq('session_id', sessionId)
        .eq('user_id', userId);
  }

  Future<void> startSession(String sessionId) async {
    final challenges = await getRandomChallenges(5);

    await _client.from('sessions').update({
      'status': 'active',
      'current_round': 1,
      'started_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', sessionId);

    for (var i = 0; i < challenges.length; i++) {
      await _client.from('session_rounds').insert({
        'session_id': sessionId,
        'challenge_id': challenges[i].id,
        'round_number': i + 1,
      });
    }
  }

  Future<GameSession> createSoloSession({int totalRounds = 10}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client.from('sessions').insert({
      'host_id': userId,
      'mode': 'solo',
      'status': 'active',
      'max_players': 1,
      'total_rounds': totalRounds,
      'current_round': 1,
      'started_at': DateTime.now().toUtc().toIso8601String(),
    }).select().single();

    await _client.from('session_participants').insert({
      'session_id': response['id'],
      'user_id': userId,
      'is_ready': true,
    });

    return GameSession.fromJson(response);
  }

  Future<String> createSoloRound({
    required String sessionId,
    required String challengeId,
    required int roundNumber,
  }) async {
    final response = await _client.from('session_rounds').insert({
      'session_id': sessionId,
      'challenge_id': challengeId,
      'round_number': roundNumber,
    }).select('id').single();
    return response['id'] as String;
  }

  Future<void> completeSoloSession(String sessionId) async {
    await _client.from('sessions').update({
      'status': 'completed',
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', sessionId);
  }

  Future<List<Challenge>> getRandomChallenges(int count) async {
    final response = await _client
        .from('challenges')
        .select()
        .eq('is_active', true)
        .limit(count * 3);

    final all = (response as List)
        .map((e) => Challenge.fromJson(e as Map<String, dynamic>))
        .toList();
    all.shuffle(Random.secure());
    return all.take(count).toList();
  }

  Future<SessionRound?> getCurrentRound(
      String sessionId, int roundNumber) async {
    final response = await _client
        .from('session_rounds')
        .select()
        .eq('session_id', sessionId)
        .eq('round_number', roundNumber)
        .maybeSingle();

    if (response == null) return null;
    return SessionRound.fromJson(response);
  }

  Future<Challenge?> getChallenge(String challengeId) async {
    final response = await _client
        .from('challenges')
        .select()
        .eq('id', challengeId)
        .maybeSingle();

    if (response == null) return null;
    return Challenge.fromJson(response);
  }

  Future<void> submitAnswer({
    required String sessionId,
    required String roundId,
    required String chosenOption,
    required int responseTimeMs,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    final points = _calculatePoints(responseTimeMs);

    await _client.from('scores').insert({
      'session_id': sessionId,
      'round_id': roundId,
      'user_id': userId,
      'chosen_option': chosenOption,
      'response_time_ms': responseTimeMs,
      'points_earned': points,
    });
  }

  int _calculatePoints(int responseTimeMs) {
    if (responseTimeMs < 2000) return 100;
    if (responseTimeMs < 5000) return 75;
    if (responseTimeMs < 10000) return 50;
    return 25;
  }

  Future<void> advanceRound(String sessionId, int nextRound,
      int totalRounds) async {
    if (nextRound > totalRounds) {
      await _client.from('sessions').update({
        'status': 'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', sessionId);
    } else {
      await _client.from('sessions').update({
        'current_round': nextRound,
      }).eq('id', sessionId);
    }
  }

  Future<List<Score>> getSessionScores(String sessionId) async {
    final response = await _client
        .from('scores')
        .select()
        .eq('session_id', sessionId);

    return (response as List)
        .map((e) => Score.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PlayerScore>> getPlayerScores(String sessionId) async {
    final scores = await getSessionScores(sessionId);
    final participants = await getParticipants(sessionId);

    final scoresByUser = <String, List<Score>>{};
    for (final score in scores) {
      scoresByUser.putIfAbsent(score.userId, () => []).add(score);
    }

    final participantMap = {
      for (final p in participants) p.userId: p,
    };

    return scoresByUser.entries.map((entry) {
      final participant = participantMap[entry.key];
      final totalPoints =
          entry.value.fold<int>(0, (sum, s) => sum + s.pointsEarned);
      return PlayerScore(
        userId: entry.key,
        username: participant?.username ?? participant?.displayName ?? 'Player',
        totalPoints: totalPoints,
        roundsAnswered: entry.value.length,
      );
    }).toList()
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
  }

  RealtimeChannel subscribeToSession(
    String sessionId, {
    required void Function(Map<String, dynamic> payload) onSessionChange,
  }) {
    return _client.channel('session:$sessionId').onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'sessions',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: sessionId,
      ),
      callback: (payload) => onSessionChange(payload.newRecord),
    ).subscribe();
  }

  RealtimeChannel subscribeToParticipants(
    String sessionId, {
    required void Function() onParticipantChange,
  }) {
    return _client.channel('participants:$sessionId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'session_participants',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'session_id',
        value: sessionId,
      ),
      callback: (_) => onParticipantChange(),
    ).subscribe();
  }

  RealtimeChannel subscribeToScores(
    String sessionId, {
    required void Function(Map<String, dynamic> payload) onScoreInserted,
  }) {
    return _client.channel('scores:$sessionId').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'scores',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'session_id',
        value: sessionId,
      ),
      callback: (payload) => onScoreInserted(payload.newRecord),
    ).subscribe();
  }

  void unsubscribe(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }

  Future<GameSession?> getSession(String sessionId) async {
    final response = await _client
        .from('sessions')
        .select()
        .eq('id', sessionId)
        .maybeSingle();

    if (response == null) return null;
    return GameSession.fromJson(response);
  }

  Future<List<LeaderboardEntry>> getGlobalLeaderboard({int limit = 50}) async {
    final response = await _client.rpc(
      'get_leaderboard',
      params: {'limit_count': limit},
    );
    return (response as List)
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<LeaderboardEntry>> getFriendsLeaderboard({int limit = 50}) async {
    final response = await _client.rpc(
      'get_friends_leaderboard',
      params: {'limit_count': limit},
    );
    return (response as List)
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    final response = await _client.rpc(
      'get_user_profile',
      params: {'target_user_id': userId},
    );
    final list = response as List;
    if (list.isEmpty) return null;
    return UserProfile.fromJson(list.first as Map<String, dynamic>);
  }

  Future<UserProfile?> getMyProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;
    return getUserProfile(userId);
  }

  Future<List<HistoryEntry>> getUserHistory(
    String userId, {
    int limit = 25,
  }) async {
    final response = await _client.rpc(
      'get_user_history',
      params: {'target_user_id': userId, 'limit_count': limit},
    );
    return (response as List)
        .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserSearchResult>> searchUsers(String term,
      {int limit = 20}) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return const [];
    final response = await _client.rpc(
      'search_users',
      params: {'search_term': trimmed, 'limit_count': limit},
    );
    return (response as List)
        .map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<LeaderboardEntry>> listFollowing(String userId) async {
    final response = await _client
        .from('follows')
        .select('followee:users!follows_followee_id_fkey('
            'id, username, display_name, avatar_url, total_score, '
            'games_played, games_won)')
        .eq('follower_id', userId);

    return (response as List)
        .map((row) => (row as Map<String, dynamic>)['followee']
            as Map<String, dynamic>)
        .map(LeaderboardEntry.fromJson)
        .toList();
  }

  Future<List<LeaderboardEntry>> listFollowers(String userId) async {
    final response = await _client
        .from('follows')
        .select('follower:users!follows_follower_id_fkey('
            'id, username, display_name, avatar_url, total_score, '
            'games_played, games_won)')
        .eq('followee_id', userId);

    return (response as List)
        .map((row) => (row as Map<String, dynamic>)['follower']
            as Map<String, dynamic>)
        .map(LeaderboardEntry.fromJson)
        .toList();
  }

  Future<void> followUser(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    if (userId == targetUserId) return;
    await _client.from('follows').upsert({
      'follower_id': userId,
      'followee_id': targetUserId,
    });
  }

  Future<void> unfollowUser(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) return;
    await _client
        .from('follows')
        .delete()
        .eq('follower_id', userId)
        .eq('followee_id', targetUserId);
  }
}
