import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/multiplayer_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../shared/services/sentry_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _inviteController = TextEditingController();

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final currentUserId =
        ref.watch(supabaseClientProvider).auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync or Sink'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Leaderboard',
            icon: const Icon(Icons.leaderboard),
            onPressed: () => context.pushNamed('leaderboard'),
          ),
          IconButton(
            tooltip: 'Friends',
            icon: const Icon(Icons.group),
            onPressed: () => context.pushNamed('friends'),
          ),
          if (currentUserId != null)
            IconButton(
              tooltip: 'My profile',
              icon: const Icon(Icons.person),
              onPressed: () => context.pushNamed(
                'profile',
                pathParameters: {'userId': currentUserId},
              ),
            ),
          if (kDebugMode)
            IconButton(
              key: const Key('sentry-smoke-test'),
              tooltip: 'Throw test error (Sentry smoke test)',
              icon: const Icon(Icons.bug_report),
              onPressed: triggerSentrySmokeTest,
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sync or Sink',
                style: theme.textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Would You Rather — with friends',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 48),

              // Solo play
              FilledButton.icon(
                onPressed: () => context.goNamed('game'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Solo Play'),
              ),
              const SizedBox(height: 16),

              // Create challenge
              FilledButton.tonalIcon(
                onPressed: () async {
                  await ref
                      .read(multiplayerProvider.notifier)
                      .createSession();
                  if (context.mounted) {
                    context.goNamed('waiting-room');
                  }
                },
                icon: const Icon(Icons.group_add),
                label: const Text('Create Challenge'),
              ),
              const SizedBox(height: 24),

              // Join with code
              SizedBox(
                width: 280,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inviteController,
                        decoration: const InputDecoration(
                          hintText: 'Enter invite code',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () async {
                        final code = _inviteController.text.trim();
                        if (code.isEmpty) return;

                        final joined = await ref
                            .read(multiplayerProvider.notifier)
                            .joinSession(code);

                        if (joined && context.mounted) {
                          context.goNamed('waiting-room');
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Could not join. Check code and try again.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
