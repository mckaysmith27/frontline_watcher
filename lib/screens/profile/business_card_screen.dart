import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_role_service.dart';
import 'business_card_order_screen.dart';
import '../../widgets/terms_agreement.dart';
import 'profile_screen.dart';

class BusinessCardScreen extends StatefulWidget {
  const BusinessCardScreen({super.key});

  @override
  State<BusinessCardScreen> createState() => _BusinessCardScreenState();
}

class _BusinessCardScreenState extends State<BusinessCardScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _shortnameController = TextEditingController();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final ImagePicker _imagePicker = ImagePicker();

  String? _currentShortname;
  String? _validationMessage;
  bool _isValidating = false;
  bool _isAvailable = false;
  bool _termsAgreed = false;
  bool _isFormComplete = false;
  String? _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _shortnameController.addListener(_validateShortname);
    _firstNameController.addListener(_checkFormComplete);
    _lastNameController.addListener(_checkFormComplete);
    _phoneController.addListener(_checkFormComplete);
    _emailController.addListener(_checkFormComplete);
    _shortnameController.addListener(_checkFormComplete);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _shortnameController.dispose();
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
        _shortnameController.text = _currentShortname ?? '';
        
        // Load existing user data
        final fullName = user.displayName ?? '';
        if (fullName.isNotEmpty) {
          final nameParts = fullName.split(' ');
          _firstNameController.text = nameParts.isNotEmpty ? nameParts[0] : '';
          _lastNameController.text = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        }
        _phoneController.text = data['phoneNumber'] ?? '';
        _emailController.text = user.email ?? '';
        _profilePhotoUrl = user.photoURL ?? data['photoUrl'];
      });
      
      // Auto-save existing data
      _saveField('firstName', _firstNameController.text);
      _saveField('lastName', _lastNameController.text);
      _saveField('phoneNumber', _phoneController.text);
      _saveField('email', _emailController.text);
      
      _checkFormComplete();
    }
  }

  Future<void> _pickProfilePhoto() async {
    // Check if user has access to business card feature
    final roleService = UserRoleService();
    final hasBusinessCardAccess = await roleService.hasFeatureAccess('business_card');
    
    if (!hasBusinessCardAccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This feature is not available for your role.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image == null) return;
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading profile photo...')),
        );
      }
      
      // Upload to Firebase Storage
      final user = _auth.currentUser;
      if (user == null) return;
      
      final file = File(image.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');
      
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();
      
      // Update Firebase Auth profile
      await user.updatePhotoURL(downloadUrl);
      await user.reload();
      
      // Update Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': downloadUrl,
      });
      
      // Reload user to get updated photoURL
      final updatedUser = _auth.currentUser;
      await updatedUser?.reload();
      final refreshedUser = _auth.currentUser;
      
      // Update local state
      setState(() {
        _profilePhotoUrl = refreshedUser?.photoURL ?? downloadUrl;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error uploading profile photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _checkFormComplete() {
    final isComplete = _firstNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty &&
        _phoneController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _shortnameController.text.isNotEmpty &&
        _isAvailable &&
        _termsAgreed;
    
    if (_isFormComplete != isComplete) {
      setState(() {
        _isFormComplete = isComplete;
      });
    }
  }

  Future<void> _saveField(String field, String value) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        field: value,
      });
    } catch (e) {
      print('Error saving $field: $e');
    }
  }

  Future<void> _validateShortname() async {
    final shortname = _shortnameController.text.trim().toLowerCase();
    
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

    // Auto-save shortname
    if (shortname != _currentShortname) {
      await _saveField('shortname', shortname);
      setState(() {
        _currentShortname = shortname;
      });
    }

    // Check availability
    setState(() {
      _isValidating = true;
    });

    try {
      final callable = _functions.httpsCallable('checkShortnameAvailability');
      final result = await callable.call({'shortname': shortname});
      final data = result.data as Map<String, dynamic>;
      final isAvailable = data['available'] as bool;

      setState(() {
        _isValidating = false;
        if (isAvailable) {
          _validationMessage = 'available!';
          _isAvailable = true;
        } else {
          _validationMessage = data['reason'] as String? ?? 'not available';
          _isAvailable = false;
        }
      });
      _checkFormComplete();
    } catch (e) {
      print('Error checking shortname availability: $e');
      setState(() {
        _isValidating = false;
        _validationMessage = 'Error checking availability: ${e.toString()}';
        _isAvailable = false;
      });
    }
  }

  String _getBusinessCardUrl() {
    final shortname = _shortnameController.text.trim().toLowerCase();
    return shortname.isNotEmpty ? 'https://sub67.com/$shortname' : '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Card'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Business Card Form
            _buildBusinessCardForm(),
            const SizedBox(height: 24),
            
            // Terms and Conditions
            BusinessCardTermsAgreement(
              onAgreed: (agreed) {
                setState(() {
                  _termsAgreed = agreed;
                });
                _checkFormComplete();
              },
            ),
            const SizedBox(height: 24),
            
            // Checkout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isFormComplete ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusinessCardOrderScreen(
                        shortname: _shortnameController.text.trim().toLowerCase(),
                        firstName: _firstNameController.text,
                        lastName: _lastNameController.text,
                        userPhone: _phoneController.text,
                        userEmail: _emailController.text,
                      ),
                    ),
                  );
                } : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Checkout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessCardForm() {
    // Business card aspect ratio: approximately 3.5" x 2" = 1.75:1
    // For UI, we'll use a reasonable size with sharp corners
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      height: 230, // Approximate business card height
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero, // Sharp corners
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
          // First row: First Name and Last Name
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    hintText: 'First Name',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  onChanged: (value) async {
                    await _saveField('firstName', value);
                    _checkFormComplete();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    hintText: 'Last Name',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  onChanged: (value) async {
                    await _saveField('lastName', value);
                    _checkFormComplete();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Second row: Phone and Email
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Phone and Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        hintText: 'Phone',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      keyboardType: TextInputType.phone,
                      onChanged: (value) {
                        _saveField('phoneNumber', value);
                        _checkFormComplete();
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (value) {
                        _saveField('email', value);
                        _checkFormComplete();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right: QR Code placeholder
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey[400]!, width: 1),
                ),
                child: _isFormComplete
                    ? QrImageView(
                        data: _getBusinessCardUrl(),
                        version: QrVersions.auto,
                        size: 100,
                        backgroundColor: Colors.white,
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'QR Code needs the full form filled out with each of the items below the form checked and clicked respectively in order for it to work and a working QR code to be generated for print.',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
              ),
            ],
          ),
          const Spacer(),
          // Profile Photo (before shortname/link field)
          Row(
            children: [
              GestureDetector(
                onTap: _pickProfilePhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: _profilePhotoUrl != null
                          ? NetworkImage(_profilePhotoUrl!)
                          : null,
                      child: _profilePhotoUrl == null
                          ? Text(
                              _auth.currentUser?.email?[0].toUpperCase() ?? 'U',
                              style: const TextStyle(fontSize: 24),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Photo',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to upload or change',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bottom: URL field
          TextField(
            controller: _shortnameController,
            decoration: InputDecoration(
              prefixText: 'sub67.com/',
              prefixStyle: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              hintText: 'shortname',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              suffixIcon: _isValidating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: Padding(
                        padding: EdgeInsets.all(4.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            textCapitalization: TextCapitalization.none,
            onChanged: (value) {
              _validateShortname();
              _checkFormComplete();
            },
          ),
          if (_validationMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _validationMessage!,
                style: TextStyle(
                  color: _isAvailable ? Colors.green : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Custom Terms Agreement widget for business cards
class BusinessCardTermsAgreement extends StatefulWidget {
  final Function(bool) onAgreed;

  const BusinessCardTermsAgreement({super.key, required this.onAgreed});

  @override
  State<BusinessCardTermsAgreement> createState() => _BusinessCardTermsAgreementState();
}

class _BusinessCardTermsAgreementState extends State<BusinessCardTermsAgreement> {
  bool _agreed = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _agreed,
              onChanged: (value) {
                setState(() {
                  _agreed = value ?? false;
                });
                widget.onAgreed(_agreed);
              },
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _expanded = !_expanded;
                  });
                },
                child: Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: const [
                            TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms and Conditions',
                              style: TextStyle(decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(left: 48, top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const SingleChildScrollView(
              child: Text(
                _businessCardTermsText,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}

const String _businessCardTermsText = '''
BUSINESS CARD TERMS AND CONDITIONS

By creating and ordering business cards through Sub67, you agree to the following terms:

1. DATA USE AND SHARING
You grant Sub67 and its affiliates permission to use the information provided in this form (including but not limited to your name, phone number, email address, and shortname) for the following purposes:

- Transmission to individuals who access your professional page via the QR code or link
- Enabling visitors to manually or automatically fill out information needed to:
  * Add you as a preferred substitute teacher
  * Reserve you for specific dates
  * Contact you professionally or otherwise
- Use of your data for advertising and promotional purposes as permitted by iOS App Store, Google Play Store, and web platform policies
- Promotion of Sub67's own products and services

2. INFORMATION ACCURACY
You are responsible for ensuring all information on your business card is accurate and up-to-date. Sub67 is not responsible for errors in information you provide.

3. PROFESSIONAL USE
Your business card and associated information will be publicly accessible via the provided URL and QR code. You agree to use this service for professional purposes only.

4. DATA RETENTION
Sub67 may retain your business card information for as long as necessary to provide services and as permitted by applicable laws and platform policies.

5. MODIFICATIONS
Sub67 reserves the right to modify these terms at any time. Continued use of the business card service constitutes acceptance of modified terms.

By checking the box above, you acknowledge that you have read, understood, and agree to these terms and conditions.
''';
