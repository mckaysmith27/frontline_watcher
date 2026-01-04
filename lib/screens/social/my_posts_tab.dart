import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/social_service.dart';
import '../../models/post.dart';
import 'post_card.dart';

class MyPostsTab extends StatelessWidget {
  const MyPostsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final socialService = SocialService();

    if (authProvider.user == null) {
      return const Center(child: Text('Please log in to see your posts'));
    }

    return StreamBuilder<List<Post>>(
      stream: socialService.getUserPosts(authProvider.user!.uid),
      builder: (context, snapshot) {
        // Show loading only on initial load
        if (snapshot.connectionState == ConnectionState.waiting && 
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Handle errors
        if (snapshot.hasError) {
          print('Error loading user posts: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading posts: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Stream will automatically retry
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Show empty state
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
          );
        }

        final posts = snapshot.data!;
        final pinnedPosts = posts.where((p) => p.isPinned).toList()
          ..sort((a, b) => a.pinOrder.compareTo(b.pinOrder));
        final regularPosts = posts.where((p) => !p.isPinned).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return RefreshIndicator(
          onRefresh: () async {
            // Stream will automatically update, but this provides pull-to-refresh
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            itemCount: pinnedPosts.length + regularPosts.length,
            itemBuilder: (context, index) {
              if (index < pinnedPosts.length) {
                return PostCard(
                  post: pinnedPosts[index],
                  isOwnPost: true,
                );
              }
              return PostCard(
                post: regularPosts[index - pinnedPosts.length],
                isOwnPost: true,
              );
            },
          ),
        );
      },
    );
  }
}



