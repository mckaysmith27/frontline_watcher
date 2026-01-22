import 'package:flutter/material.dart';
import 'dart:async';
import '../services/user_role_service.dart';
import 'app_tooltip.dart';

enum MarketingPointKey {
  fastAlerts,
  priorityBooking,
  keywordFiltering,
  schoolSelectionMap,
  calendarSync,
  bizCards,
  qrCodeLink,
  communityConnect,
  educatorSupport,
  vipEarlyOutHours,
  vipPreferredSubShortcut,
}

class MarketingPointData {
  const MarketingPointData({
    required this.icon,
    required this.text,
    required this.termTooltips,
  });

  final IconData icon;
  final String text;

  /// Map of UNDERLINED TERMS -> tooltip/definition.
  final Map<String, String> termTooltips;
}

class MarketingPoints {
  static MarketingPointData data(MarketingPointKey key) {
    switch (key) {
      case MarketingPointKey.fastAlerts:
        return const MarketingPointData(
          icon: Icons.bolt,
          text: "Get notified quickly when a new job is posted with 'FAST ALERTS' technology.",
          termTooltips: {
            'FAST ALERTS':
                'Fast Alerts: optimized scanning + delivery so you get notified as quickly as possible after a job is posted.',
          },
        );
      case MarketingPointKey.priorityBooking:
        return const MarketingPointData(
          icon: Icons.workspace_premium,
          text: "Be first to accept the job with proprietary 'PRIORITY BOOKING'.",
          termTooltips: {
            'PRIORITY BOOKING':
                'Priority Booking: features designed to reduce the time between seeing a job and successfully accepting it.',
          },
        );
      case MarketingPointKey.keywordFiltering:
        return const MarketingPointData(
          icon: Icons.filter_list,
          text: 'Cut through the noise with ‘KEYWORD FILTERING’.',
          termTooltips: {
            'KEYWORD FILTERING':
                'Keyword Filtering: only get alerts for the job details you care about (subject, school, teacher, etc.).',
          },
        );
      case MarketingPointKey.schoolSelectionMap:
        return const MarketingPointData(
          icon: Icons.map_outlined,
          text:
              'Select schools you want to teach at based on the apx. distance or time from where you live.',
          termTooltips: {},
        );
      case MarketingPointKey.calendarSync:
        return const MarketingPointData(
          icon: Icons.sync,
          text: 'Sync jobs to your mobile device/cloud calendar with CALENDAR SYNC.',
          termTooltips: {
            'CALENDAR SYNC':
                'Calendar Sync: CALENDAR SYNC is a feature that automatically syncs the jobs you have booked that were booked utilizing the Sub67 app layer to the specified calendar that you use on your electronic device(s). Changes made through cancellations made utilizing the Sub67 app layer will also be reflected. Other advanced features such as notifications to ensure punctuality (alerts through the app when to leave in order to make it to the job location on time—or ahead of time) may be achieved through the selected calendar or through the app as well.',
          },
        );
      case MarketingPointKey.bizCards:
        return const MarketingPointData(
          icon: Icons.badge,
          text: 'Get free* personalized business cards sent directly to you in the mail.',
          termTooltips: {
            'free*': 'Free*: included with an active subscription (details may vary).',
          },
        );
      case MarketingPointKey.qrCodeLink:
        return const MarketingPointData(
          icon: Icons.qr_code_2,
          text:
              "Simplify the process of becoming a 'preferred sub' with your own personalized QR-CODE/LINK",
          termTooltips: {
            'QR-CODE/LINK':
                'QR-CODE/LINK: a scannable code + shareable link that takes teachers/admin straight to your profile.',
          },
        );
      case MarketingPointKey.communityConnect:
        return const MarketingPointData(
          icon: Icons.people,
          text: 'Connect with fellow subs, teachers, and administration with TEACHERS CONNECT.',
          termTooltips: {
            'TEACHERS CONNECT':
                "Ask questions and get real answers! Post and upvote posts by other subs on the 'community' page. Checkout the socials of other <userRole>'s.",
          },
        );
      case MarketingPointKey.educatorSupport:
        return const MarketingPointData(
          icon: Icons.support_agent,
          text: 'Get quick answers to all of your questions from other educators and AI ANSWERS.',
          termTooltips: {
            'AI ANSWERS':
                'AI ANSWERS: quick help for questions, templates, and suggestions (not a replacement for district policy).',
          },
        );
      case MarketingPointKey.vipEarlyOutHours:
        return const MarketingPointData(
          icon: Icons.speed,
          text: 'Get paid for a full days time with EARLY OUT* hours.',
          termTooltips: {
            'EARLY OUT*':
                '\u200B*Some districts have early-out days at select schools and/or at select grade levels. Some jobs listed also offer a time durations (anything over four hours) that end up being rounded up to have the same payout of a full workday while there may not as many hours as a full workday being required in the duration specified. This perk seeks to guarantee a selection for at least one job a week where-in the users other settings and availability would allow for it. If a users settings explicitly may interfere with this perk being applied, the user will be notified and be asked if they system can adjust their settings in the following ways in order to successfully apply this perk for the week—or before seven to eight days time from the time in which the original purchase was made.',
          },
        );
      case MarketingPointKey.vipPreferredSubShortcut:
        return const MarketingPointData(
          icon: Icons.workspace_premium,
          text: "Apply 'PREFFERRED SUB SHORTCUT'.",
          termTooltips: {
            'PREFFERRED SUB SHORTCUT':
                "For each 'VIP Perks Power-up' purchase made, a teacher/administrater with the sub67 app within your school district at the schools you have selected to get alerts for in your maps widget on the filter page will recieve an alert showing your sub profile link* with your contact information and bio, and prompting the teacher/administrator with a request to be added to their prefferred sub list**.\n\n*An email will be sent out with your profile link to an email subscriber who as opted-in to recieve sub67 marketing and promotions materials for teachers/administration, if in the case that there aren't yet teachers/administrators who are sub67 users in the schools you have selected on your filters page. This email will include your link inviting the subscriber to add to add you as a preferred sub.\n\n**Preferred Sub list requests are optional and controlled by teachers/administration and district processes; Sub67 cannot guarantee you will be added.",
          },
        );
    }
  }
}

