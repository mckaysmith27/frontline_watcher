import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import '../../config/app_config.dart';

class PaymentScreen extends StatefulWidget {
  final String tier;
  final Map<String, dynamic> tierData;

  const PaymentScreen({
    super.key,
    required this.tier,
    required this.tierData,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  final TextEditingController _promoController = TextEditingController();
  String? _appliedPromo;
  bool _isProcessing = false;
  bool _promoCardRequired = true;

  double get _finalPrice {
    final base = (widget.tierData['price'] as num).toDouble();
    if (_appliedPromo == null) return base;
    // For now, promo codes are validated server-side. If promo is applied,
    // we treat it as free (or discounted) based on the server response.
    // This screen uses the server for final pricing at checkout time.
    // Display optimistic: show $0 when promo is applied.
    return 0.0;
  }

  double get _basePriceUsd => (widget.tierData['price'] as num).toDouble();

  int get _days => (widget.tierData['days'] as num).toInt();

  String get _payButtonLabel {
    if (_appliedPromo != null) {
      return _promoCardRequired ? 'Checkout (card required for renewal)' : 'Checkout';
    }
    return 'Checkout';
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _applyPromo() async {
    final promo = _promoController.text.trim();
    if (promo.isEmpty) return;
    try {
      final callable = _functions.httpsCallable('validatePromoCode');
      final res = await callable.call({'code': promo, 'tier': widget.tier});
      final data = Map<String, dynamic>.from(res.data as Map);
      final cardReq = data['isCardStillRequired'] == true;
      setState(() {
        _appliedPromo = promo.toUpperCase();
        _promoCardRequired = cardReq;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cardReq ? 'Promo applied. Card still required for renewal.' : 'Promo applied.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid promo code: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _processPayment() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      if (AppConfig.stripePublishableKey.trim().isEmpty) {
        throw Exception('Stripe publishable key not configured in AppConfig.stripePublishableKey');
      }

      final promoCode = _appliedPromo;

      // Ask backend to create a session based on promo + tier.
      final createCallable = _functions.httpsCallable('createStripePaymentSession');
      final sessionRes = await createCallable.call({
        'tier': widget.tier,
        'basePriceUsd': _basePriceUsd,
        if (promoCode != null) 'promoCode': promoCode,
      });
      final session = Map<String, dynamic>.from(sessionRes.data as Map);

      final mode = (session['mode'] as String?) ?? 'none'; // none|setup|payment
      final intentId = session['intentId'] as String?;
      final customerId = session['customerId'] as String?;
      final ephemeralKeySecret = session['ephemeralKeySecret'] as String?;
      final paymentIntentClientSecret = session['paymentIntentClientSecret'] as String?;
      final setupIntentClientSecret = session['setupIntentClientSecret'] as String?;

      if (mode == 'payment') {
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
      } else if (mode == 'setup') {
        await stripe.Stripe.instance.initPaymentSheet(
          paymentSheetParameters: stripe.SetupPaymentSheetParameters(
            merchantDisplayName: AppConfig.stripeMerchantDisplayName,
            customerId: customerId,
            customerEphemeralKeySecret: ephemeralKeySecret,
            setupIntentClientSecret: setupIntentClientSecret,
            style: ThemeMode.system,
          ),
        );
        await stripe.Stripe.instance.presentPaymentSheet();
      } else {
        // no card required
      }

      // Finalize subscription and mark promo redemption server-side.
      final confirmCallable = _functions.httpsCallable('confirmSubscriptionPurchase');
      await confirmCallable.call({
        'tier': widget.tier,
        'days': _days,
        'mode': mode,
        if (intentId != null) 'intentId': intentId,
        if (promoCode != null) 'promoCode': promoCode,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription active for $_days days.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Payment processing error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Purchase')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Summary',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.tier
                              .split('-')
                              .map((w) => w[0].toUpperCase() + w.substring(1))
                              .join(' '),
                        ),
                        Text(
                          '\$${widget.tierData['price']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${widget.tierData['days']} days'),
                        const Text('Subscription'),
                      ],
                    ),
                    if (_appliedPromo != null) ...[
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Promo: $_appliedPromo',
                            style: TextStyle(color: Colors.green[700]),
                          ),
                          Text(
                            '-\$${widget.tierData['price']}',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${_finalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Promo Code',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoController,
                    decoration: const InputDecoration(
                      hintText: 'Enter promo code',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _applyPromo,
                  child: const Text('Apply'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator()
                    : Text(_payButtonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

