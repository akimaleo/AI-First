import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/leaderboard_provider.dart';
import '../../shared/models/leaderboard_entry.dart';
import '../../shared/widgets/player_avatar.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(leaderboardScopeProvider);
    final entries = ref.watch(leaderboardProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('home'),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(leaderboardProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<LeaderboardScope>(
              segments: const [
                ButtonSegment(
                  value: LeaderboardScope.global,
                  label: Text('Global'),
                  icon: Icon(Icons.public),
                ),
                ButtonSegment(
                  value: LeaderboardScope.friends,
                  label: Text('Friends'),
                  icon: Icon(Icons.group),
                ),
              ],
              selected: {scope},
              onSelectionChanged: (selection) {
                ref.read(leaderboardScopeProvider.notifier).state =
                    selection.first;
              },
            ),
          ),
        ),
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load leaderboard: $error'),
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  scope == LeaderboardScope.friends
                      ? 'No friends yet — follow players to see their scores.'
                      : 'No scores yet. Be the first!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(leaderboardProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = rows[index];
                final isMe = row.userId == currentUserId;
                return _LeaderboardTile(
                  entry: row,
                  rank: index + 1,
                  highlight: isMe,
                  onTap: () => context.pushNamed(
                    'profile',
                    pathParameters: {'userId': row.userId},
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.entry,
    required this.rank,
    this.highlight = false,
    this.onTap,
  });

  final LeaderboardEntry entry;
  final int rank;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rankLabel = _rankLabel(rank);
    final subtitleParts = <String>[
      '${entry.gamesPlayed} games',
      if (entry.gamesWon > 0) '${entry.gamesWon} wins',
    ];
    return ListTile(
      onTap: onTap,
      tileColor: highlight ? theme.colorScheme.primaryContainer : null,
      leading: SizedBox(
        width: 56,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                rankLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _rankColor(theme, rank),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PlayerAvatar(
              username: entry.username,
              avatarUrl: entry.avatarUrl,
            ),
          ],
        ),
      ),
      title: Text(
        entry.displayName?.isNotEmpty == true
            ? entry.displayName!
            : entry.username,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Text('@${entry.username} · ${subtitleParts.join(" · ")}'),
      trailing: Text(
        _formatScore(entry.totalScore),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _rankLabel(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '$rank';
    }
  }

  Color? _rankColor(ThemeData theme, int rank) {
    if (rank <= 3) return null;
    return theme.colorScheme.onSurfaceVariant;
  }

  String _formatScore(int score) {
    if (score >= 1000) {
      return '${(score / 1000).toStringAsFixed(1)}k';
    }
    return '$score';
  }
}
