import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/filters_provider.dart';
import '../../providers/credits_provider.dart';
import '../../services/automation_service.dart';
import '../../utils/keyword_mapper.dart';
import '../../widgets/filter_column.dart';
import '../../widgets/nested_filter_column.dart';
import '../../widgets/school_map_widget.dart';
import '../../widgets/profile_app_bar.dart';
import 'automation_bottom_sheet.dart';
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
  
  @override
  void dispose() {
    _propagationTimer?.cancel();
    super.dispose();
  }
  
  void _schedulePropagation(FiltersProvider filtersProvider, CreditsProvider creditsProvider) {
    // Cancel existing timer
    _propagationTimer?.cancel();
    
    // Schedule new propagation after a short delay (debounce)
    _propagationTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        filtersProvider.onGlobalFiltersChanged(
          creditsProvider.committedDates,
          isUnavailable: (dateStr) => creditsProvider.excludedDates.contains(dateStr),
          hasJob: (dateStr) => creditsProvider.scheduledJobDates.contains(dateStr),
        );
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer2<FiltersProvider, CreditsProvider>(
      builder: (context, filtersProvider, creditsProvider, _) {
        // Check if filters changed and schedule propagation
        final currentIncluded = filtersProvider.includedLs.toSet();
        final currentExcluded = filtersProvider.excludeLs.toSet();
        final lastIncludedSet = _lastIncluded.toSet();
        final lastExcludedSet = _lastExcluded.toSet();
        
        if (currentIncluded != lastIncludedSet || currentExcluded != lastExcludedSet) {
          _lastIncluded = filtersProvider.includedLs.toList();
          _lastExcluded = filtersProvider.excludeLs.toList();
          _schedulePropagation(filtersProvider, creditsProvider);
        }
        
        return _buildFiltersScreen(context, filtersProvider, creditsProvider);
      },
    );
  }
  
  Widget _buildFiltersScreen(BuildContext context, FiltersProvider filtersProvider, CreditsProvider creditsProvider) {

    return Scaffold(
      appBar: ProfileAppBar(
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select your job preferences',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // Filter Legend with Tooltips
            _buildFilterLegend(context),
            const SizedBox(height: 24),
            // Other filter categories first (subjects, specialties, duration)
            ...filtersProvider.filtersDict.entries.map((entry) {
              // Skip schools-by-city as it's now handled by the map widget
              if (entry.key == 'schools-by-city') {
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Consumer<CreditsProvider>(
            builder: (context, creditsProvider, _) {
              // Locked condition: subscription is not active
              final isLocked = !creditsProvider.hasActiveSubscription;
              
              return ElevatedButton.icon(
                onPressed: isLocked ? null : () => _applyFilters(context),
                icon: Icon(isLocked ? Icons.lock : Icons.check_circle),
                label: Text(isLocked ? 'Apply Filters (Locked)' : 'Apply Filters'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isLocked 
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: isLocked
                      ? Colors.grey[300]
                      : Theme.of(context).colorScheme.onPrimary,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  
  void _showPurchaseOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AutomationBottomSheet(),
    );
  }

  Future<void> _applyFilters(BuildContext context) async {
    final filtersProvider = Provider.of<FiltersProvider>(context, listen: false);
    final creditsProvider = Provider.of<CreditsProvider>(context, listen: false);
    final automationService = AutomationService();
    
    // Check if locked (subscription not active)
    final isLocked = !creditsProvider.hasActiveSubscription;
    
    // Collect included and excluded words from filters
    final includedWords = filtersProvider.includedLs.toList();
    final excludedWords = filtersProvider.excludeLs.toList();
    
    // Convert committed dates to date keywords (format: 2_5_2026)
    // Dates are stored as "2024-01-15", convert to "1_15_2024" (no leading zeros)
    final dateKeywords = creditsProvider.committedDates.map((dateStr) {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = parts[0];
        final month = int.parse(parts[1]); // Remove leading zero
        final day = int.parse(parts[2]); // Remove leading zero
        return '${month}_${day}_${year}';
      }
      return KeywordMapper.dateToKeyword(dateStr);
    }).toList();
    
    // If locked, only filter for committed dates (green days)
    // Otherwise, add all date keywords to included words
    if (isLocked) {
      // Only filter for committed dates - don't add other date keywords
      // This means filtering only works for days already selected (green days)
    } else {
      // Add date keywords to included words for full filtering
      includedWords.addAll(dateKeywords);
    }
    
    try {
      await automationService.startAutomation(
        includedWords: includedWords,
        excludedWords: excludedWords,
        committedDates: creditsProvider.committedDates,
        notifyEnabled: !isLocked, // Disable notifications when locked
      );
      
      // Propagate global filter changes to all notification days
      await filtersProvider.onGlobalFiltersChanged(
        creditsProvider.committedDates,
        isUnavailable: (dateStr) => creditsProvider.excludedDates.contains(dateStr),
        hasJob: (dateStr) => creditsProvider.scheduledJobDates.contains(dateStr),
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isLocked 
                ? 'Filters applied for committed dates only. Notifications disabled.'
                : 'Filters applied successfully!'),
            backgroundColor: isLocked ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying filters: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildFilterLegend(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'How Filters Work',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tap tags to cycle: Green (include) → Gray (ignore) → Red (exclude)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildLegendItemWithTooltip(
                context,
                'Green',
                Colors.green,
                'Include: Show jobs with ANY of these tags\nExample: "elementary" + "middle school" = jobs with either one',
                Icons.check_circle_outline,
              ),
              _buildLegendItemWithTooltip(
                context,
                'Red',
                Colors.red,
                'Exclude: Hide jobs with ANY of these tags\nExample: "kindergarten" = blocks all kindergarten jobs',
                Icons.cancel_outlined,
              ),
              _buildLegendItemWithTooltip(
                context,
                'Gray',
                Colors.grey,
                'Ignore: These tags don\'t affect filtering\nExample: Unselected tags are ignored',
                Icons.radio_button_unchecked,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItemWithTooltip(
    BuildContext context,
    String label,
    Color color,
    String tooltipText,
    IconData icon,
  ) {
    return Tooltip(
      message: tooltipText,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: () {
          // Show tooltip on tap as well
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tooltipText),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(
                icon,
                size: 14,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.help_outline,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}



