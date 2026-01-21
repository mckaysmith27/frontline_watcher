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
    // Keep each headline visible long enough to read.
    Future<void>.delayed(const Duration(seconds: 7), () {
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
      child = Text(
        'Get alerts, get the job, get preferred, get booked for more jobs.',
        style: style,
        textAlign: TextAlign.center,
      );
    } else if (_headlineIndex == 1) {
      child = Text(
        '"I can actually accept the job before it disappears! 🥲" —Mr.H',
        style: style,
        textAlign: TextAlign.center,
      );
    } else {
      child = Text(
        '"It shouldn’t be a part time job just trying to get a job." —Mr.McCay',
        style: style,
        textAlign: TextAlign.center,
      );
    }

    // Keep this area a fixed height so the rest of the sheet doesn't jump
    // as sentences change length.
    return SizedBox(
      height: 86,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: SizedBox(
          key: ValueKey(_headlineIndex),
          width: double.infinity,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: child,
            ),
          ),
        ),
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
                      textAlign: TextAlign.center,
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
                              text: "Cut through the noise with ‘KEYWORD FILTERING’.",
                            ),
                            _featureRow(
                              icon: Icons.sync,
                              text: 'Sync jobs to your mobile calendar.',
                            ),
                            _featureRow(
                              icon: Icons.badge,
                              text:
                                  'Get free* personalized business cards sent directly to you in the mail.',
                            ),
                            _featureRow(
                              icon: Icons.qr_code_2,
                              text:
                                  'Get added quickly as a preferred sub with you own personalized QR code link.',
                            ),
                            _featureRow(
                              icon: Icons.people,
                              text:
                                  'Connect with fellow subs, teachers, and administration.',
                            ),
                            _featureRow(
                              icon: Icons.support_agent,
                              text:
                                  'Get quick answers to all of your questions from other educators and AI support.',
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

