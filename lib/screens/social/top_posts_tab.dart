import 'package:flutter/material.dart';
import '../../services/social_service.dart';
import '../../models/post.dart';
import 'post_card.dart';

class TopPostsTab extends StatefulWidget {
  const TopPostsTab({super.key});

  @override
  State<TopPostsTab> createState() => _TopPostsTabState();
}

class _TopPostsTabState extends State<TopPostsTab> {
  final SocialService _socialService = SocialService();
  String? _selectedCategoryTag; // null means "ALL"
  
  // Category tags with emojis
  static const Map<String, String> categoryTags = {
    'funny': '😂',
    'question': '🤔',
    'heart-warming': '😄',
    'sad': '😢',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tag filter buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // ALL button
                _buildCategoryButton('ALL', null, isSelected: _selectedCategoryTag == null),
                const SizedBox(width: 8),
                // Category buttons
                ...categoryTags.entries.map((entry) {
                  final tag = entry.key;
                  final emoji = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildCategoryButton(
                      '$emoji ${tag.replaceAll('-', ' ')}',
                      tag,
                      isSelected: _selectedCategoryTag == tag,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const Divider(),
        // Posts list
        Expanded(
          child: StreamBuilder<List<Post>>(
            stream: _socialService.getTopPosts(categoryTag: _selectedCategoryTag),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No posts yet'));
              }

              final allPosts = snapshot.data!;
              final now = DateTime.now();
              final thirtyOneDaysAgo = now.subtract(const Duration(days: 31));
              
              // Split into recent (last 31 days) and all time
              final recentPosts = allPosts
                  .where((post) => post.createdAt.isAfter(thirtyOneDaysAgo))
                  .toList();
              final allTimePosts = allPosts
                  .where((post) => !post.createdAt.isAfter(thirtyOneDaysAgo))
                  .toList();

              // Track views when posts are displayed
              for (var post in allPosts) {
                _socialService.viewPost(post.id);
              }

              return ListView.builder(
                itemCount: (recentPosts.isNotEmpty ? 1 : 0) + 
                          recentPosts.length + 
                          (allTimePosts.isNotEmpty ? 1 : 0) + 
                          allTimePosts.length,
                itemBuilder: (context, index) {
                  // Recent section header
                  if (recentPosts.isNotEmpty && index == 0) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Text(
                        'Recent (Last 31 Days)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    );
                  }
                  
                  // Recent posts
                  if (recentPosts.isNotEmpty && index > 0 && index <= recentPosts.length) {
                    return PostCard(
                      post: recentPosts[index - 1],
                      isOwnPost: false,
                    );
                  }
                  
                  // All Time section header
                  final allTimeStartIndex = recentPosts.isNotEmpty ? recentPosts.length + 1 : 0;
                  if (allTimePosts.isNotEmpty && index == allTimeStartIndex) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Text(
                        'All Time',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    );
                  }
                  
                  // All Time posts
                  final allTimePostIndex = index - allTimeStartIndex - (allTimePosts.isNotEmpty ? 1 : 0);
                  if (allTimePostIndex >= 0 && allTimePostIndex < allTimePosts.length) {
                    return PostCard(
                      post: allTimePosts[allTimePostIndex],
                      isOwnPost: false,
                    );
                  }
                  
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryButton(String label, String? tag, {required bool isSelected}) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategoryTag = selected ? tag : null;
        });
      },
    );
  }
}

