import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/subscription_provider.dart';
import '../filters/automation_bottom_sheet.dart';
import '../profile/profile_screen.dart';
import '../../widgets/app_bar_quick_toggles.dart';
import '../../widgets/profile_app_bar.dart';
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
      body: Consumer2<NotificationsProvider, SubscriptionProvider>(
        builder: (context, notificationsProvider, subscriptionProvider, _) {
          final hasActiveSubscription = subscriptionProvider.hasActiveSubscription;
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildToggles(context, notificationsProvider, hasActiveSubscription),
            ],
          );
        },
      ),
    );
  }

  Widget _buildToggles(BuildContext context, NotificationsProvider notificationsProvider, bool hasActiveSubscription) {
    return Column(
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
        
        // Enable FAST Notifications toggle (paid feature)
        Card(
          child: SwitchListTile(
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                const Text("Enable 'FAST ALERT'"),
                Tooltip(
                  message:
                      'Uses proprietary scanning architecture to minimize the gap between a job first being posted and the user being notified.',
                  child: Icon(
                    Icons.help_outline,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            subtitle: const Text('Get instant notifications for matching jobs'),
            value: notificationsProvider.fastNotificationsEnabled,
            onChanged: hasActiveSubscription
                ? (value) {
                    notificationsProvider.setFastNotificationsEnabled(value);
                  }
                : (_) {
                    _showPurchaseOptions(context);
                  },
            secondary: Icon(
              hasActiveSubscription ? Icons.lock_open : Icons.lock,
              color: hasActiveSubscription ? Colors.green : Colors.orange,
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Enable FAST Job Accept toggle (paid feature)
        Card(
          child: SwitchListTile(
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                const Text("Enable 'PRIORITY BOOKING'"),
                Tooltip(
                  message:
                      'Uses proprietary technology features—like the applying of a keywords filter and guidance towards a users desired call to action thus enabling the user to reduce time between being notified and accepting a desired new job.',
                  child: Icon(
                    Icons.help_outline,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            subtitle: const Text('Automatically accept jobs that match your preferences'),
            value: notificationsProvider.fastJobAcceptEnabled,
            onChanged: hasActiveSubscription
                ? (value) {
                    notificationsProvider.setFastJobAcceptEnabled(value);
                  }
                : (_) {
                    _showPurchaseOptions(context);
                  },
            secondary: Icon(
              hasActiveSubscription ? Icons.lock_open : Icons.lock,
              color: hasActiveSubscription ? Colors.green : Colors.orange,
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Apply Filter Keywords toggle (paid feature)
        Card(
          child: SwitchListTile(
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                const Text('Apply Filter Keywords'),
                Tooltip(
                  message:
                      "This activates the keywords specified on the 'filters' feature so that you are only notified of jobs that meet your keyword specifications.",
                  child: Icon(
                    Icons.help_outline,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            subtitle: const Text('Apply your keyword filters to job notifications'),
            value: notificationsProvider.applyFilterEnabled,
            onChanged: hasActiveSubscription
                ? (value) {
                    notificationsProvider.setApplyFilterEnabled(value);
                  }
                : (_) {
                    _showPurchaseOptions(context);
                  },
            secondary: Icon(
              hasActiveSubscription ? Icons.lock_open : Icons.lock,
              color: hasActiveSubscription ? Colors.green : Colors.orange,
            ),
          ),
        ),
        const SizedBox(height: 16),
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

  void _addTimeWindow(BuildContext context, NotificationsProvider provider) {
    final newWindow = TimeWindow(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: const TimeOfDay(hour: 8, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    );
    provider.addTimeWindow(newWindow);
  }
}
