import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;

import 'marketing_points.dart';
import 'business_card_info_module.dart';
import '../config/app_config.dart';

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
  static const double _basePriceUsd = 7.99;

  BusinessCardInfo? _bizInfo;
  bool _isProcessing = false;
  String? _inlineStatusMessage;
  bool _inlineStatusIsError = false;

  final TextEditingController _promoController = TextEditingController();
  _PromoInfo? _promo;

  String _formatStripeError(Object e) {
    // flutter_stripe exceptions sometimes stringify as "Instance of ...".
    // Prefer human-readable messages when available.
    if (e is stripe.StripeException) {
      final msg = e.error.localizedMessage ?? e.error.message;
      if (msg != null && msg.trim().isNotEmpty) return msg.trim();
      return e.toString();
    }
    if (e is stripe.StripeConfigException) {
      final msg = e.message;
      if (msg.trim().isNotEmpty) return msg.trim();
      return e.toString();
    }
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring('Exception: '.length) : s;
  }

  Future<void> _showCheckoutErrorDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Checkout failed'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  double _applyPromoToBase(double baseUsd, _PromoInfo promo) {
    var finalUsd = baseUsd;
    if (promo.discountType == 'free') {
      finalUsd = 0.0;
    } else if (promo.discountType == 'percent' && promo.percentOff != null) {
      finalUsd = baseUsd * (1 - (promo.percentOff! / 100));
    } else if (promo.discountType == 'amount' && promo.amountOffUsd != null) {
      finalUsd = baseUsd - promo.amountOffUsd!;
    }
    if (finalUsd < 0) finalUsd = 0;
    return finalUsd;
  }

  String _formatUsd(double v) => v.toStringAsFixed(2);

  Future<void> _applyPromo() async {
    final promo = _promoController.text.trim();
    if (promo.isEmpty) return;
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('validatePromoCode');
      // VIP uses its own tier key.
      final res = await callable.call({'code': promo, 'tier': 'vip_powerup'});
      final data = Map<String, dynamic>.from(res.data as Map);
      setState(() {
        _promo = _PromoInfo.fromMap(data);
        _inlineStatusMessage = 'Promo applied.';
        _inlineStatusIsError = false;
      });
    } catch (e) {
      final msg = 'Invalid promo code: $e';
      setState(() {
        _promo = null;
        _inlineStatusMessage = msg;
        _inlineStatusIsError = true;
      });
      await _showCheckoutErrorDialog(msg);
    }
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canCheckout = _bizInfo?.isComplete == true;
    final displayUsd = _promo == null ? _basePriceUsd : _applyPromoToBase(_basePriceUsd, _promo!);

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

                    // Promo code (inline).
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Promo code',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _promoController,
                                    textInputAction: TextInputAction.done,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter code',
                                      border: OutlineInputBorder(),
                                    ),
                                    onSubmitted: (_) => _applyPromo(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton(
                                  onPressed: _applyPromo,
                                  child: const Text('Apply'),
                                ),
                              ],
                            ),
                          ],
                        ),
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
                                            Row(
                                              children: [
                                                Text(
                                                  '$_packageQty • ',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                                if (_promo != null && displayUsd != _basePriceUsd) ...[
                                                  Text(
                                                    '\$${_formatUsd(_basePriceUsd)}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                      fontStyle: FontStyle.italic,
                                                      decoration: TextDecoration.lineThrough,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '\$${_formatUsd(displayUsd)}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.green[700],
                                                      fontStyle: FontStyle.italic,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ] else ...[
                                                  Text(
                                                    '\$${_formatUsd(_basePriceUsd)}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    if ((_inlineStatusMessage ?? '').trim().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_inlineStatusIsError ? Colors.red : Colors.green).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (_inlineStatusIsError ? Colors.red : Colors.green).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          _inlineStatusMessage!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: _inlineStatusIsError ? Colors.red[800] : Colors.green[800],
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ElevatedButton.icon(
                      onPressed: (canCheckout && !_isProcessing) ? _checkout : null,
                      icon: const Icon(Icons.shopping_cart_checkout),
                      label: Text(_isProcessing ? 'Processing…' : 'Checkout'),
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
    _processVipCheckout();
  }

  Future<void> _processVipCheckout() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _inlineStatusMessage = null;
      _inlineStatusIsError = false;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      if (stripe.Stripe.publishableKey.trim().isEmpty) {
        throw Exception(
          'Stripe is not configured yet (missing publishable key). '
          'Set functions config stripe.publishable_key and redeploy functions.',
        );
      }

      final functions = FirebaseFunctions.instance;
      final createCallable = functions.httpsCallable('createVipPowerupPaymentSession');
      final sessionRes = await createCallable.call({
        if (_promo?.code.isNotEmpty == true) 'promoCode': _promo!.code,
      });
      final session = Map<String, dynamic>.from(sessionRes.data as Map);

      final mode = (session['mode'] as String?) ?? 'payment'; // none|payment
      final customerId = session['customerId'] as String?;
      final ephemeralKeySecret = session['ephemeralKeySecret'] as String?;
      final paymentIntentClientSecret = session['paymentIntentClientSecret'] as String?;
      final intentId = session['intentId'] as String?;

      if (mode == 'payment') {
        if (customerId == null ||
            ephemeralKeySecret == null ||
            paymentIntentClientSecret == null ||
            intentId == null) {
          throw Exception('Invalid payment session');
        }

        await stripe.Stripe.instance.initPaymentSheet(
          paymentSheetParameters: stripe.SetupPaymentSheetParameters(
            merchantDisplayName: AppConfig.stripeMerchantDisplayName,
            customerId: customerId,
            customerEphemeralKeySecret: ephemeralKeySecret,
            paymentIntentClientSecret: paymentIntentClientSecret,
            style: ThemeMode.system,
          ),
        );
        await stripe.Stripe.instance.presentPaymentSheet();
      }

      final confirmCallable = functions.httpsCallable('confirmVipPowerupPurchase');
      await confirmCallable.call({
        'mode': mode,
        if (intentId != null) 'intentId': intentId,
        if (_promo?.code.isNotEmpty == true) 'promoCode': _promo!.code,
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = 'VIP checkout failed: ${_formatStripeError(e)}';
      setState(() {
        _inlineStatusMessage = msg;
        _inlineStatusIsError = true;
      });
      await _showCheckoutErrorDialog(msg);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

class _PromoInfo {
  const _PromoInfo({
    required this.code,
    required this.discountType,
    this.tier,
    this.percentOff,
    this.amountOffUsd,
  });

  final String code;
  final String? tier;
  final String discountType; // free|percent|amount
  final double? percentOff;
  final double? amountOffUsd;

  factory _PromoInfo.fromMap(Map<String, dynamic> data) {
    return _PromoInfo(
      code: (data['code'] as String? ?? '').toUpperCase(),
      tier: (data['tier'] as String?)?.toLowerCase(),
      discountType: (data['discountType'] as String? ?? 'free').toLowerCase(),
      percentOff: (data['percentOff'] is num) ? (data['percentOff'] as num).toDouble() : null,
      amountOffUsd: (data['amountOffUsd'] is num) ? (data['amountOffUsd'] as num).toDouble() : null,
    );
  }
}

