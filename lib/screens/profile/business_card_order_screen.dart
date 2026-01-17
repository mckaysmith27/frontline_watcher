import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math';
import '../../providers/subscription_provider.dart';
import '../../config/app_config.dart';

class BusinessCardOrderScreen extends StatefulWidget {
  final String shortname;
  final String firstName;
  final String lastName;
  final String? userPhone;
  final String? userEmail;

  const BusinessCardOrderScreen({
    super.key,
    required this.shortname,
    required this.firstName,
    required this.lastName,
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
  
  int _selectedQuantity = 20; // Default to recommended
  String _selectedShipping = 'standard'; // 'standard' or 'express'
  bool _isProcessing = false;
  bool _hasCreditsOrSubscription = false;
  
  // Promo code
  final TextEditingController _promoController = TextEditingController();
  String? _appliedPromo;
  double _promoDiscount = 0.0;
  
  // Payment details
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _cardNameController = TextEditingController();
  
  // Business card pricing (base prices)
  static const Map<int, double> _basePricing = {
    5: 0.0,
    10: 5.99,
    20: 9.99,
    50: 19.00,
    100: 34.99,
    500: 89.99,
  };
  
  // Shipping options
  static const Map<String, Map<String, dynamic>> _shippingOptions = {
    'standard': {
      'name': 'USPS 10-14 business days',
      'price': 0.0,
      'days': '10-14',
    },
    'express': {
      'name': 'USPS 4-7 business days',
      'price': 3.99,
      'days': '4-7',
    },
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
    _promoController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardNameController.dispose();
    super.dispose();
  }
  
  Future<void> _checkEligibility() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    
    // Check if user has an active timestamp-based subscription.
    final hasActiveSubscription = subscriptionProvider.hasActiveSubscription;
    final hasSubscriptionFlag = userData?['subscriptionActive'] == true;
    
    setState(() {
      _hasCreditsOrSubscription = hasActiveSubscription || hasSubscriptionFlag;
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
  
  // Calculate discount based on credits/subscription
  double _getDiscount(int quantity) {
    if (!_hasCreditsOrSubscription) return 0.0;
    
    if (quantity <= 20) {
      return 0.10; // 10% off
    } else if (quantity >= 50) {
      return 0.20; // 20% off
    }
    return 0.0;
  }
  
  // Calculate promo code discount (can be combined with credits/subscription discount)
  double _getPromoDiscount() {
    return _promoDiscount;
  }
  
  Future<void> _applyPromo() async {
    final promo = _promoController.text.trim();
    if (promo.isEmpty) return;

    // Check if promo code is valid (using same codes as credit purchases)
    final validPromos = AppConfig.creditPromoCodes;
    final isValid = validPromos.any(
      (p) => p.toLowerCase() == promo.toLowerCase(),
    );

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid promo code'),
          backgroundColor: Colors.red,
        ),
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

    // Apply discount (10% off for business card orders)
    setState(() {
      _appliedPromo = promo;
      _promoDiscount = 0.10; // 10% discount from promo code
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Promo code applied!'),
        backgroundColor: Colors.green,
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
  
  double _getBasePrice(int quantity) {
    return _basePricing[quantity] ?? 0.0;
  }
  
  double _getDiscountedPrice(int quantity) {
    final basePrice = _getBasePrice(quantity);
    final creditsDiscount = _getDiscount(quantity);
    final promoDiscount = _getPromoDiscount();
    
    // Apply both discounts (multiplicative)
    final totalDiscount = 1 - ((1 - creditsDiscount) * (1 - promoDiscount));
    return basePrice * (1 - totalDiscount);
  }
  
  double get _totalPrice {
    final basePrice = _getBasePrice(_selectedQuantity);
    final creditsDiscount = _getDiscount(_selectedQuantity);
    final promoDiscount = _getPromoDiscount();
    
    // Apply both discounts (multiplicative)
    final totalDiscount = 1 - ((1 - creditsDiscount) * (1 - promoDiscount));
    final discountedPrice = basePrice * (1 - totalDiscount);
    
    final shippingPrice = _shippingOptions[_selectedShipping]!['price'] as double;
    return discountedPrice + shippingPrice;
  }
  
  double get _finalPriceAfterAllDiscounts {
    final basePrice = _getBasePrice(_selectedQuantity);
    final creditsDiscount = _getDiscount(_selectedQuantity);
    final promoDiscount = _getPromoDiscount();
    
    // Apply both discounts (multiplicative)
    final totalDiscount = 1 - ((1 - creditsDiscount) * (1 - promoDiscount));
    final discountedPrice = basePrice * (1 - totalDiscount);
    
    final shippingPrice = _shippingOptions[_selectedShipping]!['price'] as double;
    return discountedPrice + shippingPrice;
  }
  
  String _generateOrderId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
      7,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ));
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
      
      final orderId = _generateOrderId();
      
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
      
      // Create order document
      final orderData = {
        'orderId': orderId,
        'userId': user.uid,
        'shortname': widget.shortname,
        'firstName': widget.firstName,
        'lastName': widget.lastName,
        'userPhone': widget.userPhone,
        'userEmail': widget.userEmail,
        'orderQuantity': _selectedQuantity,
        'orderTimestamp': FieldValue.serverTimestamp(),
        'basePrice': _getBasePrice(_selectedQuantity),
        'discount': _getDiscount(_selectedQuantity),
        'promoCode': _appliedPromo,
        'promoDiscount': _promoDiscount,
        'discountedPrice': _getDiscountedPrice(_selectedQuantity),
        'shippingOption': _selectedShipping,
        'shippingPrice': _shippingOptions[_selectedShipping]!['price'] as double,
        'totalPrice': _finalPriceAfterAllDiscounts,
        'shippingAddress': {
          'name': _nameController.text,
          'address1': _address1Controller.text,
          'address2': _address2Controller.text,
          'city': _cityController.text,
          'state': _stateController.text,
          'zip': _zipController.text,
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      // Process payment first
      if (_totalPrice > 0) {
        // Validate payment details
        if (_cardNumberController.text.isEmpty ||
            _expiryController.text.isEmpty ||
            _cvvController.text.isEmpty ||
            _cardNameController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please fill in all payment details'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isProcessing = false);
          return;
        }
        
        // Simulate payment processing (replace with actual Stripe/payment integration)
        await Future.delayed(const Duration(seconds: 2));
        
        // TODO: Integrate with actual payment provider (Stripe, etc.)
        // For now, we'll simulate successful payment
      }
      
      // If promo code was used, mark it as used
      if (_appliedPromo != null) {
        try {
          await _markPromoCodeAsUsed(_appliedPromo!);
        } catch (e) {
          print('Error marking promo code as used: $e');
          // Continue anyway - don't block the order
        }
      }
      
      // Use Cloud Function to create order (will handle image generation)
      try {
        final createOrder = _functions.httpsCallable('createBusinessCardOrder');
        
        await createOrder.call({
          'orderId': orderId,
          'quantity': _selectedQuantity,
          'shortname': widget.shortname,
          'firstName': widget.firstName,
          'lastName': widget.lastName,
          'userPhone': widget.userPhone,
          'userEmail': widget.userEmail,
          'shippingAddress': orderData['shippingAddress'],
          'shippingOption': _selectedShipping,
          'basePrice': orderData['basePrice'],
          'discount': orderData['discount'],
          'promoCode': _appliedPromo,
          'promoDiscount': _promoDiscount,
          'totalPrice': _finalPriceAfterAllDiscounts,
        });
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order confirmed! Order ID: $orderId. Your ${_selectedQuantity} cards will arrive in ${_shippingOptions[_selectedShipping]!['days']} business days via USPS.',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        print('Error creating order via Cloud Function: $e');
        // Fallback: create order directly
        await _firestore.collection('business_card_orders').add(orderData);
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order confirmed! Order ID: $orderId. Your ${_selectedQuantity} cards will arrive in ${_shippingOptions[_selectedShipping]!['days']} business days via USPS.',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
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
  
  Widget _buildBusinessCardPreview() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      height: 230,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.firstName} ${widget.lastName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.userPhone != null && widget.userPhone!.isNotEmpty)
                      Text(
                        widget.userPhone!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    if (widget.userPhone != null && widget.userPhone!.isNotEmpty)
                      const SizedBox(height: 8),
                    if (widget.userEmail != null && widget.userEmail!.isNotEmpty)
                      Text(
                        widget.userEmail!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              QrImageView(
                data: 'https://sub67.com/${widget.shortname}',
                version: QrVersions.auto,
                size: 100,
                backgroundColor: Colors.white,
              ),
            ],
          ),
          const Spacer(),
          Text(
            'sub67.com/${widget.shortname}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Cards'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Business Card Preview (non-editable)
            _buildBusinessCardPreview(),
            const SizedBox(height: 24),
            
            // Quantity Selection
            Text(
              'Select Quantity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ..._basePricing.entries.map((entry) {
              final quantity = entry.key;
              final basePrice = entry.value;
              final isSelected = _selectedQuantity == quantity;
              final discount = _getDiscount(quantity);
              final discountedPrice = basePrice * (1 - discount);
              final showDiscount = discount > 0;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: isSelected 
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: RadioListTile<int>(
                  title: Row(
                    children: [
                      Text('$quantity Cards'),
                      if (quantity == 20) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(recommended)',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: showDiscount
                      ? Row(
                          children: [
                            Text(
                              '\$${basePrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '\$${discountedPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          '\$${basePrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
            
            // Shipping Options
            Text(
              'Shipping Options',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ..._shippingOptions.entries.map((entry) {
              final key = entry.key;
              final option = entry.value;
              final isSelected = _selectedShipping == key;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: isSelected 
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: RadioListTile<String>(
                  title: Text(option['name'] as String),
                  subtitle: Text(
                    option['price'] == 0.0
                        ? 'Free'
                        : '\$${(option['price'] as double).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: option['price'] == 0.0 ? Colors.green : null,
                    ),
                  ),
                  value: key,
                  groupValue: _selectedShipping,
                  onChanged: (value) {
                    setState(() {
                      _selectedShipping = value!;
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
            
            // Promo Code Section
            Text(
              'Promo Code',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoController,
                    decoration: InputDecoration(
                      hintText: 'Enter promo code',
                      border: const OutlineInputBorder(),
                      suffixIcon: _appliedPromo != null
                          ? IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              onPressed: () {
                                setState(() {
                                  _appliedPromo = null;
                                  _promoDiscount = 0.0;
                                  _promoController.clear();
                                });
                              },
                            )
                          : null,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    enabled: _appliedPromo == null,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _appliedPromo == null ? _applyPromo : null,
                  child: const Text('Apply'),
                ),
              ],
            ),
            if (_appliedPromo != null) ...[
              const SizedBox(height: 8),
              Text(
                'Promo code "$_appliedPromo" applied!',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 24),
            
            // Payment Details Section
            if (_finalPriceAfterAllDiscounts > 0) ...[
              Text(
                'Payment Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cardNameController,
                decoration: const InputDecoration(
                  labelText: 'Cardholder Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cardNumberController,
                decoration: const InputDecoration(
                  labelText: 'Card Number *',
                  border: OutlineInputBorder(),
                  hintText: '1234 5678 9012 3456',
                ),
                keyboardType: TextInputType.number,
                maxLength: 19, // 16 digits + 3 spaces
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _expiryController,
                      decoration: const InputDecoration(
                        labelText: 'Expiry (MM/YY) *',
                        border: OutlineInputBorder(),
                        hintText: '12/25',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _cvvController,
                      decoration: const InputDecoration(
                        labelText: 'CVV *',
                        border: OutlineInputBorder(),
                        hintText: '123',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            
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
                        Text('${_selectedQuantity} Cards'),
                        (_hasCreditsOrSubscription && _getDiscount(_selectedQuantity) > 0) || 
                        (_appliedPromo != null && _promoDiscount > 0)
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${_getBasePrice(_selectedQuantity).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    '\$${_getDiscountedPrice(_selectedQuantity).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                '\$${_getBasePrice(_selectedQuantity).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ],
                    ),
                    if (_hasCreditsOrSubscription && _getDiscount(_selectedQuantity) > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Discount (${(_getDiscount(_selectedQuantity) * 100).toStringAsFixed(0)}%)'),
                          Text(
                            '-\$${(_getBasePrice(_selectedQuantity) * _getDiscount(_selectedQuantity)).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_appliedPromo != null && _promoDiscount > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Promo Code: $_appliedPromo'),
                          Text(
                            '-\$${(_getBasePrice(_selectedQuantity) * _promoDiscount).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_shippingOptions[_selectedShipping]!['name'] as String),
                        Text(
                          _shippingOptions[_selectedShipping]!['price'] == 0.0
                              ? 'Free'
                              : '\$${(_shippingOptions[_selectedShipping]!['price'] as double).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _shippingOptions[_selectedShipping]!['price'] == 0.0
                                ? Colors.green
                                : null,
                          ),
                        ),
                      ],
                    ),
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
                          '\$${_finalPriceAfterAllDiscounts.toStringAsFixed(2)}',
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
                    : Text(_finalPriceAfterAllDiscounts > 0
                        ? 'Pay \$${_finalPriceAfterAllDiscounts.toStringAsFixed(2)} & Order'
                        : 'Complete Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
