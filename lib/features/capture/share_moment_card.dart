import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Context passed from the game into the capture flow so the share card has
/// the score / prompt data needed to compose a branded moment.
class GameMomentContext {
  const GameMomentContext({
    required this.promptText,
    this.totalScore,
    this.totalRounds,
    this.challengeQuestion,
  });

  final String promptText;
  final int? totalScore;
  final int? totalRounds;
  final String? challengeQuestion;
}

/// Router payload for the capture route. Supports a bare prompt string for
/// callers that don't have game context.
class CaptureExtra {
  const CaptureExtra({required this.prompt, this.gameContext});

  factory CaptureExtra.prompt(String prompt) => CaptureExtra(prompt: prompt);

  static CaptureExtra from(Object? extra) {
    if (extra is CaptureExtra) return extra;
    if (extra is String) return CaptureExtra.prompt(extra);
    return const CaptureExtra(prompt: 'Capture the moment');
  }

  final String prompt;
  final GameMomentContext? gameContext;
}

/// Final share-card payload. Held in [lastShareCardProvider] so screens after
/// the capture flow (solo results, profile) can re-share without a reshoot.
class ShareCardData {
  const ShareCardData({
    required this.modifiedImagePath,
    required this.prompt,
    required this.usedFallback,
    required this.capturedAt,
    this.gameContext,
    this.pipelineLatencyMs,
  });

  final String modifiedImagePath;
  final String prompt;
  final bool usedFallback;
  final DateTime capturedAt;
  final GameMomentContext? gameContext;
  final int? pipelineLatencyMs;
}

/// Keeps the most recent share card so downstream screens (solo results, etc.)
/// can display and share it after the capture provider is reset.
final lastShareCardProvider = StateProvider<ShareCardData?>((ref) => null);

/// Loads the modified image as a local file or network resource depending on
/// the source returned by the selfie pipeline. Replicate returns remote URLs;
/// the fallback path is local disk.
class SelfieImage extends StatelessWidget {
  const SelfieImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;

  bool get _isRemote =>
      path.startsWith('http://') || path.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    if (_isRemote) {
      return Image.network(
        path,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        errorBuilder: (context, error, stack) =>
            const _ImageError(message: 'Could not load image'),
      );
    }
    return Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stack) =>
          const _ImageError(message: 'Image missing'),
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black26,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}

/// A shareable composite of the modified selfie plus the game score / prompt
/// overlay. Rendered inside a [RepaintBoundary] by callers that want to snap
/// a PNG for the share sheet.
class ShareMomentCard extends StatelessWidget {
  const ShareMomentCard({
    super.key,
    required this.data,
    this.aspectRatio = 4 / 5,
  });

  final ShareCardData data;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final ctx = data.gameContext;
    final prompt = ctx?.promptText.isNotEmpty == true
        ? ctx!.promptText
        : data.prompt;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B1B4B), Color(0xFF5E1B7A), Color(0xFFB02A7A)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.9,
                child: SelfieImage(path: data.modifiedImagePath),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x88000000),
                      Color(0x00000000),
                      Color(0xAA000000),
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: _Chip(
                      icon: Icons.flash_on,
                      label: 'Sync or Sink',
                    ),
                  ),
                  if (ctx?.totalScore != null)
                    Flexible(
                      child: _Chip(
                        icon: Icons.star,
                        label: '${ctx!.totalScore} pts',
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '“$prompt”',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(blurRadius: 8, color: Colors.black87),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (ctx?.totalRounds != null)
                        Text(
                          '${ctx!.totalRounds} rounds',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      if (data.usedFallback)
                        const Text(
                          'AI unavailable',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.amberAccent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
