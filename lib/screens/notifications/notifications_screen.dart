import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/subscription_provider.dart';
import '../profile/profile_screen.dart';
import '../../widgets/app_bar_quick_toggles.dart';
import '../../widgets/profile_app_bar.dart';
import '../../widgets/marketing_points.dart';
import '../../widgets/premium_unlock_bottom_sheet.dart';
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
          final hasVipPerks = notificationsProvider.vipPerksPurchased;
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildToggles(context, notificationsProvider, hasActiveSubscription, hasVipPerks),
            ],
          );
        },
      ),
    );
  }

  Widget _buildToggles(
    BuildContext context,
    NotificationsProvider notificationsProvider,
    bool hasActiveSubscription,
    bool hasVipPerks,
  ) {
    return Column(
      children: [
        // Enable Job Alerts toggle (subscription-gated)
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    const Text('Enable Job Alerts'),
                    Tooltip(
                      message:
                          'Turns on job alerts. When enabled, Sub67 will notify you when a new matching job is posted.',
                      child: Icon(
                        Icons.help_outline,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                subtitle: const Text('Receive job alerts for new job postings'),
                value: notificationsProvider.notificationsEnabled,
                onChanged: (value) {
                  if (!hasActiveSubscription && value == true) {
                    PremiumUnlockBottomSheet.show(context);
                    return;
                  }
                  notificationsProvider.setNotificationsEnabled(value);
                },
                secondary: Icon(
                  hasActiveSubscription ? Icons.lock_open : Icons.lock,
                  color: hasActiveSubscription ? Colors.green : Colors.orange,
                ),
              ),
              // Marketing points visually connected to Job Alerts
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    MarketingPointRow(point: MarketingPointKey.fastAlerts, dense: true),
                    MarketingPointRow(point: MarketingPointKey.priorityBooking, dense: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Set Times toggle
        Card(
          child: SwitchListTile(
            title: const Text('Set Alert Times'),
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
        
        // Apply Filter Keywords toggle (paid feature)
        Card(
          child: SwitchListTile(
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                const Text('Enable Keyword Filter'),
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
            subtitle: const Text("Apply your own tailored filter to the job alerts you'll recieve."),
            value: notificationsProvider.applyFilterEnabled,
            onChanged: hasActiveSubscription
                ? (value) {
                    notificationsProvider.setApplyFilterEnabled(value);
                  }
                : (_) {
                    PremiumUnlockBottomSheet.show(context);
                  },
            secondary: Icon(
              hasActiveSubscription ? Icons.lock_open : Icons.lock,
              color: hasActiveSubscription ? Colors.green : Colors.orange,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Calendar Sync toggle (paid feature)
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    const Text('Calendar Sync'),
                    Tooltip(
                      message: "Sync up the jobs you have booked to your mobile's  calendar.",
                      child: Icon(
                        Icons.help_outline,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                value: notificationsProvider.calendarSyncEnabled,
                onChanged: hasActiveSubscription
                    ? (value) => notificationsProvider.setCalendarSyncEnabled(value)
                    : (_) => PremiumUnlockBottomSheet.show(context),
                secondary: Icon(
                  hasActiveSubscription ? Icons.lock_open : Icons.lock,
                  color: hasActiveSubscription ? Colors.green : Colors.orange,
                ),
              ),
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarketingPointRow(point: MarketingPointKey.calendarSync, dense: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // VIP Perks Power-up (one-time purchase feature)
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    const Text('VIP Perks Power-up'),
                    Tooltip(
                      message: 'One-time purchase feature with VIP perks.',
                      child: Icon(
                        Icons.help_outline,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                value: notificationsProvider.vipPerksEnabled,
                onChanged: (value) {
                  if (!hasVipPerks && value == true) {
                    _showVipPerksPurchaseSheet(context);
                    return;
                  }
                  notificationsProvider.setVipPerksEnabled(value);
                },
                secondary: Icon(
                  hasVipPerks ? Icons.lock_open : Icons.lock,
                  color: Colors.deepPurple,
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MarketingPointRow(
                      point: MarketingPointKey.vipEarlyOutHours,
                      dense: true,
                    ),
                    const MarketingPointRow(
                      point: MarketingPointKey.vipPreferredSubShortcut,
                      dense: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "An email will be sent out with your profile link to an email subscriber who as opted-in to recieve sub67 marketing and promotions materials for teachers/administration, if in the case that there aren't yet teachers/administrators who are sub67 users in the schools you have selected on your filters page. This email will include your link inviting the subscriber to add to add you as a preferred sub.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Preferred Sub list requests are optional and controlled by teachers/administration and district processes; Sub67 cannot guarantee you will be added.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showVipPerksPurchaseSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VIP Perks Power-up',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'One-time purchase',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[700],
                      ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Checkout for VIP Perks is not wired up yet in this build.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('VIP Perks checkout coming soon.'),
                        ),
                      );
                    },
                    child: const Text('Checkout'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
