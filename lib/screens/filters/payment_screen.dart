import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _promoController = TextEditingController();
  String? _appliedPromo;
  bool _isProcessing = false;

  final List<String> _validPromos = AppConfig.creditPromoCodes;

  double get _finalPrice {
    if (_appliedPromo != null && widget.tier == 'bi-weekly') {
      return 0.0; // Free with promo
    }
    return widget.tierData['price'] as double;
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _applyPromo() async {
    final promo = _promoController.text.trim();
    if (promo.isEmpty) return;

    final isValid = _validPromos.any(
      (p) => p.toLowerCase() == promo.toLowerCase(),
    );

    if (!isValid || widget.tier != 'bi-weekly') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid promo code')),
      );
      return;
    }

    // Check if promo code has already been used
    final hasUsed = await _hasUsedPromoCode(promo);

    if (hasUsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This promo code has already been used'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _appliedPromo = promo;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Promo code applied!')),
    );
  }

  Future<void> _processPayment() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final days = (widget.tierData['days'] as num).toInt();
      
      // If promo code was used, mark it as used before adding credits
      if (_appliedPromo != null) {
        try {
          await _markPromoCodeAsUsed(_appliedPromo!);
        } catch (e) {
          print('Error marking promo code as used: $e');
          // Continue anyway - don't block the purchase
        }
      }

      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));

      // Timestamp-based subscription (single source of truth).
      // NOTE: In production this should be written/verified from store receipt events.
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userSnap = await userDocRef.get();
      final data = userSnap.data();

      DateTime baseUtc = DateTime.now().toUtc();
      final existingEnds = data?['subscriptionEndsAt'];
      if (existingEnds is Timestamp) {
        final existingEndsUtc = existingEnds.toDate().toUtc();
        if (existingEndsUtc.isAfter(baseUtc)) {
          baseUtc = existingEndsUtc;
        }
      }

      final startsAtUtc = DateTime.now().toUtc();
      final endsAtUtc = baseUtc.add(Duration(days: days));

      final purchaseAction = <String, dynamic>{
        'timestamp': FieldValue.serverTimestamp(),
        'promotion': _appliedPromo,
        'subscriptionDays': days,
        'tier': widget.tier,
      };

      await userDocRef.set({
        'subscriptionStartsAt': Timestamp.fromDate(startsAtUtc),
        'subscriptionEndsAt': Timestamp.fromDate(endsAtUtc),
        'subscriptionAutoRenewing': true, // placeholder; should be driven by store renewal state
        'subscriptionActive': true, // derived; kept for compatibility
        'purchaseActions': FieldValue.arrayUnion([purchaseAction]),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription active for $days days.'),
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
            if (widget.tier == 'bi-weekly' && _appliedPromo == null) ...[
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
              const SizedBox(height: 24),
            ],
            // Payment method selection would go here
            // For now, we'll use a simple button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator()
                    : Text('Pay \$${_finalPrice.toStringAsFixed(2)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _hasUsedPromoCode(String promoCode) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return false;
    final data = doc.data();
    final usedPromoCodes = List<String>.from(data?['usedPromoCodes'] ?? const []);
    return usedPromoCodes.contains(promoCode.toUpperCase());
  }

  Future<void> _markPromoCodeAsUsed(String promoCode) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'usedPromoCodes': FieldValue.arrayUnion([promoCode.toUpperCase()]),
    }, SetOptions(merge: true));
  }
}

