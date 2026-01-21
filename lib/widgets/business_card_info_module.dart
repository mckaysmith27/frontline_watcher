import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BusinessCardInfo {
  const BusinessCardInfo({
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.email,
    required this.shortname,
    required this.cardInstructions,
    required this.bio,
    required this.isShortnameAvailable,
    required this.shortnameStatusMessage,
    required this.isValidatingShortname,
  });

  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String email;
  final String shortname;
  final String cardInstructions;
  final String bio;

  final bool isShortnameAvailable;
  final String? shortnameStatusMessage;
  final bool isValidatingShortname;

  bool get isComplete =>
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      phoneNumber.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      shortname.trim().isNotEmpty &&
      isShortnameAvailable;
}

/// Reusable Business Card "info" module (fields + shortname validation + saving).
///
/// Use this anywhere you need to ensure a user has filled the required Business Card fields
/// (e.g. VIP Power-up checkout gating).
class BusinessCardInfoModule extends StatefulWidget {
  const BusinessCardInfoModule({
    super.key,
    this.compact = false,
    this.onInfoChanged,
  });

  final bool compact;
  final ValueChanged<BusinessCardInfo>? onInfoChanged;

  @override
  State<BusinessCardInfoModule> createState() => _BusinessCardInfoModuleState();
}

class _BusinessCardInfoModuleState extends State<BusinessCardInfoModule> {
  static const String _defaultInstructions =
      "Scan the QR code to add me as a 'preferred' sub! Keep this card and re-scan, to quickly request me for a specific day.";
  static const String _defaultBio =
      'An experienced sub who can who can manage a classroom and accomplish the mission.';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _shortnameController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  String? _nickname;
  String? _currentShortname;
  String? _validationMessage;
  bool _isValidating = false;
  bool _isAvailable = false;

  Timer? _shortnameDebounce;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _shortnameController.addListener(_scheduleValidateShortname);

