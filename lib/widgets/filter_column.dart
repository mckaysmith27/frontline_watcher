import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/filters_provider.dart';
import 'tag_chip.dart';

class FilterColumn extends StatefulWidget {
  final String category;
  final List<String> tags;
  final bool isPremium;
  final bool isUnlocked;
  final String? dateStr; // If provided, filters are date-specific

  const FilterColumn({
    super.key,
    required this.category,
    required this.tags,
    this.isPremium = false,
    this.isUnlocked = false,
    this.dateStr,
  });

  @override
  State<FilterColumn> createState() => _FilterColumnState();
}

class _FilterColumnState extends State<FilterColumn> {
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
    final key = 'filter_column_expanded_${widget.category}';
    // Default: subjects collapsed, others open
    final defaultExpanded = widget.category != 'subjects';
    setState(() {
      _isExpanded = prefs.getBool(key) ?? defaultExpanded;
    });
  }

  Future<void> _saveExpansionState(bool expanded) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'filter_column_expanded_${widget.category}';
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

  List<String> _getFilteredTags() {
    if (_searchQuery.isEmpty) {
      return widget.tags;
    }
    return widget.tags
        .where((tag) => tag.toLowerCase().contains(_searchQuery))
        .toList();
  }

  bool _isTagUnique(String tag) {
    final filtersProvider = Provider.of<FiltersProvider>(context, listen: false);
    for (var category in filtersProvider.filtersDict.keys) {
      if (category != widget.category) {
        if (filtersProvider.filtersDict[category]?.contains(tag.toLowerCase()) ?? false) {
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _handleAddCustomTag() async {
    if (_searchQuery.isEmpty) return;
    
    final tag = _searchQuery.trim();
    if (widget.tags.contains(tag)) return;
    
    if (!_isTagUnique(tag)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This keyword already exists in another category'),
          ),
        );
      }
      return;
    }

    final filtersProvider = Provider.of<FiltersProvider>(context, listen: false);
    await filtersProvider.addCustomTag(widget.category, tag);
    if (mounted) {
      _searchController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtersProvider = Provider.of<FiltersProvider>(context);
    final filteredTags = _getFilteredTags();
    final isCustomTag = _searchQuery.isNotEmpty &&
        !widget.tags.contains(_searchQuery) &&
        _isTagUnique(_searchQuery);

    return Container(
      decoration: BoxDecoration(
        color: widget.isPremium && !widget.isUnlocked
            ? Theme.of(context).colorScheme.surface.withOpacity(0.5)
            : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isPremium && !widget.isUnlocked
              ? Colors.grey
              : Colors.transparent,
        ),
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
          color: widget.isPremium && !widget.isUnlocked ? Colors.grey : null,
        ),
        title: Row(
          children: [
            if (widget.isPremium && !widget.isUnlocked)
              const Icon(Icons.lock, size: 20, color: Colors.grey),
            if (widget.isPremium && !widget.isUnlocked)
              const SizedBox(width: 8),
            Text(
              _getTitle(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: widget.isPremium && !widget.isUnlocked
                        ? Colors.grey
                        : null,
                  ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  enabled: widget.isUnlocked || !widget.isPremium,
                  decoration: InputDecoration(
                    hintText: 'Search or add keyword...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          ),
                        if (isCustomTag)
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _handleAddCustomTag,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: filteredTags.map((tag) {
                    final isCustom = filtersProvider.customTags[widget.category]?.contains(tag) ?? false;
                    // Use date-specific state if dateStr is provided
                    final state = widget.dateStr != null
                        ? filtersProvider.getTagStateForDate(tag, widget.dateStr)
                        : (filtersProvider.tagStates[tag] ?? TagState.gray);
                    
                    return TagChip(
                      tag: tag,
                      state: state,
                      isPremium: widget.isPremium,
                      isUnlocked: widget.isUnlocked,
                      isCustom: isCustom,
                      onTap: () async {
                        if (widget.isPremium && !widget.isUnlocked) return;
                        if (widget.dateStr != null) {
                          await filtersProvider.toggleTagForDate(widget.category, tag, widget.dateStr!);
                        } else {
                          await filtersProvider.toggleTag(widget.category, tag);
                        }
                      },
                      onDelete: isCustom
                          ? () {
                              filtersProvider.removeCustomTag(widget.category, tag);
                            }
                          : null,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

