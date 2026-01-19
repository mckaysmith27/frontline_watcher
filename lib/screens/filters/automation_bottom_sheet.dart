import 'package:flutter/material.dart';
import '../../widgets/premium_unlock_bottom_sheet.dart';

class AutomationBottomSheet extends StatefulWidget {
  const AutomationBottomSheet({super.key});

  @override
  State<AutomationBottomSheet> createState() => _AutomationBottomSheetState();
}

class _AutomationBottomSheetState extends State<AutomationBottomSheet> {
  @override
  Widget build(BuildContext context) {
    // Backwards-compatible wrapper: we now use a single premium checkout bottom sheet
    // across the entire app for any locked subscription feature.
    return const PremiumUnlockBottomSheet();
  }
}