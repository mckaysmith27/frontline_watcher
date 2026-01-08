import 'package:flutter/material.dart';
import '../../services/social_service.dart';
import '../../models/post.dart';
import 'post_card.dart';

class FeedTab extends StatelessWidget {
  const FeedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final socialService = SocialService();

    return StreamBuilder<List<Post>>(
      stream: socialService.getFeedPosts(),
      builder: (context, snapshot) {
        // Track views when posts are displayed
        if (snapshot.hasData) {
          for (var post in snapshot.data!) {
            // Track view asynchronously (don't await to avoid blocking UI)
            socialService.viewPost(post.id);
          }
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No posts yet'));
        }

        final posts = snapshot.data!;
        final topPosts = posts.where((p) => p.upvotes > 10).take(3).toList();
        final regularPosts = posts.where((p) => !topPosts.contains(p)).toList();

        return ListView.builder(
          itemCount: topPosts.length + regularPosts.length,
          itemBuilder: (context, index) {
            if (index < topPosts.length) {
              return PostCard(
                post: topPosts[index],
                isOwnPost: false,
                isTopPost: true,
              );
            }
            return PostCard(
              post: regularPosts[index - topPosts.length],
              isOwnPost: false,
            );
          },
        );
      },
    );
  }
}



