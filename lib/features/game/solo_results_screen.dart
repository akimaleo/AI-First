import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/game_provider.dart';
import '../capture/share_moment_card.dart';

class SoloResultsScreen extends ConsumerWidget {
  const SoloResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final shareCard = ref.watch(lastShareCardProvider);
    final theme = Theme.of(context);

    final maxPossible = state.totalRounds * 100;
    final percentage = maxPossible > 0
        ? (state.totalScore / maxPossible * 100).round()
        : 0;

    final icon = percentage >= 80
        ? Icons.emoji_events
        : percentage >= 50
            ? Icons.thumb_up
            : Icons.sentiment_neutral;
    final iconColor = percentage >= 80
        ? Colors.amber
        : percentage >= 50
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant;
    final message = percentage >= 80
        ? 'Amazing!'
        : percentage >= 50
            ? 'Well done!'
            : 'Keep practicing!';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Icon(icon, size: 80, color: iconColor),
              const SizedBox(height: 16),
              Text(
                message,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        '${state.totalScore}',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Total Points',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(
                            label: 'Rounds',
                            value: '${state.totalRounds}',
                          ),
                          _StatItem(
                            label: 'Avg Points',
                            value: state.roundScores.isNotEmpty
                                ? '${(state.totalScore / state.roundScores.length).round()}'
                                : '0',
                          ),
                          _StatItem(
                            label: 'Best',
                            value: state.roundScores.isNotEmpty
                                ? '${state.roundScores.reduce((a, b) => a > b ? a : b)}'
                                : '0',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (shareCard != null) ...[
                const SizedBox(height: 16),
                _MomentCardTile(shareCard: shareCard),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: state.roundScores.length,
                  itemBuilder: (context, index) {
                    final challenge = index < state.challenges.length
                        ? state.challenges[index]
                        : null;
                    final choice = index < state.roundChoices.length
                        ? state.roundChoices[index]
                        : null;
                    final score = state.roundScores[index];

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: score >= 75
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.2),
                        child: Text(
                          '${index + 1}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                      title: Text(
                        challenge != null
                            ? (choice == 'a'
                                ? challenge.optionA
                                : challenge.optionB)
                            : 'Round ${index + 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        '+$score',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: score >= 75
                              ? Colors.green
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(gameProvider.notifier).reset();
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
                        ref.read(gameProvider.notifier).startGame();
                        context.goNamed('game');
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
}

class _MomentCardTile extends StatelessWidget {
  const _MomentCardTile({required this.shareCard});

  final ShareCardData shareCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.goNamed('capture-result'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 90,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SelfieImage(path: shareCard.modifiedImagePath),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Capture the Moment',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shareCard.gameContext?.promptText ?? shareCard.prompt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.ios_share),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
