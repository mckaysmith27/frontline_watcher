import 'package:flutter/material.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String strength;

  const PasswordStrengthIndicator({
    super.key,
    required this.strength,
  });

  Color _getColor() {
    switch (strength.toLowerCase()) {
      case 'weak':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'strong':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Password Strength: ',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          strength,
          style: TextStyle(
            color: _getColor(),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 100,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _getStrengthFactor(),
            child: Container(
              decoration: BoxDecoration(
                color: _getColor(),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _getStrengthFactor() {
    switch (strength.toLowerCase()) {
      case 'weak':
        return 0.33;
      case 'medium':
        return 0.66;
      case 'strong':
        return 1.0;
      default:
        return 0.0;
    }
  }
}


