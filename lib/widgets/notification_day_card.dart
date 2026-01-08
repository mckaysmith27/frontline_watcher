import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/filters_provider.dart';
import '../providers/credits_provider.dart';
import '../screens/filters/date_filter_editor.dart';
import '../widgets/tag_chip.dart';
import '../services/job_service.dart';
import '../models/job.dart';
import '../utils/keyword_mapper.dart';

class NotificationDayCard extends StatelessWidget {
  final String dateStr; // Format: "YYYY-MM-DD"
  final bool isPast;
  final Job? bookedJob;

  const NotificationDayCard({
    super.key,
    required this.dateStr,
    this.isPast = false,
    this.bookedJob,
  });

  @override
  Widget build(BuildContext context) {
    final filtersProvider = Provider.of<FiltersProvider>(context);
    final creditsProvider = Provider.of<CreditsProvider>(context);
    
    // Get date-specific filters (if any)
    final dateFilters = filtersProvider.getDateFilters(dateStr);
    final includedWords = dateFilters['includedWords'] ?? [];
    final excludedWords = dateFilters['excludedWords'] ?? [];
    
    // Parse date for display
    final dateParts = dateStr.split('-');
    final date = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );
    
    final monthNames = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekdayName = weekdayNames[date.weekday - 1];
    final monthName = monthNames[date.month];
    final day = date.day;

    // Check if this date has a job (blue highlight)
    final hasJob = creditsProvider.scheduledJobDates.contains(dateStr);
    // Check if this is a notification day (green highlight)
    final isNotificationDay = creditsProvider.committedDates.contains(dateStr);
    
    // Get matched keywords from booked job if available
    final matchedKeywords = bookedJob != null ? _getMatchedKeywords(bookedJob, includedWords) : [];

    // Determine border color
    Color? borderColor;
    if (hasJob) {
      borderColor = Colors.blue;
    } else if (isNotificationDay) {
      borderColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isPast ? Colors.grey[200] : null,
      shape: borderColor != null
          ? RoundedRectangleBorder(
              side: BorderSide(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: InkWell(
        onTap: isPast ? null : () {
          // Open filter editor for this specific date (only if not past)
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => DateFilterEditor(dateStr: dateStr),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$weekdayName, $monthName $day',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '${date.year}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                  if (!isPast)
                    Icon(
                      Icons.edit,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  if (hasJob)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue, width: 1),
                      ),
                      child: Text(
                        'Has Job',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Show matched keywords if there's a booked job
              if (matchedKeywords.isNotEmpty) ...[
                Text(
                  'Matched Keywords:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isPast ? Colors.grey[600] : null,
                      ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: matchedKeywords.map((word) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue, width: 1),
                      ),
                      child: Text(
                        word,
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (includedWords.isEmpty && excludedWords.isEmpty)
                Text(
                  'No filters set for this day',
                  style: TextStyle(
                    color: isPast ? Colors.grey[500] : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                )
              else ...[
                if (includedWords.isNotEmpty) ...[
                  Text(
                    'Include:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isPast ? Colors.grey[600] : null,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: includedWords.map((word) {
                      return TagChip(
                        tag: word,
                        state: TagState.green,
                        isPremium: false,
                        isUnlocked: true,
                        isCustom: false,
                        onTap: null, // Read-only in card view
                        onDelete: null,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                if (excludedWords.isNotEmpty) ...[
                  Text(
                    'Exclude:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isPast ? Colors.grey[600] : null,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: excludedWords.map((word) {
                      return TagChip(
                        tag: word,
                        state: TagState.red,
                        isPremium: false,
                        isUnlocked: true,
                        isCustom: false,
                        onTap: null, // Read-only in card view
                        onDelete: null,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<String> _getMatchedKeywords(Job job, List<String> includedWords) {
    if (includedWords.isEmpty) return [];
    
    // Extract keywords from job data
    final jobText = '${job.title} ${job.location} ${job.teacher}'.toLowerCase();
    final matched = <String>[];
    
    for (var word in includedWords) {
      if (jobText.contains(word.toLowerCase())) {
        matched.add(word);
      }
    }
    
    return matched;
  }
}

