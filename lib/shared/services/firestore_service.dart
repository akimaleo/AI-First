import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/challenge.dart';
import '../models/game_session.dart';
import '../models/score.dart';

// Firestore-backed data service for GUSAA-50 Phase 3. Collection layout mirrors
// the old Supabase tables so existing model `fromJson` paths keep working:
//
//   users/{uid}
//   sessions/{sessionId}
//   sessions/{sessionId}/participants/{uid}
//   sessions/{sessionId}/rounds/{roundDocId}   -- queried by round_number
//   sessions/{sessionId}/scores/{uid_roundId}  -- idempotent on resubmit
//   challenges/{challengeId}
//   follows/{followerUid_followeeUid}
//
// Field names stay snake_case so the per-model fromJson helpers do not need to
// change during the Phase 3b cutover and so the Phase 3 one-time Supabase ->
// Firestore upload can copy column keys verbatim.
class FirestoreService {
  FirestoreService(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get currentUserId => _auth.currentUser?.uid;

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  CollectionReference<Map<String, dynamic>> _sessions() =>
      _db.collection('sessions');
  CollectionReference<Map<String, dynamic>> _participants(String sessionId) =>
      _sessions().doc(sessionId).collection('participants');
  CollectionReference<Map<String, dynamic>> _rounds(String sessionId) =>
      _sessions().doc(sessionId).collection('rounds');
  CollectionReference<Map<String, dynamic>> _scores(String sessionId) =>
      _sessions().doc(sessionId).collection('scores');
  CollectionReference<Map<String, dynamic>> _challenges() =>
      _db.collection('challenges');

  Map<String, dynamic> _stampSession({
    required String userId,
    required String mode,
    required String status,
    required int maxPlayers,
    required int totalRounds,
    String? inviteCode,
    DateTime? startedAt,
    int currentRound = 0,
  }) {
    return {
      'host_id': userId,
      'mode': mode,
      'status': status,
      'max_players': maxPlayers,
      'current_round': currentRound,
      'total_rounds': totalRounds,
      'invite_code': inviteCode,
      'started_at': startedAt?.toUtc().toIso8601String(),
      'completed_at': null,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  GameSession _sessionFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data() ?? const {})
      ..['id'] = doc.id;
    return GameSession.fromJson(data);
  }

  Future<GameSession> createSession({int totalRounds = 5}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final inviteCode = _generateInviteCode();
    final ref = _sessions().doc();
    final payload = _stampSession(
      userId: userId,
      mode: 'versus',
      status: 'waiting',
      maxPlayers: 2,
      totalRounds: totalRounds,
      inviteCode: inviteCode,
    );

    final batch = _db.batch()
      ..set(ref, payload)
      ..set(_participants(ref.id).doc(userId), {
        'session_id': ref.id,
        'user_id': userId,
        'is_ready': false,
        'joined_at': FieldValue.serverTimestamp(),
      });
    await batch.commit();

    final snap = await ref.get();
    return _sessionFromDoc(snap);
  }

  Future<GameSession?> joinSessionByCode(String inviteCode) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final query = await _sessions()
        .where('invite_code', isEqualTo: inviteCode.toUpperCase())
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    await _participants(doc.id).doc(userId).set({
      'session_id': doc.id,
      'user_id': userId,
      'is_ready': false,
      'joined_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return _sessionFromDoc(doc);
  }

  Future<GameSession> createSoloSession({int totalRounds = 10}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final ref = _sessions().doc();
    final now = DateTime.now().toUtc();
    final payload = _stampSession(
      userId: userId,
      mode: 'solo',
      status: 'active',
      maxPlayers: 1,
      totalRounds: totalRounds,
      startedAt: now,
      currentRound: 1,
    );

    final batch = _db.batch()
      ..set(ref, payload)
      ..set(_participants(ref.id).doc(userId), {
        'session_id': ref.id,
        'user_id': userId,
        'is_ready': true,
        'joined_at': FieldValue.serverTimestamp(),
      });
    await batch.commit();

    final snap = await ref.get();
    return _sessionFromDoc(snap);
  }

  Future<GameSession?> getSession(String sessionId) async {
    final snap = await _sessions().doc(sessionId).get();
    if (!snap.exists) return null;
    return _sessionFromDoc(snap);
  }

  Future<List<SessionParticipant>> getParticipants(String sessionId) async {
    final snap = await _participants(sessionId).get();
    if (snap.docs.isEmpty) return const [];

    final userIds = snap.docs.map((d) => d.id).toList();
    final userDocs = await Future.wait(
      userIds.map((uid) => _db.collection('users').doc(uid).get()),
    );
    final userById = {
      for (final d in userDocs)
        if (d.exists) d.id: d.data() ?? const <String, dynamic>{},
    };

    return snap.docs.map((doc) {
      final base = Map<String, dynamic>.from(doc.data())
        ..['session_id'] = sessionId
        ..['user_id'] = doc.id;
      final user = userById[doc.id];
      if (user != null) {
        base['users'] = {
          'username': user['username'],
          'display_name': user['display_name'],
        };
      }
      return SessionParticipant.fromJson(base);
    }).toList();
  }

  Future<void> setReady(String sessionId, bool ready) async {
    final userId = currentUserId;
    if (userId == null) return;
    await _participants(sessionId).doc(userId).set(
      {'is_ready': ready},
      SetOptions(merge: true),
    );
  }

  Future<void> startSession(String sessionId) async {
    final challenges = await getRandomChallenges(5);
    final sessionRef = _sessions().doc(sessionId);

    final batch = _db.batch()
      ..update(sessionRef, {
        'status': 'active',
        'current_round': 1,
        'started_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': FieldValue.serverTimestamp(),
      });

    for (var i = 0; i < challenges.length; i++) {
      final roundRef = _rounds(sessionId).doc();
      batch.set(roundRef, {
        'session_id': sessionId,
        'challenge_id': challenges[i].id,
        'round_number': i + 1,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<String> createSoloRound({
    required String sessionId,
    required String challengeId,
    required int roundNumber,
  }) async {
    final ref = _rounds(sessionId).doc();
    await ref.set({
      'session_id': sessionId,
      'challenge_id': challengeId,
      'round_number': roundNumber,
      'created_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> completeSoloSession(String sessionId) async {
    await _sessions().doc(sessionId).update({
      'status': 'completed',
      'completed_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Challenge>> getRandomChallenges(int count) async {
    final snap = await _challenges()
        .where('is_active', isEqualTo: true)
        .limit(count * 3)
        .get();
    final all = snap.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data())..['id'] = doc.id;
      return Challenge.fromJson(data);
    }).toList();
    all.shuffle(Random.secure());
    return all.take(count).toList();
  }

  Future<SessionRound?> getCurrentRound(
      String sessionId, int roundNumber) async {
    final snap = await _rounds(sessionId)
        .where('round_number', isEqualTo: roundNumber)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    final data = Map<String, dynamic>.from(doc.data())..['id'] = doc.id;
    return SessionRound.fromJson(data);
  }

  Future<Challenge?> getChallenge(String challengeId) async {
    final snap = await _challenges().doc(challengeId).get();
    if (!snap.exists) return null;
    final data = Map<String, dynamic>.from(snap.data() ?? const {})
      ..['id'] = snap.id;
    return Challenge.fromJson(data);
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
    final scoreId = '${userId}_$roundId';

    await _scores(sessionId).doc(scoreId).set({
      'session_id': sessionId,
      'round_id': roundId,
      'user_id': userId,
      'chosen_option': chosenOption,
      'response_time_ms': responseTimeMs,
      'points_earned': points,
      'answered_at': FieldValue.serverTimestamp(),
    });
  }

  int _calculatePoints(int responseTimeMs) {
    if (responseTimeMs < 2000) return 100;
    if (responseTimeMs < 5000) return 75;
    if (responseTimeMs < 10000) return 50;
    return 25;
  }

  Future<void> advanceRound(
      String sessionId, int nextRound, int totalRounds) async {
    if (nextRound > totalRounds) {
      await _sessions().doc(sessionId).update({
        'status': 'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } else {
      await _sessions().doc(sessionId).update({
        'current_round': nextRound,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<List<Score>> getSessionScores(String sessionId) async {
    final snap = await _scores(sessionId).get();
    return snap.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data())..['id'] = doc.id;
      return Score.fromJson(data);
    }).toList();
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
          entry.value.fold<int>(0, (acc, s) => acc + s.pointsEarned);
      return PlayerScore(
        userId: entry.key,
        username: participant?.username ?? participant?.displayName ?? 'Player',
        totalPoints: totalPoints,
        roundsAnswered: entry.value.length,
      );
    }).toList()
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
  }
}
