import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/filters_provider.dart';
import '../../providers/credits_provider.dart';
import '../../widgets/filter_column.dart';
import '../../widgets/nested_filter_column.dart';
import '../../utils/keyword_mapper.dart';

class DateFilterEditor extends StatefulWidget {
  final String dateStr; // Format: "YYYY-MM-DD"

  const DateFilterEditor({
    super.key,
    required this.dateStr,
  });

  @override
  State<DateFilterEditor> createState() => _DateFilterEditorState();
}

class _DateFilterEditorState extends State<DateFilterEditor> {
  @override
  Widget build(BuildContext context) {
    final filtersProvider = Provider.of<FiltersProvider>(context);
    final creditsProvider = Provider.of<CreditsProvider>(context);
    
    // Get current date-specific filters
    final dateFilters = filtersProvider.getDateFilters(widget.dateStr);
    
    // Parse date for display
    final dateParts = widget.dateStr.split('-');
    final date = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );
    
    final monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final weekdayName = weekdayNames[date.weekday - 1];
    final monthName = monthNames[date.month];
    final day = date.day;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filters for',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '$weekdayName, $monthName $day, ${date.year}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set specific filters for this notification day. These filters will override your default filters for this date only.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 24),
                      ...filtersProvider.filtersDict.entries.map((entry) {
                        // Handle nested dictionaries (like "schools-by-city")
                        if (entry.value is Map) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: NestedFilterColumn(
                              category: entry.key,
                              nestedData: entry.value as Map<String, dynamic>,
                              customTags: filtersProvider.customTags[entry.key] ?? [],
                              dateStr: widget.dateStr, // Pass date for date-specific filtering
                            ),
                          );
                        } else {
                          // Regular list of tags
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: FilterColumn(
                              category: entry.key,
                              tags: [
                                ...(entry.value as List<String>),
                                ...(filtersProvider.customTags[entry.key] ?? []),
                              ],
                              isPremium: false,
                              isUnlocked: true,
                              dateStr: widget.dateStr, // Pass date for date-specific filtering
                            ),
                          );
                        }
                      }),
                    ],
                  ),
                ),
              ),
              Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // Clear date-specific filters
                          filtersProvider.clearDateFilters(widget.dateStr);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Date filters cleared')),
                          );
                        },
                        child: const Text('Clear Filters'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Save date-specific filters
                          await filtersProvider.saveDateFilters(widget.dateStr);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Filters saved for this date!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        child: const Text('Save Filters'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

