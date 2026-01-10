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

