import 'package:flutter/material.dart';

/// Tap-to-toggle tooltip that stays open until the user taps again
/// (anywhere, including the trigger).
///
/// This replaces Flutter's built-in [Tooltip] behavior which auto-dismisses
/// after a short duration.
class AppTooltip extends StatefulWidget {
  const AppTooltip({
    super.key,
    required this.child,
    this.message,
    this.richMessage,
    this.maxWidth = 340,
    this.offset = const Offset(0, 8),
    this.useInkWell = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  }) : assert(message != null || richMessage != null, 'Provide message or richMessage');

  final Widget child;
  final String? message;
  final InlineSpan? richMessage;
  final double maxWidth;
  final Offset offset;
  final bool useInkWell;
  final BorderRadius borderRadius;

  @override
  State<AppTooltip> createState() => _AppTooltipState();
}

class _AppTooltipState extends State<AppTooltip> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  void _toggle() {
    if (_entry != null) {
      _remove();
    } else {
      _show();
    }
  }

  void _remove() {
    _entry?.remove();
    _entry = null;
  }

  void _show() {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    _entry = OverlayEntry(
      builder: (overlayContext) {
        final theme = Theme.of(overlayContext);
        final tt = theme.tooltipTheme;
        final baseTextStyle =
            tt.textStyle ?? theme.textTheme.bodySmall?.copyWith(color: Colors.white) ?? const TextStyle(color: Colors.white);
        final bgColor =
            (tt.decoration is BoxDecoration) ? ((tt.decoration as BoxDecoration).color ?? const Color(0xFF303030)) : const Color(0xFF303030);

        final bubble = Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: widget.borderRadius,
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 18,
                    offset: Offset(0, 10),
                    color: Color(0x33000000),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: DefaultTextStyle(
                  style: baseTextStyle,
                  child: widget.richMessage != null
                      ? RichText(text: widget.richMessage!)
                      : Text(widget.message ?? ''),
                ),
              ),
            ),
          ),
        );

        return Stack(
          children: [
            // Tap anywhere to dismiss (including tapping the trigger again).
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _remove,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: widget.offset,
              child: bubble,
            ),
          ],
        );
      },
    );

    overlay.insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    final targetChild = widget.useInkWell
        ? InkWell(onTap: _toggle, child: widget.child)
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: widget.child,
          );

    return CompositedTransformTarget(
      link: _link,
      child: targetChild,
    );
  }
}

