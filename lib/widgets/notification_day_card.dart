import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/filters_provider.dart';
import '../providers/availability_provider.dart';
import '../screens/filters/date_filter_editor.dart';
import '../models/job.dart';
import 'app_tooltip.dart';

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
    return Consumer2<FiltersProvider, AvailabilityProvider>(
      builder: (context, filtersProvider, availabilityProvider, _) {
    
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
    final hasJob = availabilityProvider.scheduledJobDates.contains(dateStr);
    final isUnavailable = availabilityProvider.unavailableDates.contains(dateStr);
    final hasPartialAvailability = availabilityProvider.partialAvailabilityByDate.containsKey(dateStr);
    // Check if this date has unique keywords (orange accent)
    final hasUniqueKeywords = filtersProvider.hasUniqueKeywords(dateStr);
    
    // Get unique keywords (keywords that differ from global filters)
    final uniqueKeywords = filtersProvider.getUniqueKeywords(dateStr);
    final uniqueIncluded = uniqueKeywords['includedWords'] ?? [];
    final uniqueExcluded = uniqueKeywords['excludedWords'] ?? [];
    
    // Get matched keywords from booked job if available
    final matchedKeywords = bookedJob != null ? _getMatchedKeywords(bookedJob!, includedWords) : [];

    // Determine border color (priority: blue > red > mustard > orange)
    Color? borderColor;
    if (hasJob) {
      borderColor = Colors.blue;
    } else if (isUnavailable) {
      borderColor = Colors.red;
    } else if (hasPartialAvailability) {
      borderColor = const Color(0xFFBFA100);
    } else if (hasUniqueKeywords) {
      borderColor = Colors.orange;
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
                  if (!hasJob && isUnavailable)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red, width: 1),
                      ),
                      child: Text(
                        'Unavailable',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (!hasJob && !isUnavailable && hasPartialAvailability)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBFA100).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFA100), width: 1),
                      ),
                      child: const Text(
                        'Partial',
                        style: TextStyle(
                          color: Color(0xFF8B6F00),
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
              // Show unique keywords section
              if (hasUniqueKeywords) ...[
                Row(
                  children: [
                    Text(
                      'Unique Keywords',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isPast ? Colors.grey[600] : Colors.orange[700],
                          ),
                    ),
                    const SizedBox(width: 4),
                    AppTooltip(
                      message: 'These are keywords that are applied to just this specific day but which are different from the filter of keywords which was applied to all days',
                      child: Icon(
                        Icons.help_outline,
                        size: 16,
                        color: isPast ? Colors.grey[600] : Colors.orange[700],
                      ),
                    ),
                    const Spacer(),
                    if (!isPast)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        color: Colors.orange[700],
                        tooltip: 'Clear unique keywords',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          await filtersProvider.clearUniqueKeywords(dateStr);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Unique keywords cleared'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (uniqueIncluded.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: uniqueIncluded.map((word) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange, width: 1),
                        ),
                        child: Text(
                          word,
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                ],
                if (uniqueExcluded.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: uniqueExcluded.map((word) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red, width: 1),
                        ),
                        child: Text(
                          word,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (uniqueIncluded.isEmpty && uniqueExcluded.isEmpty)
                  Text(
                    'No unique keywords',
                    style: TextStyle(
                      color: isPast ? Colors.grey[500] : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
              ] else if (includedWords.isEmpty && excludedWords.isEmpty)
                Text(
                  'No filters set for this day',
                  style: TextStyle(
                    color: isPast ? Colors.grey[500] : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
      );
    },
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

