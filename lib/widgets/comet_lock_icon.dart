import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Lock icon that shows a circling comet when unlocked.
class CometLockIcon extends StatelessWidget {
  const CometLockIcon({
    super.key,
    required this.unlocked,
    this.size = 26,
    this.lockedColor = Colors.orange,
    this.unlockedColor = Colors.deepPurple,
    this.cometColor = const Color(0xFF7C4DFF),
  });

  final bool unlocked;
  final double size;
  final Color lockedColor;
  final Color unlockedColor;
  final Color cometColor;

  @override
  Widget build(BuildContext context) {
    final iconColor = unlocked ? unlockedColor : lockedColor;
    final iconData = unlocked ? Icons.lock_open : Icons.lock;
    final cometSize = size * 0.78;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(iconData, color: iconColor, size: size),
        if (unlocked)
          Positioned(
            right: -cometSize * 0.10,
            top: -cometSize * 0.65,
            child: Transform.rotate(
              angle: 0.12, // slight tilt right
              child: SvgPicture.asset(
                'assets/icons/comet.svg',
                width: cometSize,
                height: cometSize,
                colorFilter: ColorFilter.mode(cometColor, BlendMode.srcIn),
              ),
            ),
          ),
      ],
    );
  }
}

