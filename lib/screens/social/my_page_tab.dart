import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../services/social_service.dart';
import '../../models/post.dart';
import '../../models/social_link.dart';
import 'post_card.dart';
import 'social_links_editor.dart';

class MyPageTab extends StatelessWidget {
  final String? userId; // If null, uses current user
  final bool isOwnPage;

  const MyPageTab({
    super.key,
    this.userId,
    this.isOwnPage = true,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final socialService = SocialService();

    if (authProvider.user == null) {
      return const Center(child: Text('Please log in to see your page'));
    }

    final targetUserId = userId ?? authProvider.user!.uid;
    final isViewingOwnPage = targetUserId == authProvider.user!.uid;

    return StreamBuilder<List<SocialLink>>(
      stream: socialService.getSocialLinksStream(targetUserId),
      builder: (context, linksSnapshot) {
        return StreamBuilder<List<Post>>(
          stream: socialService.getUserPosts(targetUserId),
          builder: (context, postsSnapshot) {
            // Show loading only on initial load
            if ((linksSnapshot.connectionState == ConnectionState.waiting && 
                 !linksSnapshot.hasData) ||
                (postsSnapshot.connectionState == ConnectionState.waiting && 
                 !postsSnapshot.hasData)) {
              return const Center(child: CircularProgressIndicator());
            }

            final links = linksSnapshot.data ?? [];
            final posts = postsSnapshot.data ?? [];
            
            // Sort posts: pinned first (latest pinned first), then regular posts
            final pinnedPosts = posts.where((p) => p.isPinned).toList()
              ..sort((a, b) => b.pinOrder.compareTo(a.pinOrder)); // Latest pinned first
            final regularPosts = posts.where((p) => !p.isPinned).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return RefreshIndicator(
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: ListView(
                children: [
                  // Links Section
                  _buildLinksSection(context, links, isViewingOwnPage, targetUserId),
                  
                  // Posts Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Posts',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  
                  // Pinned Posts
                  ...pinnedPosts.map((post) => PostCard(
                        post: post,
                        isOwnPost: true,
                      )),
                  
                  // Regular Posts
                  ...regularPosts.map((post) => PostCard(
                        post: post,
                        isOwnPost: true,
                      )),
                  
                  // Empty state
                  if (posts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.post_add, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No posts yet'),
                            SizedBox(height: 8),
                            Text(
                              'Create your first post to get started!',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLinksSection(
    BuildContext context,
    List<SocialLink> links,
    bool isOwnPage,
    String userId,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Links',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (isOwnPage)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => SocialLinksEditor(userId: userId),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (links.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                isOwnPage
                    ? 'Add your social media links'
                    : 'No links added',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: links.map((link) {
                return InkWell(
                  onTap: () async {
                    final uri = Uri.parse(link.url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          link.platform,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

