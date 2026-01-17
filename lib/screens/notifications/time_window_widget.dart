import 'package:flutter/material.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/time_window_picker.dart';

class TimeWindowWidget extends StatefulWidget {
  final TimeWindow timeWindow;
  final Function(TimeWindow) onUpdate;
  final VoidCallback onDelete;

  const TimeWindowWidget({
    super.key,
    required this.timeWindow,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<TimeWindowWidget> createState() => _TimeWindowWidgetState();
}

class _TimeWindowWidgetState extends State<TimeWindowWidget> {
  @override
  Widget build(BuildContext context) {
    final startMinutes = widget.timeWindow.startTime.hour * 60 + widget.timeWindow.startTime.minute;
    final endMinutes = widget.timeWindow.endTime.hour * 60 + widget.timeWindow.endTime.minute;

    return TimeWindowPicker(
      title: 'Notification window',
      value: TimeWindowValue(startMinutes: startMinutes, endMinutes: endMinutes),
      onChanged: (v) {
        final updated = TimeWindow(
          id: widget.timeWindow.id,
          startTime: TimeOfDay(hour: v.startMinutes ~/ 60, minute: v.startMinutes % 60),
          endTime: TimeOfDay(hour: v.endMinutes ~/ 60, minute: v.endMinutes % 60),
        );
        widget.onUpdate(updated);
      },
      showReason: false,
      showJobHistogram: true,
      histogramScope: 'global',
      showDelete: true,
      onDelete: widget.onDelete,
    );
  }
}
