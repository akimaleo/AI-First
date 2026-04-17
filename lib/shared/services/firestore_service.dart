import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/challenge.dart';
import '../models/game_session.dart';
import '../models/leaderboard_entry.dart';
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

  // ---------------------------------------------------------------------------
  // Challenge seeding — populates the challenges collection on first run
  // ---------------------------------------------------------------------------

  Future<void> seedChallengesIfEmpty() async {
    final snap = await _challenges().limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = _db.batch();
    for (final c in _defaultChallenges) {
      batch.set(_challenges().doc(), {
        'option_a': c.$1,
        'option_b': c.$2,
        'category': c.$3,
        'difficulty': c.$4,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  static const _defaultChallenges = <(String, String, String, int)>[
    // Lifestyle
    ('Always be 10 minutes late', 'Always be 20 minutes early', 'lifestyle', 1),
    ('Live in a treehouse', 'Live in a houseboat', 'lifestyle', 1),
    ('Have a personal chef', 'Have a personal trainer', 'lifestyle', 2),
    ('Live without internet', 'Live without AC/heating', 'lifestyle', 3),
    ('Give up your phone', 'Give up your bed', 'lifestyle', 3),
    ('Wear the same outfit every day', 'Never eat the same meal twice', 'lifestyle', 2),
    ('Live in a tiny house', 'Live in a mansion you can never leave', 'lifestyle', 4),
    ('Wake up at 4 AM every day', 'Stay up until 4 AM every night', 'lifestyle', 2),
    // Food
    ('Only eat pizza forever', 'Only eat tacos forever', 'food', 1),
    ('Never eat sweets again', 'Never eat savory food again', 'food', 3),
    ('Eat only raw food', 'Eat only canned food', 'food', 2),
    ('Drink only water forever', 'Drink everything except water', 'food', 3),
    ('Always cook your own meals', 'Always eat out but at random restaurants', 'food', 2),
    ('Have taste buds on your fingers', 'Have fingers for taste buds', 'food', 5),
    ('Only eat breakfast food', 'Never eat breakfast food again', 'food', 1),
    // Travel
    ('Explore deep space', 'Explore the deep ocean', 'travel', 2),
    ('Travel the world for a year with no luggage', 'Stay home for a year with unlimited online shopping', 'travel', 2),
    ('Only travel by bicycle', 'Only travel by boat', 'travel', 3),
    ('Visit every country but only for one hour', 'Live in one country forever', 'travel', 3),
    ('Always sit in the middle seat', 'Always have a 12-hour layover', 'travel', 2),
    ('Teleport anywhere but arrive naked', 'Fly but only at walking speed', 'travel', 4),
    ('Live on a tropical island alone', 'Live in a big city with a million roommates', 'travel', 3),
    // Entertainment
    ('Never use social media again', 'Never watch TV/movies again', 'entertainment', 2),
    ('Only listen to one song forever', 'Never listen to music again', 'entertainment', 4),
    ('Be in a reality TV show', 'Be the host of a game show', 'entertainment', 2),
    ('Only watch movies made before 1970', "Only watch movies that haven't been released yet", 'entertainment', 3),
    ('Play one video game for the rest of your life', 'Never play video games again', 'entertainment', 3),
    ('Read minds but only boring thoughts', 'See the future but only 10 seconds ahead', 'entertainment', 4),
    ('Have your life narrated by Morgan Freeman', 'Have your life scored by Hans Zimmer', 'entertainment', 1),
    // Relationships
    ('Always speak your mind', 'Never speak again', 'relationships', 4),
    ('Be the funniest person in the room', 'Be the smartest person in the room', 'relationships', 3),
    ('Always know when someone is lying', 'Always get away with lying', 'relationships', 4),
    ('Have one best friend who knows everything about you', 'Have 100 friends who know nothing about you', 'relationships', 3),
    ('Always have to say yes', 'Always have to say no', 'relationships', 3),
    ('Know how every relationship ends', 'Never know how anyone feels about you', 'relationships', 5),
    ('Be loved by everyone but trust no one', 'Be trusted by everyone but loved by no one', 'relationships', 5),
    // Career
    ('Be famous but hated', 'Be unknown but loved', 'career', 3),
    ('Work your dream job for minimum wage', 'Work a boring job for a million dollars a year', 'career', 3),
    ('Be your own boss but work 80 hours a week', 'Work 20 hours a week but have a terrible boss', 'career', 3),
    ('Be an astronaut', 'Be a deep sea diver', 'career', 1),
    ('Have a job where you travel 100% of the time', 'Have a job where you work from home 100% of the time', 'career', 2),
    ("Be the world's best at something nobody cares about", 'Be average at something everyone admires', 'career', 4),
    ('Retire at 30 with \$1M', 'Retire at 60 with \$10M', 'career', 4),
    // Hypothetical
    ('Travel to the past', 'Travel to the future', 'hypothetical', 2),
    ('Have unlimited money', 'Have unlimited time', 'hypothetical', 3),
    ('Have a rewind button for life', 'Have a pause button for life', 'hypothetical', 3),
    ('Be able to fly', 'Be able to read minds', 'hypothetical', 2),
    ('Win the lottery', 'Live twice as long', 'hypothetical', 4),
    ('Never age physically', 'Never age mentally', 'hypothetical', 5),
    ('Know the date of your death', 'Know the cause of your death', 'hypothetical', 5),
    ('Have all traffic lights be green for you', 'Never have to wait in line again', 'hypothetical', 1),
    // Silly
    ('Always feel too hot', 'Always feel too cold', 'silly', 1),
    ('Have fingers as long as your legs', 'Have legs as long as your fingers', 'silly', 2),
    ('Sweat maple syrup', 'Cry lemonade', 'silly', 2),
    ('Have a permanent clown nose', 'Have permanent clown shoes', 'silly', 1),
    ('Speak every language but only in whispers', 'Speak one language but always shouting', 'silly', 3),
    ('Have spaghetti for hair', 'Have marshmallows for teeth', 'silly', 2),
    ('Hiccup every time you say your name', 'Sneeze every time someone says thank you', 'silly', 1),
    ('Sound like a duck when you laugh', 'Sound like a goat when you sing', 'silly', 1),
    ('Have T-Rex arms', 'Have giraffe legs', 'silly', 2),
  ];

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

  // ---------------------------------------------------------------------------
  // Follows
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _follows() =>
      _db.collection('follows');

  Future<void> followUser(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    if (userId == targetUserId) return;
    final docId = '${userId}_$targetUserId';
    await _follows().doc(docId).set({
      'follower_id': userId,
      'followee_id': targetUserId,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unfollowUser(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) return;
    final docId = '${userId}_$targetUserId';
    await _follows().doc(docId).delete();
  }

  Future<List<LeaderboardEntry>> listFollowing(String userId) async {
    final snap = await _follows()
        .where('follower_id', isEqualTo: userId)
        .get();
    if (snap.docs.isEmpty) return const [];

    final followeeIds = snap.docs
        .map((d) => d.data()['followee_id'] as String)
        .toList();
    final userDocs = await Future.wait(
      followeeIds.map((id) => _db.collection('users').doc(id).get()),
    );
    return userDocs
        .where((d) => d.exists)
        .map((d) {
          final data = Map<String, dynamic>.from(d.data() ?? {})
            ..['id'] = d.id;
          return LeaderboardEntry.fromJson(data);
        })
        .toList();
  }

  Future<List<LeaderboardEntry>> listFollowers(String userId) async {
    final snap = await _follows()
        .where('followee_id', isEqualTo: userId)
        .get();
    if (snap.docs.isEmpty) return const [];

    final followerIds = snap.docs
        .map((d) => d.data()['follower_id'] as String)
        .toList();
    final userDocs = await Future.wait(
      followerIds.map((id) => _db.collection('users').doc(id).get()),
    );
    return userDocs
        .where((d) => d.exists)
        .map((d) {
          final data = Map<String, dynamic>.from(d.data() ?? {})
            ..['id'] = d.id;
          return LeaderboardEntry.fromJson(data);
        })
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Leaderboard / profile / history / search  (plan B: client-side queries)
  // ---------------------------------------------------------------------------

  Future<List<LeaderboardEntry>> getGlobalLeaderboard({int limit = 50}) async {
    final snap = await _db.collection('users')
        .orderBy('total_score', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data())..['id'] = d.id;
      return LeaderboardEntry.fromJson(data);
    }).toList();
  }

  Future<List<LeaderboardEntry>> getFriendsLeaderboard(
      {int limit = 50}) async {
    final userId = currentUserId;
    if (userId == null) return const [];

    final followSnap = await _follows()
        .where('follower_id', isEqualTo: userId)
        .get();
    if (followSnap.docs.isEmpty) return const [];

    final followeeIds = followSnap.docs
        .map((d) => d.data()['followee_id'] as String)
        .toList();
    final userDocs = await Future.wait(
      followeeIds.map((id) => _db.collection('users').doc(id).get()),
    );
    final entries = userDocs
        .where((d) => d.exists)
        .map((d) {
          final data = Map<String, dynamic>.from(d.data() ?? {})
            ..['id'] = d.id;
          return LeaderboardEntry.fromJson(data);
        })
        .toList()
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    return entries.take(limit).toList();
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return null;

    final data = Map<String, dynamic>.from(doc.data() ?? {})
      ..['user_id'] = doc.id;

    final followersSnap = await _follows()
        .where('followee_id', isEqualTo: userId)
        .count()
        .get();
    final followingSnap = await _follows()
        .where('follower_id', isEqualTo: userId)
        .count()
        .get();

    data['followers_count'] = followersSnap.count ?? 0;
    data['following_count'] = followingSnap.count ?? 0;

    final myId = currentUserId;
    if (myId != null && myId != userId) {
      final followDoc = await _follows().doc('${myId}_$userId').get();
      data['is_following'] = followDoc.exists;
    } else {
      data['is_following'] = false;
    }

    return UserProfile.fromJson(data);
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
    // Get sessions where the user participated.
    final participantSnap = await _db.collectionGroup('participants')
        .where('user_id', isEqualTo: userId)
        .limit(limit * 2)
        .get();

    final sessionIds = participantSnap.docs
        .map((d) => d.reference.parent.parent?.id)
        .where((id) => id != null)
        .cast<String>()
        .toSet()
        .toList();
    if (sessionIds.isEmpty) return const [];

    final sessionDocs = await Future.wait(
      sessionIds.map((id) => _sessions().doc(id).get()),
    );

    final entries = <HistoryEntry>[];
    for (final sDoc in sessionDocs) {
      if (!sDoc.exists) continue;
      final sData = sDoc.data() ?? {};
      if (sData['status'] != 'completed') continue;

      final scoresSnap = await _scores(sDoc.id).get();
      final allScores = scoresSnap.docs.map((d) => d.data()).toList();

      final userPoints = allScores
          .where((s) => s['user_id'] == userId)
          .fold<int>(0, (acc, s) => acc + ((s['points_earned'] as num?)?.toInt() ?? 0));

      final playerTotals = <String, int>{};
      for (final s in allScores) {
        final pid = s['user_id'] as String;
        playerTotals[pid] = (playerTotals[pid] ?? 0) +
            ((s['points_earned'] as num?)?.toInt() ?? 0);
      }
      final sorted = playerTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final rank = sorted.indexWhere((e) => e.key == userId) + 1;

      entries.add(HistoryEntry.fromJson({
        'session_id': sDoc.id,
        'mode': sData['mode'] ?? 'versus',
        'status': sData['status'] ?? 'completed',
        'completed_at': sData['completed_at'],
        'total_rounds': sData['total_rounds'] ?? 0,
        'user_points': userPoints,
        'user_rank': rank > 0 ? rank : 1,
        'player_count': playerTotals.length,
        'won': rank == 1,
      }));
    }

    entries.sort((a, b) => (b.completedAt ?? DateTime(0))
        .compareTo(a.completedAt ?? DateTime(0)));
    return entries.take(limit).toList();
  }

  Future<List<UserSearchResult>> searchUsers(String term,
      {int limit = 20}) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return const [];
    final lower = trimmed.toLowerCase();

    // Firestore prefix range query on username.
    final end = '$lower\uf8ff';
    final snap = await _db.collection('users')
        .where('username', isGreaterThanOrEqualTo: lower)
        .where('username', isLessThanOrEqualTo: end)
        .limit(limit)
        .get();

    final myId = currentUserId;
    Set<String>? followees;
    if (myId != null) {
      final followSnap = await _follows()
          .where('follower_id', isEqualTo: myId)
          .get();
      followees = followSnap.docs
          .map((d) => d.data()['followee_id'] as String)
          .toSet();
    }

    return snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data())
        ..['user_id'] = d.id
        ..['is_following'] = followees?.contains(d.id) ?? false;
      return UserSearchResult.fromJson(data);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Realtime subscriptions via Firestore snapshots
  // ---------------------------------------------------------------------------

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
      subscribeToSession(
    String sessionId, {
    required void Function(Map<String, dynamic> payload) onSessionChange,
  }) {
    return _sessions().doc(sessionId).snapshots().listen((snap) {
      if (snap.exists) {
        final data = Map<String, dynamic>.from(snap.data() ?? {})
          ..['id'] = snap.id;
        onSessionChange(data);
      }
    });
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
      subscribeToParticipants(
    String sessionId, {
    required void Function() onParticipantChange,
  }) {
    return _participants(sessionId).snapshots().listen((_) {
      onParticipantChange();
    });
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subscribeToScores(
    String sessionId, {
    required void Function(Map<String, dynamic> payload) onScoreInserted,
  }) {
    // Track already-seen score doc IDs to emit only new ones.
    final seen = <String>{};
    return _scores(sessionId).snapshots().listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added &&
            !seen.contains(change.doc.id)) {
          seen.add(change.doc.id);
          final data = Map<String, dynamic>.from(change.doc.data() ?? {})
            ..['id'] = change.doc.id;
          onScoreInserted(data);
        }
      }
    });
  }
}
