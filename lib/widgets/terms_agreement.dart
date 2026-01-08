import 'package:flutter/material.dart';

class TermsAgreement extends StatefulWidget {
  final Function(bool) onAgreed;

  const TermsAgreement({super.key, required this.onAgreed});

  @override
  State<TermsAgreement> createState() => _TermsAgreementState();
}

class _TermsAgreementState extends State<TermsAgreement> {
  bool _agreed = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                      'Terms of Service',
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
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const SingleChildScrollView(
              child: Text(
                _termsText,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}

const String _termsText = '''
TERMS OF SERVICE AGREEMENT

1. SERVICE DESCRIPTION
Sub67 is an independent service that provides automation tools for substitute teachers using the Frontline Education (ESS) platform. Sub67 is not affiliated with, endorsed by, or associated with Frontline Education or ESS.

2. CREDENTIALS AND SECURITY
- Your ESS login credentials are stored securely using industry-standard encryption
- Credentials are used solely to interact with the ESS platform on your behalf
- We do not share, sell, or misuse your credentials
- You are responsible for maintaining the confidentiality of your credentials

3. AUTOMATION SERVICES
- Sub67 will automatically monitor job postings based on your selected filters
- Jobs matching your criteria will be automatically accepted
- Credits are only consumed when a job is successfully booked
- You can cancel automation at any time

4. PAYMENT AND REFUNDS
- All purchases are final
- Credits are non-refundable but do not expire
- Promotional codes are subject to terms and conditions

5. LIMITATIONS OF LIABILITY
- Sub67 is provided "as is" without warranties
- We are not responsible for missed jobs, booking errors, or platform changes
- Use of this service is at your own risk

6. USER RESPONSIBILITIES
- You must have a valid ESS account
- You are responsible for all actions taken using your credentials
- You must comply with ESS terms of service

7. MODIFICATIONS
We reserve the right to modify these terms at any time. Continued use constitutes acceptance.

By using Sub67, you acknowledge that you have read, understood, and agree to these terms.
''';




