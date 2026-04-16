import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'perf_recorder.dart';
import 'sentry_service.dart';

/// Records the GUSAA-15 perf metrics into:
///   * the in-memory [PerfRecorder] for the hidden Settings → Perf debug screen
///   * the Dart `Timeline` (visible in DevTools' Performance view)
///   * a Sentry breadcrumb so timings ride along with crashes for correlation
///
/// Each call is a few cheap operations and never throws — safe to leave on in
/// release and profile builds.
class PerfInstrumentation {
  PerfInstrumentation(this._recorder);

  final PerfRecorder _recorder;

  /// Stopwatch covering the boot path from [markAppStart] to the home
  /// screen's first frame. Process-scoped so the same instance is shared by
  /// `main()` and the eventual completion in `HomeScreen`.
  static final Stopwatch _startupStopwatch = Stopwatch();
  static bool _startupRecorded = false;

  /// Call as the first line of `main()`.
  static void markAppStart() {
    if (_startupRecorded) return;
    if (!_startupStopwatch.isRunning) {
      _startupStopwatch
        ..reset()
        ..start();
    }
  }

  /// Stops the startup stopwatch and records the elapsed time. Idempotent —
  /// only the first call per process records a sample.
  ///
  /// Returns the recorded duration in milliseconds, or null if startup was
  /// never marked or has already been recorded.
  int? completeStartupAndRecord({Map<String, String> tags = const {}}) {
    if (_startupRecorded) return null;
    if (!_startupStopwatch.isRunning) return null;
    _startupStopwatch.stop();
    _startupRecorded = true;
    final ms = _startupStopwatch.elapsedMilliseconds;
    _recorder.record(PerfMetric.startup, ms, tags: tags);
    developer.Timeline.instantSync(
      'app_startup_complete',
      arguments: <String, Object?>{'duration_ms': ms, ...tags},
    );
    _addBreadcrumb('app.startup', ms, tags);
    return ms;
  }

  /// Records an end-to-end Capture the Moment latency in milliseconds —
  /// from the moment the user taps the shutter to the modified selfie's
  /// first frame on the hero screen.
  void recordCaptureMoment({
    required int durationMs,
    Map<String, String> tags = const {},
  }) {
    if (durationMs < 0) return;
    _recorder.record(PerfMetric.captureMoment, durationMs, tags: tags);
    developer.Timeline.instantSync(
      'capture_moment_complete',
      arguments: <String, Object?>{'duration_ms': durationMs, ...tags},
    );
    _addBreadcrumb('capture.moment', durationMs, tags);
  }

  void _addBreadcrumb(
    String category,
    int durationMs,
    Map<String, String> tags,
  ) {
    if (sentryDsn.isEmpty) return;
    Sentry.addBreadcrumb(
      Breadcrumb(
        category: category,
        type: 'info',
        level: SentryLevel.info,
        message: '${durationMs}ms',
        data: <String, Object?>{'duration_ms': durationMs, ...tags},
      ),
    );
  }

  /// Test-only — resets the process-scoped startup state.
  @visibleForTesting
  static void debugResetStartup() {
    _startupStopwatch
      ..stop()
      ..reset();
    _startupRecorded = false;
  }
}

final perfInstrumentationProvider = Provider<PerfInstrumentation>((ref) {
  return PerfInstrumentation(ref.watch(perfRecorderProvider));
});
