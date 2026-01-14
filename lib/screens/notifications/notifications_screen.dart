import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/credits_provider.dart';
import '../../widgets/notifications_terms_agreement.dart';
import '../filters/automation_bottom_sheet.dart';
import '../filters/filters_screen.dart';
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
          final hasActiveSubscription = creditsProvider.hasActiveSubscription;
          final termsAccepted = notificationsProvider.termsAccepted;
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Terms and Conditions Agreement (shown if not accepted)
              if (!termsAccepted)
                NotificationsTermsAgreement(
                  onAgreed: (_) {},
                  onAccept: () {
                    notificationsProvider.acceptTerms();
                  },
                ),
              
              if (!termsAccepted) const SizedBox(height: 16),
              
              // All toggles are disabled until terms are accepted
              if (!termsAccepted)
                Opacity(
                  opacity: 0.5,
                  child: IgnorePointer(
                    child: _buildToggles(context, notificationsProvider, creditsProvider, hasActiveSubscription),
                  ),
                )
              else
                _buildToggles(context, notificationsProvider, creditsProvider, hasActiveSubscription),
            ],
          );
        },
      ),
    );
  }

  Widget _buildToggles(BuildContext context, NotificationsProvider notificationsProvider, CreditsProvider creditsProvider, bool hasActiveSubscription) {
    return Column(
      children: [
        // Enable Notifications toggle
        Card(
          child: SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Receive notifications for new job postings'),
            value: notificationsProvider.notificationsEnabled,
            onChanged: notificationsProvider.termsAccepted
                ? (value) {
                    notificationsProvider.setNotificationsEnabled(value);
                  }
                : null,
          ),
        ),
        const SizedBox(height: 16),
        
        // Enable FAST Notifications toggle (paid feature)
        Card(
          child: SwitchListTile(
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                const Text("Enable 'FAST Notifications'"),
                Text(
                  '(recommended)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            subtitle: Row(
              children: [
                const Expanded(
                  child: Text('Get instant notifications for matching jobs'),
                ),
                Tooltip(
                  message: 'Uses proprietary scanning architecture to minimize the gap between a job first being posted and the user being notified.',
                  child: Icon(
                    Icons.help_outline,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            value: notificationsProvider.fastNotificationsEnabled,
            onChanged: notificationsProvider.termsAccepted
                ? (hasActiveSubscription
                    ? (value) {
                        notificationsProvider.setFastNotificationsEnabled(value);
                      }
                    : (_) {
                        _showPurchaseOptions(context);
                      })
                : null,
            secondary: !hasActiveSubscription
                ? const Icon(Icons.lock, color: Colors.orange)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        
        // Enable FAST Job Accept toggle (paid feature)
        Card(
          child: SwitchListTile(
            title: const Text("Enable 'FAST Job Accept'"),
            subtitle: Row(
              children: [
                const Expanded(
                  child: Text('Automatically accept jobs that match your preferences'),
                ),
                Tooltip(
                  message: 'Uses proprietary technology features—like the applying of a keywords filter and guidance towards a users desired call to action thus enabling the user to reduce time between being notified and accepting a desired new job.',
                  child: Icon(
                    Icons.help_outline,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            value: notificationsProvider.fastJobAcceptEnabled,
            onChanged: notificationsProvider.termsAccepted
                ? (hasActiveSubscription
                    ? (value) {
                        notificationsProvider.setFastJobAcceptEnabled(value);
                      }
                    : (_) {
                        _showPurchaseOptions(context);
                      })
                : null,
            secondary: !hasActiveSubscription
                ? const Icon(Icons.lock, color: Colors.orange)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        
        // Apply Filter (keywords) toggle (paid feature)
        Card(
          child: SwitchListTile(
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                const Text('Apply Filter (keywords)'),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FiltersScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Filter (keywords)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: const Text('Apply your keyword filters to job notifications'),
            value: notificationsProvider.applyFilterEnabled,
            onChanged: notificationsProvider.termsAccepted
                ? (hasActiveSubscription
                    ? (value) {
                        notificationsProvider.setApplyFilterEnabled(value);
                      }
                    : (_) {
                        _showPurchaseOptions(context);
                      })
                : null,
            secondary: !hasActiveSubscription
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
            onChanged: notificationsProvider.termsAccepted
                ? (value) {
                    notificationsProvider.setSetTimesEnabled(value);
                  }
                : null,
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
              onPressed: notificationsProvider.termsAccepted
                  ? () {
                      _addTimeWindow(context, notificationsProvider);
                    }
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('Add Time Window'),
            ),
          ),
        ],
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
