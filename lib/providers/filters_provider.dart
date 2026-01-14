import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FiltersProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic> _filtersDict = {
    "subjects": [
      "math",
      "algebra",
      "geometry",
      "calculus",
      "english",
      "language arts",
      "reading",
      "writing",
      "science",
      "biology",
      "chemistry",
      "physics",
      "history",
      "social studies",
      "pe",
      "physical education",
      "fine arts",
      "art",
      "choir",
      "band",
      "orchestra",
      "music",
      "health",
      "spanish",
      "french",
      "german",
      "chinese",
      "esl",
      "ell",
      "food",
      "cte",
      "technology",
      "engineering"
    ],
    "specialties": ["aide", "ap", "honors", "sped"],
    "Duration": ["half", "full"],
    "schools-by-city": {
      "Alpine": [
        "Alpine Elementary",
        "Timberline Middle School",
        "Westfield Elementary"
      ],
      "American Fork": [
        "American Fork High School",
        "American Fork Junior High School",
        "Barratt Elementary",
        "East Shore High School",
        "Forbes Elementary",
        "Geneva Elementary",
        "Greenwood Elementary",
        "Legacy Elementary",
        "Polaris High School",
        "Polaris West High School",
        "Sharon Elementary",
        "Shelley Elementary",
        "Suncrest Elementary",
        "Valley View Elementary"
      ],
      "Cedar Fort": [
        "Cedar Valley Elementary"
      ],
      "Cedar Hills": [
        "Cedar Ridge Elementary",
        "Deerfield Elementary"
      ],
      "Eagle Mountain": [
        "Black Ridge Elementary",
        "Brookhaven Elementary",
        "Desert Sky Elementary",
        "Eagle Valley Elementary",
        "Frontier Middle School",
        "Hidden Hollow Elementary",
        "Mountain Trails Elementary",
        "Pony Express Elementary",
        "Sage Canyon Middle School"
      ],
      "Highland": [
        "Freedom Elementary",
        "Highland Elementary",
        "Lone Peak High School",
        "Mountain Ridge Junior High School",
        "Ridgeline Elementary"
      ],
      "Lehi": [
        "Belmont Elementary",
        "Dry Creek Elementary",
        "Eaglecrest Elementary",
        "Fox Hollow Elementary",
        "Lehi Elementary",
        "Lehi High School",
        "Lehi Junior High School",
        "Liberty Hills Elementary",
        "Meadow Elementary",
        "North Point Elementary",
        "River Rock Elementary",
        "Sego Lily Elementary",
        "Skyridge High School",
        "Snow Springs Elementary",
        "Traverse Mountain Elementary",
        "Viewpoint Middle School",
        "Willowcreek Middle School"
      ],
      "Lindon": [
        "Lindon Elementary",
        "Rocky Mountain Elementary"
      ],
      "Orem": [
        "Aspen Elementary",
        "Bonneville Elementary",
        "Canyon View Junior High School",
        "Cascade Elementary",
        "Centennial Elementary",
        "Cherry Hill Elementary",
        "Foothill Elementary",
        "Lakeridge Junior High School",
        "Mountain View High School",
        "Northridge Elementary",
        "Orchard Elementary",
        "Orem Elementary",
        "Orem High School",
        "Orem Junior High School",
        "Parkside Elementary",
        "Timpanogos High School",
        "Westmore Elementary"
      ],
      "Pleasant Grove": [
        "Central Elementary",
        "Grovecrest Elementary",
        "Manila Elementary",
        "Mount Mahogany Elementary",
        "Oak Canyon Junior High School",
        "Pleasant Grove High School",
        "Pleasant Grove Junior High School"
      ],
      "Saratoga Springs": [
        "Harbor Point Elementary",
        "Harvest Elementary",
        "Lake Mountain Middle School",
        "Riverview Elementary",
        "Sage Hills Elementary",
        "Saratoga Shores Elementary",
        "Thunder Ridge Elementary",
        "Vista Heights Middle School",
        "Westlake High School"
      ],
      "Vineyard": [
        "Trailside Elementary",
        "Vineyard Elementary"
      ],
      "Other": [
        "Alpine Online",
        "Alpine Summit Programs",
        "zFloater Program",
        "SPED Summer School",
        "Summit RTC",
        "District Offices",
        "ATEC - East",
        "Lehi High Summer School",
        "Mountain View High Summer School"
      ]
    },
  };

  Map<String, TagState> _tagStates = {};
  List<String> _includedLs = [];
  List<String> _excludeLs = [];
  Map<String, List<String>> _customTags = {};
  // Per-date filters: dateStr -> {includedWords: [], excludedWords: []}
  Map<String, Map<String, List<String>>> _dateFilters = {};
  
  // Keyword mapping for alternative terms
  static const Map<String, List<String>> keywordMappings = {
    "pe": ["physical education", "p.e.", "p. e."],
    "sped": ["special ed", "special ed.", "special edu", "special education"],
    "esl": ["english sign language"],
    "ell": ["english language learning", "english language learner"],
    "art": ["arts"],
    "half": ["half day"],
    "full": ["full day"],
  };

  Map<String, dynamic> get filtersDict => _filtersDict;
  Map<String, TagState> get tagStates => _tagStates;
  List<String> get includedLs => _includedLs;
  List<String> get excludeLs => _excludeLs;
  Map<String, List<String>> get customTags => _customTags;
  Map<String, Map<String, List<String>>> get dateFilters => _dateFilters;

  // Get filtered schools-by-city (no longer filters by school-types, that's handled in map widget)
  Map<String, List<String>> getFilteredSchoolsByCity() {
    return Map<String, List<String>>.from(_filtersDict['schools-by-city'] as Map);
  }

  FiltersProvider() {
    _initializeDefaults();
    _loadFromFirebase();
  }

  void _initializeDefaults() {
    // Default: all tags are gray (unselected)
    // User must explicitly select what they want
    for (var category in _filtersDict.keys) {
      final categoryValue = _filtersDict[category];
      
      // Handle nested dictionaries (like "schools-by-city")
      if (categoryValue is Map) {
        categoryValue.forEach((city, schools) {
          // Initialize city name as a tag
          _tagStates[city] = TagState.gray;
          if (schools is List) {
            for (var school in schools) {
              _tagStates[school] = TagState.gray;
            }
          }
        });
      } else if (categoryValue is List) {
        // Regular list of tags
        for (var tag in categoryValue) {
          _tagStates[tag] = TagState.gray;
        }
      }
    }
  }

  Future<void> _loadFromFirebase() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        
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
        
        // Load date-specific filters
        final dateFiltersData = data['dateFilters'] as Map<String, dynamic>?;
        if (dateFiltersData != null) {
          dateFiltersData.forEach((dateStr, filters) {
            if (filters is Map<String, dynamic>) {
              _dateFilters[dateStr] = {
                'includedWords': List<String>.from(filters['includedWords'] ?? []),
                'excludedWords': List<String>.from(filters['excludedWords'] ?? []),
              };
            }
          });
        }
        
        notifyListeners();
      }
    } catch (e) {
      print('Error loading filters: $e');
    }
  }

  // Get filters for a specific date (returns date-specific or default filters)
  Map<String, List<String>> getDateFilters(String dateStr) {
    if (_dateFilters.containsKey(dateStr)) {
      return _dateFilters[dateStr]!;
    }
    // Return default filters if no date-specific filters
    return {
      'includedWords': _includedLs,
      'excludedWords': _excludeLs,
    };
  }

  // Get unique keywords for a specific date (keywords that differ from global filters)
  Map<String, List<String>> getUniqueKeywords(String dateStr) {
    final dateFilters = getDateFilters(dateStr);
    final globalIncluded = _includedLs.toSet();
    final globalExcluded = _excludeLs.toSet();
    
    final dateIncluded = (dateFilters['includedWords'] ?? []).toSet();
    final dateExcluded = (dateFilters['excludedWords'] ?? []).toSet();
    
    // Find unique included keywords (in date but not in global, or different state)
    final uniqueIncluded = <String>[];
    for (var keyword in dateIncluded) {
      // Skip date keywords (format: "1_15_2024" or similar)
      if (_isDateKeyword(keyword)) continue;
      
      // If keyword is in date included but not in global included, it's unique
      if (!globalIncluded.contains(keyword)) {
        uniqueIncluded.add(keyword);
      }
    }
    
    // Also check if global keywords are missing from date (but this means date has fewer, not unique)
    // We only want keywords that are in date but not in global
    
    // Find unique excluded keywords (in date but not in global)
    final uniqueExcluded = <String>[];
    for (var keyword in dateExcluded) {
      // Skip date keywords
      if (_isDateKeyword(keyword)) continue;
      
      // If keyword is in date excluded but not in global excluded, it's unique
      if (!globalExcluded.contains(keyword)) {
        uniqueExcluded.add(keyword);
      }
    }
    
    return {
      'includedWords': uniqueIncluded,
      'excludedWords': uniqueExcluded,
    };
  }

  // Check if a keyword is a date keyword (format: "1_15_2024" or similar)
  bool _isDateKeyword(String keyword) {
    // Date keywords typically have format: "month_day_year" with underscores
    // Pattern: digits_digits_digits (e.g., "1_15_2024", "12_25_2024")
    final datePattern = RegExp(r'^\d{1,2}_\d{1,2}_\d{4}$');
    return datePattern.hasMatch(keyword);
  }

  // Check if a date has unique keywords
  bool hasUniqueKeywords(String dateStr) {
    final unique = getUniqueKeywords(dateStr);
    return (unique['includedWords']?.isNotEmpty ?? false) ||
           (unique['excludedWords']?.isNotEmpty ?? false);
  }

  // Auto-apply global filters to a specific date (only if date doesn't have unique keywords)
  // Also checks if date is unavailable or has job - won't apply in those cases
  Future<void> autoApplyFiltersToDate(String dateStr, {
    required bool isNotificationDay,
    required bool isUnavailable,
    required bool hasJob,
  }) async {
    // Don't apply filters if:
    // 1. Date is not a notification day
    // 2. Date is marked unavailable
    // 3. Date has a job booked
    if (!isNotificationDay || isUnavailable || hasJob) {
      return;
    }
    
    // If date already has unique keywords, merge global filters but keep unique keywords
    if (hasUniqueKeywords(dateStr)) {
      // Get current unique keywords
      final unique = getUniqueKeywords(dateStr);
      final uniqueIncluded = (unique['includedWords'] ?? []).toSet();
      final uniqueExcluded = (unique['excludedWords'] ?? []).toSet();
      
      // Merge: global filters + unique keywords
      final mergedIncluded = <String>[..._includedLs, ...uniqueIncluded].toSet().toList();
      final mergedExcluded = <String>[..._excludeLs, ...uniqueExcluded].toSet().toList();
      
      _dateFilters[dateStr] = {
        'includedWords': mergedIncluded,
        'excludedWords': mergedExcluded,
      };
    } else {
      // No unique keywords, just apply global filters
      _dateFilters[dateStr] = {
        'includedWords': _includedLs.toList(),
        'excludedWords': _excludeLs.toList(),
      };
    }
    
    await _saveToFirebase();
    notifyListeners();
  }

  // Clear unique keywords for a date (reset to global filters)
  Future<void> clearUniqueKeywords(String dateStr) async {
    // Remove date-specific filters, which will make it use global filters
    _dateFilters.remove(dateStr);
    await _saveToFirebase();
    notifyListeners();
  }

  // Apply global filter changes to all notification days (except unique keywords)
  Future<void> propagateGlobalFiltersToAllDates(
    List<String> committedDates, {
    required bool Function(String) isUnavailable,
    required bool Function(String) hasJob,
  }) async {
    for (var dateStr in committedDates) {
      // Skip if date is unavailable or has job
      if (isUnavailable(dateStr) || hasJob(dateStr)) {
        continue;
      }
      
      // Skip if date has unique keywords (user has customized it)
      if (hasUniqueKeywords(dateStr)) {
        // Still apply global filters, but keep unique keywords
        final dateFilters = _dateFilters[dateStr] ?? {
          'includedWords': [],
          'excludedWords': [],
        };
        
        final unique = getUniqueKeywords(dateStr);
        final uniqueIncluded = (unique['includedWords'] ?? []).toSet();
        final uniqueExcluded = (unique['excludedWords'] ?? []).toSet();
        
        // Merge: global filters + unique keywords
        final mergedIncluded = <String>[..._includedLs, ...uniqueIncluded].toSet().toList();
        final mergedExcluded = <String>[..._excludeLs, ...uniqueExcluded].toSet().toList();
        
        dateFilters['includedWords'] = mergedIncluded;
        dateFilters['excludedWords'] = mergedExcluded;
        
        _dateFilters[dateStr] = dateFilters;
      } else {
        // No unique keywords, just apply global filters
        await autoApplyFiltersToDate(
          dateStr,
          isNotificationDay: true,
          isUnavailable: isUnavailable(dateStr),
          hasJob: hasJob(dateStr),
        );
      }
    }
    
    await _saveToFirebase();
    notifyListeners();
  }
  
  // Auto-apply filters to newly committed dates (called when credits are added)
  Future<void> autoApplyToNewDates(
    List<String> newDates, {
    required bool Function(String) isUnavailable,
    required bool Function(String) hasJob,
  }) async {
    for (var dateStr in newDates) {
      // Only apply if date is a notification day and not unavailable/has job
      if (!isUnavailable(dateStr) && !hasJob(dateStr)) {
        await autoApplyFiltersToDate(
          dateStr,
          isNotificationDay: true,
          isUnavailable: false,
          hasJob: false,
        );
      }
    }
  }

  // Get tag state for a specific date (date-specific or default)
  TagState getTagStateForDate(String tag, String? dateStr) {
    if (dateStr != null && _dateFilters.containsKey(dateStr)) {
      final dateFilters = _dateFilters[dateStr]!;
      if (dateFilters['includedWords']?.contains(tag) ?? false) {
        return TagState.green;
      }
      if (dateFilters['excludedWords']?.contains(tag) ?? false) {
        return TagState.red;
      }
      return TagState.gray;
    }
    // Default tag state
    return _tagStates[tag] ?? TagState.gray;
  }

  // Toggle tag for a specific date
  Future<void> toggleTagForDate(String category, String tag, String dateStr) async {
    // Initialize date filters if not exists
    if (!_dateFilters.containsKey(dateStr)) {
      _dateFilters[dateStr] = {
        'includedWords': [],
        'excludedWords': [],
      };
    }

    final dateFilters = _dateFilters[dateStr]!;
    final currentState = getTagStateForDate(tag, dateStr);
    TagState newState;
    
    // Update date-specific filters
    switch (currentState) {
      case TagState.green:
        newState = TagState.gray;
        dateFilters['includedWords']!.remove(tag);
        break;
      case TagState.gray:
        newState = TagState.red;
        dateFilters['excludedWords']!.add(tag);
        break;
      case TagState.red:
        newState = TagState.green;
        dateFilters['excludedWords']!.remove(tag);
        dateFilters['includedWords']!.add(tag);
        break;
      default:
        newState = TagState.green;
        dateFilters['includedWords']!.add(tag);
    }

    // If this is a nested category and the tag is a city name, update all schools under it
    final categoryValue = _filtersDict[category];
    if (categoryValue is Map && categoryValue.containsKey(tag)) {
      // This tag is a city name - update all schools under this city for this date
      final schools = categoryValue[tag];
      if (schools is List) {
        for (var school in schools) {
          // Update date-specific filters for schools
          if (newState == TagState.green) {
            if (!dateFilters['includedWords']!.contains(school)) {
              dateFilters['includedWords']!.add(school);
            }
            dateFilters['excludedWords']!.remove(school);
          } else if (newState == TagState.red) {
            if (!dateFilters['excludedWords']!.contains(school)) {
              dateFilters['excludedWords']!.add(school);
            }
            dateFilters['includedWords']!.remove(school);
          } else {
            // Gray state - remove from both lists
            dateFilters['includedWords']!.remove(school);
            dateFilters['excludedWords']!.remove(school);
          }
        }
      }
    }

    await _saveToFirebase();
    notifyListeners();
  }

  // Clear filters for a specific date
  Future<void> clearDateFilters(String dateStr) async {
    _dateFilters.remove(dateStr);
    await _saveToFirebase();
    notifyListeners();
  }

  // Save date filters to Firestore
  Future<void> saveDateFilters(String dateStr) async {
    await _saveToFirebase();
  }

  Future<void> toggleTag(String category, String tag) async {
    final currentState = _tagStates[tag] ?? TagState.gray;
    TagState newState;
    
    // Store old included/excluded lists to detect changes
    final oldIncluded = _includedLs.toSet();
    final oldExcluded = _excludeLs.toSet();

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

    _tagStates[tag] = newState;

    // If this is a nested category and the tag is a city name, update all schools under it
    final categoryValue = _filtersDict[category];
    if (categoryValue is Map && categoryValue.containsKey(tag)) {
      // This tag is a city name - update all schools under this city
      final schools = categoryValue[tag];
      if (schools is List) {
        for (var school in schools) {
          // Set all schools to the same state as the city
          _tagStates[school] = newState;

          // Update included/excluded lists accordingly
          if (newState == TagState.green) {
            if (!_includedLs.contains(school)) {
              _includedLs.add(school);
            }
            _excludeLs.remove(school);
          } else if (newState == TagState.red) {
            if (!_excludeLs.contains(school)) {
              _excludeLs.add(school);
            }
            _includedLs.remove(school);
          } else {
            // Gray state - remove from both lists
            _includedLs.remove(school);
            _excludeLs.remove(school);
          }
        }
      }
    }

    await _saveToFirebase();
    
    // Propagate global filter changes to all notification days (except unique keywords)
    // Note: This requires access to CreditsProvider, which we'll handle via callback or listener
    // For now, we'll add a method that can be called with committed dates
    
    notifyListeners();
  }
  
  // Method to be called when global filters change - propagates to all notification days
  // This should be called from the screen that has access to both providers
  Future<void> onGlobalFiltersChanged(List<String> committedDates, {
    required bool Function(String) isUnavailable,
    required bool Function(String) hasJob,
  }) async {
    await propagateGlobalFiltersToAllDates(committedDates, 
      isUnavailable: isUnavailable,
      hasJob: hasJob,
    );
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


  // Make saveToFirebase public for map widget to use
  Future<void> saveToFirebase() async {
    await _saveToFirebase();
  }

  Future<void> _saveToFirebase() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final statesMap = <String, int>{};
    _tagStates.forEach((key, value) {
      statesMap[key] = value.index;
    });

    // Convert date filters to Firestore format
    final dateFiltersMap = <String, Map<String, dynamic>>{};
    _dateFilters.forEach((dateStr, filters) {
      dateFiltersMap[dateStr] = {
        'includedWords': filters['includedWords'] ?? [],
        'excludedWords': filters['excludedWords'] ?? [],
      };
    });

    await _firestore.collection('users').doc(user.uid).update({
      'tagStates': statesMap,
      'includedLs': _includedLs,
      'excludeLs': _excludeLs,
      'customTags': _customTags,
      'dateFilters': dateFiltersMap,
    });
  }
}

enum TagState { green, gray, red, purple }

