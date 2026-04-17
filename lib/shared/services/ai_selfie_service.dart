import 'dart:io';

import '../models/ai_selfie.dart';

/// Client for the AI selfie transform pipeline.
///
/// The Supabase edge function this service used to call has been removed as part
/// of the GUSAA-50 migration. All methods now throw [AiSelfieException] so the
/// pipeline falls back to the original selfie (via [stubOnFailure] in
/// [ReplicateSelfiePipelineService]).
class AiSelfieService {
  AiSelfieService();

  static const _unavailable =
      'Selfie transform unavailable — Supabase edge functions removed in GUSAA-50';

  Future<AiSelfieJob> transform({
    required File selfie,
    required String promptKey,
    String? sessionId,
    String? roundId,
  }) async {
    throw AiSelfieException(_unavailable);
  }

  Future<AiSelfieJob> startAsync({
    required File selfie,
    required String promptKey,
    String? sessionId,
    String? roundId,
  }) async {
    throw AiSelfieException(_unavailable);
  }

  Future<AiSelfieJob> pollJob(String jobId) async {
    throw AiSelfieException(_unavailable, jobId: jobId);
  }

  Future<AiSelfieJob> waitForJob(
    String jobId, {
    Duration timeout = const Duration(seconds: 45),
    Duration initialDelay = const Duration(milliseconds: 800),
  }) async {
    throw AiSelfieException(_unavailable, jobId: jobId);
  }

}

class AiSelfieException implements Exception {
  AiSelfieException(this.message, {this.jobId});

  final String message;
  final String? jobId;

  @override
  String toString() => 'AiSelfieException: $message';
}
