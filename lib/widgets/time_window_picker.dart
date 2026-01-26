import 'dart:math';
import 'package:flutter/material.dart';
import '../services/job_time_histogram_service.dart';

class TimeWindowValue {
  final int startMinutes; // inclusive
  final int endMinutes; // exclusive

  const TimeWindowValue({required this.startMinutes, required this.endMinutes});
}

class TimeWindowPicker extends StatefulWidget {
  final String title;
  final TimeWindowValue value;
  final ValueChanged<TimeWindowValue> onChanged;

  final bool showReason;
  final TextEditingController? reasonController;
  final int reasonMaxLength;

  /// Histogram options
  final bool showJobHistogram;
  final String histogramScope; // 'global' or 'district'
  final String? districtId;

  /// Layout
  final bool showDelete;
  final VoidCallback? onDelete;

  const TimeWindowPicker({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.showReason = false,
    this.reasonController,
    this.reasonMaxLength = 250,
    this.showJobHistogram = true,
    this.histogramScope = 'global',
    this.districtId,
    this.showDelete = false,
    this.onDelete,
  });

  @override
  State<TimeWindowPicker> createState() => _TimeWindowPickerState();
}

class _TimeWindowPickerState extends State<TimeWindowPicker> {
  static const _steps = 96; // 24h * 4
  static const _minutesPerStep = 15;

  late int _start; // minutes
  late int _end; // minutes

  List<int>? _hist;
  bool _loadingHist = false;
  String? _histError;

  @override
  void initState() {
    super.initState();
    _start = _snapStart(widget.value.startMinutes);
    _end = _snapEnd(widget.value.endMinutes);
    _ensureValid();
    _loadHistogram();
  }

  @override
  void didUpdateWidget(covariant TimeWindowPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextStart = _snapStart(widget.value.startMinutes);
    final nextEnd = _snapEnd(widget.value.endMinutes);
    if (nextStart != _start || nextEnd != _end) {
      _start = nextStart;
      _end = nextEnd;
      _ensureValid();
    }
  }

  int _clampMinutes(int minutes) => minutes.clamp(0, 24 * 60);

  /// Snap **down** to the nearest 15-minute mark (for start times).
  int _snapStart(int minutes) {
    final clamped = _clampMinutes(minutes);
    final snapped = (clamped ~/ _minutesPerStep) * _minutesPerStep;
    return snapped.clamp(0, 24 * 60);
  }

  /// Snap **up** to the nearest 15-minute mark (for end times).
  int _snapEnd(int minutes) {
    final clamped = _clampMinutes(minutes);
    if (clamped == 24 * 60) return clamped;
    final snapped = ((clamped + (_minutesPerStep - 1)) ~/ _minutesPerStep) * _minutesPerStep;
    return snapped.clamp(0, 24 * 60);
  }

  void _ensureValid() {
    if (_end <= _start) {
      _end = min(_start + _minutesPerStep, 24 * 60);
    }
    if (_start >= 24 * 60) {
      _start = 24 * 60 - _minutesPerStep;
    }
    if (_end > 24 * 60) _end = 24 * 60;
  }

