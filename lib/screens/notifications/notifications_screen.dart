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
import '../../widgets/comet_lock_icon.dart';
import '../../widgets/app_tooltip.dart';
import 'time_window_widget.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _hintTooltipText(MarketingPointKey key) {
    final d = MarketingPoints.data(key);
    var msg = d.text.replaceAll('<userRole>', 'user');
    if (d.termTooltips.isNotEmpty) {
      msg = '$msg\n\n${d.termTooltips.values.join('\n\n')}';
    }
    return msg;
  }

  Widget _hintIconsRow(BuildContext context, List<MarketingPointKey> keys) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < keys.length; i++) ...[
              AppTooltip(
                message: _hintTooltipText(keys[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    MarketingPoints.data(keys[i]).icon,
                    size: 20,
                    color: cs.primary,
                  ),
                ),
              ),
              if (i != keys.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hintSticker(BuildContext context, List<MarketingPointKey> keys) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.20),
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
        ),
        child: _hintIconsRow(context, keys),
      ),
    );
  }

  Widget _marketingPointsList(List<MarketingPointKey> keys) {
    return Column(
      children: [
        for (final k in keys) MarketingPointRow(point: k, dense: true),
      ],
    );
  }

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
    final jobAlertsHints = const [
      MarketingPointKey.fastAlerts,
      MarketingPointKey.priorityBooking,
      MarketingPointKey.jobAlertsCustomTimeWindows,
      MarketingPointKey.jobAlertsHistogramGuide,
    ];
    final keywordHints = const [
      MarketingPointKey.keywordFiltering,
      MarketingPointKey.schoolSelectionMap,
    ];
    final calendarHints = const [
      MarketingPointKey.calendarSync,
    ];
    final vipHints = const [
      MarketingPointKey.vipEarlyOutHours,
      MarketingPointKey.vipPreferredSubShortcut,
    ];
    final vipActive = hasVipPerks && notificationsProvider.vipPerksEnabled;

    return Column(
      children: [
        // Enable Job Alerts toggle (subscription-gated)
        Card(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  if (notificationsProvider.notificationsEnabled) const SizedBox(height: 12),
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
                  if (notificationsProvider.notificationsEnabled) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Set Alert Times'),
                            subtitle: const Text('Only receive notifications during specified time windows'),
                            value: notificationsProvider.setTimesEnabled,
                            onChanged: (value) {
                              notificationsProvider.setSetTimesEnabled(value);
                            },
                          ),
                          if (notificationsProvider.setTimesEnabled) ...[
                            const SizedBox(height: 8),
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
                        ],
                      ),
                    ),
                  ] else ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: _marketingPointsList(jobAlertsHints),
                    ),
                  ],
                ],
              ),
              if (notificationsProvider.notificationsEnabled)
                Positioned(
                  right: 14,
                  top: -14,
                  child: _hintSticker(context, jobAlertsHints),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Apply Filter Keywords toggle (paid feature)
        Card(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  if (notificationsProvider.applyFilterEnabled) const SizedBox(height: 12),
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
                  if (!notificationsProvider.applyFilterEnabled) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: _marketingPointsList(keywordHints),
                    ),
                  ],
                ],
              ),
              if (notificationsProvider.applyFilterEnabled)
                Positioned(
                  right: 14,
                  top: -14,
                  child: _hintSticker(context, keywordHints),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Calendar Sync toggle (paid feature)
        Card(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  if (notificationsProvider.calendarSyncEnabled) const SizedBox(height: 12),
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
                  if (!notificationsProvider.calendarSyncEnabled) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: _marketingPointsList(calendarHints),
                    ),
                  ],
                ],
              ),
              if (notificationsProvider.calendarSyncEnabled)
                Positioned(
                  right: 14,
                  top: -14,
                  child: _hintSticker(context, calendarHints),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // VIP Perks Power-up (one-time purchase feature)
        Card(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  if (hasVipPerks) const SizedBox(height: 12),
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
                    leading: CometLockIcon(
                      unlocked: vipActive,
                      lockedColor: Colors.deepPurple,
                      unlockedColor: Colors.deepPurple,
                      cometColor: const Color(0xFF7C4DFF),
                    ),
                  ),
                  if (!hasVipPerks) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: _marketingPointsList(vipHints),
                    ),
                  ],
                ],
              ),
              if (hasVipPerks)
                Positioned(
                  right: 14,
                  top: -14,
                  child: _hintSticker(context, vipHints),
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
