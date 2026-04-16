import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/camera_provider.dart';
import '../../shared/services/share_card_renderer.dart';
import 'share_moment_card.dart';

final shareCardRendererProvider = Provider<ShareCardRenderer>(
  (ref) => ShareCardRenderer(),
);

class CaptureResultScreen extends ConsumerStatefulWidget {
  const CaptureResultScreen({super.key});

  @override
  ConsumerState<CaptureResultScreen> createState() =>
      _CaptureResultScreenState();
}

class _CaptureResultScreenState extends ConsumerState<CaptureResultScreen> {
  final GlobalKey _cardBoundaryKey = GlobalKey();
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final captureState = ref.watch(captureMomentProvider);
    final shareCard = ref.watch(lastShareCardProvider);
    final theme = Theme.of(context);

    if (shareCard == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Capture the Moment')),
        body: const Center(child: Text('No capture to show.')),
      );
    }

    final latencyMs = captureState.pipelineElapsedMs ??
        shareCard.pipelineLatencyMs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Moment'),
        actions: [
          IconButton(
            tooltip: 'Done',
            icon: const Icon(Icons.check),
            onPressed: () => _finish(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: RepaintBoundary(
                    key: _cardBoundaryKey,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: ShareMomentCard(data: shareCard),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (shareCard.usedFallback)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "AI transform didn't finish in time — your original"
                          ' selfie is on the card.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              if (latencyMs != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Ready in ${(latencyMs / 1000).toStringAsFixed(1)}s',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(captureMomentProvider.notifier).reset();
                        context.pushReplacementNamed(
                          'capture',
                          extra: CaptureExtra(
                            prompt: shareCard.prompt,
                            gameContext: shareCard.gameContext,
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _sharing ? null : _share,
                      icon: _sharing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.ios_share),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _finish(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _finish(BuildContext context) {
    ref.read(captureMomentProvider.notifier).reset();
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('home');
    }
  }

  Future<void> _share() async {
    final boundary = _cardBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    final shareCard = ref.read(lastShareCardProvider);
    if (boundary == null || shareCard == null) return;

    setState(() => _sharing = true);
    try {
      final renderer = ref.read(shareCardRendererProvider);
      final file = await renderer.exportToPng(boundary);
      final promptText =
          shareCard.gameContext?.promptText ?? shareCard.prompt;
      final score = shareCard.gameContext?.totalScore;
      final text = score != null
          ? 'I scored $score in Sync or Sink! $promptText'
          : promptText;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
        subject: 'My Sync or Sink moment',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}
