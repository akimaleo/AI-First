import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/auth_provider.dart';
import '../../providers/multiplayer_provider.dart';
import '../../shared/models/score.dart';
import '../../shared/services/share_links.dart';

class ChallengeResultsScreen extends ConsumerWidget {
  const ChallengeResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mp = ref.watch(multiplayerProvider);
    final theme = Theme.of(context);
    final myId = ref.watch(currentUserIdProvider);
    final scores = mp.playerScores;

    final isWinner =
        scores.isNotEmpty && scores.first.userId == myId;
    final isTie = scores.length >= 2 &&
        scores[0].totalPoints == scores[1].totalPoints;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Icon(
                isTie
                    ? Icons.handshake
                    : isWinner
                        ? Icons.emoji_events
                        : Icons.sentiment_dissatisfied,
                size: 80,
                color: isTie
                    ? Colors.orange
                    : isWinner
                        ? Colors.amber
                        : theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                isTie
                    ? "It's a Tie!"
                    : isWinner
                        ? 'You Win!'
                        : 'You Lose!',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Final Scores',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.builder(
                  itemCount: scores.length,
                  itemBuilder: (context, index) {
                    final score = scores[index];
                    final isMe = score.userId == myId;
                    return Card(
                      color: isMe
                          ? theme.colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: index == 0
                              ? Colors.amber
                              : theme.colorScheme.surfaceContainerHighest,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: index == 0
                                  ? Colors.black
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        title: Text(
                          isMe ? 'You' : score.username,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle:
                            Text('${score.roundsAnswered} rounds answered'),
                        trailing: Text(
                          '${score.totalPoints} pts',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isMe
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (scores.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _shareResults(
                      scores: scores,
                      myId: myId,
                      isWinner: isWinner,
                      isTie: isTie,
                    ),
                    icon: const Icon(Icons.share),
                    label: const Text('Share result'),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(multiplayerProvider.notifier).reset();
                        context.goNamed('home');
                      },
                      icon: const Icon(Icons.home),
                      label: const Text('Home'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        ref.read(multiplayerProvider.notifier).reset();
                        ref
                            .read(multiplayerProvider.notifier)
                            .createSession();
                        context.goNamed('waiting-room');
                      },
                      icon: const Icon(Icons.replay),
                      label: const Text('Play Again'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareResults({
    required List<PlayerScore> scores,
    required String? myId,
    required bool isWinner,
    required bool isTie,
  }) async {
    final me = myId == null
        ? null
        : scores.where((s) => s.userId == myId).firstOrNull;
    final opponent = myId == null
        ? null
        : scores.where((s) => s.userId != myId).firstOrNull;

    final outcome = isTie
        ? 'tied'
        : isWinner
            ? 'won'
            : 'lost';
    final score = me?.totalPoints;
    final handle = me?.username;
    final vs = opponent != null
        ? ' vs @${opponent.username} (${opponent.totalPoints} pts)'
        : '';
    final prompt = score != null
        ? 'I $outcome $score pts$vs in Sync or Sink!'
        : 'I $outcome my Sync or Sink match$vs!';

    await Share.share(
      ShareLinks.momentShareText(
        fromUsername: handle,
        totalScore: score,
        promptText: prompt,
      ),
      subject: 'Sync or Sink result',
    );
  }
}
