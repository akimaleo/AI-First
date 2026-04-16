import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/game_provider.dart';
import '../../shared/widgets/countdown_timer.dart';
import '../capture/share_moment_card.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final _timerKey = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      // Clear any stale share card from a prior game before starting fresh.
      ref.read(lastShareCardProvider.notifier).state = null;
      ref.read(gameProvider.notifier).startGame();
    });
  }

  @override
  void dispose() {
    _timerKey.dispose();
    super.dispose();
  }

  void _onTimerExpired() {
    final state = ref.read(gameProvider);
    if (!state.hasAnswered && state.phase == SoloPhase.playing) {
      ref.read(gameProvider.notifier).submitAnswer('a');
    }
  }

  String _capturePromptFor(SoloGameState state) {
    final challenge = state.currentChallenge;
    if (challenge == null) {
      return 'Capture your reaction to this round!';
    }
    final lastChoice =
        state.roundChoices.isNotEmpty ? state.roundChoices.last : null;
    final chosen = lastChoice == 'a'
        ? challenge.optionA
        : lastChoice == 'b'
            ? challenge.optionB
            : challenge.optionA;
    return 'Your face: "$chosen"';
  }

  Future<void> _launchCaptureMoment(SoloGameState state) async {
    final prompt = _capturePromptFor(state);
    await context.pushNamed(
      'capture',
      extra: CaptureExtra(
        prompt: prompt,
        gameContext: GameMomentContext(
          promptText: prompt,
          totalScore: state.totalScore,
          totalRounds: state.totalRounds,
          challengeQuestion: state.currentChallenge == null
              ? null
              : 'Would you rather... ${state.currentChallenge!.optionA}'
                  ' OR ${state.currentChallenge!.optionB}',
        ),
      ),
    );
    if (!mounted) return;
    _timerKey.value++;
    ref.read(gameProvider.notifier).nextRound();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameProvider);
    final theme = Theme.of(context);

    ref.listen(gameProvider, (prev, next) {
      if (next.phase == SoloPhase.completed) {
        context.goNamed('solo-results');
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(gameProvider.notifier).reset();
            context.goNamed('home');
          },
        ),
        title: const Text('Solo Play'),
      ),
      body: _buildBody(state, theme),
    );
  }

  Widget _buildBody(SoloGameState state, ThemeData theme) {
    switch (state.phase) {
      case SoloPhase.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading challenges...'),
            ],
          ),
        );

      case SoloPhase.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  state.error ?? 'Something went wrong',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => ref.read(gameProvider.notifier).startGame(),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        );

      case SoloPhase.playing:
        return _buildPlaying(state, theme);

      case SoloPhase.completed:
        return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildPlaying(SoloGameState state, ThemeData theme) {
    final challenge = state.currentChallenge;
    if (challenge == null) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Score: ${state.totalScore}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Column(
                  children: [
                    Text(
                      'Round ${state.currentRound}/${state.totalRounds}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(
                        value: state.currentRound / state.totalRounds,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                ValueListenableBuilder<int>(
                  valueListenable: _timerKey,
                  builder: (context, key, _) => CountdownTimer(
                    key: ValueKey('timer-$key'),
                    durationSeconds: 30,
                    onExpired: _onTimerExpired,
                    isPaused: state.hasAnswered,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              'Would you rather...',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (!state.hasAnswered) ...[
              Expanded(
                flex: 2,
                child: _OptionCard(
                  label: challenge.optionA,
                  color: theme.colorScheme.primaryContainer,
                  onTap: () =>
                      ref.read(gameProvider.notifier).submitAnswer('a'),
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
                  onTap: () =>
                      ref.read(gameProvider.notifier).submitAnswer('b'),
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
                '+${state.lastPointsEarned} points',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              if (state.isLastRound)
                _CaptureMomentCallout(
                  prompt: _capturePromptFor(state),
                  onCapture: () => _launchCaptureMoment(state),
                  onSkip: () {
                    _timerKey.value++;
                    ref.read(gameProvider.notifier).nextRound();
                  },
                )
              else
                FilledButton(
                  onPressed: () {
                    _timerKey.value++;
                    ref.read(gameProvider.notifier).nextRound();
                  },
                  child: const Text('Next Round'),
                ),
              const Spacer(),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _CaptureMomentCallout extends StatelessWidget {
  const _CaptureMomentCallout({
    required this.prompt,
    required this.onCapture,
    required this.onSkip,
  });

  final String prompt;
  final VoidCallback onCapture;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt,
                      color: theme.colorScheme.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Text(
                    'Capture the Moment',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                prompt,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onSkip,
                child: const Text('Skip'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: onCapture,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take selfie'),
              ),
            ),
          ],
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
