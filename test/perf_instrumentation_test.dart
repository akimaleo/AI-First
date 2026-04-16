import 'package:flutter_test/flutter_test.dart';
import 'package:sync_or_sink/shared/services/perf_instrumentation.dart';
import 'package:sync_or_sink/shared/services/perf_recorder.dart';

void main() {
  group('PerfInstrumentation', () {
    setUp(PerfInstrumentation.debugResetStartup);
    tearDown(PerfInstrumentation.debugResetStartup);

    test('completeStartupAndRecord pushes a sample and returns ms', () async {
      final recorder = PerfRecorder();
      final perf = PerfInstrumentation(recorder);

      PerfInstrumentation.markAppStart();
      // Give the stopwatch a non-trivial elapsed time without slowing tests.
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final ms = perf.completeStartupAndRecord(tags: {'env': 'test'});
      expect(ms, isNotNull);
      expect(ms, greaterThanOrEqualTo(0));
      final samples = recorder.recent(PerfMetric.startup);
      expect(samples, hasLength(1));
      expect(samples.first.tags['env'], 'test');
    });

    test('completeStartupAndRecord is idempotent within a process', () async {
      final recorder = PerfRecorder();
      final perf = PerfInstrumentation(recorder);

      PerfInstrumentation.markAppStart();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      perf.completeStartupAndRecord();
      // Second call must not record a duplicate sample.
      final second = perf.completeStartupAndRecord();
      expect(second, isNull);
      expect(recorder.recent(PerfMetric.startup), hasLength(1));
    });

    test('completeStartupAndRecord no-ops when markAppStart never ran', () {
      final recorder = PerfRecorder();
      final perf = PerfInstrumentation(recorder);

      expect(perf.completeStartupAndRecord(), isNull);
      expect(recorder.recent(PerfMetric.startup), isEmpty);
    });

    test('recordCaptureMoment pushes a tagged sample', () {
      final recorder = PerfRecorder();
      final perf = PerfInstrumentation(recorder);

      perf.recordCaptureMoment(
        durationMs: 4321,
        tags: {'used_fallback': 'false'},
      );
      final samples = recorder.recent(PerfMetric.captureMoment);
      expect(samples, hasLength(1));
      expect(samples.first.durationMs, 4321);
      expect(samples.first.tags['used_fallback'], 'false');
    });

    test('recordCaptureMoment rejects negative durations', () {
      final recorder = PerfRecorder();
      final perf = PerfInstrumentation(recorder);

      perf.recordCaptureMoment(durationMs: -50);
      expect(recorder.recent(PerfMetric.captureMoment), isEmpty);
    });
  });
}
