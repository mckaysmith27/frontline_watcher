import 'package:flutter/material.dart';
import '../../../services/growth_kpi_service.dart';
import '_kpi_widgets.dart';

class PaidEngineScreen extends StatefulWidget {
  const PaidEngineScreen({super.key});

  @override
  State<PaidEngineScreen> createState() => _PaidEngineScreenState();
}

class _PaidEngineScreenState extends State<PaidEngineScreen> {
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
      final data = await _svc.getEngineKpis('paid');
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtMoney(num? v) => v == null ? '—' : '\$${v.toStringAsFixed(2)}';
  String _fmtNum(num? v) => v == null ? '—' : v.toStringAsFixed(2);
  String _fmtDays(num? v) => v == null ? '—' : '${v.toStringAsFixed(0)} days';

  @override
  Widget build(BuildContext context) {
    return EngineScaffold(
      title: 'Paid Engine',
      icon: Icons.attach_money,
      loading: _loading,
      onRefresh: _load,
      child: _error != null
          ? Center(child: Text('Error: $_error'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                KpiCard(
                  title: 'LTV / CAC Ratio',
                  value: _fmtNum(_data['ltvToCac'] as num?),
                  subtitle: 'Uses manual CAC inputs + computed LTV',
                  icon: Icons.balance,
                ),
                KpiCard(
                  title: 'Customer Acquisition Cost (CAC)',
                  value: _fmtMoney(_data['cacUsd'] as num?),
                  subtitle: 'From admin-entered spend/new customers (30d)',
                  icon: Icons.campaign,
                ),
                KpiCard(
                  title: 'CAC Payback Period',
                  value: _fmtDays(_data['cacPaybackDays'] as num?),
                  subtitle: 'Approx using ARPU (30d)',
                  icon: Icons.schedule,
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

