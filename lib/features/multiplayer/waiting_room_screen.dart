import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/multiplayer_provider.dart';
import '../../shared/services/share_links.dart';

class WaitingRoomScreen extends ConsumerWidget {
  const WaitingRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mp = ref.watch(multiplayerProvider);
    final theme = Theme.of(context);

    ref.listen(multiplayerProvider, (prev, next) {
      if (next.phase == MultiplayerPhase.playing) {
        context.goNamed('multiplayer-game');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Room'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(multiplayerProvider.notifier).reset();
            context.goNamed('home');
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Invite Code',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mp.inviteCode,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: mp.inviteCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Code copied!')),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () {
                            final me = mp.participants
                                .where((p) =>
                                    p.userId == mp.session?.hostId)
                                .firstOrNull;
                            Share.share(
                              ShareLinks.inviteShareText(
                                inviteCode: mp.inviteCode,
                                fromUsername: me?.username,
                              ),
                              subject: 'Sync or Sink challenge',
                            );
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Players (${mp.participantCount}/2)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: mp.participants.length,
                itemBuilder: (context, index) {
                  final p = mp.participants[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (p.displayName ?? p.username ?? 'P')
                              .substring(0, 1)
                              .toUpperCase(),
                        ),
                      ),
                      title: Text(p.displayName ?? p.username ?? 'Player'),
                      subtitle: p.userId == mp.session?.hostId
                          ? const Text('Host')
                          : null,
                      trailing: Icon(
                        p.isReady ? Icons.check_circle : Icons.circle_outlined,
                        color: p.isReady ? Colors.green : Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (!mp.isHost)
              FilledButton.icon(
                onPressed: () =>
                    ref.read(multiplayerProvider.notifier).toggleReady(),
                icon: const Icon(Icons.check),
                label: Text(
                  mp.participants
                          .where(
                              (p) => p.userId == mp.session?.hostId)
                          .firstOrNull
                          ?.isReady ??
                      false
                      ? 'Unready'
                      : 'Ready Up',
                ),
              ),
            if (mp.isHost) ...[
              FilledButton.icon(
                onPressed: () =>
                    ref.read(multiplayerProvider.notifier).toggleReady(),
                icon: const Icon(Icons.check),
                label: const Text('Ready Up'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: mp.allReady && mp.participantCount >= 2
                    ? () =>
                        ref.read(multiplayerProvider.notifier).startGame()
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Game'),
              ),
            ],
            if (mp.error != null) ...[
              const SizedBox(height: 8),
              Text(
                mp.error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
