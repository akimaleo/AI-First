import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/services/camera_service.dart';
import '../shared/services/selfie_pipeline_service.dart';
import 'ai_selfie_provider.dart';

final cameraServiceProvider = Provider<CameraService>((ref) {
  return CameraService();
});

final selfiePipelineServiceProvider = Provider<SelfiePipelineService>((ref) {
  return ref.watch(replicateSelfiePipelineServiceProvider);
});

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
    this.capturedImagePath,
    this.result,
    this.error,
  });

  final CapturePhase phase;
  final String? prompt;
  final String? capturedImagePath;
  final SelfiePipelineResult? result;
  final String? error;

  CaptureMomentState copyWith({
    CapturePhase? phase,
    String? prompt,
    String? capturedImagePath,
    SelfiePipelineResult? result,
    String? error,
  }) {
    return CaptureMomentState(
      phase: phase ?? this.phase,
      prompt: prompt ?? this.prompt,
      capturedImagePath: capturedImagePath ?? this.capturedImagePath,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }
}

class CaptureMomentNotifier extends Notifier<CaptureMomentState> {
  @override
  CaptureMomentState build() => const CaptureMomentState();

  Future<void> beginCapture(String prompt) async {
    state = CaptureMomentState(
      phase: CapturePhase.requestingPermission,
      prompt: prompt,
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

  Future<void> onPhotoCaptured(String imagePath) async {
    state = state.copyWith(
      phase: CapturePhase.processing,
      capturedImagePath: imagePath,
    );

    final pipeline = ref.read(selfiePipelineServiceProvider);
    final prompt = state.prompt ?? 'capture the moment';

    try {
      final result = await pipeline.transformSelfie(
        selfie: File(imagePath),
        prompt: prompt,
      );
      state = state.copyWith(
        phase: CapturePhase.completed,
        result: result,
      );
    } catch (e) {
      state = CaptureMomentState(
        phase: CapturePhase.error,
        prompt: state.prompt,
        capturedImagePath: state.capturedImagePath,
        error: e.toString(),
      );
    }
  }

  void setError(String message) {
    state = CaptureMomentState(
      phase: CapturePhase.error,
      prompt: state.prompt,
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
