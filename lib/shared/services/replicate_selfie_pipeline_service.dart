import 'dart:io';
import 'dart:math';

import '../models/ai_selfie.dart';
import 'ai_selfie_service.dart';
import 'selfie_pipeline_service.dart';

/// Concrete [SelfiePipelineService] backed by the Supabase `selfie-transform`
/// edge function (Replicate under the hood).
///
/// The [prompt] parameter accepts either:
/// - a known [AiSelfiePromptKeys] key (e.g. `third_eye`)
/// - any other string, in which case a random prompt key is chosen so the
///   camera flow can supply a free-form description (like the round's
///   game copy) without knowing the enum.
class ReplicateSelfiePipelineService implements SelfiePipelineService {
  ReplicateSelfiePipelineService(
    this._service, {
    this.stubOnFailure = true,
    Random? random,
  }) : _random = random ?? Random.secure();

  final AiSelfieService _service;
  final Random _random;

  /// When true, fall back to returning the original selfie as a stub result if
  /// the AI call fails. Keeps the game playable when Replicate is degraded.
  final bool stubOnFailure;

  @override
  Future<SelfiePipelineResult> transformSelfie({
    required File selfie,
    required String prompt,
  }) {
    return transformSelfieInSession(selfie: selfie, prompt: prompt);
  }

  /// Session-aware variant that tags the generated job with game session/round
  /// ids so the output can be shown to other participants and retained for
  /// social sharing replays.
  Future<SelfiePipelineResult> transformSelfieInSession({
    required File selfie,
    required String prompt,
    String? sessionId,
    String? roundId,
  }) async {
    final resolvedKey = _resolvePromptKey(prompt);
    try {
      final job = await _service.transform(
        selfie: selfie,
        promptKey: resolvedKey,
        sessionId: sessionId,
        roundId: roundId,
      );
      final finished = job.status == AiSelfieStatus.processing
          ? await _service.waitForJob(job.jobId)
          : job;
      if (finished.status == AiSelfieStatus.succeeded &&
          finished.outputUrl != null) {
        return SelfiePipelineResult(
          modifiedImagePath: finished.outputUrl!,
          originalImagePath: selfie.path,
          prompt: resolvedKey,
        );
      }
      throw AiSelfieException(
        finished.error ??
            'Transform did not succeed (status: ${finished.status.name})',
        jobId: finished.jobId,
      );
    } catch (err) {
      if (stubOnFailure) {
        return SelfiePipelineResult(
          modifiedImagePath: selfie.path,
          originalImagePath: selfie.path,
          prompt: resolvedKey,
          usedFallback: true,
        );
      }
      rethrow;
    }
  }

  String _resolvePromptKey(String input) {
    final normalized = input.trim().toLowerCase().replaceAll(' ', '_');
    final match = AiSelfiePromptKeys.all
        .where((p) => p.key == normalized)
        .firstOrNull;
    if (match != null) return match.key;
    // Surprise filter on free-form prompts — matches the game's design.
    final keys = AiSelfiePromptKeys.all;
    return keys[_random.nextInt(keys.length)].key;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
