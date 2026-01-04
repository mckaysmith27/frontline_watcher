import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/credits_provider.dart';
import '../../services/social_service.dart';
import '../../models/post.dart';
import 'post_composer.dart';
import 'my_posts_tab.dart';
import 'feed_tab.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final creditsProvider = Provider.of<CreditsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Social'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Posts'),
            Tab(text: 'Feed'),
            Tab(text: 'Contests'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Post Composer
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  child: Text(
                    authProvider.user?.email?[0].toUpperCase() ?? 'U',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const PostComposer(),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('What\'s on your mind?'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                MyPostsTab(),
                FeedTab(),
                Center(child: Text('Contests coming soon!')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



