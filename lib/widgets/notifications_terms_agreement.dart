import 'package:flutter/material.dart';

class NotificationsTermsAgreement extends StatefulWidget {
  final Function(bool) onAgreed;
  final VoidCallback onAccept;

  const NotificationsTermsAgreement({
    super.key,
    required this.onAgreed,
    required this.onAccept,
  });

  @override
  State<NotificationsTermsAgreement> createState() => _NotificationsTermsAgreementState();
}

class _NotificationsTermsAgreementState extends State<NotificationsTermsAgreement> {
  bool _agreed = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _agreed,
                  onChanged: (value) {
                    setState(() {
                      _agreed = value ?? false;
                    });
                    widget.onAgreed(_agreed);
                  },
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _expanded = !_expanded;
                      });
                    },
                    child: Row(
                      children: [
                        Text(
                          'I agree to the ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          'Terms and Conditions',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_expanded)
              Container(
                margin: const EdgeInsets.only(left: 48, top: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _termsText,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _agreed ? widget.onAccept : null,
                child: const Text('Accept Terms and Conditions'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const String _termsText = '''
NOTIFICATIONS SERVICE TERMS AND CONDITIONS

Welcome! We're excited to help you stay on top of new job opportunities. This agreement explains how our notification service works and how we keep your information safe.

WHAT THIS SERVICE DOES

Our notification feature helps you get notified about new substitute teaching jobs that match your preferences. To do this effectively, the service needs to access the Frontline Education website on your behalf to check for new job postings.

YOUR LOGIN INFORMATION

To provide this service, we need your Frontline Education username and password. Here's what you need to know:

• Your credentials are stored securely on your device only - we never send them to our servers
• We use industry-standard encryption to protect your login information
• Your credentials are used solely to log into Frontline's website and check for new jobs
• We never share, sell, or misuse your login information

HOW IT WORKS TECHNICALLY

To make the service fast and efficient, we use some technical methods:

• Session Cookies: We save authentication cookies (like a temporary ID card) so we don't have to log in every single time. This makes checking for jobs much faster.

• Warm Load Techniques: We keep your login session "warm" by maintaining an active connection. This means when a new job appears, we can check it almost instantly instead of having to log in from scratch each time.

• Local Storage: All of this happens using storage on your device - nothing sensitive is stored on our servers.

These techniques help us minimize the time between when a job is posted and when you get notified, which is especially important for popular positions that fill up quickly.

YOUR PRIVACY AND SECURITY

We take your security seriously:
• Your credentials never leave your device in an unencrypted form
• We use the same security standards that banks use for protecting sensitive information
• You can disable notifications or delete your stored credentials at any time
• We don't track your personal activity or browsing habits

WHAT YOU'RE AGREEING TO

By using this service, you agree that:
• You have the right to use the Frontline Education account you're providing
• You understand that we'll use your credentials to check for jobs automatically
• You'll keep your login information secure and notify us if you suspect unauthorized access
• You understand this is an automated service that runs in the background

LIMITATIONS

While we work hard to provide a reliable service:
• We can't guarantee you'll get every job notification (though we try our best!)
• Technical issues or changes to Frontline's website may occasionally affect service
• You're responsible for maintaining the security of your device and account

CHANGES TO THIS AGREEMENT

We may update these terms occasionally. If we make significant changes, we'll notify you. Continued use of the service means you accept any updates.

QUESTIONS?

If you have questions about how we protect your information or how the service works, please reach out to us. We're here to help!

By checking the box and clicking "Accept Terms and Conditions," you acknowledge that you've read, understood, and agree to these terms.
''';
