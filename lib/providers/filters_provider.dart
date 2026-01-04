import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FiltersProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, List<String>> _filtersDict = {
    "subjects": ["science", "math", "english", "art", "history"],
    "specialties": ["sped", "social studies", "psychology"],
    "premium-classes": ["ap", "honors"],
    "premium-workdays": [
      "early-out (with a full-day pay)",
      "prep period included",
      "free lunch coupon",
      "extra pay (SPED teacher)"
    ],
  };

  Map<String, TagState> _tagStates = {};
  List<String> _includedLs = [];
  List<String> _excludeLs = [];
  Map<String, List<String>> _customTags = {};
  bool _premiumClassesUnlocked = false;
  bool _premiumWorkdaysUnlocked = false;

  Map<String, List<String>> get filtersDict => _filtersDict;
  Map<String, TagState> get tagStates => _tagStates;
  List<String> get includedLs => _includedLs;
  List<String> get excludeLs => _excludeLs;
  Map<String, List<String>> get customTags => _customTags;
  bool get premiumClassesUnlocked => _premiumClassesUnlocked;
  bool get premiumWorkdaysUnlocked => _premiumWorkdaysUnlocked;

  FiltersProvider() {
    _initializeDefaults();
    _loadFromFirebase();
  }

  void _initializeDefaults() {
    // Default: subjects and specialties are green (included)
    for (var tag in _filtersDict["subjects"] ?? []) {
      _tagStates[tag] = TagState.green;
      _includedLs.add(tag);
    }
    for (var tag in _filtersDict["specialties"] ?? []) {
      _tagStates[tag] = TagState.green;
      _includedLs.add(tag);
    }
    // Default: premium tags are gray (unselected)
    for (var tag in _filtersDict["premium-classes"] ?? []) {
      _tagStates[tag] = TagState.gray;
    }
    for (var tag in _filtersDict["premium-workdays"] ?? []) {
      _tagStates[tag] = TagState.gray;
    }
  }

  Future<void> _loadFromFirebase() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _premiumClassesUnlocked = data['premiumClassesUnlocked'] ?? false;
        _premiumWorkdaysUnlocked = data['premiumWorkdaysUnlocked'] ?? false;
        
        // Load tag states
        final savedStates = data['tagStates'] as Map<String, dynamic>?;
        if (savedStates != null) {
          savedStates.forEach((key, value) {
            _tagStates[key] = TagState.values[value as int];
          });
        }
        
        // Load lists
        _includedLs = List<String>.from(data['includedLs'] ?? []);
        _excludeLs = List<String>.from(data['excludeLs'] ?? []);
        _customTags = Map<String, List<String>>.from(
          data['customTags'] ?? {},
        );
        
        notifyListeners();
      }
    } catch (e) {
      print('Error loading filters: $e');
    }
  }

  Future<void> toggleTag(String category, String tag) async {
    // Check if premium and locked
    if ((category == "premium-classes" && !_premiumClassesUnlocked) ||
        (category == "premium-workdays" && !_premiumWorkdaysUnlocked)) {
      return;
    }

    final currentState = _tagStates[tag] ?? TagState.gray;
    TagState newState;

    if (category == "premium-classes" || category == "premium-workdays") {
      // Premium tags: gray <-> purple
      newState = currentState == TagState.purple ? TagState.gray : TagState.purple;
    } else {
      // Regular tags: green -> gray -> red -> green
      switch (currentState) {
        case TagState.green:
          newState = TagState.gray;
          _includedLs.remove(tag);
          break;
        case TagState.gray:
          newState = TagState.red;
          _excludeLs.add(tag);
          break;
        case TagState.red:
          newState = TagState.green;
          _excludeLs.remove(tag);
          _includedLs.add(tag);
          break;
        default:
          newState = TagState.green;
          _includedLs.add(tag);
      }
    }

    _tagStates[tag] = newState;
    await _saveToFirebase();
    notifyListeners();
  }

  Future<void> addCustomTag(String category, String tag) async {
    if (_customTags[category] == null) {
      _customTags[category] = [];
    }
    
    // Check if tag exists in any category
    bool exists = false;
    for (var cat in _filtersDict.keys) {
      if (_filtersDict[cat]?.contains(tag.toLowerCase()) ?? false) {
        exists = true;
        break;
      }
    }
    
    if (!exists && !(_customTags[category]?.contains(tag) ?? false)) {
      _customTags[category]!.add(tag);
      _tagStates[tag] = TagState.gray;
      await _saveToFirebase();
      notifyListeners();
    }
  }

  Future<void> removeCustomTag(String category, String tag) async {
    _customTags[category]?.remove(tag);
    _tagStates.remove(tag);
    _includedLs.remove(tag);
    _excludeLs.remove(tag);
    await _saveToFirebase();
    notifyListeners();
  }

  Future<void> unlockPremium(String type, String promoCode) async {
    // Import AppConfig for promo codes
    final validCodes = [
      "PremiumVIP", "VIP26", "UrCute", "PrettyCute", "VIPCute",
      "VIP67", "VIP41", "4Libby<3", "4Libby", "4Kim", "4Kim<3"
    ];
    
    // Case-insensitive check
    final upperPromo = promoCode.toUpperCase();
    final isValid = validCodes.any((code) => code.toUpperCase() == upperPromo);
    
    if (!isValid) {
      throw Exception('Invalid promo code');
    }

    final user = _auth.currentUser;
    if (user == null) return;

    if (type == "premium-classes") {
      _premiumClassesUnlocked = true;
      await _firestore.collection('users').doc(user.uid).update({
        'premiumClassesUnlocked': true,
      });
    } else if (type == "premium-workdays") {
      _premiumWorkdaysUnlocked = true;
      await _firestore.collection('users').doc(user.uid).update({
        'premiumWorkdaysUnlocked': true,
      });
    }

    await _saveToFirebase();
    notifyListeners();
  }

  Future<void> _saveToFirebase() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final statesMap = <String, int>{};
    _tagStates.forEach((key, value) {
      statesMap[key] = value.index;
    });

    await _firestore.collection('users').doc(user.uid).update({
      'tagStates': statesMap,
      'includedLs': _includedLs,
      'excludeLs': _excludeLs,
      'customTags': _customTags,
    });
  }
}

enum TagState { green, gray, red, purple }

