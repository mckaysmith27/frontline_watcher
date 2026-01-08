import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/credits_provider.dart';
import '../../providers/filters_provider.dart';
import '../../widgets/terms_agreement.dart';
import 'payment_screen.dart';

class AutomationBottomSheet extends StatefulWidget {
  const AutomationBottomSheet({super.key});

  @override
  State<AutomationBottomSheet> createState() => _AutomationBottomSheetState();
}

class _AutomationBottomSheetState extends State<AutomationBottomSheet> {
  String? _selectedTier;
  bool _hasAgreedToTerms = false;
  bool _hasShownTerms = false;

  final Map<String, Map<String, dynamic>> _tiers = {
    'daily': {'days': 1, 'price': 1.99, 'credits': 1},
    'weekly': {'days': 5, 'price': 4.99, 'credits': 5},
    'bi-weekly': {'days': 10, 'price': 8.99, 'credits': 10},
    'monthly': {'days': 20, 'price': 15.99, 'credits': 20},
    'annually': {'days': 180, 'price': 89.99, 'credits': 180},
  };

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Select Automation Duration',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    ..._tiers.entries.map((entry) {
                      final isSelected = _selectedTier == entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTier = entry.key;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: entry.key,
                                  groupValue: _selectedTier,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedTier = value;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.key
                                            .split('-')
                                            .map((w) => w[0].toUpperCase() + w.substring(1))
                                            .join(' '),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${entry.value['days']} days • \$${entry.value['price']} • ${entry.value['credits']} credits',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    TermsAgreement(
                      onAgreed: (agreed) {
                        setState(() {
                          _hasAgreedToTerms = agreed;
                          if (!_hasShownTerms) {
                            _hasShownTerms = true;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _selectedTier != null &&
                              (_hasAgreedToTerms && _hasShownTerms)
                          ? () => _handleAutomate()
                          : null,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Automate'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleAutomate() async {
    if (_selectedTier == null) return;

    // Check if user has ESS credentials stored locally (device keychain)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final essCreds = await authProvider.getEssCredentials();

    if (essCreds['username'] == null || essCreds['password'] == null) {
      // Show ESS login dialog - credentials saved to device keychain only
      final result = await _showEssLoginDialog();
      if (result == null) return;
      
      // Save credentials to device keychain (FlutterSecureStorage)
      // These are NEVER sent to backend - used only for in-app job acceptance
      await authProvider.saveEssCredentials(
        username: result['username']!,
        password: result['password']!,
      );
    }

    // Navigate to payment screen
    // Note: No credentials are sent to backend - automation uses Cloud Run scrapers
    // User credentials stay on device for job acceptance only
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            tier: _selectedTier!,
            tierData: _tiers[_selectedTier]!,
          ),
        ),
      );
    }
  }

  Future<Map<String, String>?> _showEssLoginDialog() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => WillPopScope(
        onWillPop: () async {
          usernameController.dispose();
          passwordController.dispose();
          return true;
        },
        child: AlertDialog(
          title: const Text('ESS Login Information'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'ESS Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your ESS username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'ESS Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your ESS password';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                usernameController.dispose();
                passwordController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final result = {
                    'username': usernameController.text,
                    'password': passwordController.text,
                  };
                  usernameController.dispose();
                  passwordController.dispose();
                  Navigator.pop(context, result);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}