    void notify() => _emitInfoChanged();
    _firstNameController.addListener(notify);
    _lastNameController.addListener(notify);
    _phoneController.addListener(notify);
    _emailController.addListener(notify);
    _instructionsController.addListener(notify);
    _bioController.addListener(notify);
    _shortnameController.addListener(notify);
  }

  @override
  void dispose() {
    _shortnameDebounce?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _shortnameController.dispose();
    _instructionsController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};

    final fsFirstName = (data['firstName'] is String) ? (data['firstName'] as String).trim() : '';
    final fsLastName = (data['lastName'] is String) ? (data['lastName'] as String).trim() : '';
    final fsPhone = (data['phoneNumber'] is String) ? (data['phoneNumber'] as String).trim() : '';
    final fsEmail = (data['email'] is String) ? (data['email'] as String).trim() : '';
    final fsShortname = (data['shortname'] is String) ? (data['shortname'] as String).trim().toLowerCase() : '';
    final fsNickname = (data['nickname'] is String) ? (data['nickname'] as String).trim() : '';
    final fsInstructions = (data['cardInstructions'] is String) ? (data['cardInstructions'] as String).trim() : '';
    final fsBio = (data['bio'] is String) ? (data['bio'] as String).trim() : '';

    // Avoid fighting the user's edits; only set controller text if empty.
    if (_firstNameController.text.trim().isEmpty) {
      _firstNameController.text = fsFirstName;
    }
    if (_lastNameController.text.trim().isEmpty) {
      _lastNameController.text = fsLastName;
    }
    if (_phoneController.text.trim().isEmpty) {
      _phoneController.text = _formatPhoneDashed(fsPhone);
    }
    if (_emailController.text.trim().isEmpty) {
      _emailController.text = (user.email ?? fsEmail).trim();
    }
    if (_shortnameController.text.trim().isEmpty) {
      _shortnameController.text = fsShortname;
    }
    if (_instructionsController.text.trim().isEmpty) {
      _instructionsController.text = fsInstructions.isNotEmpty ? fsInstructions : _defaultInstructions;
    }
    if (_bioController.text.trim().isEmpty) {
      _bioController.text = fsBio.isNotEmpty ? fsBio : _defaultBio;
    }

    _nickname = fsNickname.isNotEmpty ? fsNickname : null;
    _currentShortname = fsShortname.isNotEmpty ? fsShortname : null;
    _isAvailable = fsShortname.isNotEmpty;
    _validationMessage = fsShortname.isNotEmpty ? 'available!' : null;

    _emitInfoChanged();
  }

  void _emitInfoChanged() {
    final info = BusinessCardInfo(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      phoneNumber: _phoneController.text,
      email: _emailController.text,
      shortname: _shortnameController.text.trim().toLowerCase(),
      cardInstructions: _instructionsController.text,
      bio: _bioController.text,
      isShortnameAvailable: _isAvailable,
      shortnameStatusMessage: _validationMessage,
      isValidatingShortname: _isValidating,
    );
    widget.onInfoChanged?.call(info);
  }

  Future<void> _saveField(String field, String value) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({field: value}, SetOptions(merge: true));
  }

  void _scheduleValidateShortname() {
    _shortnameDebounce?.cancel();
    _shortnameDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _validateShortname();
    });
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

  Future<void> _validateShortname() async {
    final shortname = _shortnameController.text.trim().toLowerCase();

    if (shortname.isEmpty) {
      setState(() {
        _validationMessage = null;
        _isAvailable = false;
        _isValidating = false;
      });
      _emitInfoChanged();
      return;
    }

    // If unchanged from current shortname, treat as valid/available instantly.
    if (_currentShortname != null && shortname == _currentShortname) {
      setState(() {
        _validationMessage = 'available!';
        _isAvailable = true;
        _isValidating = false;
      });
      _emitInfoChanged();
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
      _emitInfoChanged();
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
      _emitInfoChanged();
      return;
    }

    // Save shortname immediately (best-effort) so it persists for other flows.
    await _saveField('shortname', shortname);
    _currentShortname = shortname;

    setState(() => _isValidating = true);
    _emitInfoChanged();

    try {
      final callable = _functions.httpsCallable('checkShortnameAvailability');
      final result = await callable.call({'shortname': shortname});
      final data = Map<String, dynamic>.from(result.data as Map);
      final available = data['available'] == true;

      if (!mounted) return;
      setState(() {
        _isValidating = false;
        if (available) {
          _validationMessage = 'available!';
          _isAvailable = true;
        } else {
          _validationMessage = (data['reason'] as String?) ?? 'not available';
          _isAvailable = false;
        }
      });
      _emitInfoChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _validationMessage = 'Error checking availability';
        _isAvailable = false;
      });
      _emitInfoChanged();
    }
  }

  String _formatPhoneDashed(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final capped = digits.length > 10 ? digits.substring(0, 10) : digits;
    if (capped.isEmpty) return '';
    if (capped.length <= 3) return capped;
    if (capped.length <= 6) return '${capped.substring(0, 3)}-${capped.substring(3)}';
    return '${capped.substring(0, 3)}-${capped.substring(3, 6)}-${capped.substring(6)}';
  }

  @override
  Widget build(BuildContext context) {
    final dense = widget.compact;
    final cardHeight = dense ? 220.0 : 240.0;

    return Column(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          height: cardHeight,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: Colors.grey[300]!, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
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
                                onChanged: (value) => _saveField('firstName', value.trim()),
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
                                onChanged: (value) => _saveField('lastName', value.trim()),
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
                          onChanged: (value) => _saveField('phoneNumber', value.trim()),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _shortnameController,
                          decoration: const InputDecoration(
                            prefixText: 'sub67.com/',
                            prefixStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                            hintText: 'shortname',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            suffixIcon: Icon(Icons.edit, size: 16, color: Colors.black45),
                            suffixIconConstraints: BoxConstraints(minWidth: 18, minHeight: 18),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          textCapitalization: TextCapitalization.none,
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
                          onChanged: (value) => _saveField('email', value.trim()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // QR placeholder
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.grey[400]!, width: 1),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          widget.compact
                              ? 'Fill fields to enable QR'
                              : 'QR Code link generated on next page.',
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
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Center(
                    child: TextField(
                      controller: _instructionsController,
                      maxLines: null,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) => _saveField('cardInstructions', value),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isValidating)
          Padding(
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
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                ),
              ],
            ),
          )
        else if ((_validationMessage ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _isAvailable
                  ? 'The shortname ${_shortnameController.text.trim().toLowerCase()} is available!'
                  : 'The shortname ${_shortnameController.text.trim().toLowerCase()} is not available: ${_validationMessage!}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _isAvailable ? Colors.green : Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
      ],
    );
  }
}

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

