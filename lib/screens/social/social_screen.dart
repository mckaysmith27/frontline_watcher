import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'post_composer.dart';
import 'my_page_tab.dart';
import 'feed_tab.dart';
import 'top_posts_tab.dart';
import '../profile/profile_screen.dart';
import '../../widgets/app_bar_quick_toggles.dart';
import '../../widgets/profile_app_bar.dart';

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

    return Scaffold(
      appBar: ProfileAppBar(
        actions: [
          const AppBarQuickToggles(),
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
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const PostComposer(),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "What's on your mind?",
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.70),
                                      ),
                                ),
                              ),
                            ],
                          ),
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
                      _buildTagButton(context, '🤔', 'question', () {
                        _openComposerWithTag(context, 'question');
                      }),
                      const SizedBox(width: 8),
                      _buildTagButton(context, '☀️', 'summer-job-opportunities', () {
                        _openComposerWithTag(context, 'summer-job-opportunities');
                      }),
                      const SizedBox(width: 8),
                      _buildTagButton(context, '😂', 'funny', () {
                        _openComposerWithTag(context, 'funny');
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

  String _tagLabel(String tag) {
    if (tag == 'summer-job-opportunities') return 'Summer Job Opportunities';
    return tag.replaceAll('-', ' ');
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
              _tagLabel(tag),
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



