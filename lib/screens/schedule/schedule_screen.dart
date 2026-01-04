import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/credits_provider.dart';
import '../../models/job.dart';
import '../../services/job_service.dart';
import 'job_card.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  String _selectedTab = 'Scheduled Jobs';
  List<Job> _scheduledJobs = [];
  List<Job> _pastJobs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final jobService = JobService();
      _scheduledJobs = await jobService.getScheduledJobs();
      _pastJobs = await jobService.getPastJobs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading jobs: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isWeekend(DateTime day) {
    return day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
  }

  bool _isPast(DateTime day) {
    final now = DateTime.now();
    final utc6 = now.add(const Duration(hours: 6));
    final cutoff = DateTime(utc6.year, utc6.month, utc6.day, 13, 31);
    return day.isBefore(cutoff);
  }

  Color? _getDayColor(DateTime day) {
    final creditsProvider = Provider.of<CreditsProvider>(context, listen: false);
    final dateStr = _formatDate(day);

    if (creditsProvider.scheduledJobDates.contains(dateStr)) {
      return Colors.blue; // Has job
    }
    if (creditsProvider.committedDates.contains(dateStr)) {
      return Colors.green; // Credit committed
    }
    if (creditsProvider.excludedDates.contains(dateStr)) {
      return Colors.red; // Excluded
    }
    return null;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _handleDayTap(DateTime day) async {
    if (_isWeekend(day) || _isPast(day)) return;

    final creditsProvider = Provider.of<CreditsProvider>(context, listen: false);
    final dateStr = _formatDate(day);

    if (creditsProvider.excludedDates.contains(dateStr)) {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Unavailable Day'),
          content: const Text(
            'You had marked yourself as unavailable on this day. '
            'Are you sure you want to remove this "non-work" day and mark yourself now as available?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, Remove'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await creditsProvider.removeExcludedDate(dateStr);
        // Call backend to remove from ESS
      }
    } else if (creditsProvider.committedDates.contains(dateStr)) {
      // Uncommit - this will automatically add the credit back
      try {
        await creditsProvider.uncommitDate(dateStr);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Credit returned'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else if (creditsProvider.scheduledJobDates.contains(dateStr)) {
      // Already has job, do nothing
      return;
    } else {
      // Commit credit - this will automatically deduct the credit
      try {
        await creditsProvider.commitDate(dateStr);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Credit committed to this day'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final creditsProvider = Provider.of<CreditsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Row(
                children: [
                  const Icon(Icons.stars, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${creditsProvider.credits}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _handleDayTap(selectedDay);
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              enabledDayPredicate: (day) {
                return !_isWeekend(day) && !_isPast(day);
              },
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: Colors.grey[400]),
                disabledTextStyle: TextStyle(color: Colors.grey[400]),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, date, _) {
                  final color = _getDayColor(date);
                  if (color == null) return null;
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(color: color),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Calendar Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 16,
              children: [
                _buildLegendItem('Has Job', Colors.blue),
                _buildLegendItem('Committed', Colors.green),
                _buildLegendItem('Unavailable', Colors.red),
              ],
            ),
          ),
          const Divider(),
          // Jobs Feed
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Scheduled Jobs'),
                  selected: _selectedTab == 'Scheduled Jobs',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedTab = 'Scheduled Jobs');
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Past Jobs'),
                  selected: _selectedTab == 'Past Jobs',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedTab = 'Past Jobs');
                    }
                  },
                ),
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _selectedTab == 'Scheduled Jobs'
                        ? _scheduledJobs.length
                        : _pastJobs.length,
                    itemBuilder: (context, index) {
                      final job = _selectedTab == 'Scheduled Jobs'
                          ? _scheduledJobs[index]
                          : _pastJobs[index];
                      return JobCard(
                        job: job,
                        isPast: _selectedTab == 'Past Jobs',
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () async {
            // Sync calendar
            await _loadJobs();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Calendar synced')),
            );
          },
          icon: const Icon(Icons.sync),
          label: const Text('Sync Calendar'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}



