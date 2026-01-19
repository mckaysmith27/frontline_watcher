import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/job.dart';

class DayActionBottomSheet extends StatelessWidget {
  final DateTime day;
  final bool isUnavailable; // Red - unavailable
  final bool hasPartialAvailability; // Mustard - partial availability
  final bool hasJob; // Blue - has scheduled job (may overlap with partial availability)
  final Job? job; // Job details if hasJob is true

  const DayActionBottomSheet({
    super.key,
    required this.day,
    required this.isUnavailable,
    required this.hasPartialAvailability,
    required this.hasJob,
    this.job,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Day header
          Text(
            DateFormat('EEEE, MMMM d, yyyy').format(day),
            style: titleStyle,
          ),
          const SizedBox(height: 24),
          // Status indicator
          if (hasJob && job != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.work, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Has Scheduled Job',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (job != null) ...[
                    const SizedBox(height: 8),
                    Text('${job!.title} - ${job!.location}'),
                    Text('${job!.startTime} - ${job!.endTime}'),
                  ],
                ],
              ),
            )
          else if (isUnavailable)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.block, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    'Unavailable',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else if (hasPartialAvailability)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFBFA100).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFA100), width: 2),
              ),
              child: const Row(
                children: [
                  Icon(Icons.access_time, color: Color(0xFFBFA100)),
                  SizedBox(width: 8),
                  Text(
                    'Partial Availability',
                    style: TextStyle(
                      color: Color(0xFF8B6F00),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'No status set',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          // Action buttons
          if (hasJob)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, 'cancel_job'),
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel Job'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            )
          else if (isUnavailable)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, 'remove_unavailable'),
                icon: const Icon(Icons.check_circle),
                label: const Text('Mark Available'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            )
          else if (hasPartialAvailability) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, 'edit_time_window'),
                icon: const Icon(Icons.edit),
                label: const Text('Edit Time Window'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'clear_time_window'),
                icon: const Icon(Icons.close),
                label: const Text('Clear Time Window'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'mark_unavailable'),
                icon: const Icon(Icons.block),
                label: const Text('Mark Unavailable'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: Colors.red,
                ),
              ),
            ),
          ]
          else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                // Default action per your spec: assume marking unavailable unless user chooses time window
                onPressed: () => Navigator.pop(context, 'mark_unavailable'),
                icon: const Icon(Icons.block),
                label: const Text('Mark Unavailable'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                // Only after explicitly choosing partial availability should we open the time window editor.
                onPressed: () => Navigator.pop(context, 'add_time_window'),
                icon: const Icon(Icons.access_time),
                label: const Text('Mark Partial Availability'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBFA100),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}
