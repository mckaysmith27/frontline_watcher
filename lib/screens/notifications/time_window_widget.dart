import 'package:flutter/material.dart';
import '../../providers/notifications_provider.dart';

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
  late TimeWindow _currentWindow;

  @override
  void initState() {
    super.initState();
    _currentWindow = TimeWindow(
      id: widget.timeWindow.id,
      startTime: widget.timeWindow.startTime,
      endTime: widget.timeWindow.endTime,
    );
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _currentWindow.startTime,
    );
    if (picked != null) {
      setState(() {
        _currentWindow.startTime = picked;
      });
      widget.onUpdate(_currentWindow);
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _currentWindow.endTime,
    );
    if (picked != null) {
      setState(() {
        _currentWindow.endTime = picked;
      });
      widget.onUpdate(_currentWindow);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour == 0 
        ? 12 
        : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start Time',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _selectStartTime(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, size: 18),
                          const SizedBox(width: 8),
                          Text(_formatTime(_currentWindow.startTime)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('to', style: TextStyle(color: Colors.grey)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'End Time',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _selectEndTime(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, size: 18),
                          const SizedBox(width: 8),
                          Text(_formatTime(_currentWindow.endTime)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: widget.onDelete,
              tooltip: 'Remove time window',
            ),
          ],
        ),
      ),
    );
  }
}
