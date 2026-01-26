import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/user_role_service.dart';
import '../../widgets/app_bar_quick_toggles.dart';
import '../../widgets/profile_app_bar.dart';
import 'business_card_order_screen.dart';
import 'profile_screen.dart';

class BusinessCardScreen extends StatefulWidget {
  const BusinessCardScreen({super.key});

  @override
  State<BusinessCardScreen> createState() => _BusinessCardScreenState();
}

enum TeacherPreviewAction { preferred, specificDay }

class _BusinessCardScreenState extends State<BusinessCardScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _shortnameController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final ImagePicker _imagePicker = ImagePicker();

  String? _currentShortname;
  String? _nickname;
  String? _validationMessage;
  bool _isValidating = false;
  bool _isAvailable = false;
  bool _isFormComplete = false;
  String? _profilePhotoUrl;

  // Teacher-flow preview state (mirrors TeacherLandingScreen "page 1")
  TeacherPreviewAction _teacherPreviewAction = TeacherPreviewAction.preferred;
  DateTime _teacherPreviewFocusedDay = DateTime.now();
  DateTime? _teacherPreviewSelectedDay;
  bool _teacherPreviewTermsAccepted = false;
  bool _teacherPreviewDownloadAppChecked = true;

  late final AnimationController _teacherTermsNudgeController;
  late final Animation<double> _teacherTermsShakeX;
  late final Animation<double> _teacherTermsCheckboxScale;

  static const String _defaultInstructions =
      "Scan the QR code to add me as a 'preferred' sub! Keep this card and re-scan, to quickly request me for a specific day.";
  static const String _defaultBio =
      'An experienced sub who can who can manage a classroom and accomplish the mission.';

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
    _instructionsController.addListener(_checkFormComplete);
    _bioController.addListener(_checkFormComplete);

    _teacherTermsNudgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _teacherTermsShakeX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4, end: 4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _teacherTermsNudgeController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );
    _teacherTermsCheckboxScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _teacherTermsNudgeController,
        curve: const Interval(0.65, 1.0, curve: Curves.elasticOut),
      ),
    );
  }

  Future<void> _nudgeTeacherTerms() async {
    if (!mounted) return;
    if (_teacherTermsNudgeController.isAnimating) return;
    _teacherTermsNudgeController.reset();
    await _teacherTermsNudgeController.forward();
  }

  bool get _teacherPreviewCanContinue {
    if (!_teacherPreviewTermsAccepted) return false;
    if (_teacherPreviewAction == TeacherPreviewAction.specificDay && _teacherPreviewSelectedDay == null) return false;
    return true;
  }

  Future<void> _showTeacherTermsPreview() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: SingleChildScrollView(
          child: Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: const [
                TextSpan(
                  text: 'Sub67 quickly connects teachers to a sub quickly, utilizing existing systems and infrastructure.\n\n',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text:
                      'To proceed, teachers may enter third‑party credentials (such as Frontline/ESS) to sign in and submit actions on their behalf. '
                      'Credentials are intended to be stored locally on the teacher’s device (not in the Sub67 database). '
                      'We may collect limited app usage data to improve user experience. '
                      'Automations may run scripts to fill specific fields on the third‑party site based on selections.\n',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _shortnameController.dispose();
    _instructionsController.dispose();
    _bioController.dispose();
    _teacherTermsNudgeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      final fsFirstName = (data['firstName'] is String) ? (data['firstName'] as String).trim() : '';
      final fsLastName = (data['lastName'] is String) ? (data['lastName'] as String).trim() : '';
      setState(() {
        _currentShortname = data['shortname'];
        _nickname = (data['nickname'] is String) ? (data['nickname'] as String) : null;
        _shortnameController.text = _currentShortname ?? '';
        _validationMessage = (_currentShortname ?? '').isNotEmpty ? 'available!' : null;
        _isAvailable = (_currentShortname ?? '').isNotEmpty;
        
        // Load existing user data (prefer Firestore fields; do NOT overwrite user-entered values).
        if (fsFirstName.isNotEmpty || fsLastName.isNotEmpty) {
          _firstNameController.text = fsFirstName;
          _lastNameController.text = fsLastName;
        } else {
          // Fallback: FirebaseAuth displayName (may be blank or abbreviated)
          final fullName = user.displayName ?? '';
          if (fullName.isNotEmpty) {
            final nameParts = fullName.split(' ');
            _firstNameController.text = nameParts.isNotEmpty ? nameParts[0] : '';
            _lastNameController.text = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
          }
        }
        _phoneController.text = _formatPhoneDashed(data['phoneNumber'] ?? '');
        _emailController.text = user.email ?? '';
        _profilePhotoUrl = user.photoURL ?? data['photoUrl'];
        _instructionsController.text = (data['cardInstructions'] as String?)?.trim().isNotEmpty == true
            ? (data['cardInstructions'] as String)
            : _defaultInstructions;
        _bioController.text = (data['bio'] as String?)?.trim().isNotEmpty == true
            ? (data['bio'] as String)
            : _defaultBio;
      });
      
      // Only backfill Firestore name fields if they were missing.
      if (fsFirstName.isEmpty && _firstNameController.text.trim().isNotEmpty) {
        _saveField('firstName', _firstNameController.text.trim());
      }
      if (fsLastName.isEmpty && _lastNameController.text.trim().isNotEmpty) {
        _saveField('lastName', _lastNameController.text.trim());
      }
      _saveField('phoneNumber', _phoneController.text);
      _saveField('email', _emailController.text);
      _saveField('cardInstructions', _instructionsController.text);
      _saveField('bio', _bioController.text);
      
      _checkFormComplete();
    }
  }

  String? _shortnameDistinctnessError(String shortname) {
    final nick = (_nickname ?? '').trim().toLowerCase();
    if (nick.isEmpty) return null;
    final sn = shortname.trim().toLowerCase();
    if (sn.isEmpty) return null;

    final digitsSn = RegExp(r'\d').allMatches(sn).map((m) => m.group(0)!).toSet();
    final digitsNick = RegExp(r'\d').allMatches(nick).map((m) => m.group(0)!).toSet();
    final overlapDigits = digitsSn.intersection(digitsNick).toList()..sort();
    if (overlapDigits.isNotEmpty) {
      final cannotUse = overlapDigits.join();
      return 'Cannot use the same numbers as your nickname (CANNOT USE $cannotUse)';
    }

    String lettersOnly(String x) => x.replaceAll(RegExp(r'[^a-z]'), '');
    final a = lettersOnly(sn);
    final b = lettersOnly(nick);
    if (a.length >= 3 && b.length >= 3) {
      final subs = <String>{};
      for (int i = 0; i <= a.length - 3; i++) {
        subs.add(a.substring(i, i + 3));
      }
      for (int i = 0; i <= b.length - 3; i++) {
        if (subs.contains(b.substring(i, i + 3))) {
          return 'Cannot share any run of 3 letters with your nickname';
        }
      }
    }

    return null;
  }

  String _formatPhoneDashed(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final capped = digits.length > 10 ? digits.substring(0, 10) : digits;
    if (capped.isEmpty) return '';
    if (capped.length <= 3) return capped;
    if (capped.length <= 6) return '${capped.substring(0, 3)}-${capped.substring(3)}';
    return '${capped.substring(0, 3)}-${capped.substring(3, 6)}-${capped.substring(6)}';
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
        _isAvailable;
    
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

    // If unchanged from current shortname, treat as valid/available instantly.
    if (_currentShortname != null && shortname == _currentShortname) {
      setState(() {
        _validationMessage = 'available!';
        _isAvailable = true;
        _isValidating = false;
      });
      _checkFormComplete();
      return;
    }

    // Must be completely different than nickname (numbers + 3-letter runs).
    final distinctErr = _shortnameDistinctnessError(shortname);
    if (distinctErr != null) {
      setState(() {
        _validationMessage = distinctErr;
        _isAvailable = false;
        _isValidating = false;
      });
      return;
    }

    // Check format: at least 6 characters, 1 number (to reduce collisions)
    final hasMinLength = shortname.length >= 6;
    final hasNumber = RegExp(r'\d').hasMatch(shortname);

    if (!hasMinLength || !hasNumber) {
      setState(() {
        _validationMessage = 'Required: at least 6 characters and 1 number';
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

  Future<void> _logEvent(String type, {Map<String, dynamic>? meta}) async {
    try {
      final callable = _functions.httpsCallable('logAnalyticsEvent');
      await callable.call({
        'type': type,
        if (_shortnameController.text.trim().isNotEmpty) 'shortname': _shortnameController.text.trim().toLowerCase(),
        if (meta != null) 'meta': meta,
      });
    } catch (_) {
      // Best-effort; never block UX.
    }
  }

  String _getBusinessCardUrl() {
    final shortname = _shortnameController.text.trim().toLowerCase();
    return shortname.isNotEmpty ? 'https://sub67.com/$shortname' : '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfileAppBar(
        actions: [
          const AppBarQuickToggles(),
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
            _buildShortnameStatusBelowCard(),
            const SizedBox(height: 12),
            Text(
              'NOTE: Text elements as well as the QR code will adjust to proper alignment. Final card before print viewable on the next page.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Teacher preview
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'What teacher sees after scanning your QR code:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            _buildTeacherPreviewPhone(),
            const SizedBox(height: 24),
            
            // Terms and Conditions
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
                child: const Text('Proceed to Checkout'),
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
      height: 240, // Closer to true business card proportions
      padding: const EdgeInsets.all(16.0),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name (same row; shorter labels so the card doesn't get taller)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(
                              hintText: 'First',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                              suffixIcon: Icon(Icons.edit, size: 16, color: Colors.black45),
                              suffixIconConstraints: BoxConstraints(minWidth: 18, minHeight: 18),
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            onChanged: (value) async {
                              await _saveField('firstName', value);
                              _checkFormComplete();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _lastNameController,
                            decoration: const InputDecoration(
                              hintText: 'Last',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                              suffixIcon: Icon(Icons.edit, size: 16, color: Colors.black45),
                              suffixIconConstraints: BoxConstraints(minWidth: 18, minHeight: 18),
                            ),
                            style: const TextStyle(
                              fontSize: 18,
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
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        hintText: 'Phone',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                        suffixIcon: Icon(Icons.edit, size: 16, color: Colors.black45),
                        suffixIconConstraints: BoxConstraints(minWidth: 18, minHeight: 18),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        DashedPhoneNumberTextInputFormatter(),
                      ],
                      onChanged: (value) {
                        _saveField('phoneNumber', value);
                        _checkFormComplete();
                      },
                    ),
                    const SizedBox(height: 6),
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
                        suffixIcon: const Icon(Icons.edit, size: 16, color: Colors.black45),
                        suffixIconConstraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      textCapitalization: TextCapitalization.none,
                      onChanged: (_) {
                        _validateShortname();
                        _checkFormComplete();
                      },
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                        suffixIcon: Icon(Icons.edit, size: 16, color: Colors.black45),
                        suffixIconConstraints: BoxConstraints(minWidth: 18, minHeight: 18),
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
              // QR Code placeholder (top-aligned with name fields)
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey[400]!, width: 1),
                ),
                child: _isFormComplete
                    ? QrImageView(
                        data: _getBusinessCardUrl(),
                        version: QrVersions.auto,
                        size: 92,
                        backgroundColor: Colors.white,
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'QR Code link generated on next page.',
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
          const SizedBox(height: 10),
          Expanded(
            child: _buildInstructionsBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildShortnameStatusBelowCard() {
    final shortname = _shortnameController.text.trim().toLowerCase();

    if (_isValidating) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Checking shortname…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                  ),
            ),
          ],
        ),
      );
    }

    if ((_validationMessage ?? '').trim().isEmpty) return const SizedBox.shrink();

    final msg = _isAvailable
        ? "The shortname $shortname is available!"
        : (shortname.isEmpty
            ? 'Shortname: ${_validationMessage!}'
            : "The shortname $shortname is not available: ${_validationMessage!}");

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _isAvailable ? Colors.green : Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _buildInstructionsBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(
        children: [
          Center(
            child: TextField(
              controller: _instructionsController,
              maxLines: null,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                _saveField('cardInstructions', value);
              },
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: 'Reset instructions',
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reset Instructions?'),
                    content: const Text(
                      'Are you sure you want to reset instructions section to its default?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  setState(() {
                    _instructionsController.text = _defaultInstructions;
                  });
                  await _saveField('cardInstructions', _defaultInstructions);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherPreviewPhone() {
    final url = _getBusinessCardUrl().replaceFirst('https://', '');
    final fullName = '${_firstNameController.text} ${_lastNameController.text}'.trim();

    final content = Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            // Extra inset to avoid clipping against rounded edges.
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: Text(
              'Powered by Sub67…',
              softWrap: true,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                  ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickProfilePhoto,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 56,
                backgroundImage: _profilePhotoUrl != null ? NetworkImage(_profilePhotoUrl!) : null,
                child: _profilePhotoUrl == null
                    ? Text(
                        _auth.currentUser?.email?[0].toUpperCase() ?? 'U',
                        style: const TextStyle(fontSize: 28),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _copyRow(
          label: fullName.isEmpty ? 'Name' : fullName,
          valueToCopy: fullName,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _bioController,
                maxLength: 500,
                maxLines: null,
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: 'Quick bio (max 500 chars)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.all(12),
                ),
                style: const TextStyle(fontStyle: FontStyle.italic),
                onChanged: (value) => _saveField('bio', value),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Reset bio',
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reset Bio?'),
                    content: const Text('Are you sure you want to reset bio to its default?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  setState(() {
                    _bioController.text = _defaultBio;
                  });
                  await _saveField('bio', _defaultBio);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        _copyRow(label: _phoneController.text.isEmpty ? 'Phone' : _phoneController.text, valueToCopy: _phoneController.text),
        _copyRow(label: _emailController.text.isEmpty ? 'Email' : _emailController.text, valueToCopy: _emailController.text),
        _copyRow(label: url.isEmpty ? 'sub67.com/<shortname>' : url, valueToCopy: url),
        const SizedBox(height: 12),
        Divider(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Choose what you’d like to do:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: RadioListTile<TeacherPreviewAction>(
            value: TeacherPreviewAction.preferred,
            groupValue: _teacherPreviewAction,
            onChanged: (v) => setState(() => _teacherPreviewAction = v!),
            title: Text(
              'Add $fullName (${_phoneController.text.isEmpty ? 'no phone' : _phoneController.text}) to preferred teaching list?*',
              softWrap: true,
            ),
          ),
        ),
        Card(
          child: RadioListTile<TeacherPreviewAction>(
            value: TeacherPreviewAction.specificDay,
            groupValue: _teacherPreviewAction,
            onChanged: (v) => setState(() => _teacherPreviewAction = v!),
            title: Text(
              'Request $fullName (${_phoneController.text.isEmpty ? 'no phone' : _phoneController.text}) for a specific day?',
              softWrap: true,
            ),
          ),
        ),
        if (_teacherPreviewAction == TeacherPreviewAction.specificDay) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 1)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _teacherPreviewFocusedDay,
                selectedDayPredicate: (day) => _teacherPreviewSelectedDay != null && isSameDay(_teacherPreviewSelectedDay, day),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _teacherPreviewSelectedDay = selected;
                    _teacherPreviewFocusedDay = focused;
                  });
                },
                onPageChanged: (focused) => _teacherPreviewFocusedDay = focused,
                calendarStyle: const CalendarStyle(isTodayHighlighted: true),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _teacherTermsNudgeController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_teacherTermsShakeX.value, 0),
                      child: child,
                    );
                  },
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _teacherTermsNudgeController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _teacherTermsCheckboxScale.value,
                            child: child,
                          );
                        },
                        child: Checkbox(
                          value: _teacherPreviewTermsAccepted,
                          onChanged: (v) => setState(() => _teacherPreviewTermsAccepted = v ?? false),
                        ),
                      ),
                      Expanded(
                        child: Wrap(
                          children: [
                            Text(
                              'I Agree to the ',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            InkWell(
                              onTap: _showTeacherTermsPreview,
                              child: Text(
                                'Terms & Conditions',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      decoration: TextDecoration.underline,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Checkbox(
                      value: _teacherPreviewDownloadAppChecked,
                      onChanged: (v) => setState(() => _teacherPreviewDownloadAppChecked = v ?? false),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: const [
                            TextSpan(
                              text: 'Download the app!',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: '—For a faster, smoother experience and to unlock other useful features.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              if (!_teacherPreviewCanContinue) {
                await _nudgeTeacherTerms();
                return;
              }
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Preview: Teachers will tap Next, enter Frontline/ESS credentials, then continue.'),
                ),
              );
            },
            child: const Text('Next'),
          ),
        ),
      ],
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _buildPhoneFrame(
          context,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneFrame(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    final bezel = cs.onSurface.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.55 : 0.88);

    return Container(
      height: 680,
      decoration: BoxDecoration(
        color: bezel,
        borderRadius: BorderRadius.circular(46),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(38),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: child,
              ),
            ),
            // Notch / speaker cutout (visual cue that this is a phone).
            Positioned(
              top: 3,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 126,
                  height: 28,
                  decoration: BoxDecoration(
                    color: bezel,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Home indicator.
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 122,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _copyRow({required String label, required String valueToCopy}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
            softWrap: true,
          ),
        ),
        IconButton(
          tooltip: 'Copy',
          icon: const Icon(Icons.copy, size: 18),
          onPressed: valueToCopy.trim().isEmpty
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: valueToCopy.trim()));
                  if (valueToCopy.trim().startsWith('https://sub67.com/')) {
                    await _logEvent('business_card_link_shared', meta: {'method': 'copy'});
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied')),
                    );
                  }
                },
        ),
      ],
    );
  }
}

// Business card terms were consolidated into the global one-time Terms & Conditions gate.

class DashedPhoneNumberTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final capped = digits.length > 10 ? digits.substring(0, 10) : digits;

    String formatted;
    if (capped.isEmpty) {
      formatted = '';
    } else if (capped.length <= 3) {
      formatted = capped;
    } else if (capped.length <= 6) {
      formatted = '${capped.substring(0, 3)}-${capped.substring(3)}';
    } else {
      formatted = '${capped.substring(0, 3)}-${capped.substring(3, 6)}-${capped.substring(6)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
