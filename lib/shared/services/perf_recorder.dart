import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Perf metrics tracked for the GUSAA-15 beta sign-off targets.
enum PerfMetric { startup, captureMoment }

extension PerfMetricLabel on PerfMetric {
  String get label {
    switch (this) {
      case PerfMetric.startup:
        return 'Startup';
      case PerfMetric.captureMoment:
        return 'Capture the Moment';
    }
  }

  /// Target latency the metric must beat for beta sign-off.
  Duration get target {
    switch (this) {
      case PerfMetric.startup:
        return const Duration(seconds: 2);
      case PerfMetric.captureMoment:
        return const Duration(seconds: 8);
    }
  }
}

@immutable
class PerfMeasurement {
  const PerfMeasurement({
    required this.metric,
    required this.durationMs,
    required this.recordedAt,
    this.tags = const {},
  });

  final PerfMetric metric;
  final int durationMs;
  final DateTime recordedAt;
  final Map<String, String> tags;
}

@immutable
class PerfStats {
  const PerfStats({required this.count, this.p50, this.p95});

  final int count;
  final int? p50;
  final int? p95;

  bool get isEmpty => count == 0;
}

/// In-memory ring buffer for perf measurements. Cheap by design — a list
/// append plus an at-most O(N) trim, where N stays small (default 50). Safe
/// to call from release/profile builds.
class PerfRecorder extends ChangeNotifier {
  PerfRecorder({this.maxPerMetric = 50});

  final int maxPerMetric;
  final Map<PerfMetric, Queue<PerfMeasurement>> _buffers = {};

  void record(
    PerfMetric metric,
    int durationMs, {
    Map<String, String> tags = const {},
    DateTime? recordedAt,
  }) {
    if (durationMs < 0) return;
    final buf = _buffers.putIfAbsent(metric, () => Queue<PerfMeasurement>());
    buf.addLast(
      PerfMeasurement(
        metric: metric,
        durationMs: durationMs,
        recordedAt: recordedAt ?? DateTime.now(),
        tags: Map.unmodifiable(tags),
      ),
    );
    while (buf.length > maxPerMetric) {
      buf.removeFirst();
    }
    notifyListeners();
  }

  /// Most recent samples for [metric], newest first. At most [limit] entries.
  List<PerfMeasurement> recent(PerfMetric metric, {int limit = 5}) {
    final buf = _buffers[metric];
    if (buf == null || buf.isEmpty) return const [];
    final list = buf.toList(growable: false);
    final from = list.length > limit ? list.length - limit : 0;
    return list.sublist(from).reversed.toList(growable: false);
  }

  List<PerfMeasurement> all(PerfMetric metric) =>
      _buffers[metric]?.toList(growable: false) ?? const [];

  /// p50 / p95 across all buffered samples for [metric].
  PerfStats stats(PerfMetric metric) {
    final list = all(metric);
    if (list.isEmpty) return const PerfStats(count: 0);
    final durations = list.map((m) => m.durationMs).toList()..sort();
    return PerfStats(
      count: durations.length,
      p50: _percentile(durations, 0.5),
      p95: _percentile(durations, 0.95),
    );
  }

  void clear([PerfMetric? metric]) {
    if (metric == null) {
      _buffers.clear();
    } else {
      _buffers.remove(metric);
    }
    notifyListeners();
  }

  static int _percentile(List<int> sorted, double percentile) {
    final rank =
        (percentile * (sorted.length - 1)).clamp(0, sorted.length - 1);
    final lower = rank.floor();
    final upper = rank.ceil();
    if (lower == upper) return sorted[lower];
    final weight = rank - lower;
    return (sorted[lower] + (sorted[upper] - sorted[lower]) * weight).round();
  }
}

/// Singleton recorder for the running app session.
final perfRecorderProvider = Provider<PerfRecorder>((ref) {
  final recorder = PerfRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});
