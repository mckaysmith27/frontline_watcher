import 'package:flutter/material.dart';
import '../../../services/growth_kpi_service.dart';
import '_kpi_widgets.dart';

class StickyEngineScreen extends StatefulWidget {
  const StickyEngineScreen({super.key});

  @override
  State<StickyEngineScreen> createState() => _StickyEngineScreenState();
}

class _StickyEngineScreenState extends State<StickyEngineScreen> {
  final GrowthKpiService _svc = GrowthKpiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.getEngineKpis('sticky');
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtPct(num? v) => v == null ? '—' : '${(v * 100).toStringAsFixed(1)}%';
  String _fmtMoney(num? v) => v == null ? '—' : '\$${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return EngineScaffold(
      title: 'Sticky (Retention) Engine',
      icon: Icons.loop,
      loading: _loading,
      onRefresh: _load,
      child: _error != null
          ? Center(child: Text('Error: $_error'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                KpiCard(
                  title: 'Cohort Retention (Day 7)',
                  value: _fmtPct(_data['retentionDay7'] as num?),
                  subtitle: 'Based on users created 7 days ago',
                  icon: Icons.event_repeat,
                ),
                KpiCard(
                  title: 'Cohort Retention (Day 30)',
                  value: _fmtPct(_data['retentionDay30'] as num?),
                  subtitle: 'Based on users created 30 days ago',
                  icon: Icons.calendar_month,
                ),
                KpiCard(
                  title: 'Churn Rate (30d)',
                  value: _fmtPct(_data['churnRate30d'] as num?),
                  subtitle: 'Subscriptions ended in last 30d and not active now',
                  icon: Icons.trending_down,
                ),
                KpiCard(
                  title: 'Lifetime Value (LTV)',
                  value: _fmtMoney(_data['ltvUsd'] as num?),
                  subtitle: 'Average revenue per paying user (approx)',
                  icon: Icons.monetization_on,
                ),
                if ((_data['notes'] as String?)?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _data['notes'] as String,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                    ),
                  ),
              ],
            ),
    );
  }
}

