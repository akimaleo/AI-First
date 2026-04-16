import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_or_sink/features/capture/share_moment_card.dart';
import 'package:sync_or_sink/providers/camera_provider.dart';
import 'package:sync_or_sink/shared/services/camera_service.dart';
import 'package:sync_or_sink/shared/services/selfie_pipeline_service.dart';

class _GrantedCameraService extends CameraService {
  @override
  Future<CameraPermissionStatus> requestPermission() async {
    return CameraPermissionStatus.granted;
  }
}

class _SlowPipeline implements SelfiePipelineService {
  @override
  Future<SelfiePipelineResult> transformSelfie({
    required File selfie,
    required String prompt,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 30));
    return SelfiePipelineResult(
      modifiedImagePath: selfie.path,
      originalImagePath: selfie.path,
      prompt: prompt,
    );
  }
}

class _ThrowingPipeline implements SelfiePipelineService {
  @override
  Future<SelfiePipelineResult> transformSelfie({
    required File selfie,
    required String prompt,
  }) {
    throw Exception('pipeline exploded');
  }
}

class _FastPipeline implements SelfiePipelineService {
  @override
  Future<SelfiePipelineResult> transformSelfie({
    required File selfie,
    required String prompt,
  }) async {
    return SelfiePipelineResult(
      modifiedImagePath: 'https://cdn.example.com/modified.png',
      originalImagePath: selfie.path,
      prompt: prompt,
    );
  }
}

void main() {
  group('CaptureMomentNotifier', () {
    test('falls back to original selfie when pipeline exceeds budget',
        () async {
      final container = ProviderContainer(
        overrides: [
          selfiePipelineServiceProvider.overrideWithValue(_SlowPipeline()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(captureMomentProvider.notifier);
      await notifier.onPhotoCaptured(
        '/tmp/fake-selfie.jpg',
        budget: const Duration(milliseconds: 20),
      );

      final state = container.read(captureMomentProvider);
      expect(state.phase, CapturePhase.completed);
      expect(state.result, isNotNull);
      expect(state.result!.usedFallback, isTrue);
      expect(state.result!.modifiedImagePath, '/tmp/fake-selfie.jpg');

      final card = container.read(lastShareCardProvider);
      expect(card, isNotNull);
      expect(card!.usedFallback, isTrue);
    });

    test('falls back when pipeline throws', () async {
      final container = ProviderContainer(
        overrides: [
          selfiePipelineServiceProvider.overrideWithValue(_ThrowingPipeline()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(captureMomentProvider.notifier);
      await notifier.onPhotoCaptured('/tmp/fake-selfie.jpg');

      final state = container.read(captureMomentProvider);
      expect(state.phase, CapturePhase.completed);
      expect(state.result!.usedFallback, isTrue);
      expect(state.result!.modifiedImagePath, '/tmp/fake-selfie.jpg');
    });

    test('persists pipeline result, game context, and latency on success',
        () async {
      final container = ProviderContainer(
        overrides: [
          cameraServiceProvider.overrideWithValue(_GrantedCameraService()),
          selfiePipelineServiceProvider.overrideWithValue(_FastPipeline()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(captureMomentProvider.notifier);
      await notifier.beginCapture(
        'Your face: "eat sushi"',
        gameContext: const GameMomentContext(
          promptText: 'Your face: "eat sushi"',
          totalScore: 840,
          totalRounds: 10,
        ),
      );
      await notifier.onPhotoCaptured('/tmp/fake-selfie.jpg');

      final state = container.read(captureMomentProvider);
      expect(state.phase, CapturePhase.completed);
      expect(state.result!.usedFallback, isFalse);
      expect(state.result!.modifiedImagePath,
          'https://cdn.example.com/modified.png');
      expect(state.pipelineElapsedMs, isNotNull);

      final card = container.read(lastShareCardProvider);
      expect(card, isNotNull);
      expect(card!.gameContext?.totalScore, 840);
      expect(card.gameContext?.totalRounds, 10);
      expect(card.pipelineLatencyMs, isNotNull);
    });

    test('reset clears active capture but preserves last share card',
        () async {
      final container = ProviderContainer(
        overrides: [
          selfiePipelineServiceProvider.overrideWithValue(_FastPipeline()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(captureMomentProvider.notifier);
      await notifier.onPhotoCaptured('/tmp/fake-selfie.jpg');

      expect(container.read(lastShareCardProvider), isNotNull);
      notifier.reset();
      expect(container.read(captureMomentProvider).phase, CapturePhase.idle);
      // Share card persists so solo-results can still display + share it.
      expect(container.read(lastShareCardProvider), isNotNull);
    });
  });

  group('CaptureExtra', () {
    test('preserves typed payload', () {
      const ctx = GameMomentContext(promptText: 'p', totalScore: 10);
      const extra = CaptureExtra(prompt: 'p', gameContext: ctx);
      expect(CaptureExtra.from(extra), same(extra));
    });

    test('coerces bare strings', () {
      final extra = CaptureExtra.from('fallback prompt');
      expect(extra.prompt, 'fallback prompt');
      expect(extra.gameContext, isNull);
    });

    test('handles null/unknown extras with safe default', () {
      expect(CaptureExtra.from(null).prompt, 'Capture the moment');
      expect(CaptureExtra.from(42).prompt, 'Capture the moment');
    });
  });
}
