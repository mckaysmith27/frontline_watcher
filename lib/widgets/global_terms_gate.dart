import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// One-and-done global Terms & Conditions gate.
///
/// Shown once after login, before entering the app. Acceptance is stored in Firestore:
/// `users/{uid}.globalTermsAccepted = true`
class GlobalTermsGate extends StatefulWidget {
  final Widget child;

  const GlobalTermsGate({super.key, required this.child});

  @override
  State<GlobalTermsGate> createState() => _GlobalTermsGateState();
}

class _GlobalTermsGateState extends State<GlobalTermsGate> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _loading = true;
  bool _accepted = false;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _accepted = false;
      });
      return;
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    final accepted = data?['globalTermsAccepted'] == true;

    if (mounted) {
      setState(() {
        _accepted = accepted;
        _loading = false;
      });
    }
  }

  Future<void> _accept() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set(
      {
        'globalTermsAccepted': true,
        'globalTermsAcceptedAt': FieldValue.serverTimestamp(),
        // Ensure the app can receive district notifications (current MVP uses a single district)
        'districtIds': FieldValue.arrayUnion(['alpine_school_district']),
      },
      SetOptions(merge: true),
    );

    if (mounted) {
      setState(() {
        _accepted = true;
      });
    }
  }

  Future<void> _ensureDialogShown() async {
    if (_dialogShown || _accepted) return;
    _dialogShown = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _GlobalTermsDialog(
        onAccept: () async {
          await _accept();
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_accepted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureDialogShown();
      });
    }

    // Render the app behind the dialog so the transition is clean.
    return widget.child;
  }
}

class _GlobalTermsDialog extends StatefulWidget {
  final Future<void> Function() onAccept;

  const _GlobalTermsDialog({required this.onAccept});

  @override
  State<_GlobalTermsDialog> createState() => _GlobalTermsDialogState();
}

class _GlobalTermsDialogState extends State<_GlobalTermsDialog> {
  bool _checked = false;
  bool _expanded = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Terms & Conditions'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick heads-up: Sub67 helps you track job postings and manage your preferences. '
                'Please review and accept the terms to continue.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _checked,
                    onChanged: (v) => setState(() => _checked = v ?? false),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Row(
                        children: [
                          Text(
                            'I agree to the Terms & Conditions',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_expanded)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    _termsText,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: null, // one-and-done gate; no cancel
          child: const Text(''),
        ),
        ElevatedButton(
          onPressed: (!_checked || _saving)
              ? null
              : () async {
                  setState(() => _saving = true);
                  try {
                    await widget.onAccept();
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Accept'),
        ),
      ],
    );
  }
}

const String _termsText = '''
SUB67 — TERMS & CONDITIONS (SUMMARY)

1) What Sub67 does
Sub67 helps you monitor substitute job postings, set preferences, receive notifications, and other features. Sub67 and its affiliates are not affiliated with or endorsed by Frontline Education or ESS.

2) Notifications & “FAST” features
When enabled, Sub67 can send notifications when new jobs are posted. Some “FAST” features may be subscription-only. If you don’t have an active subscription, you may still receive notifications, but some features such as advanced filtering may be limited.

3) Filters (keywords)
You can choose keyword preferences. Keyword filtering only applies when you enable it in the Notifications settings (and when subscription requirements are met).

4) Credentials (Frontline / third‑party)
If you enter a third‑party username/password (e.g., Frontline), those credentials are stored locally on your device (device keychain / secure storage) and used to log you in, you retrieve the district name(s) and the schools listed within the district(s) that are available for you to teach at, and may also be used to retrieve job postings information. Sub67 does NOT store the third-party username and password credentials in our database.

5) Performance techniques
To reduce delays, we may reuse session cookies and warm-load sessions so you don’t have to sign in from scratch every time. This can improve speed and reliability.

6) Payments
If you make a purchase, you agree to the pricing displayed at checkout. Subscription access is time-based (days). Purchases may be subject to platform rules (Apple/Google), adhering to any refund policy published by those platforms.

7) Limitations
Sub67 and its affiliates do not guarantee that you will receive every job notification or that you will be able to successfully book every job. It is actually likely that many or even most new jobs you will not be notified about or be able to successfully book. These limitations are due to many factors with some due to the limitations of not having global access to 3rd party systems beyond that of individual users. 3rd-party changes, connectivity, high demand, and/or low supply for job postings may also affect results.

By accepting, you confirm you’ve read and agree to these Terms & Conditions.
''';

