import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/subscription_provider.dart';
import '../profile/profile_screen.dart';
import '../../widgets/app_bar_quick_toggles.dart';
import '../../widgets/profile_app_bar.dart';
import '../../widgets/marketing_points.dart';
import '../../widgets/premium_unlock_bottom_sheet.dart';
import '../../widgets/vip_powerup_bottom_sheet.dart';
import '../../widgets/crowned_lock_icon.dart';
import '../../widgets/app_tooltip.dart';
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
                    AppTooltip(
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
                secondary: CrownedLockIcon(unlocked: hasActiveSubscription),
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

        // Set Alert Times + windows (only show when Job Alerts is enabled)
        if (notificationsProvider.notificationsEnabled) ...[
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Set Alert Times'),
                  subtitle: const Text('Only receive notifications during specified time windows'),
                  value: notificationsProvider.setTimesEnabled,
                  onChanged: (value) {
                    notificationsProvider.setSetTimesEnabled(value);
                  },
                ),
                if (notificationsProvider.setTimesEnabled) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      children: [
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
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _addTimeWindow(context, notificationsProvider);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Time Window'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Apply Filter Keywords toggle (paid feature)
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    const Text('Enable Keyword Filter'),
                    AppTooltip(
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
                secondary: CrownedLockIcon(unlocked: hasActiveSubscription),
              ),
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarketingPointRow(point: MarketingPointKey.keywordFiltering, dense: true),
                    MarketingPointRow(point: MarketingPointKey.schoolSelectionMap, dense: true),
                  ],
                ),
              ),
            ],
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
                    AppTooltip(
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
                secondary: CrownedLockIcon(unlocked: hasActiveSubscription),
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
              ListTile(
                onTap: () => VipPowerupBottomSheet.show(context),
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    const Text('VIP Perks Power-up'),
                    AppTooltip(
                      message: 'One-time purchase feature with VIP perks.',
                      child: Icon(
                        Icons.help_outline,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  hasVipPerks ? 'Purchased' : 'Tap to view VIP Power-up package',
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Colors.grey[600],
                ),
                leading: Icon(
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

  void _addTimeWindow(BuildContext context, NotificationsProvider provider) {
    final newWindow = TimeWindow(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: const TimeOfDay(hour: 8, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
    );
    provider.addTimeWindow(newWindow);
  }
}
