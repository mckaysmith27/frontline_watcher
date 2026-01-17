import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../../services/admin_service.dart';

class BusinessCardOrdersQueueScreen extends StatefulWidget {
  const BusinessCardOrdersQueueScreen({super.key});

  @override
  State<BusinessCardOrdersQueueScreen> createState() => _BusinessCardOrdersQueueScreenState();
}

class _BusinessCardOrdersQueueScreenState extends State<BusinessCardOrdersQueueScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _adminService.isAdmin();
    setState(() {
      _isAdmin = isAdmin;
    });
  }

  Future<void> _markOrderComplete(String orderId) async {
    try {
      await _firestore.collection('business_card_orders').doc(orderId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as complete'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printOrder(String orderId) async {
    // TODO: Implement print functionality
    // This would typically open a print dialog or send to printer
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Print functionality coming soon'),
        ),
      );
    }
  }

  Future<void> _printAllUncompleted() async {
    // TODO: Implement batch print functionality
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batch print functionality coming soon'),
        ),
      );
    }
  }

  Future<void> _refundOrder(String orderId, String userId, String userEmail, double totalPrice) async {
    // Show dialog for refund note
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Refund Order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Total: \$${totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Please provide a reason for the refund:'),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    hintText: 'Enter refund reason...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  autofocus: true,
                  onChanged: (value) {
                    setDialogState(() {}); // Update dialog state to enable/disable button
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: noteController.text.trim().isNotEmpty
                  ? () => Navigator.pop(context, true)
                  : null,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Refund'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || noteController.text.trim().isEmpty) {
      noteController.dispose();
      return;
    }

    final refundNote = noteController.text.trim();
    noteController.dispose();

    try {
      // Call Cloud Function to process refund
      final refundOrder = _functions.httpsCallable('refundBusinessCardOrder');
      
      await refundOrder.call({
        'orderId': orderId,
        'userId': userId,
        'userEmail': userEmail,
        'totalPrice': totalPrice,
        'refundNote': refundNote,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order refunded successfully. User has been notified.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Error refunding order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing refund: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Business Card Orders')),
        body: const Center(
          child: Text('Access denied. Admin privileges required.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Card Orders Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print All Uncompleted',
            onPressed: _printAllUncompleted,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('business_card_orders')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No orders found'));
          }

          final orders = snapshot.data!.docs;
          
          // Separate orders by status
          final uncompletedOrders = orders.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] as String? ?? 'pending';
            return status != 'completed' && status != 'refunded';
          }).toList();
          
          final completedOrders = orders.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] as String? ?? 'pending';
            return status == 'completed';
          }).toList();
          
          final refundedOrders = orders.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] == 'refunded';
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Uncompleted orders first
              ...uncompletedOrders.map((doc) => _buildOrderCard(doc, false)),
              
              // Divider
              if (completedOrders.isNotEmpty && uncompletedOrders.isNotEmpty)
                const Divider(thickness: 2),
              
              // Completed orders
              ...completedOrders.map((doc) => _buildOrderCard(doc, true)),
              
              // Divider
              if (refundedOrders.isNotEmpty && (completedOrders.isNotEmpty || uncompletedOrders.isNotEmpty))
                const Divider(thickness: 2),
              
              // Refunded orders at bottom
              ...refundedOrders.map((doc) => _buildOrderCard(doc, false, isRefunded: true)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(DocumentSnapshot doc, bool isCompleted, {bool isRefunded = false}) {
    final data = doc.data() as Map<String, dynamic>;
    final orderId = data['orderId'] as String? ?? doc.id;
    final quantity = data['orderQuantity'] as int? ?? 0;
    final timestamp = data['orderTimestamp'] as Timestamp?;
    final createdAt = data['createdAt'] as Timestamp?;
    final firstName = data['firstName'] as String? ?? '';
    final lastName = data['lastName'] as String? ?? '';
    final shortname = data['shortname'] as String? ?? '';
    final totalPrice = data['totalPrice'] as double? ?? 0.0;
    final shippingAddress = data['shippingAddress'] as Map<String, dynamic>?;
    final cardImageUrl = data['cardImageUrl'] as String?;
    final userId = data['userId'] as String? ?? '';
    final userEmail = data['userEmail'] as String? ?? '';

    final date = timestamp?.toDate() ?? createdAt?.toDate() ?? DateTime.now();
    final dateStr = DateFormat('MMM dd, yyyy HH:mm').format(date);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isCompleted 
          ? Colors.grey[200] 
          : isRefunded 
              ? Colors.red[50] 
              : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order ID: $orderId',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$firstName $lastName',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        'sub67.com/$shortname',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'COMPLETED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (isRefunded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'REFUNDED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Order details
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quantity: $quantity Cards'),
                      Text('Total: \$${totalPrice.toStringAsFixed(2)}'),
                      Text('Date: $dateStr'),
                      if (shippingAddress != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Ship to: ${shippingAddress['name'] ?? ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
                if (cardImageUrl != null)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Image.network(
                      cardImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Icon(Icons.image_not_supported));
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Refund note (if refunded)
            if (isRefunded) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Refund Note:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['refundNote'] as String? ?? 'No note provided',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (data['refundedAt'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Refunded: ${DateFormat('MMM dd, yyyy HH:mm').format((data['refundedAt'] as Timestamp).toDate())}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            
            // Action buttons
            if (!isCompleted && !isRefunded)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle),
                    color: Colors.green,
                    tooltip: 'Mark Order Complete',
                    onPressed: () => _markOrderComplete(doc.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.print),
                    color: Colors.blue,
                    tooltip: 'Print Order',
                    onPressed: () => _printOrder(doc.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.money_off),
                    color: Colors.red,
                    tooltip: 'Refund Order',
                    onPressed: () => _refundOrder(orderId, userId, userEmail, totalPrice),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
