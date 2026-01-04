import 'package:flutter/material.dart';
import '../providers/filters_provider.dart';

class TagChip extends StatelessWidget {
  final String tag;
  final TagState state;
  final bool isPremium;
  final bool isUnlocked;
  final bool isCustom;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TagChip({
    super.key,
    required this.tag,
    required this.state,
    this.isPremium = false,
    this.isUnlocked = false,
    this.isCustom = false,
    required this.onTap,
    this.onDelete,
  });

  Color _getColor(BuildContext context) {
    if (!isUnlocked && isPremium) {
      return Colors.grey;
    }

    switch (state) {
      case TagState.green:
        return Colors.green;
      case TagState.gray:
        return Colors.grey;
      case TagState.red:
        return Colors.red;
      case TagState.purple:
        return Colors.purple;
    }
  }

  Color _getTextColor(BuildContext context) {
    if (!isUnlocked && isPremium) {
      return Colors.grey.shade600;
    }

    switch (state) {
      case TagState.green:
      case TagState.purple:
        return Colors.white;
      case TagState.gray:
      case TagState.red:
        return Colors.black87;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    final textColor = _getTextColor(context);

    return GestureDetector(
      onTap: isUnlocked || !isPremium ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tag,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isCustom && onDelete != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}



