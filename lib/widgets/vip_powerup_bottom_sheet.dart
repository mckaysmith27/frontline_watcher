import 'package:flutter/material.dart';

import 'marketing_points.dart';
import 'business_card_info_module.dart';

class VipPowerupBottomSheet extends StatefulWidget {
  const VipPowerupBottomSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final brightness = Theme.of(context).brightness;
    final scrimAlpha = brightness == Brightness.dark ? 0.55 : 0.25;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: scrimAlpha),
      builder: (sheetContext) {
        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(sheetContext).maybePop(),
              child: const SizedBox.expand(),
            ),
            const VipPowerupBottomSheet(),
          ],
        );
      },
    );
  }

  @override
  State<VipPowerupBottomSheet> createState() => _VipPowerupBottomSheetState();
}

class _VipPowerupBottomSheetState extends State<VipPowerupBottomSheet> {
  static const String _packageName = 'VIP Power-up Package';
  static const String _packageQty = '1 Power-up';
  static const String _packagePrice = '\$7.99';

  BusinessCardInfo? _bizInfo;

  @override
  Widget build(BuildContext context) {
    final canCheckout = _bizInfo?.isComplete == true;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.55,
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
                      'VIP Power-up!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'One-time purchase',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[700],
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            MarketingPointRow(point: MarketingPointKey.vipEarlyOutHours),
                            MarketingPointRow(point: MarketingPointKey.vipPreferredSubShortcut),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    if (!canCheckout) ...[
                      Text(
                        'We need a little bit more information from you in order for you to fully utilize your power-up. Prospective educators will need this information if they choose to add you as a perferred sub...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      BusinessCardInfoModule(compact: true, onInfoChanged: (info) => setState(() => _bizInfo = info)),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      'Choose your VIP package:',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[700],
                          ),
                    ),
                    const SizedBox(height: 12),

                    // Single selectable option (already selected).
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.radio_button_checked),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _packageName,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontSize: 16,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w400,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$_packageQty • $_packagePrice',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: canCheckout ? _checkout : null,
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

  void _checkout() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('VIP Power-up checkout coming soon.'),
      ),
    );
  }
}

