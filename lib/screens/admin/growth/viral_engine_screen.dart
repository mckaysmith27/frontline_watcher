import 'package:flutter/material.dart';
import '../../../services/growth_kpi_service.dart';
import '_kpi_widgets.dart';

class ViralEngineScreen extends StatefulWidget {
  const ViralEngineScreen({super.key});

  @override
  State<ViralEngineScreen> createState() => _ViralEngineScreenState();
}

class _ViralEngineScreenState extends State<ViralEngineScreen> {
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
      final data = await _svc.getEngineKpis('viral');
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
  String _fmtNum(num? v) => v == null ? '—' : v.toStringAsFixed(2);
  String _fmtMins(num? v) => v == null ? '—' : '${v.toStringAsFixed(0)} min';

  @override
  Widget build(BuildContext context) {
    return EngineScaffold(
      title: 'Viral Engine',
      icon: Icons.share,
      loading: _loading,
      onRefresh: _load,
      child: _error != null
          ? Center(child: Text('Error: $_error'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                KpiCard(
                  title: 'Viral Coefficient (K-factor)',
                  value: _fmtNum(_data['kFactor'] as num?),
                  subtitle: 'Approx from business-card link usage',
                  icon: Icons.share,
                ),
                KpiCard(
                  title: 'Invite Acceptance Rate',
                  value: _fmtPct(_data['inviteAcceptanceRate'] as num?),
                  subtitle: 'booking_starts / link_visits (30d)',
                  icon: Icons.check_circle,
                ),
                KpiCard(
                  title: 'Viral Cycle Time',
                  value: _fmtMins(_data['viralCycleTimeMinutes'] as num?),
                  subtitle: 'Avg time from link visit → booking start (30d)',
                  icon: Icons.timelapse,
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

