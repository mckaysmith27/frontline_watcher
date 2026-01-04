import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/filters_provider.dart';
import '../../providers/credits_provider.dart';
import '../../widgets/filter_column.dart';
import 'automation_bottom_sheet.dart';

class FiltersScreen extends StatelessWidget {
  const FiltersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final filtersProvider = Provider.of<FiltersProvider>(context);
    final creditsProvider = Provider.of<CreditsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filters'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Row(
                children: [
                  const Icon(Icons.stars, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${creditsProvider.credits}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
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
            const SizedBox(height: 24),
            ...filtersProvider.filtersDict.entries.map((entry) {
              final isPremium = entry.key == 'premium-classes' ||
                  entry.key == 'premium-workdays';
              final isUnlocked = entry.key == 'premium-classes'
                  ? filtersProvider.premiumClassesUnlocked
                  : filtersProvider.premiumWorkdaysUnlocked;

              return Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: FilterColumn(
                  category: entry.key,
                  tags: [
                    ...entry.value,
                    ...(filtersProvider.customTags[entry.key] ?? []),
                  ],
                  isPremium: isPremium,
                  isUnlocked: isUnlocked,
                ),
              );
            }),
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
          child: ElevatedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const AutomationBottomSheet(),
              );
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Automate'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }
}



