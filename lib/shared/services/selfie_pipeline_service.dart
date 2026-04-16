import 'dart:io';

class SelfiePipelineResult {
  const SelfiePipelineResult({
    required this.modifiedImagePath,
    required this.originalImagePath,
    required this.prompt,
    this.usedFallback = false,
  });

  final String modifiedImagePath;
  final String originalImagePath;
  final String prompt;
  final bool usedFallback;
}

abstract class SelfiePipelineService {
  Future<SelfiePipelineResult> transformSelfie({
    required File selfie,
    required String prompt,
  });
}

class StubSelfiePipelineService implements SelfiePipelineService {
  StubSelfiePipelineService({this.simulatedDelay = const Duration(seconds: 2)});

  final Duration simulatedDelay;

  @override
  Future<SelfiePipelineResult> transformSelfie({
    required File selfie,
    required String prompt,
  }) async {
    await Future.delayed(simulatedDelay);
    return SelfiePipelineResult(
      modifiedImagePath: selfie.path,
      originalImagePath: selfie.path,
      prompt: prompt,
      usedFallback: true,
    );
  }
}
