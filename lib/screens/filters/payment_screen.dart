import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/credits_provider.dart';
import '../../providers/auth_provider.dart';
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
    final creditsProvider = Provider.of<CreditsProvider>(context, listen: false);
    final hasUsed = await creditsProvider.hasUsedPromoCode(promo);

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
      final creditsProvider = Provider.of<CreditsProvider>(context, listen: false);
      final credits = widget.tierData['credits'] as int;
      
      // If promo code was used, mark it as used before adding credits
      if (_appliedPromo != null) {
        try {
          await creditsProvider.markPromoCodeAsUsed(_appliedPromo!);
        } catch (e) {
          print('Error marking promo code as used: $e');
          // Continue anyway - don't block the purchase
        }
      }

      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));

      // Add credits with error handling
      try {
        await creditsProvider.addCredits(credits);
      } catch (e) {
        print('Error adding credits: $e');
        throw Exception('Failed to add credits: $e');
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully purchased $credits credits!'),
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
                        Text('${widget.tierData['credits']} credits'),
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
}

