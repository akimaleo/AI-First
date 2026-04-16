import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/services/perf_recorder.dart';

class PerfDebugScreen extends ConsumerWidget {
  const PerfDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recorder = ref.watch(perfRecorderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance'),
        actions: [
          IconButton(
            tooltip: 'Clear samples',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => recorder.clear(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: recorder,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            for (final metric in PerfMetric.values)
              _MetricSection(metric: metric, recorder: recorder),
          ],
        ),
      ),
    );
  }
}

class _MetricSection extends StatelessWidget {
  const _MetricSection({required this.metric, required this.recorder});

  final PerfMetric metric;
  final PerfRecorder recorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = recorder.stats(metric);
    final recent = recorder.recent(metric);
    final targetMs = metric.target.inMilliseconds;
    final p95Over = stats.p95 != null && stats.p95! > targetMs;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(metric.label, style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                'target ${_formatMs(targetMs)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatChip(label: 'count', value: stats.count.toString()),
              const SizedBox(width: 8),
              _StatChip(label: 'p50', value: _formatStat(stats.p50)),
              const SizedBox(width: 8),
              _StatChip(
                label: 'p95',
                value: _formatStat(stats.p95),
                emphasised: p95Over,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            Text(
              'No samples yet.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else
            ...recent.map((m) => _SampleTile(measurement: m, targetMs: targetMs)),
          const Divider(height: 24),
        ],
      ),
    );
  }
}

class _SampleTile extends StatelessWidget {
  const _SampleTile({required this.measurement, required this.targetMs});

  final PerfMeasurement measurement;
  final int targetMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = measurement.durationMs > targetMs;
    final color = over ? theme.colorScheme.error : theme.colorScheme.onSurface;
    final tagsText = measurement.tags.entries
        .map((e) => '${e.key}=${e.value}')
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              _formatMs(measurement.durationMs),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            _formatTime(measurement.recordedAt),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (tagsText.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tagsText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = emphasised
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerHighest;
    final fg = emphasised
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: theme.textTheme.bodySmall?.copyWith(color: fg),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatStat(int? ms) => ms == null ? '—' : _formatMs(ms);

String _formatMs(int ms) {
  if (ms < 1000) return '${ms}ms';
  return '${(ms / 1000).toStringAsFixed(2)}s';
}

String _formatTime(DateTime ts) {
  final t = ts.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}
