import 'package:flutter/material.dart';

class CountdownTimer extends StatefulWidget {
  const CountdownTimer({
    super.key,
    this.durationSeconds = 30,
    required this.onExpired,
    this.onTick,
    this.isPaused = false,
  });

  final int durationSeconds;
  final VoidCallback onExpired;
  final ValueChanged<int>? onTick;
  final bool isPaused;

  @override
  State<CountdownTimer> createState() => CountdownTimerState();
}

class CountdownTimerState extends State<CountdownTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  int get remainingSeconds =>
      (widget.durationSeconds * _controller.value).ceil();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationSeconds),
      value: 1.0,
    );
    _controller.addListener(_handleTick);
    _controller.addStatusListener(_handleStatus);
    if (!widget.isPaused) {
      _controller.reverse(from: 1.0);
    }
  }

  @override
  void didUpdateWidget(CountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused && !oldWidget.isPaused) {
      _controller.stop();
    } else if (!widget.isPaused && oldWidget.isPaused) {
      _controller.reverse();
    }
  }

  int _lastReportedSecond = -1;

  void _handleTick() {
    final seconds = remainingSeconds;
    if (seconds != _lastReportedSecond) {
      _lastReportedSecond = seconds;
      widget.onTick?.call(seconds);
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      widget.onExpired();
    }
  }

  void restart() {
    _controller.reverse(from: 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final seconds = remainingSeconds;
        final isUrgent = seconds <= 5;
        final color = isUrgent
            ? theme.colorScheme.error
            : seconds <= 10
                ? Colors.orange
                : theme.colorScheme.primary;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: _controller.value,
                    strokeWidth: 4,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.15),
                  ),
                  Center(
                    child: Text(
                      '$seconds',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
