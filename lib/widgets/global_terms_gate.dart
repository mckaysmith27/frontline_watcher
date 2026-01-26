import 'dart:async';
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

  Future<void> _persistAcceptance() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
            {
              'globalTermsAccepted': true,
              'globalTermsAcceptedAt': FieldValue.serverTimestamp(),
              // Ensure the app can receive district notifications (current MVP uses a single district)
              'districtIds': FieldValue.arrayUnion(['alpine_school_district']),
            },
            SetOptions(merge: true),
          )
          // Don't let acceptance UI hang on slow network/DNS issues.
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Intentionally swallow: user should be able to proceed instantly.
      // If this fails, they may be asked again next time if Firestore never persisted.
    }
  }

  Future<void> _acceptFast() async {
    // Make the UI instant: mark accepted locally first, then persist in background.
    if (mounted) {
      setState(() {
        _accepted = true;
      });
    }

    // Fire-and-forget persistence so the button doesn't spin forever.
    unawaited(_persistAcceptance());

    return;
  }

  Future<void> _ensureDialogShown() async {
    if (_dialogShown || _accepted) return;
    _dialogShown = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _GlobalTermsDialog(
        onAccept: () async {
          await _acceptFast();
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
                'Quick heads-up: Sub67 helps you track job postings and manage your preferences among other features. '
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
TERMS OF SERVICE — Sub67

Effective Date: [DATE]
Last Updated: [DATE]

App / Service Name: Sub67 (“Sub67,” “we,” “us,” “our”)
Contact: [SUPPORT_EMAIL]
Website (optional): [WEBSITE_URL]

These Terms of Service (“Terms”) govern your access to and use of Sub67’s mobile application, web application, and related services (collectively, the “Service”). By creating an account, accessing, or using the Service, you agree to these Terms.

If you do not agree, do not use the Service.

1) Eligibility

You must be at least 13 years old (or the minimum age required in your jurisdiction) to use the Service. If you use the Service on behalf of a school, district, or other organization, you represent that you have authority to bind that organization.

2) Account Registration & Security

You are responsible for:

maintaining the confidentiality of your login credentials,

all activity that occurs under your account,

providing accurate and current information.

You must notify us promptly if you suspect unauthorized access or use of your account.

3) What the Service Does (and Does Not Do)

Sub67 provides tools that may help users:

receive alerts or notifications about job opportunities,

filter, organize, and monitor opportunities across systems,

optionally purchase premium features or one-time enhancements,

optionally interact with community or social features.

Sub67 is not affiliated with, endorsed by, or sponsored by any school district, employer, or third-party platform.

The Service provides informational and organizational tools only. Sub67 does not submit applications, accept assignments, negotiate terms, or take actions on your behalf unless explicitly initiated by you within the Service.

We do not guarantee job availability, acceptance, assignment outcomes, pay rates, scheduling, district policies, or any preferred or priority status.

Sub67 may reference, surface, or process information originating from third-party platforms or public sources. We do not control and are not responsible for the accuracy, availability, completeness, legality, or policies of any third-party systems. Your use of such platforms remains subject to their own terms and policies, and you are responsible for complying with them.

4) User Content (Posts, Comments, Profile Information)

The Service may allow you to submit content such as posts, comments, profile information, or other materials (“User Content”).

You retain ownership of your User Content. By submitting User Content, you grant Sub67 a worldwide, non-exclusive, royalty-free license to host, store, reproduce, modify (for formatting or technical display), display, and distribute your User Content solely to operate, improve, and maintain the Service.

You agree not to post User Content that is unlawful, harmful, harassing, discriminatory, defamatory, infringing, sexually explicit, misleading, or that violates applicable laws, employer policies, or district rules.

We may remove or restrict access to User Content at any time.

5) Acceptable Use

You agree not to:

misuse the Service or attempt unauthorized access,

interfere with or disrupt the Service or its security features,

reverse engineer, copy, or bypass protections,

use the Service for fraudulent or unlawful activity,

scrape, harvest, or collect personal data from other users without permission,

impersonate any person or entity.

6) Notifications, Messaging, and Device Permissions

If you enable notifications, you authorize us to send push notifications and related messages. You can control notification permissions through your device settings and within the Service.

Some features may require permissions (such as location). You may deny or revoke permissions, though certain features may not function fully without them.

7) Paid Features, Subscriptions, and One-Time Purchases

Sub67 may offer paid features, including subscriptions (“Premium”) and one-time purchases.

Payments: Payments are processed by third-party payment processors (such as Stripe). We do not store full payment card numbers.

Pricing & Taxes: Prices are shown in-app and may change. Taxes may apply.

Promo Codes: Promotional offers may include restrictions, expiration dates, and eligibility limits and may be revoked for misuse.

No Guarantees: Paid features do not guarantee employment outcomes, acceptance, pay increases, or preferred status.

Auto-Renewal (if applicable): Subscriptions may renew automatically unless canceled in accordance with the applicable platform’s instructions.

Refunds: Unless required by law, purchases are final and non-refundable. Contact [SUPPORT_EMAIL] if you believe a charge was made in error.

8) Marketing, Profiles, and Outreach Features

Some features may include profiles, links, QR codes, or outreach tools. You acknowledge that:

