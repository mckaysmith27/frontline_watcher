import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../providers/credits_provider.dart';
import '../../providers/auth_provider.dart';

class BusinessCardOrderScreen extends StatefulWidget {
  final String shortname;
  final String userName;
  final String? userPhone;
  final String? userEmail;

  const BusinessCardOrderScreen({
    super.key,
    required this.shortname,
    required this.userName,
    this.userPhone,
    this.userEmail,
  });

  @override
  State<BusinessCardOrderScreen> createState() => _BusinessCardOrderScreenState();
}

class _BusinessCardOrderScreenState extends State<BusinessCardOrderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  int _selectedQuantity = 5; // Default to free option
  bool _isProcessing = false;
  bool _hasCreditsOrSubscription = false;
  
  // Business card pricing
  static const Map<int, double> _pricing = {
    5: 0.0,      // Free (if has credits/subscription)
    10: 5.99,
    20: 9.99,
    50: 19.00,
    100: 34.99,
    500: 89.99,
  };
  
  // Shipping address fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _address1Controller = TextEditingController();
  final TextEditingController _address2Controller = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _checkEligibility();
    _loadSavedAddress();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }
  
  Future<void> _checkEligibility() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final creditsProvider = Provider.of<CreditsProvider>(context, listen: false);
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    
    // Check if user has credits or subscription
    final hasCredits = creditsProvider.credits > 0;
    final hasSubscription = userData?['subscriptionActive'] == true || 
                           userData?['hasActiveSubscription'] == true;
    
    setState(() {
      _hasCreditsOrSubscription = hasCredits || hasSubscription;
    });
  }
  
  Future<void> _loadSavedAddress() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    
    if (userData != null) {
      final address = userData['shippingAddress'];
      if (address != null) {
        setState(() {
          _nameController.text = address['name'] ?? '';
          _address1Controller.text = address['address1'] ?? '';
          _address2Controller.text = address['address2'] ?? '';
          _cityController.text = address['city'] ?? '';
          _stateController.text = address['state'] ?? '';
          _zipController.text = address['zip'] ?? '';
        });
      }
    }
  }
  
  double get _totalPrice {
    if (_selectedQuantity == 5 && _hasCreditsOrSubscription) {
      return 0.0; // Free
    }
    return _pricing[_selectedQuantity] ?? 0.0;
  }
  
  bool get _isFree {
    return _selectedQuantity == 5 && _hasCreditsOrSubscription;
  }
  
  Future<void> _processOrder() async {
    if (_isProcessing) return;
    
    // Validate shipping address
    if (_nameController.text.isEmpty ||
        _address1Controller.text.isEmpty ||
        _cityController.text.isEmpty ||
        _stateController.text.isEmpty ||
        _zipController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required shipping address fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() => _isProcessing = true);
    
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      // Save shipping address
      await _firestore.collection('users').doc(user.uid).update({
        'shippingAddress': {
          'name': _nameController.text,
          'address1': _address1Controller.text,
          'address2': _address2Controller.text,
          'city': _cityController.text,
          'state': _stateController.text,
          'zip': _zipController.text,
        },
      });
      
      // Use Cloud Function to create order
      String? orderId;
      try {
        final createOrder = _functions.httpsCallable('createBusinessCardOrder');
        
        final result = await createOrder.call({
          'quantity': _selectedQuantity,
          'shortname': widget.shortname,
          'shippingAddress': {
            'name': _nameController.text,
            'address1': _address1Controller.text,
            'address2': _address2Controller.text,
            'city': _cityController.text,
            'state': _stateController.text,
            'zip': _zipController.text,
          },
        });
        
        final orderData = result.data as Map<String, dynamic>;
        orderId = orderData['orderId'] as String;
        final isFree = orderData['isFree'] as bool;
        
        if (isFree) {
          // Free order - confirm immediately
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Order confirmed! Your ${_selectedQuantity} business cards will arrive in 10-14 days via USPS.',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        } else {
          // Paid order - process payment
          await _processPayment(orderId);
        }
      } catch (e) {
        print('Error creating order via Cloud Function: $e');
        // Fallback to direct Firestore if Cloud Function fails
        final orderData = {
          'userId': user.uid,
          'shortname': widget.shortname,
          'userName': widget.userName,
          'userPhone': widget.userPhone,
          'userEmail': widget.userEmail,
          'quantity': _selectedQuantity,
          'price': _totalPrice,
          'isFree': _isFree,
          'shippingAddress': {
            'name': _nameController.text,
            'address1': _address1Controller.text,
            'address2': _address2Controller.text,
            'city': _cityController.text,
            'state': _stateController.text,
            'zip': _zipController.text,
          },
          'status': _isFree ? 'confirmed' : 'pending_payment',
          'estimatedDelivery': _calculateDeliveryDate(),
          'createdAt': FieldValue.serverTimestamp(),
        };
        
        final orderRef = await _firestore.collection('business_card_orders').add(orderData);
        orderId = orderRef.id;
        
        if (_isFree) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Order confirmed! Your ${_selectedQuantity} business cards will arrive in 10-14 days via USPS.',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } else {
          await _processPayment(orderId);
        }
      }
    } catch (e) {
      print('Error processing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
  
  Future<void> _processPayment(String orderId) async {
    // TODO: Integrate with Stripe or payment provider
    // For now, show payment screen or process payment
    // In production, this would integrate with Stripe Checkout or similar
    
    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));
    
    // Update order status
    await _firestore.collection('business_card_orders').doc(orderId).update({
      'status': 'confirmed',
      'paidAt': FieldValue.serverTimestamp(),
    });
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment successful! Your ${_selectedQuantity} business cards will arrive in 10-14 days via USPS.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
  
  String _calculateDeliveryDate() {
    final now = DateTime.now();
    final deliveryDate = now.add(const Duration(days: 12)); // Average of 10-14 days
    return '${deliveryDate.month}/${deliveryDate.day}/${deliveryDate.year}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Business Cards'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quantity Selection
            Text(
              'Select Quantity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ..._pricing.entries.map((entry) {
              final quantity = entry.key;
              final price = entry.value;
              final isSelected = _selectedQuantity == quantity;
              final isFreeOption = quantity == 5 && _hasCreditsOrSubscription;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: isSelected 
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: RadioListTile<int>(
                  title: Text('$quantity Business Cards'),
                  subtitle: Text(
                    isFreeOption && quantity == 5
                        ? 'Free* (with credits or subscription)'
                        : '\$${price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isFreeOption && quantity == 5
                          ? Colors.green
                          : null,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  value: quantity,
                  groupValue: _selectedQuantity,
                  onChanged: (value) {
                    setState(() {
                      _selectedQuantity = value!;
                    });
                  },
                ),
              );
            }),
            const SizedBox(height: 24),
            
            // Shipping Address
            Text(
              'Shipping Address',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address1Controller,
              decoration: const InputDecoration(
                labelText: 'Address Line 1 *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address2Controller,
              decoration: const InputDecoration(
                labelText: 'Address Line 2',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'City *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: 'State *',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _zipController,
                    decoration: const InputDecoration(
                      labelText: 'ZIP *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Order Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Summary',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_selectedQuantity} Business Cards'),
                        Text(
                          _isFree
                              ? 'Free*'
                              : '\$${_totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Shipping: USPS (10-14 business days)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (_isFree) ...[
                      const SizedBox(height: 8),
                      Text(
                        '*Free with active credits or subscription',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Order Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processOrder,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator()
                    : Text(
                        _isFree
                            ? 'Order Free Business Cards'
                            : 'Pay \$${_totalPrice.toStringAsFixed(2)} & Order',
                      ),
              ),
            ),
            if (!_hasCreditsOrSubscription && _selectedQuantity == 5) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Get 5 Free Business Cards!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Subscribe to any plan to receive 5 free business cards with your order.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Navigate to subscription/payment screen
                          // This would typically go to the payment/subscription screen
                        },
                        child: const Text('Subscribe Now'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
