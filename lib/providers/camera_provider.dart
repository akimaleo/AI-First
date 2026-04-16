import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/capture/share_moment_card.dart';
import '../shared/services/camera_service.dart';
import '../shared/services/selfie_pipeline_service.dart';
import 'ai_selfie_provider.dart';

final cameraServiceProvider = Provider<CameraService>((ref) {
  return CameraService();
});

final selfiePipelineServiceProvider = Provider<SelfiePipelineService>((ref) {
  return ref.watch(replicateSelfiePipelineServiceProvider);
});

/// Target end-to-end budget for the Capture the Moment flow (GUSAA-12).
/// If the AI transform does not finish within this window we fall back to
/// the unmodified selfie so the user is never stuck waiting.
const Duration kCaptureMomentBudget = Duration(seconds: 7);

enum CapturePhase {
  idle,
  requestingPermission,
  permissionDenied,
  permissionPermanentlyDenied,
  ready,
  capturing,
  processing,
  completed,
  error,
}

class CaptureMomentState {
  const CaptureMomentState({
    this.phase = CapturePhase.idle,
    this.prompt,
    this.gameContext,
    this.capturedImagePath,
    this.result,
    this.error,
    this.pipelineStartedAt,
    this.pipelineCompletedAt,
  });

  final CapturePhase phase;
  final String? prompt;
  final GameMomentContext? gameContext;
  final String? capturedImagePath;
  final SelfiePipelineResult? result;
  final String? error;
  final DateTime? pipelineStartedAt;
  final DateTime? pipelineCompletedAt;

  /// Pipeline elapsed time in milliseconds; null until pipeline completes.
  int? get pipelineElapsedMs {
    final start = pipelineStartedAt;
    final end = pipelineCompletedAt;
    if (start == null || end == null) return null;
    return end.difference(start).inMilliseconds;
  }

  CaptureMomentState copyWith({
    CapturePhase? phase,
    String? prompt,
    GameMomentContext? gameContext,
    String? capturedImagePath,
    SelfiePipelineResult? result,
    String? error,
    DateTime? pipelineStartedAt,
    DateTime? pipelineCompletedAt,
  }) {
    return CaptureMomentState(
      phase: phase ?? this.phase,
      prompt: prompt ?? this.prompt,
      gameContext: gameContext ?? this.gameContext,
      capturedImagePath: capturedImagePath ?? this.capturedImagePath,
      result: result ?? this.result,
      error: error ?? this.error,
      pipelineStartedAt: pipelineStartedAt ?? this.pipelineStartedAt,
      pipelineCompletedAt: pipelineCompletedAt ?? this.pipelineCompletedAt,
    );
  }
}

class CaptureMomentNotifier extends Notifier<CaptureMomentState> {
  @override
  CaptureMomentState build() => const CaptureMomentState();

  /// Wall-clock for deadline enforcement. Overridable in tests.
  DateTime Function() _now = DateTime.now;

  /// Visible for testing — lets tests inject a fake clock.
  // ignore: use_setters_to_change_properties
  void debugSetClock(DateTime Function() clock) {
    _now = clock;
  }

  Future<void> beginCapture(
    String prompt, {
    GameMomentContext? gameContext,
  }) async {
    state = CaptureMomentState(
      phase: CapturePhase.requestingPermission,
      prompt: prompt,
      gameContext: gameContext,
    );

    final service = ref.read(cameraServiceProvider);
    final status = await service.requestPermission();

    switch (status) {
      case CameraPermissionStatus.granted:
        state = state.copyWith(phase: CapturePhase.ready);
        break;
      case CameraPermissionStatus.denied:
        state = state.copyWith(phase: CapturePhase.permissionDenied);
        break;
      case CameraPermissionStatus.permanentlyDenied:
        state = state.copyWith(phase: CapturePhase.permissionPermanentlyDenied);
        break;
    }
  }

  void markCapturing() {
    state = state.copyWith(phase: CapturePhase.capturing);
  }

  Future<void> onPhotoCaptured(
    String imagePath, {
    Duration budget = kCaptureMomentBudget,
  }) async {
    final startedAt = _now();
    state = state.copyWith(
      phase: CapturePhase.processing,
      capturedImagePath: imagePath,
      pipelineStartedAt: startedAt,
    );

    final pipeline = ref.read(selfiePipelineServiceProvider);
    final prompt = state.prompt ?? 'capture the moment';

    SelfiePipelineResult result;
    try {
      result = await pipeline
          .transformSelfie(selfie: File(imagePath), prompt: prompt)
          .timeout(
        budget,
        onTimeout: () {
          // Soft fallback: keep the user moving if the AI is slow. GUSAA-12
          // deliverable requires the full flow to complete under 8s on a
          // mid-range device.
          return SelfiePipelineResult(
            modifiedImagePath: imagePath,
            originalImagePath: imagePath,
            prompt: prompt,
            usedFallback: true,
          );
        },
      );
    } catch (_) {
      // Last-resort safety net. ReplicateSelfiePipelineService already stubs
      // on failure, but any other SelfiePipelineService impl might throw — we
      // degrade to the unmodified selfie rather than surface a dead-end error.
      result = SelfiePipelineResult(
        modifiedImagePath: imagePath,
        originalImagePath: imagePath,
        prompt: prompt,
        usedFallback: true,
      );
    }

    final completedAt = _now();
    final latencyMs = completedAt.difference(startedAt).inMilliseconds;

    state = state.copyWith(
      phase: CapturePhase.completed,
      result: result,
      pipelineCompletedAt: completedAt,
    );

    ref.read(lastShareCardProvider.notifier).state = ShareCardData(
      modifiedImagePath: result.modifiedImagePath,
      prompt: result.prompt,
      usedFallback: result.usedFallback,
      capturedAt: completedAt,
      gameContext: state.gameContext,
      pipelineLatencyMs: latencyMs,
    );
  }

  void setError(String message) {
    state = CaptureMomentState(
      phase: CapturePhase.error,
      prompt: state.prompt,
      gameContext: state.gameContext,
      capturedImagePath: state.capturedImagePath,
      error: message,
    );
  }

  void reset() {
    state = const CaptureMomentState();
  }
}

final captureMomentProvider =
    NotifierProvider<CaptureMomentNotifier, CaptureMomentState>(
  CaptureMomentNotifier.new,
);
