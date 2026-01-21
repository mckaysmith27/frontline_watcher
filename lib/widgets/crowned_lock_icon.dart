import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a lock/lock_open icon, and when unlocked overlays a small crown
/// slightly above the lock (similar "floating crown" treatment used elsewhere).
class CrownedLockIcon extends StatelessWidget {
  const CrownedLockIcon({
    super.key,
    required this.unlocked,
    this.size = 26,
    this.lockedColor = Colors.orange,
    this.unlockedColor = Colors.green,
    this.crownColor = const Color(0xFFFFD54F),
  });

  final bool unlocked;
  final double size;
  final Color lockedColor;
  final Color unlockedColor;
  final Color crownColor;

  @override
  Widget build(BuildContext context) {
    final iconColor = unlocked ? unlockedColor : lockedColor;
    final iconData = unlocked ? Icons.lock_open : Icons.lock;

    final crownSize = size * 0.62;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(iconData, color: iconColor, size: size),
        if (unlocked)
          Positioned(
            // float crown above the top-right of the lock
            right: -crownSize * 0.10,
            top: -crownSize * 0.55,
            child: Transform.rotate(
              angle: 0.18, // slight tilt right
              child: SvgPicture.asset(
                'assets/icons/crown.svg',
                width: crownSize,
                height: crownSize,
                colorFilter: ColorFilter.mode(crownColor, BlendMode.srcIn),
              ),
            ),
          ),
      ],
    );
  }
}

