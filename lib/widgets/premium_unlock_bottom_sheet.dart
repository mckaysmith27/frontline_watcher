import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../screens/filters/payment_screen.dart';

class PremiumUnlockBottomSheet extends StatefulWidget {
  const PremiumUnlockBottomSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PremiumUnlockBottomSheet(),
    );
  }

  @override
  State<PremiumUnlockBottomSheet> createState() => _PremiumUnlockBottomSheetState();
}

class _PremiumUnlockBottomSheetState extends State<PremiumUnlockBottomSheet> {
  String? _selectedTier;
  int _headlineIndex = 0;

  Map<String, Map<String, dynamic>> get _tiers => AppConfig.subscriptionTiers;

  @override
  void initState() {
    super.initState();
    _startHeadlineLoop();
  }

  void _startHeadlineLoop() {
    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() => _headlineIndex = (_headlineIndex + 1) % 3);
      _startHeadlineLoop();
    });
  }

  Widget _headline(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 22,
        );

    Widget child;
    if (_headlineIndex == 0) {
      child = Text('Get the job!', style: style);
    } else if (_headlineIndex == 1) {
      child = Text.rich(
        TextSpan(
          style: style,
          children: const [
            TextSpan(text: "Get on teachers/admin 'Preferred Sub' list—by the teachers/admin that "),
            TextSpan(text: 'you', style: TextStyle(fontStyle: FontStyle.italic)),
            TextSpan(text: ' prefer.'),
          ],
        ),
      );
    } else {
      child = Text("Connect with other subs, and share in each other's experience.", style: style);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: SizedBox(
        key: ValueKey(_headlineIndex),
        width: double.infinity,
        child: child,
      ),
    );
  }

  Widget _featureRow({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Unlock Premium Features',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),

                    // Marketing headline carousel
                    _headline(context),
                    const SizedBox(height: 12),

                    // Feature bullets (with icons)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _featureRow(
                              icon: Icons.bolt,
                              text:
                                  "Get notified quickly when a new job is posted with 'FAST ALERTS' technology.",
                            ),
                            _featureRow(
                              icon: Icons.workspace_premium,
                              text:
                                  "Be first to accept the job with proprietary 'PRIORITY BOOKING'.",
                            ),
                            _featureRow(
                              icon: Icons.filter_list,
                              text:
                                  "Sort through the noise to get notifications only for the jobs you want with 'ADVANCED KEYWORKD FILTERING'.",
                            ),
                            _featureRow(
                              icon: Icons.sync,
                              text: 'Set up and sync jobs with your mobile calendar.',
                            ),
                            _featureRow(
                              icon: Icons.badge,
                              text:
                                  'Get free business cards sent to you in the mail with a QR code link for teachers/admin to give you preferred status when posting their next available job.',
                            ),
                            _featureRow(
                              icon: Icons.people,
                              text:
                                  "Connect—get quick answers, suggestions, and support from fellow subs.",
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Text(
                      'Choose your Premium Subscription:',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[700],
                          ),
                    ),
                    const SizedBox(height: 12),
                    ..._tiers.entries.map((entry) {
                      final isSelected = _selectedTier == entry.key;
                      final pretty = entry.key
                          .split('-')
                          .map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1)))
                          .join(' ');
                      final title = entry.key == 'monthly' ? '$pretty (recommended)' : pretty;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => setState(() => _selectedTier = entry.key),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: entry.key,
                                  groupValue: _selectedTier,
                                  onChanged: (value) => setState(() => _selectedTier = value),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${entry.value['days']} days • \$${entry.value['price']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: _selectedTier != null ? _checkout : null,
                      icon: const Icon(Icons.shopping_cart_checkout),
                      label: const Text('Checkout'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkout() async {
    final tier = _selectedTier;
    if (tier == null) return;
    final tierData = _tiers[tier];
    if (tierData == null) return;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          tier: tier,
          tierData: tierData,
        ),
      ),
    );
  }
}

