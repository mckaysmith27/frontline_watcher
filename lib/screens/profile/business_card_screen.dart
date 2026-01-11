import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:clipboard/clipboard.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import 'business_card_order_screen.dart';

class BusinessCardScreen extends StatefulWidget {
  const BusinessCardScreen({super.key});

  @override
  State<BusinessCardScreen> createState() => _BusinessCardScreenState();
}

class _BusinessCardScreenState extends State<BusinessCardScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _shortnameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  String? _currentShortname;
  String? _validationMessage;
  bool _isAvailable = false;
  bool _isValidating = false;
  bool _showBusinessCard = false;
  String? _userName;
  String? _userPhone;
  String? _userEmail;
  String? _userPhotoUrl;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _shortnameController.addListener(_validateShortname);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shortnameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      setState(() {
        _currentShortname = data['shortname'];
        _userName = data['shortname'] ?? 
                   data['nickname'] ?? 
                   user.displayName ?? 
                   user.email?.split('@')[0] ?? 
                   'User';
        _userPhone = data['phoneNumber'];
        _userEmail = user.email;
        _userPhotoUrl = user.photoURL ?? data['photoUrl'];
      });
      
      // If user already has a shortname, show business card
      if (_currentShortname != null && _currentShortname!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _showBusinessCard = true;
            });
            _animationController.forward();
          }
        });
      }
    }
  }

  Future<void> _validateShortname() async {
    final shortname = _shortnameController.text.trim();
    
    if (shortname.isEmpty) {
      setState(() {
        _validationMessage = null;
        _isAvailable = false;
      });
      return;
    }

    // Check format: at least 3 characters, 1 number
    final hasMinLength = shortname.length >= 3;
    final hasNumber = RegExp(r'\d').hasMatch(shortname);

    if (!hasMinLength || !hasNumber) {
      setState(() {
        _validationMessage = 'Required: @ least 3 char, 1 num';
        _isAvailable = false;
        _isValidating = false;
      });
      return;
    }

    // Check availability
    setState(() {
      _isValidating = true;
    });

    try {
      final callable = _functions.httpsCallable('checkShortnameAvailability');
      final result = await callable.call({'shortname': shortname});
      final isAvailable = result.data['available'] as bool;

      setState(() {
        _isValidating = false;
        if (isAvailable) {
          _validationMessage = 'available!';
          _isAvailable = true;
        } else {
          _validationMessage = 'not available';
          _isAvailable = false;
        }
      });
    } catch (e) {
      setState(() {
        _isValidating = false;
        _validationMessage = 'Error checking availability';
        _isAvailable = false;
      });
    }
  }

  Future<void> _submitShortname() async {
    if (!_isAvailable) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final shortname = _shortnameController.text.trim();

    try {
      // Save shortname to Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'shortname': shortname,
      });

      // Animate to business card
      setState(() {
        _currentShortname = shortname;
        _showBusinessCard = true;
      });

      _animationController.forward();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving shortname: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getBusinessCardUrl() {
    return 'https://sub67.com/${_currentShortname ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    if (_showBusinessCard && _currentShortname != null) {
      return _buildBusinessCard();
    }
    return _buildShortnameInput();
  }

  Widget _buildShortnameInput() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Card'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'sub67.com/',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _shortnameController,
                decoration: InputDecoration(
                  labelText: 'Shortname',
                  hintText: 'Enter your shortname',
                  border: OutlineInputBorder(),
                  suffixIcon: _isValidating
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (_validationMessage != null)
                Text(
                  _validationMessage!,
                  style: TextStyle(
                    color: _isAvailable ? Colors.green : Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isAvailable ? _submitShortname : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Submit Shortname'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessCard() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Card'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              setState(() {
                _showBusinessCard = false;
                _shortnameController.text = _currentShortname ?? '';
              });
              _animationController.reset();
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Business Card Container
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Section: Name, Phone, Email with QR Code on right
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left side: Name, Phone, Email
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name - big, bold, professional, aligned right in row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _userName ?? 'User',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                          letterSpacing: 0.5,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Phone - next row
                                if (_userPhone != null)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        _userPhone!,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 8),
                                // Email - next row
                                if (_userEmail != null)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _userEmail!,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.black54,
                                          ),
                                          textAlign: TextAlign.right,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Right side: QR Code
                          QrImageView(
                            data: _getBusinessCardUrl(),
                            version: QrVersions.auto,
                            size: 140,
                            backgroundColor: Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Bottom Row: URL in its own row
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _getBusinessCardUrl(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () async {
                                await FlutterClipboard.copy(_getBusinessCardUrl());
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('URL copied to clipboard'),
                                    ),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_browser, size: 20),
                              onPressed: () async {
                                final url = Uri.parse(_getBusinessCardUrl());
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Order Business Cards Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BusinessCardOrderScreen(
                            shortname: _currentShortname!,
                            userName: _userName ?? 'User',
                            userPhone: _userPhone,
                            userEmail: _userEmail,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_printshop),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Order Business Cards'),
                        SizedBox(width: 4),
                        Text(
                          'free*',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '*Free with active credits or subscription',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
