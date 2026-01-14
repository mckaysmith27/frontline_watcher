import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/credits_provider.dart';
import '../filters/automation_bottom_sheet.dart';
import 'time_window_widget.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: Consumer2<NotificationsProvider, CreditsProvider>(
        builder: (context, notificationsProvider, creditsProvider, _) {
          final hasCredits = creditsProvider.credits > 0 || creditsProvider.committedDates.isNotEmpty;
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Enable Notifications toggle
              Card(
                child: SwitchListTile(
                  title: const Text('Enable Notifications'),
                  subtitle: const Text('Receive notifications for new job postings'),
                  value: notificationsProvider.notificationsEnabled,
                  onChanged: (value) {
                    notificationsProvider.setNotificationsEnabled(value);
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // Enable FAST Notifications toggle (paid feature)
              Card(
                child: SwitchListTile(
                  title: Row(
                    children: [
                      const Text('Enable FAST* Notifications'),
                      const SizedBox(width: 4),
                      Text(
                        '(recommended)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const Spacer(),
                      if (!hasCredits)
                        IconButton(
                          icon: const Icon(Icons.lock),
                          color: Colors.orange,
                          onPressed: () {
                            _showPurchaseOptions(context);
                          },
                          tooltip: 'Requires subscription',
                        ),
                    ],
                  ),
                  subtitle: const Text('Get instant notifications for matching jobs'),
                  value: notificationsProvider.fastNotificationsEnabled,
                  onChanged: hasCredits
                      ? (value) {
                          notificationsProvider.setFastNotificationsEnabled(value);
                        }
                      : (_) {
                          _showPurchaseOptions(context);
                        },
                  secondary: !hasCredits
                      ? const Icon(Icons.lock, color: Colors.orange)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              
              // Set Times toggle
              Card(
                child: SwitchListTile(
                  title: const Text('Set Times'),
                  subtitle: const Text('Only receive notifications during specified time windows'),
                  value: notificationsProvider.setTimesEnabled,
                  onChanged: (value) {
                    notificationsProvider.setSetTimesEnabled(value);
                  },
                ),
              ),
              
              // Time windows (shown when setTimesEnabled is true)
              if (notificationsProvider.setTimesEnabled) ...[
                const SizedBox(height: 16),
                ...notificationsProvider.timeWindows.map((window) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TimeWindowWidget(
                      timeWindow: window,
                      onUpdate: (updatedWindow) {
                        notificationsProvider.updateTimeWindow(window.id, updatedWindow);
                      },
                      onDelete: () {
                        notificationsProvider.removeTimeWindow(window.id);
                      },
                    ),
                  );
                }),
                
                // Add time window button
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _addTimeWindow(context, notificationsProvider);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Time Window'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showPurchaseOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AutomationBottomSheet(),
    );
  }

  void _addTimeWindow(BuildContext context, NotificationsProvider provider) {
    final newWindow = TimeWindow(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: const TimeOfDay(hour: 8, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    );
    provider.addTimeWindow(newWindow);
  }
}
