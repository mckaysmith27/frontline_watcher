import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/filters_provider.dart';
import '../../providers/availability_provider.dart';
import '../../widgets/filter_column.dart';
import '../../widgets/nested_filter_column.dart';
import '../../widgets/school_map_widget.dart';
import '../../widgets/profile_app_bar.dart';
import '../../widgets/app_bar_quick_toggles.dart';
import '../../widgets/tag_chip.dart';
import '../profile/profile_screen.dart';

class FiltersScreen extends StatefulWidget {
  const FiltersScreen({super.key});

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  Timer? _propagationTimer;
  List<String> _lastIncluded = [];
  List<String> _lastExcluded = [];

  final TextEditingController _keywordSearchController = TextEditingController();
  String _keywordQuery = '';
  
  @override
  void dispose() {
    _propagationTimer?.cancel();
    _keywordSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _keywordSearchController.addListener(() {
      setState(() {
        _keywordQuery = _keywordSearchController.text.trim().toLowerCase();
      });
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer2<FiltersProvider, AvailabilityProvider>(
      builder: (context, filtersProvider, availabilityProvider, _) {
        // Check if filters changed and schedule propagation
        final currentIncluded = filtersProvider.includedLs.toSet();
        final currentExcluded = filtersProvider.excludeLs.toSet();
        final lastIncludedSet = _lastIncluded.toSet();
        final lastExcludedSet = _lastExcluded.toSet();
        
        if (currentIncluded != lastIncludedSet || currentExcluded != lastExcludedSet) {
          _lastIncluded = filtersProvider.includedLs.toList();
          _lastExcluded = filtersProvider.excludeLs.toList();
          _schedulePropagation(filtersProvider, availabilityProvider);
        }
        
        return _buildFiltersScreen(context, filtersProvider, availabilityProvider);
      },
    );
  }
  
  void _schedulePropagation(FiltersProvider filtersProvider, AvailabilityProvider availabilityProvider) {
    _propagationTimer?.cancel();
    _propagationTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final relevantDates = availabilityProvider.computeRelevantWorkdaysForKeywords();
      filtersProvider.onGlobalFiltersChanged(
        relevantDates,
        isUnavailable: (dateStr) => availabilityProvider.unavailableDates.contains(dateStr),
        hasJob: (dateStr) => availabilityProvider.scheduledJobDates.contains(dateStr),
      );
    });
  }
  
  Widget _buildFiltersScreen(BuildContext context, FiltersProvider filtersProvider, AvailabilityProvider availabilityProvider) {

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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Keywords drawer (Subjects + Specialties + Duration)
            _buildKeywordsDrawer(context, filtersProvider),
            const SizedBox(height: 24),
            // Other filter categories (excluding keyword categories and map-handled schools)
            ...filtersProvider.filtersDict.entries.map((entry) {
              // Skip schools-by-city as it's now handled by the map widget
              if (entry.key == 'schools-by-city' ||
                  entry.key == 'subjects' ||
                  entry.key == 'specialties' ||
                  entry.key == 'Duration') {
                return const SizedBox.shrink();
              }
              // Handle nested dictionaries
              if (entry.value is Map) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: NestedFilterColumn(
                    category: entry.key,
                    nestedData: entry.value as Map<String, dynamic>,
                    customTags: filtersProvider.customTags[entry.key] ?? [],
                  ),
                );
              } else {
                // Regular list of tags
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: FilterColumn(
                    category: entry.key,
                    tags: [
                      ...(entry.value as List<String>),
                      ...(filtersProvider.customTags[entry.key] ?? []),
                    ],
                    isPremium: false,
                    isUnlocked: true,
                  ),
                );
              }
            }),
            // School Map Widget last (after other filters)
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0, top: 24.0),
              child: const SchoolMapWidget(),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildKeywordsDrawer(BuildContext context, FiltersProvider filtersProvider) {
    final subjects = List<String>.from(filtersProvider.filtersDict['subjects'] as List? ?? const <String>[]);
    final specialtiesBase = List<String>.from(filtersProvider.filtersDict['specialties'] as List? ?? const <String>[]);
    final duration = List<String>.from(filtersProvider.filtersDict['Duration'] as List? ?? const <String>[]);
    final specialtiesCustom = List<String>.from(filtersProvider.customTags['specialties'] ?? const <String>[]);

    final allKeywords = <String>{
      ...subjects,
      ...specialtiesBase,
      ...specialtiesCustom,
      ...duration,
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final query = _keywordQuery;
    final matches = query.isEmpty
        ? allKeywords
        : allKeywords.where((t) => t.toLowerCase().contains(query)).toList();

    final isExisting = query.isNotEmpty && allKeywords.any((t) => t.toLowerCase() == query);
    final canAdd = query.isNotEmpty && !isExisting;

    bool isKeywordTag(String t) => allKeywords.contains(t);
    final excludedKeywords = filtersProvider.excludeLs.where((t) => isKeywordTag(t)).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    String categoryFor(String t) {
      final tl = t.toLowerCase();
      if (subjects.any((x) => x.toLowerCase() == tl)) return 'subjects';
      if (duration.any((x) => x.toLowerCase() == tl)) return 'Duration';
      // default: specialties (base or custom)
      return 'specialties';
    }

    Widget section(String title, List<String> tags) {
      final visible = query.isEmpty
          ? tags
          : tags.where((t) => t.toLowerCase().contains(query)).toList();
      if (visible.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visible.map((tag) {
              final state = filtersProvider.tagStates[tag] ?? TagState.gray;
              final isCustom = (filtersProvider.customTags['specialties']?.contains(tag) ?? false) && title == 'Specialties';
              return TagChip(
                tag: tag,
                state: state == TagState.green ? TagState.gray : state, // safety for legacy data
                isPremium: false,
                isUnlocked: true,
                isCustom: isCustom,
                onTap: () => filtersProvider.toggleTag(categoryFor(tag), tag),
                onDelete: isCustom ? () => filtersProvider.removeCustomTag('specialties', tag) : null,
              );
            }).toList(),
          ),
        ],
      );
    }

    return Card(
      child: ExpansionTile(
        title: Text(
          'Keywords',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _keywordSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search or add keyword...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_keywordQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _keywordSearchController.clear(),
                          ),
                        if (canAdd)
                          IconButton(
                            icon: const Icon(Icons.add),
                            tooltip: 'Add as a specialty keyword',
                            onPressed: () async {
                              final raw = _keywordQuery.trim();
                              if (raw.isEmpty) return;
                              await filtersProvider.addCustomTag('specialties', raw);
                              if (!mounted) return;
                              _keywordSearchController.clear();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                if (excludedKeywords.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: excludedKeywords.map((tag) {
                      return TagChip(
                        tag: tag,
                        state: TagState.red,
                        isPremium: false,
                        isUnlocked: true,
                        isCustom: false,
                        onTap: () => filtersProvider.toggleTag(categoryFor(tag), tag),
                        onDelete: null,
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 18),
                section('Subjects', subjects),
                const SizedBox(height: 18),
                section('Specialties', [...specialtiesBase, ...specialtiesCustom]),
                const SizedBox(height: 18),
                section('Duration', duration),
                if (matches.isEmpty && query.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'No matching keywords.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}



