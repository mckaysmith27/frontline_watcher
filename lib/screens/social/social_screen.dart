import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/social_service.dart';
import '../../services/user_role_service.dart';
import 'post_composer.dart';
import 'my_page_tab.dart';
import 'feed_tab.dart';
import 'top_posts_tab.dart';
import '../admin/question_queue_screen.dart';
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
  final TextEditingController _appBarComposer = TextEditingController();
  String _feedQuery = '';
  String? _highlightPostId;
  String _appAdminLevel = 'none'; // none|limited|full

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      // Only show/search in Feed tab (index 1).
      if (_tabController.index != 1 && _feedQuery.isNotEmpty) {
        setState(() => _feedQuery = '');
        _appBarComposer.clear();
      } else {
        setState(() {});
      }
    });
    _loadAdminLevel();
  }

  Future<void> _loadAdminLevel() async {
    try {
      final level = await UserRoleService().getCurrentAppAdminLevel();
      if (!mounted) return;
      setState(() => _appAdminLevel = level);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appBarComposer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isFeedTab = _tabController.index == 1;
    final isAppAdmin = _appAdminLevel != 'none';
    final topics = <_TopicItem>[
      const _TopicItem(label: 'Question', tag: 'question', emoji: '🤔'),
      const _TopicItem(label: 'Summer Job Opportunities', tag: 'summer-job-opportunities', emoji: '☀️'),
      const _TopicItem(label: 'Funny', tag: 'funny', emoji: '😂'),
      const _TopicItem(label: 'Heart-warming', tag: 'heart-warming', emoji: '😄'),
      const _TopicItem(label: 'Sad', tag: 'sad', emoji: '😢'),
    ];

    return Scaffold(
      appBar: ProfileAppBar(
        child: isFeedTab ? _buildFeedAppBarField(context) : null,
        actions: [
          const AppBarQuickToggles(),
          if (isFeedTab && isAppAdmin)
            IconButton(
              tooltip: 'Question queue',
              icon: const Icon(Icons.live_help_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuestionQueueScreen(appAdminLevel: _appAdminLevel),
                  ),
                );
              },
            ),
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
              children: [
                const MyPageTab(),
                FeedTab(searchQuery: _feedQuery, highlightPostId: _highlightPostId),
                const TopPostsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedAppBarField(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _appBarComposer,
        textInputAction: TextInputAction.search,
        onChanged: (v) => setState(() => _feedQuery = v),
        onSubmitted: (_) => _askQuestionFromAppBar(),
        decoration: InputDecoration(
          hintText: 'Search the feed / ask a question…',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Search + ask as a question',
                icon: const Icon(Icons.search),
                onPressed: _askQuestionFromAppBar,
              ),
              IconButton(
                tooltip: 'Post',
                icon: const Icon(Icons.send),
                onPressed: _postFromAppBar,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _askQuestionFromAppBar() async {
    final text = _appBarComposer.text.trim();
    if (text.isEmpty) return;
    final id = await SocialService().createPost(
      content: text,
      categoryTag: 'question',
      notifyAskerOnReply: true,
      queueForAdmin: true,
    );
    if (!mounted) return;
    setState(() {
      _highlightPostId = id;
      _feedQuery = '';
      _appBarComposer.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Question posted. You’ll be notified when someone replies.')),
    );
  }

  Future<void> _postFromAppBar() async {
    final text = _appBarComposer.text.trim();
    if (text.isEmpty) return;
    final id = await SocialService().createPost(content: text);
    if (!mounted) return;
    setState(() {
      _highlightPostId = id;
      _feedQuery = '';
      _appBarComposer.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Posted.')),
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



