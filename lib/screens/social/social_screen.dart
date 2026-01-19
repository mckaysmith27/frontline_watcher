import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'post_composer.dart';
import 'my_page_tab.dart';
import 'feed_tab.dart';
import 'top_posts_tab.dart';
import '../profile/profile_screen.dart';
import '../../widgets/app_bar_quick_toggles.dart';
import '../../services/social_service.dart';
import '../../services/user_role_service.dart';

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
  final TextEditingController _quickPostController = TextEditingController();
  final FocusNode _quickPostFocus = FocusNode();
  bool _sendingQuickPost = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quickPostController.dispose();
    _quickPostFocus.dispose();
    super.dispose();
  }

  Future<void> _sendQuickPost() async {
    if (_sendingQuickPost) return;
    final content = _quickPostController.text.trim();
    if (content.isEmpty) return;

    setState(() => _sendingQuickPost = true);
    try {
      final roleService = UserRoleService();
      final hasCommunityAccess = await roleService.hasFeatureAccess('community');
      if (!hasCommunityAccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This feature is not available for your role.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final socialService = SocialService();
      await socialService.createPost(content: content);

      _quickPostController.clear();
      _quickPostFocus.unfocus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Posted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingQuickPost = false);
    }
  }

  Future<void> _openComposerForImage() async {
    final initial = _quickPostController.text.trim();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PostComposer(initialText: initial),
    );
  }

  Widget _buildQuickPostField(BuildContext context) {
    final hasText = _quickPostController.text.trim().isNotEmpty;

    return SizedBox(
      height: 40,
      child: TextField(
        controller: _quickPostController,
        focusNode: _quickPostFocus,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _sendQuickPost(),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: "Quick post… (press Enter to send)",
          isDense: true,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: hasText
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Add image',
                      onPressed: _openComposerForImage,
                      icon: const Icon(Icons.image_outlined, size: 20),
                    ),
                    IconButton(
                      tooltip: 'Send',
                      onPressed: _sendingQuickPost ? null : _sendQuickPost,
                      icon: _sendingQuickPost
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, size: 20),
                    ),
                    const SizedBox(width: 4),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

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
        title: _buildQuickPostField(context),
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
                      _buildTagButton(context, '😂', 'funny', () {
                        _openComposerWithTag(context, 'funny');
                      }),
                      const SizedBox(width: 8),
                      _buildTagButton(context, '🤔', 'question', () {
                        _openComposerWithTag(context, 'question');
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



