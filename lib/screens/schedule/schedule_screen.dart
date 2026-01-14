import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/credits_provider.dart';
import '../../providers/filters_provider.dart';
import '../../models/job.dart';
import '../../services/job_service.dart';
import '../../services/user_role_service.dart';
import '../../widgets/profile_app_bar.dart';
import '../../widgets/day_action_bottom_sheet.dart';
import '../filters/automation_bottom_sheet.dart';
import '../../widgets/notification_day_card.dart';
import 'job_card.dart';
import 'package:add_2_calendar/add_2_calendar.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  String _selectedTab = 'Booked Jobs';
  List<Job> _scheduledJobs = [];
  List<String> _notificationDates = [];
  List<String> _futureDates = [];
  List<String> _pastDates = [];
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
      
      // Update scheduled job dates in credits provider
      final creditsProvider = Provider.of<CreditsProvider>(context, listen: false);
      final jobDates = _scheduledJobs.map((job) => _formatDate(job.date)).toList();
      await creditsProvider.updateScheduledJobDates(jobDates);
      
      // Load notification dates (committed dates) and separate into future/past
      final allDates = creditsProvider.committedDates.toList();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      _futureDates = [];
      _pastDates = [];
      
      for (var dateStr in allDates) {
        final dateParts = dateStr.split('-');
        final date = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );
        
        if (date.isAfter(today) || date.isAtSameMomentAs(today)) {
          _futureDates.add(dateStr);
        } else {
          _pastDates.add(dateStr);
        }
      }
      
      // Sort future dates ascending (earliest first)
      _futureDates.sort();
      // Sort past dates descending (most recent first)
      _pastDates.sort((a, b) => b.compareTo(a));
      
      _notificationDates = [..._futureDates, ..._pastDates];
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
    final filtersProvider = Provider.of<FiltersProvider>(context, listen: false);
    final dateStr = _formatDate(day);

    // Priority: blue (has job) > orange (unique keywords) > green (credit committed) > red (excluded)
    if (creditsProvider.scheduledJobDates.contains(dateStr)) {
      return Colors.blue; // Has job
    }
    // Check for unique keywords (only if it's a notification day)
    if (creditsProvider.committedDates.contains(dateStr) && 
        filtersProvider.hasUniqueKeywords(dateStr)) {
      return Colors.orange; // Has unique keywords
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
    
    // Find job for this date if it exists
    Job? jobForDate;
    try {
      jobForDate = _scheduledJobs.firstWhere(
        (job) => _formatDate(job.date) == dateStr,
      );
    } catch (e) {
      jobForDate = null;
    }

    final isCommitted = creditsProvider.committedDates.contains(dateStr);
    final isUnavailable = creditsProvider.excludedDates.contains(dateStr);
    final hasJob = creditsProvider.scheduledJobDates.contains(dateStr);

    // Show bottom sheet with day actions
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DayActionBottomSheet(
        day: day,
        isCommitted: isCommitted,
        isUnavailable: isUnavailable,
        hasJob: hasJob,
        job: jobForDate,
      ),
    );

    if (action == null || !mounted) return;

    try {
      if (action == 'mark_unavailable') {
        // Mark as unavailable - credit will be moved automatically
        await creditsProvider.excludeDate(dateStr);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Day marked as unavailable. Credit moved to next available day.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        await _loadJobs(); // Reload to refresh UI
      } else if (action == 'cancel_job' && jobForDate != null) {
        // Cancel job - handle sequential credit management
        final jobService = JobService();
        await jobService.cancelJob(jobForDate.id);
        await creditsProvider.handleJobCanceled(dateStr);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job canceled. Credit applied to maintain sequential order.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        await _loadJobs(); // Reload to refresh UI
      } else if (action == 'remove_unavailable') {
        // Remove unavailable status - handle sequential credit management
        await creditsProvider.removeExcludedDate(dateStr);
        
        // Auto-apply filters if date is now a notification day
        final filtersProvider = Provider.of<FiltersProvider>(context, listen: false);
        if (creditsProvider.committedDates.contains(dateStr) &&
            !creditsProvider.excludedDates.contains(dateStr) &&
            !creditsProvider.scheduledJobDates.contains(dateStr)) {
          await filtersProvider.autoApplyToNewDates(
            [dateStr],
            isUnavailable: (d) => creditsProvider.excludedDates.contains(d),
            hasJob: (d) => creditsProvider.scheduledJobDates.contains(d),
          );
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unavailable status removed. Credit applied to maintain sequential order.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        await _loadJobs(); // Reload to refresh UI
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

  @override
  Widget build(BuildContext context) {
    final creditsProvider = Provider.of<CreditsProvider>(context);

    return Scaffold(
      appBar: ProfileAppBar(
        actions: [
          GestureDetector(
            onTap: () => _showPurchaseOptions(context),
            child: Padding(
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
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                formatButtonShowsNext: false, // Show current format, not next
                formatButtonDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                formatButtonTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
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
                // Remove selection highlight - only show green/red/blue from custom builder
                selectedDecoration: BoxDecoration(
                  color: Colors.transparent,
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
                  // Show the color clearly without overlay interference
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
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
                // Override selectedBuilder to prevent selection highlight overlay
                selectedBuilder: (context, date, _) {
                  final color = _getDayColor(date);
                  if (color == null) {
                    // If no color, show transparent (no highlight)
                    return Container(
                      margin: const EdgeInsets.all(4),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                    );
                  }
                  // Show the color clearly - same as defaultBuilder
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
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
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
                _buildLegendItem('Notification Days (Credits)', Colors.green),
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
                  label: const Text('Booked Jobs'),
                  selected: _selectedTab == 'Booked Jobs',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedTab = 'Booked Jobs');
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Keywords by Day'),
                  selected: _selectedTab == 'Keywords by Day',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedTab = 'Keywords by Day');
                    }
                  },
                ),
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedTab == 'Booked Jobs'
                    ? _scheduledJobs.isEmpty
                        ? const Center(child: Text('No booked jobs yet'))
                        : ListView.builder(
                            itemCount: _scheduledJobs.length,
                            itemBuilder: (context, index) {
                              return JobCard(
                                job: _scheduledJobs[index],
                                isPast: false,
                              );
                            },
                          )
                    : _notificationDates.isEmpty
                        ? const Center(child: Text('No keywords by day set'))
                        : ListView.builder(
                            itemCount: _notificationDates.length,
                            itemBuilder: (context, index) {
                              final dateStr = _notificationDates[index];
                              final isPast = _pastDates.contains(dateStr);
                              // Find booked job for this date
                              Job? jobForDate;
                              try {
                                jobForDate = _scheduledJobs.firstWhere(
                                  (job) {
                                    final jobDateStr = _formatDate(job.date);
                                    return jobDateStr == dateStr;
                                  },
                                );
                              } catch (e) {
                                jobForDate = null;
                              }
                              
                              return NotificationDayCard(
                                dateStr: dateStr,
                                isPast: isPast,
                                bookedJob: jobForDate,
                              );
                            },
                          ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: Consumer<CreditsProvider>(
          builder: (context, creditsProvider, _) {
            // Locked condition: user has NO credits AND NO green days (committed dates)
            // Button is always visible but locked when BOTH conditions are true
            final isLocked = creditsProvider.credits == 0 && 
                            creditsProvider.committedDates.isEmpty;
            
            return ElevatedButton.icon(
              onPressed: isLocked ? null : () => _syncCalendarToDevice(context),
              icon: isLocked 
                  ? const Icon(Icons.lock)
                  : const Icon(Icons.sync), // Sync icon (arrows in circle) when unlocked
              label: Text(isLocked ? 'Sync Calendar (Locked)' : 'Sync Calendar'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: isLocked 
                    ? Colors.grey
                    : Theme.of(context).colorScheme.primary,
                foregroundColor: isLocked
                    ? Colors.grey[300]
                    : Theme.of(context).colorScheme.onPrimary,
              ),
            );
          },
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

  void _showPurchaseOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AutomationBottomSheet(),
    );
  }

  Future<void> _syncCalendarToDevice(BuildContext context) async {
    // Check if user has access to schedule feature (requires 'sub' role)
    final roleService = UserRoleService();
    final hasScheduleAccess = await roleService.hasFeatureAccess('schedule');
    
    if (!hasScheduleAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This feature requires substitute teacher access.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final creditsProvider = Provider.of<CreditsProvider>(context, listen: false);
    
    // Only sync jobs that are marked with "has job" color (blue) - these are in scheduledJobDates
    final bookedJobDates = creditsProvider.scheduledJobDates.toSet();
    final bookedJobs = _scheduledJobs.where((job) {
      final jobDateStr = _formatDate(job.date);
      return bookedJobDates.contains(jobDateStr);
    }).toList();

    if (bookedJobs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No booked jobs to sync'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Filter to only jobs in the next year from yesterday
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final nextYear = yesterday.add(const Duration(days: 365));
    final jobsToSync = bookedJobs.where((job) {
      final jobDate = DateTime(job.date.year, job.date.month, job.date.day);
      return jobDate.isAfter(yesterday) && jobDate.isBefore(nextYear) || 
             jobDate.isAtSameMomentAs(yesterday) || 
             jobDate.isAtSameMomentAs(nextYear);
    }).toList();

    if (jobsToSync.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No booked jobs in the next year to sync'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      int successCount = 0;
      int failureCount = 0;

      for (var job in jobsToSync) {
        try {
          // Parse date and time
          final date = job.date;
          
          // Parse start time (format: "8:00 AM" or "08:00 AM")
          final startTimeParts = job.startTime.split(' ');
          final startTimeStr = startTimeParts[0];
          final isPM = startTimeParts.length > 1 && startTimeParts[1].toUpperCase() == 'PM';
          final startHourMin = startTimeStr.split(':');
          var startHour = int.parse(startHourMin[0]);
          final startMin = int.parse(startHourMin[1]);
          
          if (isPM && startHour != 12) {
            startHour += 12;
          } else if (!isPM && startHour == 12) {
            startHour = 0;
          }
          
          final startDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            startHour,
            startMin,
          );
          
          // Parse end time (format: "3:00 PM" or "15:00")
          DateTime endDateTime;
          if (job.endTime.contains('AM') || job.endTime.contains('PM')) {
            final endTimeParts = job.endTime.split(' ');
            final endTimeStr = endTimeParts[0];
            final isEndPM = endTimeParts.length > 1 && endTimeParts[1].toUpperCase() == 'PM';
            final endHourMin = endTimeStr.split(':');
            var endHour = int.parse(endHourMin[0]);
            final endMin = int.parse(endHourMin[1]);
            
            if (isEndPM && endHour != 12) {
              endHour += 12;
            } else if (!isEndPM && endHour == 12) {
              endHour = 0;
            }
            
            endDateTime = DateTime(
              date.year,
              date.month,
              date.day,
              endHour,
              endMin,
            );
          } else {
            // 24-hour format
            final endHourMin = job.endTime.split(':');
            final endHour = int.parse(endHourMin[0]);
            final endMin = int.parse(endHourMin[1]);
            endDateTime = DateTime(
              date.year,
              date.month,
              date.day,
              endHour,
              endMin,
            );
          }
          
          // Create calendar event
          final event = Event(
            title: '${job.title} - ${job.location}',
            description: 'Substitute Teaching Job\n'
                'Teacher: ${job.teacher}\n'
                'Confirmation #: ${job.confirmationNumber}\n'
                'Duration: ${job.duration}',
            location: job.location,
            startDate: startDateTime,
            endDate: endDateTime,
            iosParams: const IOSParams(
              reminder: Duration(minutes: 30),
            ),
            androidParams: const AndroidParams(
              emailInvites: [],
            ),
          );
          
          final result = await Add2Calendar.addEvent2Cal(event);
          if (result) {
            successCount++;
          } else {
            failureCount++;
          }
        } catch (e) {
          print('Error adding job to calendar: $e');
          failureCount++;
        }
      }

      if (mounted) {
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                failureCount > 0
                    ? 'Synced $successCount job(s). $failureCount failed.'
                    : 'Successfully synced $successCount job(s) to calendar!',
              ),
              backgroundColor: failureCount > 0 ? Colors.orange : Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to sync jobs to calendar'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error syncing calendar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing calendar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}



