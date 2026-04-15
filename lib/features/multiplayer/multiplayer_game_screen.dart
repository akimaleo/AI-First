import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/multiplayer_provider.dart';
import '../../shared/widgets/countdown_timer.dart';

class MultiplayerGameScreen extends ConsumerStatefulWidget {
  const MultiplayerGameScreen({super.key});

  @override
  ConsumerState<MultiplayerGameScreen> createState() =>
      _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends ConsumerState<MultiplayerGameScreen> {
  int _timerKey = 0;
  int? _lastRound;

  void _onTimerExpired() {
    final mp = ref.read(multiplayerProvider);
    if (!mp.hasAnsweredCurrentRound && mp.phase == MultiplayerPhase.playing) {
      ref.read(multiplayerProvider.notifier).submitAnswer('a');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mp = ref.watch(multiplayerProvider);
    final theme = Theme.of(context);
    final session = mp.session;
    final challenge = mp.currentChallenge;

    if (session != null && session.currentRound != _lastRound) {
      _lastRound = session.currentRound;
      _timerKey++;
    }

    ref.listen(multiplayerProvider, (prev, next) {
      if (next.phase == MultiplayerPhase.completed) {
        context.goNamed('challenge-results');
      }
    });

    if (session == null || challenge == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Score bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ScoreChip(
                    label: 'You',
                    score: mp.myScore,
                    color: theme.colorScheme.primary,
                  ),
                  Column(
                    children: [
                      Text(
                        'Round ${session.currentRound}/${session.totalRounds}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 120,
                        child: LinearProgressIndicator(
                          value:
                              session.currentRound / session.totalRounds,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  _ScoreChip(
                    label: 'Opponent',
                    score: mp.opponentScore,
                    color: theme.colorScheme.error,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!mp.hasAnsweredCurrentRound)
                CountdownTimer(
                  key: ValueKey('mp-timer-$_timerKey'),
                  durationSeconds: 30,
                  onExpired: _onTimerExpired,
                ),
              const SizedBox(height: 16),

              // Opponent status
              if (mp.hasAnsweredCurrentRound && !mp.opponentAnsweredCurrentRound)
                Card(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Waiting for opponent...'),
                      ],
                    ),
                  ),
                ),
              if (mp.opponentAnsweredCurrentRound && !mp.hasAnsweredCurrentRound)
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Text('Opponent has answered! Hurry!'),
                  ),
                ),

              const Spacer(),

              // Challenge prompt
              Text(
                'Would you rather...',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Option cards
              if (!mp.hasAnsweredCurrentRound) ...[
                Expanded(
                  flex: 2,
                  child: _OptionCard(
                    label: challenge.optionA,
                    color: theme.colorScheme.primaryContainer,
                    onTap: () => ref
                        .read(multiplayerProvider.notifier)
                        .submitAnswer('a'),
                  ),
                ),
                const SizedBox(height: 16),
                Text('OR', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                Expanded(
                  flex: 2,
                  child: _OptionCard(
                    label: challenge.optionB,
                    color: theme.colorScheme.secondaryContainer,
                    onTap: () => ref
                        .read(multiplayerProvider.notifier)
                        .submitAnswer('b'),
                  ),
                ),
              ] else ...[
                const Spacer(),
                Icon(
                  Icons.check_circle,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Answer submitted!',
                  style: theme.textTheme.titleLarge,
                ),
                if (!mp.opponentAnsweredCurrentRound) ...[
                  const SizedBox(height: 8),
                  const CircularProgressIndicator(),
                ],
                const Spacer(),
              ],

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.label,
    required this.score,
    required this.color,
  });

  final String label;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color),
          ),
          child: Text(
            '$score',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
