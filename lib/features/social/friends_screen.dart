import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/leaderboard_provider.dart';
import '../../shared/models/leaderboard_entry.dart';
import '../../shared/widgets/player_avatar.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.goNamed('home'),
          ),
        ),
        body: const Center(child: Text('Sign in to manage friends.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('home'),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Following'),
            Tab(text: 'Followers'),
            Tab(text: 'Find'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FollowingTab(userId: currentUserId),
          _FollowersTab(userId: currentUserId),
          const _SearchTab(),
        ],
      ),
    );
  }
}

class _FollowingTab extends ConsumerWidget {
  const _FollowingTab({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(followingListProvider(userId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (rows) {
        if (rows.isEmpty) {
          return const _EmptyState(
            icon: Icons.person_search,
            message: 'Find players in the Find tab to start following.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(followingListProvider(userId)),
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return _UserTile(
                entry: rows[index],
                trailing: OutlinedButton(
                  onPressed: () async {
                    await ref
                        .read(followControllerProvider.notifier)
                        .unfollow(rows[index].userId);
                  },
                  child: const Text('Unfollow'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FollowersTab extends ConsumerWidget {
  const _FollowersTab({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(followersListProvider(userId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (rows) {
        if (rows.isEmpty) {
          return const _EmptyState(
            icon: Icons.people_outline,
            message: 'No followers yet. Play some games to get noticed!',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(followersListProvider(userId)),
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _UserTile(entry: rows[index]),
          ),
        );
      },
    );
  }
}

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab();

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(userSearchProvider.notifier).search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(userSearchProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search by username',
              border: OutlineInputBorder(),
            ),
            onChanged: _onChanged,
          ),
        ),
        Expanded(
          child: results.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
            data: (rows) {
              if (_controller.text.trim().isEmpty) {
                return const _EmptyState(
                  icon: Icons.search,
                  message: 'Type a username to find players.',
                );
              }
              if (rows.isEmpty) {
                return const _EmptyState(
                  icon: Icons.person_off,
                  message: 'No players match that search.',
                );
              }
              return ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = rows[index];
                  return ListTile(
                    leading: PlayerAvatar(
                      username: user.username,
                      avatarUrl: user.avatarUrl,
                    ),
                    title: Text(
                      user.displayName?.isNotEmpty == true
                          ? user.displayName!
                          : user.username,
                    ),
                    subtitle: Text('@${user.username}'),
                    onTap: () => context.pushNamed(
                      'profile',
                      pathParameters: {'userId': user.userId},
                    ),
                    trailing: user.isFollowing
                        ? OutlinedButton(
                            onPressed: () async {
                              await ref
                                  .read(userSearchProvider.notifier)
                                  .toggleFollow(user);
                            },
                            child: const Text('Unfollow'),
                          )
                        : FilledButton(
                            onPressed: () async {
                              await ref
                                  .read(userSearchProvider.notifier)
                                  .toggleFollow(user);
                            },
                            child: const Text('Follow'),
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.entry, this.trailing});

  final LeaderboardEntry entry;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: PlayerAvatar(
        username: entry.username,
        avatarUrl: entry.avatarUrl,
      ),
      title: Text(
        entry.displayName?.isNotEmpty == true
            ? entry.displayName!
            : entry.username,
      ),
      subtitle: Text(
        '@${entry.username} · ${entry.totalScore} pts · ${entry.gamesPlayed} games',
      ),
      onTap: () => context.pushNamed(
        'profile',
        pathParameters: {'userId': entry.userId},
      ),
      trailing: trailing,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