class MarketingPointRow extends StatefulWidget {
  const MarketingPointRow({
    super.key,
    required this.point,
    this.dense = false,
    this.iconColor,
    this.textStyle,
  });

  final MarketingPointKey point;
  final bool dense;
  final Color? iconColor;
  final TextStyle? textStyle;

  @override
  State<MarketingPointRow> createState() => _MarketingPointRowState();
}

class _MarketingPointRowState extends State<MarketingPointRow> {
  String? _userRoleLabel;
  static const String _bizCardsDisclaimer =
      "*limited time offer, amounts of cards allowed for free may change and also depend on the users current subscription or non-subscription. See the biz cards page and it's checkout page for more details.";

  @override
  void initState() {
    super.initState();
    unawaited(_loadUserRoleLabel());
  }

  Future<void> _loadUserRoleLabel() async {
    try {
      final roles = await UserRoleService().getCurrentUserRoles();
      String label = 'user';
      if (roles.contains('sub')) label = 'sub';
      if (roles.contains('teacher')) label = 'teacher';
      if (roles.contains('administration')) label = 'administrator';
      if (!mounted) return;
      setState(() => _userRoleLabel = label);
    } catch (_) {
      // ignore; fallback is generic
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = MarketingPoints.data(widget.point);
    final baseStyle = widget.textStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: widget.dense ? 13 : 14,
              height: 1.25,
            ) ??
        TextStyle(fontSize: widget.dense ? 13 : 14, height: 1.25);

    final linkStyle = baseStyle.copyWith(
      decoration: TextDecoration.underline,
      decorationThickness: 1.5,
      fontWeight: FontWeight.w700,
    );

    final tooltipThemeStyle = Theme.of(context).tooltipTheme.textStyle ?? Theme.of(context).textTheme.bodySmall;
    final tooltipBaseStyle = (tooltipThemeStyle ?? const TextStyle(fontSize: 12)).copyWith(height: 1.3);
    final tooltipSmallStyle = tooltipBaseStyle.copyWith(
      fontSize: (tooltipBaseStyle.fontSize ?? 12) - 2,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.dense ? 6 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(d.icon, size: widget.dense ? 18 : 20, color: widget.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: widget.point == MarketingPointKey.bizCards
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: _linkify(
                            d.text,
                            d.termTooltips,
                            baseStyle,
                            linkStyle,
                            tooltipBaseStyle: tooltipBaseStyle,
                            tooltipSmallStyle: tooltipSmallStyle,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _bizCardsDisclaimer,
                        style: baseStyle.copyWith(
                          fontSize: (baseStyle.fontSize ?? (widget.dense ? 13 : 14)) - 2,
                          height: 1.2,
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  )
                : Text.rich(
                    TextSpan(
                      children: _linkify(
                        d.text,
                        d.termTooltips,
                        baseStyle,
                        linkStyle,
                        tooltipBaseStyle: tooltipBaseStyle,
                        tooltipSmallStyle: tooltipSmallStyle,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  InlineSpan _buildTooltipRichMessage(
    String msg, {
    required TextStyle tooltipBaseStyle,
    required TextStyle tooltipSmallStyle,
  }) {
    // Split into paragraphs on blank lines.
    final paras = msg.split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (paras.isEmpty) return TextSpan(text: msg, style: tooltipBaseStyle);

    final children = <InlineSpan>[];
    for (int idx = 0; idx < paras.length; idx++) {
      final p = paras[idx];
      if (idx > 0) children.add(TextSpan(text: '\n\n', style: tooltipBaseStyle));

      if (p.startsWith('**')) {
        children.add(TextSpan(text: '**', style: tooltipBaseStyle));
        children.add(TextSpan(text: p.substring(2), style: tooltipSmallStyle));
      } else if (p.startsWith('*')) {
        children.add(TextSpan(text: '*', style: tooltipBaseStyle));
        children.add(TextSpan(text: p.substring(1), style: tooltipSmallStyle));
      } else {
        children.add(TextSpan(text: p, style: tooltipBaseStyle));
      }
    }

    return TextSpan(style: tooltipBaseStyle, children: children);
  }

  List<InlineSpan> _linkify(
    String text,
    Map<String, String> tooltips,
    TextStyle baseStyle,
    TextStyle linkStyle,
    {required TextStyle tooltipBaseStyle, required TextStyle tooltipSmallStyle}
  ) {
    if (tooltips.isEmpty) return [TextSpan(text: text, style: baseStyle)];

    final terms = tooltips.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length)); // longest first

    final spans = <InlineSpan>[];
    int i = 0;
    while (i < text.length) {
      int bestIdx = -1;
      String? bestTerm;

      for (final t in terms) {
        final idx = text.indexOf(t, i);
        if (idx == -1) continue;
        if (bestIdx == -1 || idx < bestIdx) {
          bestIdx = idx;
          bestTerm = t;
        }
      }

      if (bestIdx == -1 || bestTerm == null) {
        spans.add(TextSpan(text: text.substring(i), style: baseStyle));
        break;
      }

      if (bestIdx > i) {
        spans.add(TextSpan(text: text.substring(i, bestIdx), style: baseStyle));
      }

      final msg = tooltips[bestTerm] ?? '';
      final roleLabel = _userRoleLabel ?? 'user';
      final tooltipTextRaw = (msg.isEmpty ? bestTerm : msg).replaceAll('<userRole>', roleLabel);
      final tooltipText = tooltipTextRaw;
      final useRich = tooltipText.contains('\n') || tooltipText.startsWith('*');
      final rich = useRich
          ? _buildTooltipRichMessage(
              tooltipText,
              tooltipBaseStyle: tooltipBaseStyle,
              tooltipSmallStyle: tooltipSmallStyle,
            )
          : null;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: AppTooltip(
            message: useRich ? null : tooltipText,
            richMessage: rich,
            child: Text(bestTerm, style: linkStyle),
          ),
        ),
      );

      i = bestIdx + bestTerm.length;
    }

    return spans;
  }
}

