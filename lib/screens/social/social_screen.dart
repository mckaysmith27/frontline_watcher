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

class _TopicItem {
  const _TopicItem({
    required this.label,
    required this.tag,
    this.emoji,
  });

  final String label;
  final String tag;
  final String? emoji;
}

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
    final topics = <_TopicItem>[
      const _TopicItem(label: 'Question', tag: 'question', emoji: '🤔'),
      const _TopicItem(label: 'Summer Job Opportunities', tag: 'summer-job-opportunities', emoji: '☀️'),
      const _TopicItem(label: 'Funny', tag: 'funny', emoji: '😂'),
      const _TopicItem(label: 'Heart-warming', tag: 'heart-warming', emoji: '😄'),
      const _TopicItem(label: 'Sad', tag: 'sad', emoji: '😢'),
    ];

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
                // Topics row — match the PostComposer “Topics” look.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        'Topics',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: 10),
                      ...topics.map((t) {
                        final label = t.emoji == null ? t.label : '${t.emoji} ${t.label}';
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: false,
                            onSelected: (_) {
                              _openComposerWithTag(context, t.tag);
                            },
                          ),
                        );
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

  void _openComposerWithTag(BuildContext context, String tag) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PostComposer(initialTag: tag),
    );
  }
}



