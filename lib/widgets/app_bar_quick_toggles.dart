import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/subscription_provider.dart';
import 'premium_unlock_bottom_sheet.dart';

class AppBarQuickToggles extends StatelessWidget {
  const AppBarQuickToggles({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<NotificationsProvider, SubscriptionProvider>(
      builder: (context, notificationsProvider, subscriptionProvider, _) {
        final alertsOn = notificationsProvider.notificationsEnabled;
        final filtersOn = notificationsProvider.applyFilterEnabled;
        final subscribed = subscriptionProvider.hasActiveSubscription;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Filter toggle
            IconButton(
              tooltip: filtersOn ? 'Filters on (tap to turn off)' : 'Filters off (tap to turn on)',
              icon: Icon(filtersOn ? Icons.filter_alt : Icons.filter_alt_off),
              onPressed: () {
                if (filtersOn) {
                  // Turning OFF should always be allowed.
                  notificationsProvider.setApplyFilterEnabled(false);
                  return;
                }
                // Turning ON remains subscription-gated.
                if (!subscribed) {
                  PremiumUnlockBottomSheet.show(context);
                  return;
                }
                notificationsProvider.setApplyFilterEnabled(true);
              },
            ),

            // Job alerts toggle (bell)
            IconButton(
              tooltip: alertsOn ? 'Job alerts on (tap to turn off)' : 'Job alerts off (tap to turn on)',
              icon: alertsOn
                  ? Stack(
                      clipBehavior: Clip.none,
                      children: const [
                        Icon(Icons.notifications_active),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Icon(Icons.bolt, size: 14),
                        ),
                      ],
                    )
                  : const Icon(Icons.notifications_off),
              onPressed: () {
                notificationsProvider.setNotificationsEnabled(!alertsOn);
              },
            ),
          ],
        );
      },
    );
  }
}

