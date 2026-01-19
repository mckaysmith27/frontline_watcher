import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class PromoCodesScreen extends StatefulWidget {
  const PromoCodesScreen({super.key});

  @override
  State<PromoCodesScreen> createState() => _PromoCodesScreenState();
}

class _PromoCodesScreenState extends State<PromoCodesScreen> with SingleTickerProviderStateMixin {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  late final TabController _tabController;

  // Search
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  String? _searchError;
  List<Map<String, dynamic>> _results = [];

  // Create single
  final TextEditingController _codeController = TextEditingController();
  String _tier = 'weekly';
  bool _isFree = true;
  bool _isCardStillRequired = true;
  DateTime _expiresAt = DateTime.now().add(const Duration(days: 30));
  int _maxRedemptions = 1;
  final TextEditingController _maxRedemptionsController = TextEditingController(text: '1');
  bool _creating = false;
  String? _createStatus;

  // Bulk
  final TextEditingController _prefixController = TextEditingController();
  final TextEditingController _suffixController = TextEditingController();
  int _bulkCount = 25;
  int _randomLen = 5;
  final TextEditingController _bulkCountController = TextEditingController(text: '25');
  final TextEditingController _randomLenController = TextEditingController(text: '5');
  bool _bulkIsFree = true;
  bool _bulkCardStillRequired = true;
  DateTime _bulkExpiresAt = DateTime.now().add(const Duration(days: 30));
  bool _bulkCreating = false;
  String? _bulkStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _codeController.dispose();
    _maxRedemptionsController.dispose();
    _prefixController.dispose();
    _suffixController.dispose();
    _bulkCountController.dispose();
    _randomLenController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final q = _searchController.text.trim();
    setState(() {
      _searching = true;
      _searchError = null;
      _results = [];
    });
    try {
      final callable = _functions.httpsCallable('searchPromoCodes');
      final res = await callable.call({'query': q});
      final data = res.data;
      if (data is Map && data['items'] is List) {
        setState(() {
          _results = List<Map<String, dynamic>>.from(
            (data['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        });
      }
    } catch (e) {
      setState(() => _searchError = e.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pickExpiry({required bool bulk}) async {
    final initial = bulk ? _bulkExpiresAt : _expiresAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    setState(() {
      if (bulk) {
        _bulkExpiresAt = picked;
      } else {
        _expiresAt = picked;
      }
    });
  }

  Future<void> _createSingle() async {
    setState(() {
      _creating = true;
      _createStatus = null;
    });
    try {
      final code = _codeController.text.trim();
      final callable = _functions.httpsCallable('createPromoCode');
      await callable.call({
        'code': code.isEmpty ? null : code,
        'tier': _tier,
        'discountType': _isFree ? 'free' : 'percent',
        'percentOff': _isFree ? 100 : 10,
        'isCardStillRequired': _isCardStillRequired,
        'expiresAt': Timestamp.fromDate(DateTime(_expiresAt.year, _expiresAt.month, _expiresAt.day, 23, 59, 59)),
        'maxRedemptions': _maxRedemptions,
      });
      setState(() => _createStatus = 'Promo created.');
    } catch (e) {
      setState(() => _createStatus = 'Create failed: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _createBulk() async {
    setState(() {
      _bulkCreating = true;
      _bulkStatus = null;
    });
    try {
      final callable = _functions.httpsCallable('createPromoCodesBulk');
      final res = await callable.call({
        'tier': _tier,
        'count': _bulkCount,
        'randomLength': _randomLen,
        'prefix': _prefixController.text,
        'suffix': _suffixController.text,
        'discountType': _bulkIsFree ? 'free' : 'percent',
        'percentOff': _bulkIsFree ? 100 : 10,
        'isCardStillRequired': _bulkCardStillRequired,
        'expiresAt': Timestamp.fromDate(DateTime(_bulkExpiresAt.year, _bulkExpiresAt.month, _bulkExpiresAt.day, 23, 59, 59)),
        'maxRedemptions': 1,
      });
      final data = res.data;
      int created = 0;
      if (data is Map) created = (data['created'] as num?)?.toInt() ?? 0;
      setState(() => _bulkStatus = 'Created $created promo codes.');
    } catch (e) {
      setState(() => _bulkStatus = 'Bulk create failed: $e');
    } finally {
      if (mounted) setState(() => _bulkCreating = false);
    }
  }

  List<DropdownMenuItem<String>> _tierItems() {
    const tiers = ['daily', 'weekly', 'bi-weekly', 'monthly', 'annually'];
    return tiers
        .map(
          (t) => DropdownMenuItem(
            value: t,
            child: Text(t),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promo Codes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Search'),
            Tab(text: 'Create'),
            Tab(text: 'Bulk'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearch(),
          _buildCreate(),
          _buildBulk(),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search by code prefix',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _runSearch(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _searching ? null : _runSearch,
                child: _searching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Search'),
              ),
            ],
          ),
          if (_searchError != null) ...[
            const SizedBox(height: 12),
            Text('Error: $_searchError', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('No results'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final p = _results[i];
                      final code = p['code'] ?? '';
                      final tier = p['tier'] ?? '';
                      final expiresAt = p['expiresAt'] ?? '';
                      final cardReq = p['isCardStillRequired'] == true;
                      final discountType = p['discountType'] ?? '';
                      final max = p['maxRedemptions'] ?? '';
                      final redeemed = p['redeemedCount'] ?? '';
                      return Card(
                        child: ListTile(
                          title: Text(code),
                          subtitle: Text('$tier • $discountType • expires: $expiresAt\nredemptions: $redeemed/$max • card required: $cardReq'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreate() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _codeController,
          decoration: const InputDecoration(
            labelText: 'Code (optional; leave blank to auto-generate)',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _tier,
          items: _tierItems(),
          onChanged: (v) => setState(() => _tier = v ?? _tier),
          decoration: const InputDecoration(labelText: 'Package / Tier', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Free purchase'),
          subtitle: const Text('If enabled, the initial charge is \$0'),
          value: _isFree,
          onChanged: (v) => setState(() => _isFree = v),
        ),
        SwitchListTile(
          title: const Text('isCardStillRequired'),
          subtitle: const Text('If enabled, user must still enter card for renewal even when free'),
          value: _isCardStillRequired,
          onChanged: (v) => setState(() => _isCardStillRequired = v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickExpiry(bulk: false),
                icon: const Icon(Icons.event),
                label: Text('Expires: ${_expiresAt.toLocal().toString().split(' ').first}'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max redemptions',
                  border: OutlineInputBorder(),
                ),
                controller: _maxRedemptionsController,
                onChanged: (v) => setState(() => _maxRedemptions = int.tryParse(v) ?? 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _creating ? null : _createSingle,
          icon: _creating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add),
          label: const Text('Create promo code'),
        ),
        if ((_createStatus ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(_createStatus!),
        ],
      ],
    );
  }

  Widget _buildBulk() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: _tier,
          items: _tierItems(),
          onChanged: (v) => setState(() => _tier = v ?? _tier),
          decoration: const InputDecoration(labelText: 'Package / Tier', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _prefixController,
          decoration: const InputDecoration(labelText: 'Prefix (optional)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _suffixController,
          decoration: const InputDecoration(labelText: 'Suffix (optional)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Count (max 500)', border: OutlineInputBorder()),
                onChanged: (v) => setState(() => _bulkCount = (int.tryParse(v) ?? 1).clamp(1, 500)),
                controller: _bulkCountController,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Random chars (min 5)', border: OutlineInputBorder()),
                onChanged: (v) => setState(() => _randomLen = (int.tryParse(v) ?? 5).clamp(5, 32)),
                controller: _randomLenController,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Free purchase'),
          value: _bulkIsFree,
          onChanged: (v) => setState(() => _bulkIsFree = v),
        ),
        SwitchListTile(
          title: const Text('isCardStillRequired'),
          value: _bulkCardStillRequired,
          onChanged: (v) => setState(() => _bulkCardStillRequired = v),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _pickExpiry(bulk: true),
          icon: const Icon(Icons.event),
          label: Text('Expires: ${_bulkExpiresAt.toLocal().toString().split(' ').first}'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _bulkCreating ? null : _createBulk,
          icon: _bulkCreating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: const Text('Generate promo codes'),
        ),
        if ((_bulkStatus ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(_bulkStatus!),
        ],
      ],
    );
  }
}

