import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/availability_provider.dart';
import '../../providers/filters_provider.dart';
import '../../models/job.dart';
import '../../services/job_service.dart';
import '../../services/user_role_service.dart';
import '../../widgets/profile_app_bar.dart';
import '../../widgets/day_action_bottom_sheet.dart';
import '../../widgets/notification_day_card.dart';
import '../../widgets/time_window_picker.dart';
import '../../widgets/app_bar_quick_toggles.dart';
import '../filters/automation_bottom_sheet.dart';
import 'job_card.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import '../profile/profile_screen.dart';

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
  bool _isLoading = false;
  String _keywordSearch = '';
  String _unavailableSearch = '';
  String _partialSearch = '';

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
      
      // Update scheduled job dates in availability provider
      final availabilityProvider = Provider.of<AvailabilityProvider>(context, listen: false);
      final jobDates = _scheduledJobs.map((job) => _formatDate(job.date)).toList();
      await availabilityProvider.updateScheduledJobDates(jobDates);
      
      // Compute keyword dates: all relevant workdays (excludes weekends, full unavailable, and job days)
      // (This replaces the old "committedDates/credits" model.)
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
    final availabilityProvider = Provider.of<AvailabilityProvider>(context, listen: false);
    final dateStr = _formatDate(day);

    // Priority: blue (has job) > red (unavailable) > mustard (partial availability)
    if (availabilityProvider.scheduledJobDates.contains(dateStr)) {
      return Colors.blue; // Has job
    }
    if (availabilityProvider.unavailableDates.contains(dateStr)) {
      return Colors.red; // Unavailable
    }
    if (availabilityProvider.partialAvailabilityByDate.containsKey(dateStr)) {
      return const Color(0xFFBFA100); // Partial availability (mustard)
    }
    return null;
  }

  bool _isInSubscriptionDayRange(DateTime dayLocal) {
    final sub = Provider.of<SubscriptionProvider>(context, listen: false);
    final startUtc = sub.subscriptionStartsAtUtc;
    final endUtc = sub.subscriptionEndsAtUtc;
    if (startUtc == null || endUtc == null) return false;
    final startLocalDate = DateTime(startUtc.toLocal().year, startUtc.toLocal().month, startUtc.toLocal().day);
    final endLocalDate = DateTime(endUtc.toLocal().year, endUtc.toLocal().month, endUtc.toLocal().day);
    final d = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    return (d.isAtSameMomentAs(startLocalDate) || d.isAfter(startLocalDate)) &&
        (d.isAtSameMomentAs(endLocalDate) || d.isBefore(endLocalDate));
  }

  bool _isSubscriptionSegmentStart(DateTime dayLocal) {
    if (!_isInSubscriptionDayRange(dayLocal)) return false;
    final prev = dayLocal.subtract(const Duration(days: 1));
    return !_isInSubscriptionDayRange(prev);
  }

  bool _isSubscriptionSegmentEnd(DateTime dayLocal) {
    if (!_isInSubscriptionDayRange(dayLocal)) return false;
    final next = dayLocal.add(const Duration(days: 1));
    return !_isInSubscriptionDayRange(next);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _handleDayTap(DateTime day) async {
    if (_isWeekend(day) || _isPast(day)) return;

    final availabilityProvider = Provider.of<AvailabilityProvider>(context, listen: false);
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

    final isUnavailable = availabilityProvider.unavailableDates.contains(dateStr);
    final hasPartialAvailability = availabilityProvider.partialAvailabilityByDate.containsKey(dateStr);
    final hasJob = availabilityProvider.scheduledJobDates.contains(dateStr);

    // Show bottom sheet with day actions
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DayActionBottomSheet(
        day: day,
        isUnavailable: isUnavailable,
        hasPartialAvailability: hasPartialAvailability,
        hasJob: hasJob,
        job: jobForDate,
      ),
    );

    if (action == null || !mounted) return;

    try {
      if (action == 'mark_unavailable') {
        await availabilityProvider.markUnavailableWithReason(dateStr, reason: 'Unavailable');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Day marked as unavailable.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        await _loadJobs(); // Reload to refresh UI
      } else if (action == 'cancel_job' && jobForDate != null) {
        final confirmed = await _confirmCancelJob(jobForDate);
        if (confirmed != true) return;
        // Cancel job
        final jobService = JobService();
        await jobService.cancelJob(jobForDate.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job canceled.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        await _loadJobs(); // Reload to refresh UI
      } else if (action == 'remove_unavailable') {
        await availabilityProvider.removeUnavailable(dateStr);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marked available.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        await _loadJobs(); // Reload to refresh UI
      } else if (action == 'add_time_window') {
        await _showPartialAvailabilityEditor(dateStr);
      } else if (action == 'edit_time_window') {
        await _showPartialAvailabilityEditor(dateStr);
      } else if (action == 'clear_time_window') {
        await availabilityProvider.clearPartialAvailability(dateStr);
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

  Future<bool?> _confirmCancelJob(Job job) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
              const Text(
                'Cancel booked job?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('${job.title} • ${job.location}'),
              const SizedBox(height: 8),
              const Text(
                'This will attempt to cancel the job in Frontline/ESS. Are you sure you want to proceed?',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep Job'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel Job'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final availabilityProvider = Provider.of<AvailabilityProvider>(context, listen: true);
    final keywordDates = availabilityProvider.computeRelevantWorkdaysForKeywords();
    final keywordDatesFiltered = _filteredKeywordDates(keywordDates);

    return Scaffold(
      appBar: ProfileAppBar(
        actions: [
          const AppBarQuickToggles(),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
            tooltip: 'Settings',
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
                dowBuilder: (context, day) {
                  // Tappable day-of-week headers for bulk actions (Mon-Fri only)
                  final label = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];
                  final isWorkday = day.weekday >= DateTime.monday && day.weekday <= DateTime.friday;
                  return GestureDetector(
                    onTap: isWorkday ? () => _showBulkWeekdayActions(day.weekday) : null,
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isWorkday
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  );
                },
                defaultBuilder: (context, date, _) {
                  return _buildCalendarDayCell(context, date);
                },
                // Override selectedBuilder to prevent selection highlight overlay
                selectedBuilder: (context, date, _) {
                  return _buildCalendarDayCell(context, date);
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
                _buildLegendItem('Unavailable', Colors.red),
                _buildLegendItem('Partial Availability', const Color(0xFFBFA100)),
              ],
            ),
          ),
          const Divider(),
          // Jobs Feed
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Scrollbar(
              thumbVisibility: false,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Booked Jobs'),
                      selected: _selectedTab == 'Booked Jobs',
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedTab = 'Booked Jobs');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Keywords by Day'),
                      selected: _selectedTab == 'Keywords by Day',
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedTab = 'Keywords by Day');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Unavailable'),
                      selected: _selectedTab == 'Unavailable',
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedTab = 'Unavailable');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Partial Availability'),
                      selected: _selectedTab == 'Partial',
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedTab = 'Partial');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                    : _selectedTab == 'Keywords by Day'
                        ? keywordDates.isEmpty
                            ? const Center(child: Text('No upcoming workdays'))
                            : ListView.builder(
                                itemCount: keywordDatesFiltered.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                      child: TextField(
                                        decoration: const InputDecoration(
                                          labelText: 'Search (date or keyword)',
                                          hintText: 'Example: 2026-02-14 or “elementary”',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.search),
                                        ),
                                        onChanged: (v) => setState(() => _keywordSearch = v.trim().toLowerCase()),
                                      ),
                                    );
                                  }

                                  final dateStr = keywordDatesFiltered[index - 1];
                                  // Find booked job for this date
                                  Job? jobForDate;
                                  try {
                                    jobForDate = _scheduledJobs.firstWhere(
                                      (job) {
                                        final jobDateStr = _formatDate(job.date);
                                        return jobDateStr == dateStr;
                                      },
                                    );
                                  } catch (_) {
                                    jobForDate = null;
                                  }
                                  
                                  return NotificationDayCard(
                                    dateStr: dateStr,
                                    isPast: false,
                                    bookedJob: jobForDate,
                                  );
                                },
                              )
                        : _selectedTab == 'Unavailable'
                            ? _buildUnavailableList(context, availabilityProvider)
                            : _buildPartialList(context, availabilityProvider),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: Consumer<SubscriptionProvider>(
          builder: (context, subscriptionProvider, _) {
            final isLocked = !subscriptionProvider.hasActiveSubscription;
            
            return ElevatedButton.icon(
              onPressed: () {
                if (isLocked) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const AutomationBottomSheet(),
                  );
                  return;
                }
                _syncCalendarToDevice(context);
              },
              icon: isLocked 
                  ? const Icon(Icons.lock, color: Colors.orange)
                  : const Icon(Icons.sync), // Sync icon (arrows in circle) when unlocked
              label: const Text('Sync Calendar to Mobile'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCalendarDayCell(BuildContext context, DateTime date) {
    final color = _getDayColor(date);
    final inSub = _isInSubscriptionDayRange(date);
    final isStart = _isSubscriptionSegmentStart(date);
    final isEnd = _isSubscriptionSegmentEnd(date);

    final subColor = Theme.of(context).colorScheme.primary;
    final rangeBg = subColor.withOpacity(0.10);

    final baseDay = Center(
      child: Text(
        '${date.day}',
        style: TextStyle(
          color: color ?? Theme.of(context).colorScheme.onSurface,
          fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );

    return Stack(
      children: [
        if (inSub)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 8),
              decoration: BoxDecoration(
                color: rangeBg,
                border: Border.all(color: subColor, width: 1.5),
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(isStart ? 12 : 0),
                  right: Radius.circular(isEnd ? 12 : 0),
                ),
              ),
            ),
          ),
        if (color != null)
          Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.25),
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
            ),
          )
        else
          baseDay,
      ],
    );
  }

  List<String> _filteredKeywordDates(List<String> keywordDates) {
    if (_keywordSearch.isEmpty) return keywordDates;
    final out = <String>[];
    for (final d in keywordDates) {
      if (d.contains(_keywordSearch)) {
        out.add(d);
        continue;
      }
      final df = Provider.of<FiltersProvider>(context, listen: false).getDateFilters(d);
      final included = (df['includedWords'] ?? const <String>[]).join(' ').toLowerCase();
      final excluded = (df['excludedWords'] ?? const <String>[]).join(' ').toLowerCase();
      if (included.contains(_keywordSearch) || excluded.contains(_keywordSearch)) {
        out.add(d);
      }
    }
    return out;
  }

  Widget _buildUnavailableList(BuildContext context, AvailabilityProvider availabilityProvider) {
    final dates = List<String>.from(availabilityProvider.unavailableDates)..sort();
    if (dates.isEmpty) {
      return const Center(child: Text('No unavailable days'));
    }
    final filtered = dates.where((d) {
      if (_unavailableSearch.isEmpty) return true;
      final reason = availabilityProvider.unavailableReasonsByDate[d] ?? '';
      final q = _unavailableSearch.toLowerCase();
      return d.contains(q) || reason.toLowerCase().contains(q);
    }).toList();

    return ListView.builder(
      itemCount: filtered.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search unavailable days',
                hintText: 'Example: 2026-03-01',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _unavailableSearch = v.trim()),
            ),
          );
        }

        final dateStr = filtered[index - 1];
        final reason = availabilityProvider.unavailableReasonsByDate[dateStr] ?? 'Unavailable';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: Text(dateStr),
            subtitle: Text(reason),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Mark available',
              onPressed: () => _confirmMarkAvailable(dateStr),
            ),
            onTap: () => _showPartialAvailabilityEditor(dateStr),
          ),
        );
      },
    );
  }

  Widget _buildPartialList(BuildContext context, AvailabilityProvider availabilityProvider) {
    final dates = availabilityProvider.partialAvailabilityByDate.keys.toList()..sort();
    if (dates.isEmpty) {
      return const Center(child: Text('No partial availability days'));
    }
    final filtered = dates.where((d) {
      if (_partialSearch.isEmpty) return true;
      final q = _partialSearch.toLowerCase();
      final w = availabilityProvider.partialAvailabilityByDate[d];
      final reason = w?.reason.toLowerCase() ?? '';
      return d.contains(q) || reason.contains(q);
    }).toList();

    return ListView.builder(
      itemCount: filtered.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search partial availability',
                hintText: 'Example: 2026-03-01',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _partialSearch = v.trim()),
            ),
          );
        }

        final dateStr = filtered[index - 1];
        final w = availabilityProvider.partialAvailabilityByDate[dateStr]!;
        final startH = (w.startMinutes ~/ 60).toString().padLeft(2, '0');
        final startM = (w.startMinutes % 60).toString().padLeft(2, '0');
        final endH = (w.endMinutes ~/ 60).toString().padLeft(2, '0');
        final endM = (w.endMinutes % 60).toString().padLeft(2, '0');
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.access_time, color: Color(0xFFBFA100)),
            title: Text(dateStr),
            subtitle: Text('$startH:$startM - $endH:$endM • ${w.reason}'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear time window',
              onPressed: () => _confirmClearPartial(dateStr),
            ),
            onTap: () => _showPartialAvailabilityEditor(dateStr),
          ),
        );
      },
    );
  }

  Future<void> _confirmMarkAvailable(String dateStr) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
              const Text(
                'Mark available?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('This will remove your unavailable status for $dateStr.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep Unavailable'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Mark Available'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await Provider.of<AvailabilityProvider>(context, listen: false).removeUnavailable(dateStr);
  }

  Future<void> _confirmClearPartial(String dateStr) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
              const Text(
                'Clear time window?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('This will remove partial availability for $dateStr.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await Provider.of<AvailabilityProvider>(context, listen: false).clearPartialAvailability(dateStr);
  }

  Future<void> _showPartialAvailabilityEditor(String dateStr, {int? weekday}) async {
    final availabilityProvider = Provider.of<AvailabilityProvider>(context, listen: false);
    final existing = availabilityProvider.partialAvailabilityByDate[dateStr];

    final reasonController = TextEditingController(
      text: existing?.reason ?? 'Personal day.',
    );

    int startMinutes = existing?.startMinutes ?? 8 * 60;
    int endMinutes = existing?.endMinutes ?? 17 * 60;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weekday != null ? 'Partial Availability (bulk)' : 'Partial Availability',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(weekday != null ? 'Applies to all selected weekdays.' : 'Applies to $dateStr.'),
                  const SizedBox(height: 16),
                  TimeWindowPicker(
                    title: 'Time window',
                    value: TimeWindowValue(startMinutes: startMinutes, endMinutes: endMinutes),
                    onChanged: (v) => setLocalState(() {
                      startMinutes = v.startMinutes;
                      endMinutes = v.endMinutes;
                    }),
                    showReason: true,
                    reasonController: reasonController,
                    reasonMaxLength: 250,
                    showJobHistogram: true,
                    histogramScope: 'global',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final reason = reasonController.text.trim().isEmpty
                                ? 'Personal day.'
                                : reasonController.text.trim();
                            await availabilityProvider.setPartialAvailability(
                              dateStr: dateStr,
                              startMinutes: startMinutes,
                              endMinutes: endMinutes,
                              reason: reason,
                            );
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showBulkWeekdayActions(int weekday) async {
    final weekdayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'][weekday - 1];
    final reasonController = TextEditingController(text: 'Personal day.');

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apply to all $weekdayName days?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('This only applies to future workdays up to the next school year cutoff (Aug 1).'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLength: 250,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, 'mark_unavailable'),
                      icon: const Icon(Icons.block),
                      label: const Text('Mark Unavailable'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, 'add_time_window'),
                      icon: const Icon(Icons.access_time),
                      label: const Text('Add Time Window'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );

    if (action == null || !mounted) return;

    final availabilityProvider = Provider.of<AvailabilityProvider>(context, listen: false);
    final keywordDates = availabilityProvider.computeRelevantWorkdaysForKeywords();

    if (action == 'mark_unavailable') {
      // For unavailable, include all future dates in range for that weekday (even if currently filtered out)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final cutoff = today.isAfter(DateTime(today.year, 8, 1))
          ? DateTime(today.year + 1, 8, 1)
          : DateTime(today.year, 8, 1);
      final includeNextYear = today.isAfter(cutoff.subtract(const Duration(days: 31)));
      final end = includeNextYear ? DateTime(cutoff.year + 1, 8, 1) : cutoff;

      int applied = 0;
      int skippedJobs = 0;

      for (DateTime d = today; d.isBefore(end); d = d.add(const Duration(days: 1))) {
        if (d.weekday != weekday) continue;
        if (AvailabilityProvider.isWeekend(d)) continue;
        final ds = AvailabilityProvider.formatDate(d);
        if (availabilityProvider.scheduledJobDates.contains(ds)) {
          skippedJobs += 1;
          continue;
        }
        await availabilityProvider.markUnavailableWithReason(
          ds,
          reason: reasonController.text.trim().isEmpty ? 'Personal day.' : reasonController.text.trim(),
        );
        applied += 1;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked $applied days unavailable. Skipped $skippedJobs job days.')),
        );
      }
      return;
    }

    if (action == 'add_time_window') {
      // Bulk time-window editor: we prompt once, then apply to all matching weekdays in keyword date range.
      // (Allows overlap with job days.)
      // We reuse the single-date editor UI, but apply across all matching weekdays after save.
      // For now, we apply to all currently-relevant keyword dates that match the weekday.
      final matching = keywordDates.where((ds) {
        final parts = ds.split('-');
        final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        return dt.weekday == weekday;
      }).toList();

      if (matching.isEmpty) return;
      await _showPartialAvailabilityEditor(matching.first, weekday: weekday);

      // After editor save, use the chosen window from the first date and apply to all.
      final w = availabilityProvider.partialAvailabilityByDate[matching.first];
      if (w == null) return;
      for (final ds in matching.skip(1)) {
        await availabilityProvider.setPartialAvailability(
          dateStr: ds,
          startMinutes: w.startMinutes,
          endMinutes: w.endMinutes,
          reason: reasonController.text.trim().isEmpty ? w.reason : reasonController.text.trim(),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Applied time window to ${matching.length} days.')),
        );
      }
    }
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
    
    final availabilityProvider = Provider.of<AvailabilityProvider>(context, listen: false);
    
    // Only sync jobs that are marked with "has job" color (blue) - these are in scheduledJobDates
    final bookedJobDates = availabilityProvider.scheduledJobDates.toSet();
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