inclusion, visibility, or response depends on third-party recipients and opt-ins,

any preferred or priority status is controlled by employers or districts, not Sub67.

9) Third-Party Services

The Service may integrate with third-party services (such as hosting, analytics, notifications, mapping, or payments). Your use of third-party services is subject to their own terms and policies. Sub67 is not responsible for third-party services.

10) Service Availability & Changes

We may modify, suspend, or discontinue any part of the Service at any time. We do not guarantee uninterrupted or error-free operation.

11) Termination

You may stop using the Service at any time. We may suspend or terminate access if you violate these Terms or if your use poses risk to the Service or others.

12) Disclaimers

THE SERVICE IS PROVIDED “AS IS” AND “AS AVAILABLE.” TO THE MAXIMUM EXTENT PERMITTED BY LAW, SUB67 DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.

13) Limitation of Liability

TO THE MAXIMUM EXTENT PERMITTED BY LAW, SUB67 WILL NOT BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS, DATA, USE, OR GOODWILL.

SUB67’S TOTAL LIABILITY FOR ANY CLAIM WILL NOT EXCEED THE AMOUNT YOU PAID SUB67 IN THE 12 MONTHS BEFORE THE EVENT GIVING RISE TO THE CLAIM.

14) Indemnification

You agree to indemnify and hold harmless Sub67 from claims, damages, liabilities, losses, and expenses (including reasonable attorneys’ fees) arising from your use of the Service, your User Content, or your violation of these Terms, applicable laws, or third-party platform terms.

15) Non-Circumvention & Competitive Use Restrictions

You agree not to use the Service, its outputs, insights, workflows, or access to develop, operate, or assist in the creation of a substantially similar product or service that competes with Sub67, including services that provide automated job monitoring, aggregation, alerts, or optimization layers on top of existing third-party systems, where such use would rely on or be derived from your access to the Service.

This restriction does not prevent general employment, independent development based on public knowledge, or unrelated products, but is intended to prevent misuse of the Service as a substitute for building or reverse-engineering a competing offering.

16) Governing Law

These Terms are governed by the laws of [STATE/COUNTRY], without regard to conflict of laws principles. Venue for disputes will be in [COUNTY/STATE], unless prohibited by law.

17) Changes to These Terms

We may update these Terms from time to time. If changes are material, we will provide notice through the Service or other reasonable means. Continued use after changes constitutes acceptance.

18) Apple App Store Notice

If you access the Service through Apple’s App Store, you acknowledge that Apple is not responsible for the Service or its content and has no obligation to provide maintenance or support services. Apple is not responsible for any claims arising from your use of the Service.

19) Contact

Questions about these Terms: [SUPPORT_EMAIL]


PRIVACY POLICY — Sub67

Effective Date: [DATE]
Last Updated: [DATE]

Service Name: Sub67
Contact: [PRIVACY_EMAIL]
Website (optional): [WEBSITE_URL]

This Privacy Policy explains how Sub67 (“we,” “us,” “our”) collects, uses, discloses, and protects information when you use the Service.

1) Information We Collect
A. Account & Profile Information

Email address and authentication identifiers

Profile details you provide (such as name fields, nickname, bio, links, or business card information)

B. Usage & Device Information

App interactions and feature usage

Device and technical data (device model, OS version, app version)

Crash logs and performance diagnostics (where enabled)

C. Notifications Data

Push notification tokens

Notification preferences and time windows you configure

D. Location Information (Optional)

If you enable location-based features, we may process approximate or precise location data based on your device permissions and derive distances relevant to features. You can disable location permissions at any time.

E. Payments Information

Payments are processed by third-party processors. We do not store full payment card numbers. We may store customer IDs, transaction references, and purchase history metadata.

F. User Content

If you use community or social features, we collect posts, comments, and related metadata.

2) How We Use Information

We use information to:

operate and maintain the Service,

deliver alerts, filters, and features you enable,

process payments and manage subscriptions,

send notifications and service communications,

enforce Terms, prevent fraud, and maintain security,

improve functionality and user experience,

comply with legal obligations.

3) How We Share Information

We may share information:

with service providers that help operate the Service,

with other users when you choose to share publicly,

for legal reasons or to protect rights and safety,

in connection with a business transaction.

We do not sell your personal information.

4) Data Retention

We retain information as long as necessary to provide the Service, comply with legal obligations, and resolve disputes. You may request deletion as described below.

5) Security

We use reasonable administrative, technical, and organizational safeguards to protect information. No system is completely secure.

6) Your Choices & Controls

You can update certain profile information in-app.

You can control notifications and permissions through your device and the Service.

You control which features you enable; some features may not function without required permissions.

7) Children’s Privacy

The Service is not intended for children under 13 (or the minimum age required in your jurisdiction). We do not knowingly collect personal information from children.

8) International Users

Your information may be processed in the United States and other countries where our service providers operate.

9) Third-Party Links and Content

The Service may include links or content from third parties. We are not responsible for third-party privacy practices.

10) Changes to This Privacy Policy

We may update this Privacy Policy from time to time. Material changes will be communicated through the Service or other reasonable means.

11) Contact & Privacy Requests

For questions or privacy requests (access, correction, deletion):

Email: [PRIVACY_EMAIL]
''';