  Future<void> _loadHistogram() async {
    if (!widget.showJobHistogram) return;
    setState(() {
      _loadingHist = true;
      _histError = null;
    });
    try {
      final svc = JobTimeHistogramService();
      final buckets = await svc.getStartHistogram(
        scope: widget.histogramScope,
        districtId: widget.histogramScope == 'district' ? widget.districtId : null,
      );
      if (!mounted) return;
      setState(() => _hist = buckets);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hist = null;
        _histError = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loadingHist = false);
    }
  }

  void _emit() {
    widget.onChanged(TimeWindowValue(startMinutes: _start, endMinutes: _end));
  }

  String _formatMinutes(BuildContext context, int minutes) {
    if (minutes >= 24 * 60) {
      // End-of-day sentinel: show explicitly to avoid confusion with midnight start.
      return '12:00 AM (+1)';
    }
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return TimeOfDay(hour: h, minute: m).format(context);
  }

  int _toStep(int minutes) => (minutes ~/ _minutesPerStep).clamp(0, _steps);
  int _fromStep(int step) => step.clamp(0, _steps) * _minutesPerStep;

  List<double> _smoothed(List<int> buckets) {
    // simple symmetric smoothing kernel
    const kernel = [1.0, 2.0, 3.0, 2.0, 1.0];
    const denom = 9.0;
    final out = List<double>.filled(_steps, 0);
    for (int i = 0; i < _steps; i++) {
      double acc = 0;
      for (int k = 0; k < kernel.length; k++) {
        final j = i + (k - 2);
        final v = (j < 0 || j >= _steps) ? buckets[i] : buckets[j];
        acc += v * kernel[k];
      }
      out[i] = acc / denom;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final startStep = _toStep(_start);
    final endStep = _toStep(_end);

    final hist = _hist;
    final smoothed = hist == null ? null : _smoothed(hist);
    final hasHistogramData = smoothed != null && smoothed.isNotEmpty && smoothed.reduce(max) > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (widget.showDelete && widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: widget.onDelete,
                    tooltip: 'Remove time window',
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Time pickers
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: _start ~/ 60, minute: _start % 60),
                      );
                      if (picked == null) return;
                      setState(() {
                        _start = _snapStart(picked.hour * 60 + picked.minute);
                        _ensureValid();
                      });
                      _emit();
                    },
                    icon: const Icon(Icons.access_time),
                    label: Text(_formatMinutes(context, _start)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: _end ~/ 60, minute: _end % 60),
                      );
                      if (picked == null) return;
                      setState(() {
                        _end = _snapEnd(picked.hour * 60 + picked.minute);
                        _ensureValid();
                      });
                      _emit();
                    },
                    icon: const Icon(Icons.access_time_filled),
                    label: Text(_formatMinutes(context, _end)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Histogram + slider overlay
            SizedBox(
              height: 80,
              child: Stack(
                children: [
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 0,
                    height: 50,
                    child: _loadingHist
                        ? const Center(
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_histError != null
                            ? Center(
                                child: Text(
                                  'Couldn’t load histogram',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                                ),
                              )
                            : (widget.showJobHistogram && !hasHistogramData
                                ? Center(
                                    child: Text(
                                      'No histogram data yet',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                  )
                                : CustomPaint(
                                    painter: _HistogramLinePainter(
                                      values: smoothed,
                                      lineColor: Theme.of(context).colorScheme.primary.withOpacity(0.55),
                                      fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.10),
                                    ),
                                  ))),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: RangeSlider(
                        min: 0,
                        max: _steps.toDouble(),
                        divisions: _steps,
                        values: RangeValues(startStep.toDouble(), endStep.toDouble()),
                        labels: RangeLabels(
                          _formatMinutes(context, _start),
                          _formatMinutes(context, _end),
                        ),
                        onChanged: (v) {
                          setState(() {
                            _start = _fromStep(v.start.round());
                            _end = _fromStep(v.end.round());
                            _ensureValid();
                          });
                          _emit();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // hour hints (no axes)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('12a', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text('6a', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text('12p', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text('6p', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text('12a', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),

            if (widget.showReason && widget.reasonController != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: widget.reasonController,
                maxLength: widget.reasonMaxLength,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistogramLinePainter extends CustomPainter {
  final List<double>? values; // length 96
  final Color lineColor;
  final Color fillColor;

  _HistogramLinePainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final vals = values;
    if (vals == null || vals.isEmpty) return;

    final maxV = vals.reduce(max);
    if (maxV <= 0) return;

    final dx = size.width / (vals.length - 1);
    final pts = <Offset>[];
    for (int i = 0; i < vals.length; i++) {
      final x = dx * i;
      final y = size.height - (vals[i] / maxV) * size.height;
      pts.add(Offset(x, y));
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[max(0, i - 1)];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[min(pts.length - 1, i + 2)];

      // Catmull-Rom -> Bezier control points
      final c1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final c2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );

      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fill, fillPaint);

    final stroke = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _HistogramLinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor;
  }
}

