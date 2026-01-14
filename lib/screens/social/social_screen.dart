import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/credits_provider.dart';
import '../../services/social_service.dart';
import '../../models/post.dart';
import 'post_composer.dart';
import 'my_page_tab.dart';
import 'feed_tab.dart';
import 'top_posts_tab.dart';
import '../profile/profile_screen.dart';

class SocialScreen extends StatefulWidget {
  final VoidCallback? onNavigateToMyPage;
  
  const SocialScreen({
    super.key,
    this.onNavigateToMyPage,
  });

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
        leading: authProvider.user != null
            ? GestureDetector(
                onTap: () {
                  // Switch to My Page tab
                  if (_tabController.index != 0) {
                    _tabController.animateTo(0);
                  }
                  // Also trigger callback if provided
                  if (widget.onNavigateToMyPage != null) {
                    widget.onNavigateToMyPage!();
                  }
                },
                child: Container(
                  margin: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: authProvider.user!.photoURL != null
                        ? NetworkImage(authProvider.user!.photoURL!)
                        : null,
                    child: authProvider.user!.photoURL == null
                        ? Text(
                            authProvider.user!.email?[0].toUpperCase() ?? 'U',
                            style: const TextStyle(fontSize: 16),
                          )
                        : null,
                  ),
                ),
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Page'),
            Tab(text: 'Feed'),
            Tab(text: 'Top Posts'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Post Composer
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      child: Text(
                        authProvider.user?.email?[0].toUpperCase() ?? 'U',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const PostComposer(),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('What\'s on your mind?'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Emoji tag buttons in the same row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTagButton(context, '😊', 'happy', () {
                        _openComposerWithTag(context, 'happy');
                      }),
                      const SizedBox(width: 8),
                      _buildTagButton(context, '😂', 'funny', () {
                        _openComposerWithTag(context, 'funny');
                      }),
                      const SizedBox(width: 8),
                      _buildTagButton(context, '🤔', 'random-thought', () {
                        _openComposerWithTag(context, 'random-thought');
                      }),
                      const SizedBox(width: 8),
                      _buildTagButton(context, '😄', 'heart-warming', () {
                        _openComposerWithTag(context, 'heart-warming');
                      }),
                      const SizedBox(width: 8),
                      _buildTagButton(context, '😢', 'sad', () {
                        _openComposerWithTag(context, 'sad');
                      }),
                    ],
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
                MyPageTab(),
                FeedTab(),
                TopPostsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagButton(BuildContext context, String emoji, String tag, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 4),
            Text(
              tag.replaceAll('-', ' '),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openComposerWithTag(BuildContext context, String tag) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PostComposer(initialTag: tag),
    );
  }
}



