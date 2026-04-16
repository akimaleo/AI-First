import 'dart:io';

import 'ai_selfie_service.dart';
import 'selfie_pipeline_service.dart';

/// Concrete [SelfiePipelineService] backed by the Supabase `selfie-transform`
/// edge function (Replicate under the hood).
///
/// The [prompt] must be a known [AiSelfiePromptKeys] key (e.g. `third_eye`).
/// Free-form prompts are rejected by the edge function for safety.
class ReplicateSelfiePipelineService implements SelfiePipelineService {
  ReplicateSelfiePipelineService(this._service, {this.stubOnFailure = true});

  final AiSelfieService _service;

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
    try {
      final job = await _service.transform(
        selfie: selfie,
        promptKey: prompt,
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
          prompt: prompt,
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
          prompt: prompt,
          usedFallback: true,
        );
      }
      rethrow;
    }
  }
}
