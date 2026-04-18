import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sync_or_sink/providers/auth_provider.dart';
import 'package:sync_or_sink/providers/firestore_provider.dart';
import 'package:sync_or_sink/providers/initialization_provider.dart';
import 'package:sync_or_sink/router/app_router.dart';
import 'package:sync_or_sink/shared/models/challenge.dart';
import 'package:sync_or_sink/shared/models/game_session.dart';
import 'package:sync_or_sink/shared/services/firestore_service.dart';

/// A fake [FirestoreService] that returns deterministic data without Firebase.
class FakeFirestoreService implements FirestoreService {
  int _roundIdCounter = 0;

  @override
  String? get currentUserId => 'test-user-123';

  @override
  Future<List<Challenge>> getRandomChallenges(int count) async {
    return List.generate(
      count,
      (i) => Challenge(
        id: 'challenge-$i',
        optionA: 'Option A ${i + 1}',
        optionB: 'Option B ${i + 1}',
        category: 'test',
      ),
    );
  }

  @override
  Future<GameSession> createSoloSession({int totalRounds = 10}) async {
    return GameSession(
      id: 'test-session-1',
      hostId: 'test-user-123',
      mode: 'solo',
      status: 'active',
      totalRounds: totalRounds,
      startedAt: DateTime.now(),
    );
  }

  @override
  Future<String> createSoloRound({
    required String sessionId,
    required String challengeId,
    required int roundNumber,
  }) async {
    return 'round-${_roundIdCounter++}';
  }

  @override
  Future<void> submitAnswer({
    required String sessionId,
    required String roundId,
    required String chosenOption,
    required int responseTimeMs,
  }) async {}

  @override
  Future<void> completeSoloSession(String sessionId) async {}

  @override
  Future<void> seedChallengesIfEmpty() async {}

  // Unused methods — satisfy the interface.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

/// Builds the app wrapped in a [ProviderScope] with all Firebase-dependent
/// providers overridden so the test runs without a backend.
Widget buildTestApp() {
  return ProviderScope(
    overrides: [
      initializationProvider.overrideWith((ref) => Future.value()),
      firestoreServiceProvider.overrideWithValue(FakeFirestoreService()),
      currentUserIdProvider.overrideWithValue('test-user-123'),
    ],
    child: const _TestApp(),
  );
}

class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Sync or Sink Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7),
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Solo game flow', () {
    testWidgets('plays through all 10 rounds and shows results',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Home screen should show the Solo Play button.
      expect(find.text('Solo Play'), findsOneWidget);
      expect(find.text('Sync or Sink'), findsWidgets);

      // Tap Solo Play.
      await tester.tap(find.text('Solo Play'));
      await tester.pumpAndSettle();

      // Game screen should load and show playing state.
      expect(find.text('Solo Play'), findsOneWidget); // AppBar title
      expect(find.text('Would you rather...'), findsOneWidget);

      // Play through all 10 rounds.
      for (var round = 1; round <= 10; round++) {
        // Verify round indicator.
        expect(find.textContaining('Round $round/10'), findsOneWidget);

        // Should see the two options.
        expect(find.text('Option A $round'), findsOneWidget);
        expect(find.text('Option B $round'), findsOneWidget);

        // Tap option A.
        await tester.tap(find.text('Option A $round'));
        await tester.pumpAndSettle();

        // After answering, should see points earned.
        expect(find.textContaining('points'), findsOneWidget);

        if (round < 10) {
          // Not the last round - tap Next Round.
          await tester.tap(find.text('Next Round'));
          await tester.pumpAndSettle();
        } else {
          // Last round - should show Capture the Moment callout.
          expect(find.text('Capture the Moment'), findsOneWidget);
          expect(find.text('Skip'), findsOneWidget);
          expect(find.text('Take selfie'), findsOneWidget);

          // Skip capture to proceed to results.
          await tester.tap(find.text('Skip'));
          await tester.pumpAndSettle();
        }
      }

      // Should be on the results screen.
      expect(find.text('Total Points'), findsOneWidget);
      expect(find.text('Rounds'), findsOneWidget);
      expect(find.text('Avg Points'), findsOneWidget);
      expect(find.text('Best'), findsOneWidget);

      // Should show Home and Play Again buttons.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Play Again'), findsOneWidget);
    });

    testWidgets('can return home from results screen', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Navigate to solo game.
      await tester.tap(find.text('Solo Play'));
      await tester.pumpAndSettle();

      // Play through all rounds.
      for (var round = 1; round <= 10; round++) {
        await tester.tap(find.text('Option A $round'));
        await tester.pumpAndSettle();

        if (round < 10) {
          await tester.tap(find.text('Next Round'));
          await tester.pumpAndSettle();
        } else {
          await tester.tap(find.text('Skip'));
          await tester.pumpAndSettle();
        }
      }

      // On results screen - tap Home.
      expect(find.text('Total Points'), findsOneWidget);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      // Should be back on home screen.
      expect(find.text('Sync or Sink'), findsWidgets);
      expect(find.text('Solo Play'), findsOneWidget);
      expect(find.text('Create Challenge'), findsOneWidget);
    });

    testWidgets('play again starts a new game', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Play a full game.
      await tester.tap(find.text('Solo Play'));
      await tester.pumpAndSettle();

      for (var round = 1; round <= 10; round++) {
        await tester.tap(find.text('Option A $round'));
        await tester.pumpAndSettle();
        if (round < 10) {
          await tester.tap(find.text('Next Round'));
          await tester.pumpAndSettle();
        } else {
          await tester.tap(find.text('Skip'));
          await tester.pumpAndSettle();
        }
      }

      // Tap Play Again on results screen.
      expect(find.text('Play Again'), findsOneWidget);
      await tester.tap(find.text('Play Again'));
      await tester.pumpAndSettle();

      // Should be back on the game screen with round 1.
      expect(find.text('Would you rather...'), findsOneWidget);
      expect(find.textContaining('Round 1/10'), findsOneWidget);
    });
  });
}
