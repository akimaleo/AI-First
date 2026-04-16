import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/models/ai_selfie.dart';
import '../shared/services/ai_selfie_service.dart';
import '../shared/services/replicate_selfie_pipeline_service.dart';
import '../shared/services/selfie_pipeline_service.dart';
import 'supabase_provider.dart';

final aiSelfieServiceProvider = Provider<AiSelfieService>((ref) {
  return AiSelfieService(ref.watch(supabaseClientProvider));
});

final replicateSelfiePipelineServiceProvider =
    Provider<ReplicateSelfiePipelineService>((ref) {
  return ReplicateSelfiePipelineService(ref.watch(aiSelfieServiceProvider));
});

// `selfiePipelineServiceProvider` is declared in camera_provider.dart
// (introduced by GUSAA-10) and points at this real implementation via
// `replicateSelfiePipelineServiceProvider` above.

final aiSelfiePromptsProvider = Provider<List<AiSelfiePrompt>>((ref) {
  return AiSelfiePromptKeys.all;
});

class AiSelfieRequest {
  const AiSelfieRequest({
    required this.selfie,
    required this.promptKey,
    this.sessionId,
    this.roundId,
  });

  final File selfie;
  final String promptKey;
  final String? sessionId;
  final String? roundId;
}

/// One-shot transform. UI listens to the AsyncValue for loading/error states.
final aiSelfieTransformProvider = FutureProvider.autoDispose
    .family<SelfiePipelineResult, AiSelfieRequest>((ref, request) async {
  final pipeline = ref.watch(replicateSelfiePipelineServiceProvider);
  return pipeline.transformSelfieInSession(
    selfie: request.selfie,
    prompt: request.promptKey,
    sessionId: request.sessionId,
    roundId: request.roundId,
  );
});
