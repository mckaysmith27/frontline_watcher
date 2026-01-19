import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
  bool _backfilling = false;
  String? _backfillStatus;

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

  Future<void> _backfillHistogram() async {
    setState(() {
      _backfilling = true;
      _backfillStatus = 'Starting backfill…';
    });
    try {
      String? lastId;
      bool done = false;
      int totalProcessed = 0;
      int safety = 0;
      while (!done && safety < 50) {
        safety += 1;
        final callable = FirebaseFunctions.instance.httpsCallable('backfillJobStartTimeHistogram');
        final res = await callable.call({
          'scope': 'global',
          'pageSize': 1000,
          if (lastId != null) 'startAfterId': lastId,
        });
        final data = Map<String, dynamic>.from(res.data as Map);
        final processed = (data['processed'] as num?)?.toInt() ?? 0;
        lastId = data['lastId'] as String?;
        done = data['done'] == true;
        totalProcessed += processed;
        if (!mounted) return;
        setState(() {
          _backfillStatus = done
              ? 'Backfill complete. Processed $totalProcessed events.'
              : 'Processed $totalProcessed…';
        });
        if (processed == 0) break;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _backfillStatus = 'Backfill failed: $e');
    } finally {
      if (mounted) setState(() => _backfilling = false);
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin tools',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'If the time-window histogram says “No histogram data yet”, run a one-time backfill to aggregate existing job_events into 15-minute buckets.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _backfilling ? null : _backfillHistogram,
                            icon: _backfilling
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_fix_high),
                            label: const Text('Backfill job histogram'),
                          ),
                        ),
                        if ((_backfillStatus ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _backfillStatus!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
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

