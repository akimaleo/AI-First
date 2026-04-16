import 'package:flutter_test/flutter_test.dart';
import 'package:sync_or_sink/shared/services/perf_recorder.dart';

void main() {
  group('PerfRecorder', () {
    test('records and returns recent samples newest first', () {
      final r = PerfRecorder();
      final base = DateTime(2026, 4, 16, 10, 0, 0);
      for (var i = 0; i < 7; i++) {
        r.record(
          PerfMetric.startup,
          1000 + i * 100,
          recordedAt: base.add(Duration(seconds: i)),
        );
      }
      final recent = r.recent(PerfMetric.startup);
      expect(recent.length, 5);
      expect(recent.first.durationMs, 1600);
      expect(recent.last.durationMs, 1200);
    });

    test('returns empty list when no samples recorded', () {
      final r = PerfRecorder();
      expect(r.recent(PerfMetric.captureMoment), isEmpty);
      expect(r.stats(PerfMetric.captureMoment).count, 0);
      expect(r.stats(PerfMetric.captureMoment).p50, isNull);
      expect(r.stats(PerfMetric.captureMoment).p95, isNull);
    });

    test('drops oldest samples when buffer fills', () {
      final r = PerfRecorder(maxPerMetric: 3);
      for (var i = 1; i <= 5; i++) {
        r.record(PerfMetric.captureMoment, i * 100);
      }
      final all = r.all(PerfMetric.captureMoment);
      expect(all.map((m) => m.durationMs).toList(), [300, 400, 500]);
    });

    test('computes p50/p95 across the full buffer', () {
      final r = PerfRecorder();
      for (final ms in [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]) {
        r.record(PerfMetric.startup, ms);
      }
      final stats = r.stats(PerfMetric.startup);
      expect(stats.count, 10);
      // 10 samples — linear-interpolated p50 sits between the 5th and 6th
      // entries (rank 4.5 ⇒ midpoint of 500/600 = 550). p95 sits at rank
      // 8.55 ⇒ 0.55 between 900 and 1000 = 955.
      expect(stats.p50, 550);
      expect(stats.p95, 955);
    });

    test('rejects negative durations defensively', () {
      final r = PerfRecorder();
      r.record(PerfMetric.startup, -1);
      expect(r.recent(PerfMetric.startup), isEmpty);
    });

    test('clear wipes per-metric buffers', () {
      final r = PerfRecorder();
      r.record(PerfMetric.startup, 100);
      r.record(PerfMetric.captureMoment, 5000);
      r.clear(PerfMetric.startup);
      expect(r.recent(PerfMetric.startup), isEmpty);
      expect(r.recent(PerfMetric.captureMoment).length, 1);
      r.clear();
      expect(r.recent(PerfMetric.captureMoment), isEmpty);
    });

    test('notifies listeners on record and clear', () {
      final r = PerfRecorder();
      var notifications = 0;
      r.addListener(() => notifications += 1);

      r.record(PerfMetric.startup, 100);
      expect(notifications, 1);

      r.record(PerfMetric.startup, 200);
      expect(notifications, 2);

      r.clear();
      expect(notifications, 3);
    });

    test('exposes targets and labels for both metrics', () {
      expect(PerfMetric.startup.label, 'Startup');
      expect(PerfMetric.startup.target, const Duration(seconds: 2));
      expect(PerfMetric.captureMoment.label, 'Capture the Moment');
      expect(PerfMetric.captureMoment.target, const Duration(seconds: 8));
    });
  });
}
