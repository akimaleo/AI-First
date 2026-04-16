import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/leaderboard_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../shared/models/leaderboard_entry.dart';
import '../../shared/widgets/player_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(userId));
    final history = ref.watch(userHistoryProvider(userId));
    final currentUserId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final isMe = currentUserId != null && currentUserId == userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? 'My Profile' : 'Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('home');
            }
          },
        ),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load profile: $error'),
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userProfileProvider(userId));
              ref.invalidate(userHistoryProvider(userId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProfileHeader(
                  profile: user,
                  isMe: isMe,
                  onToggleFollow: () async {
                    final controller =
                        ref.read(followControllerProvider.notifier);
                    if (user.isFollowing) {
                      await controller.unfollow(user.userId);
                    } else {
                      await controller.follow(user.userId);
                    }
                  },
                ),
                const SizedBox(height: 16),
                _StatRow(profile: user),
                const SizedBox(height: 24),
                Text(
                  'Challenge History',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                history.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Could not load history: $error'),
                  ),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No completed games yet.'),
                      );
                    }
                    return Column(
                      children: [
                        for (final entry in entries)
                          _HistoryTile(entry: entry),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.isMe,
    required this.onToggleFollow,
  });

  final UserProfile profile;
  final bool isMe;
  final Future<void> Function() onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PlayerAvatar(
              username: profile.username,
              avatarUrl: profile.avatarUrl,
              radius: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName?.isNotEmpty == true
                        ? profile.displayName!
                        : profile.username,
                    style: theme.textTheme.headlineSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '@${profile.username}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(profile.bio!, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!isMe)
          SizedBox(
            width: double.infinity,
            child: profile.isFollowing
                ? OutlinedButton.icon(
                    onPressed: onToggleFollow,
                    icon: const Icon(Icons.person_remove),
                    label: const Text('Unfollow'),
                  )
                : FilledButton.icon(
                    onPressed: onToggleFollow,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Follow'),
                  ),
          ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget stat(String label, String value) {
      return Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            stat('Score', '${profile.totalScore}'),
            stat('Games', '${profile.gamesPlayed}'),
            stat('Wins', '${profile.gamesWon}'),
            stat('Followers', '${profile.followersCount}'),
            stat('Following', '${profile.followingCount}'),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = StringBuffer();
    subtitle.write(entry.isSolo ? 'Solo' : 'Versus (${entry.playerCount}p)');
    subtitle.write(' · ${entry.totalRounds} rounds');
    if (entry.completedAt != null) {
      subtitle.write(' · ${_formatDate(entry.completedAt!)}');
    }

    Widget trailing;
    if (entry.isSolo) {
      trailing = Text(
        '${entry.userPoints} pts',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      trailing = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${entry.userPoints} pts',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '#${entry.userRank} / ${entry.playerCount}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    }

    return ListTile(
      leading: Icon(
        entry.won ? Icons.emoji_events : Icons.flag,
        color: entry.won ? Colors.amber : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(entry.won ? 'Victory' : 'Played'),
      subtitle: Text(subtitle.toString()),
      trailing: trailing,
    );
  }

  String _formatDate(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
