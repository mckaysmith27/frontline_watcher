import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/filters_provider.dart';
import 'tag_chip.dart';

class NestedFilterColumn extends StatefulWidget {
  final String category;
  final Map<String, dynamic> nestedData;
  final List<String> customTags;
  final String? dateStr; // If provided, filters are date-specific

  const NestedFilterColumn({
    super.key,
    required this.category,
    required this.nestedData,
    this.customTags = const [],
    this.dateStr,
  });

  @override
  State<NestedFilterColumn> createState() => _NestedFilterColumnState();
}

class _NestedFilterColumnState extends State<NestedFilterColumn> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _loadExpansionState();
  }

  Future<void> _loadExpansionState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'nested_filter_column_expanded_${widget.category}';
    // Default: all collapsed
    setState(() {
      _isExpanded = prefs.getBool(key) ?? false;
    });
  }

  Future<void> _saveExpansionState(bool expanded) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'nested_filter_column_expanded_${widget.category}';
    await prefs.setBool(key, expanded);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getTitle() {
    return widget.category
        .split('-')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  // Get filtered schools-by-city (school-types filtering now handled in map widget)
  Map<String, List<String>> _getFilteredSchoolsByCity() {
    final filtersProvider = Provider.of<FiltersProvider>(context, listen: true);
    
    // If this is the schools-by-city category, use filtered schools
    if (widget.category == 'schools-by-city') {
      return filtersProvider.getFilteredSchoolsByCity();
    }
    
    // Otherwise return original nested data
    return Map<String, List<String>>.from(
      widget.nestedData.map((key, value) => MapEntry(
        key,
        value is List ? List<String>.from(value) : <String>[],
      )),
    );
  }

  // Filter cities and schools based on search query
  Map<String, List<String>> _getFilteredData() {
    // Start with filtered schools
    final baseData = _getFilteredSchoolsByCity();
    
    if (_searchQuery.isEmpty) {
      return baseData;
    }

    final filtered = <String, List<String>>{};
    baseData.forEach((city, schools) {
      final cityLower = city.toLowerCase();
      final matchingSchools = schools
          .where((school) => 
              school.toLowerCase().contains(_searchQuery) ||
              cityLower.contains(_searchQuery))
          .toList();
      
      // Include city if search matches city name or any school in it
      if (cityLower.contains(_searchQuery) || matchingSchools.isNotEmpty) {
        filtered[city] = matchingSchools;
      }
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filtersProvider = Provider.of<FiltersProvider>(context);
    final filteredData = _getFilteredData();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
      child: ExpansionTile(
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
          _saveExpansionState(expanded);
        },
        trailing: Icon(
          _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_left,
        ),
        title: Text(
          _getTitle(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search cities or schools...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                // Display nested structure: City tags with indented schools
                ...filteredData.entries.map((entry) {
            final city = entry.key;
            final schools = entry.value;
            // Use date-specific state if dateStr is provided
            final cityState = widget.dateStr != null
                ? filtersProvider.getTagStateForDate(city, widget.dateStr)
                : (filtersProvider.tagStates[city] ?? TagState.gray);
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // City as a selectable tag (indented, smaller text)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8, left: 16),
                    child: TagChip(
                      tag: '$city Schools (select all)',
                      state: cityState,
                      isPremium: false,
                      isUnlocked: true,
                      isCustom: false,
                      onTap: () async {
                        // Toggling city will automatically update all schools in that city
                        if (widget.dateStr != null) {
                          await filtersProvider.toggleTagForDate(widget.category, city, widget.dateStr!);
                        } else {
                          await filtersProvider.toggleTag(widget.category, city);
                        }
                      },
                      onDelete: null,
                    ),
                ),
                // Schools as tags (indented more)
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: schools.map((school) {
                      final isCustom = widget.customTags.contains(school);
                      // Use date-specific state if dateStr is provided
                      final state = widget.dateStr != null
                          ? filtersProvider.getTagStateForDate(school, widget.dateStr)
                          : (filtersProvider.tagStates[school] ?? TagState.gray);
                      
                      return TagChip(
                        tag: school,
                        state: state,
                        isPremium: false,
                        isUnlocked: true,
                        isCustom: isCustom,
                        onTap: () async {
                          if (widget.dateStr != null) {
                            await filtersProvider.toggleTagForDate(widget.category, school, widget.dateStr!);
                          } else {
                            await filtersProvider.toggleTag(widget.category, school);
                          }
                        },
                        onDelete: isCustom
                            ? () {
                                filtersProvider.removeCustomTag(widget.category, school);
                              }
                            : null,
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

