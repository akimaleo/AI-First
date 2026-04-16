import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/game/game_screen.dart';
import '../features/game/solo_results_screen.dart';
import '../features/multiplayer/waiting_room_screen.dart';
import '../features/multiplayer/multiplayer_game_screen.dart';
import '../features/multiplayer/challenge_results_screen.dart';
import '../features/social/friends_screen.dart';
import '../features/social/leaderboard_screen.dart';
import '../features/social/profile_screen.dart';
import '../features/capture/capture_moment_screen.dart';
import '../features/capture/capture_result_screen.dart';
import '../features/capture/share_moment_card.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/game',
        name: 'game',
        builder: (context, state) => const GameScreen(),
      ),
      GoRoute(
        path: '/solo-results',
        name: 'solo-results',
        builder: (context, state) => const SoloResultsScreen(),
      ),
      GoRoute(
        path: '/waiting-room',
        name: 'waiting-room',
        builder: (context, state) => const WaitingRoomScreen(),
      ),
      GoRoute(
        path: '/multiplayer-game',
        name: 'multiplayer-game',
        builder: (context, state) => const MultiplayerGameScreen(),
      ),
      GoRoute(
        path: '/challenge-results',
        name: 'challenge-results',
        builder: (context, state) => const ChallengeResultsScreen(),
      ),
      GoRoute(
        path: '/leaderboard',
        name: 'leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/friends',
        name: 'friends',
        builder: (context, state) => const FriendsScreen(),
      ),
      GoRoute(
        path: '/profile/:userId',
        name: 'profile',
        builder: (context, state) => ProfileScreen(
          userId: state.pathParameters['userId']!,
        ),
      ),
      GoRoute(
        path: '/capture',
        name: 'capture',
        builder: (context, state) {
          final extra = CaptureExtra.from(state.extra);
          return CaptureMomentScreen(extra: extra);
        },
      ),
      GoRoute(
        path: '/capture-result',
        name: 'capture-result',
        builder: (context, state) => const CaptureResultScreen(),
      ),
      GoRoute(
        path: '/join/:code',
        name: 'join',
        redirect: (context, state) {
          return '/waiting-room?invite=${state.pathParameters['code']}';
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
