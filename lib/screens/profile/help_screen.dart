import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Contact Support'),
              subtitle: const Text('sub67reachout@gmail.com'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final uri = Uri.parse('mailto:sub67reachout@gmail.com');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ExpansionTile(
              title: const Text('How do I set up filters?'),
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Go to the Filters page and select keywords that match the jobs you want. Green means include, red means exclude, and gray means neutral.',
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: ExpansionTile(
              title: const Text('How do credits work?'),
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Credits are days in which you still fall under an active subscription with us.',
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: ExpansionTile(
              title: const Text('How do I cancel a job?'),
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Go to the Schedule page, find the job in your Scheduled Jobs list, and tap the cancel button.',
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: ExpansionTile(
              title: const Text('Are my credentials/passwords secure?'),
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Yes, your credentials/passwords are safe as they are stored locally on your device or with the services operating your device. Sub67 or any of it\'s affiliates do not store any usernames or passwords.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final uri = Uri.parse('mailto:sub67reachout@gmail.com');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
        icon: const Icon(Icons.email),
        label: const Text('Email Support'),
      ),
    );
  }
}




