import 'package:flutter/material.dart';

class AgreementsScreen extends StatelessWidget {
  const AgreementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agreements')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ExpansionTile(
              title: const Text('Terms of Service'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_termsText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ExpansionTile(
              title: const Text('Privacy Policy'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_privacyText),
                ),
              ],
            ),
          ),
        ],
      ),
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

const String _privacyText = '''
PRIVACY POLICY

1. INFORMATION WE COLLECT
- Email address and username
- ESS login credentials (encrypted)
- Job preferences and filters
- Usage data and analytics

2. HOW WE USE YOUR INFORMATION
- To provide automation services
- To improve our service
- To communicate with you

3. DATA SECURITY
- All sensitive data is encrypted
- Credentials are stored securely
- We follow industry best practices

4. DATA SHARING
- We do not sell your data
- We may share anonymized analytics
- We comply with legal requirements

5. YOUR RIGHTS
- Access your data
- Delete your account
- Export your data

For questions, contact: sub67reachout@gmail.com
''';




