import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/models/leaderboard_entry.dart';
import 'supabase_provider.dart';

enum LeaderboardScope { global, friends }

final leaderboardScopeProvider =
    StateProvider<LeaderboardScope>((ref) => LeaderboardScope.global);

final leaderboardProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  final scope = ref.watch(leaderboardScopeProvider);
  return switch (scope) {
    LeaderboardScope.global => service.getGlobalLeaderboard(),
    LeaderboardScope.friends => service.getFriendsLeaderboard(),
  };
});

final myProfileProvider =
    FutureProvider.autoDispose<UserProfile?>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.getMyProfile();
});

final userProfileProvider =
    FutureProvider.autoDispose.family<UserProfile?, String>(
  (ref, userId) async {
    final service = ref.watch(supabaseServiceProvider);
    return service.getUserProfile(userId);
  },
);

final userHistoryProvider =
    FutureProvider.autoDispose.family<List<HistoryEntry>, String>(
  (ref, userId) async {
    final service = ref.watch(supabaseServiceProvider);
    return service.getUserHistory(userId);
  },
);

final followingListProvider =
    FutureProvider.autoDispose.family<List<LeaderboardEntry>, String>(
  (ref, userId) async {
    final service = ref.watch(supabaseServiceProvider);
    return service.listFollowing(userId);
  },
);

final followersListProvider =
    FutureProvider.autoDispose.family<List<LeaderboardEntry>, String>(
  (ref, userId) async {
    final service = ref.watch(supabaseServiceProvider);
    return service.listFollowers(userId);
  },
);

class UserSearchController
    extends AutoDisposeAsyncNotifier<List<UserSearchResult>> {
  @override
  Future<List<UserSearchResult>> build() async => const [];

  Future<void> search(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(supabaseServiceProvider).searchUsers(trimmed),
    );
  }

  Future<void> toggleFollow(UserSearchResult user) async {
    final service = ref.read(supabaseServiceProvider);
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = [
      for (final u in current)
        u.userId == user.userId
            ? u.copyWith(isFollowing: !user.isFollowing)
            : u,
    ];
    state = AsyncData(updated);

    try {
      if (user.isFollowing) {
        await service.unfollowUser(user.userId);
      } else {
        await service.followUser(user.userId);
      }
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }

    ref.invalidate(leaderboardProvider);
  }
}

final userSearchProvider = AutoDisposeAsyncNotifierProvider<
    UserSearchController, List<UserSearchResult>>(
  UserSearchController.new,
);

class FollowController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> follow(String userId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(supabaseServiceProvider).followUser(userId),
    );
    _invalidate(userId);
  }

  Future<void> unfollow(String userId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(supabaseServiceProvider).unfollowUser(userId),
    );
    _invalidate(userId);
  }

  void _invalidate(String userId) {
    ref.invalidate(userProfileProvider(userId));
    ref.invalidate(leaderboardProvider);
    ref.invalidate(followingListProvider);
    ref.invalidate(followersListProvider);
    ref.invalidate(myProfileProvider);
  }
}

final followControllerProvider =
    AutoDisposeAsyncNotifierProvider<FollowController, void>(
  FollowController.new,
);
