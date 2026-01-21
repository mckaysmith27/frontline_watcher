import 'package:flutter/material.dart';

enum MarketingPointKey {
  fastAlerts,
  priorityBooking,
  keywordFiltering,
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
          text: "Cut through the noise with ‘KEYWORD FILTERING’.",
          termTooltips: {
            'KEYWORD FILTERING':
                'Keyword Filtering: only get alerts for the job details you care about (subject, school, teacher, etc.).',
          },
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
          text: 'Connect with fellow subs, teachers, and administration.',
          termTooltips: {},
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
          text: 'Get paid for a full days time with EARLY OUT hours, available weekly.*',
          termTooltips: {
            'EARLY OUT':
                'Some districts have early-out days at select schools and/or at select grade levels. Some jobs listed also offer a time durations (anything over four hours) that end up being rounded up to have the same payout of a full workday while there may not as many hours as a full workday being required in the duration specified. This perk seeks to guarantee a selection for at least one job a week where-in the users other settings and availability would allow for it. If a users settings explicitly may interfere with this perk being applied, the user will be notified and be asked if they system can adjust their settings in the following ways in order to successfully apply this perk for the week—or before seven to eight days time from the time in which the original purchase was made.',
          },
        );
      case MarketingPointKey.vipPreferredSubShortcut:
        return const MarketingPointData(
          icon: Icons.workspace_premium,
          text: "Apply 'PREFFERRED SUB SHORTCUT'.",
          termTooltips: {
            'PREFFERRED SUB SHORTCUT':
                "For each 'VIP Perks Power-up' purchase made, a teacher/administrater with the sub67 app within your school district at the schools you have selected to get alerts for in your maps widget on the filter page will recieve an alert showing your sub profile link* with your contact information and bio, and prompting the teacher/administrator with a request to be added to their prefferred sub list**.",
          },
        );
    }
  }
}

class MarketingPointRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final d = MarketingPoints.data(point);
    final baseStyle = textStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: dense ? 13 : 14,
              height: 1.25,
            ) ??
        TextStyle(fontSize: dense ? 13 : 14, height: 1.25);

    final linkStyle = baseStyle.copyWith(
      decoration: TextDecoration.underline,
      decorationThickness: 1.5,
      fontWeight: FontWeight.w700,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 6 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(d.icon, size: dense ? 18 : 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(children: _linkify(d.text, d.termTooltips, baseStyle, linkStyle)),
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _linkify(
    String text,
    Map<String, String> tooltips,
    TextStyle baseStyle,
    TextStyle linkStyle,
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
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Tooltip(
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 4),
            message: msg.isEmpty ? bestTerm : msg,
            child: Text(bestTerm, style: linkStyle),
          ),
        ),
      );

      i = bestIdx + bestTerm.length;
    }

    return spans;
  }
}

