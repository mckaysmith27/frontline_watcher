import 'package:flutter/material.dart';
import '../../services/social_service.dart';
import '../../models/post.dart';
import 'post_card.dart';

class FeedTab extends StatelessWidget {
  const FeedTab({
    super.key,
    required this.searchQuery,
    this.highlightPostId,
  });

  final String searchQuery;
  final String? highlightPostId;

  List<String> _tokens(String q) {
    final cleaned = q.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.trim().isNotEmpty).toList();
    // Keep short words if they are numbers (e.g., "67") but skip 1-char junk.
    return parts.where((p) => p.length >= 2 || RegExp(r'^\d+$').hasMatch(p)).toList();
  }

  int _score(Post p, List<String> tokens) {
    if (tokens.isEmpty) return 0;
    final hay = p.content.toLowerCase();
    int s = 0;
    for (final t in tokens) {
      if (hay.contains(t)) s++;
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final socialService = SocialService();
    final q = searchQuery.trim();
    final tokens = _tokens(q);
    final isSearching = q.isNotEmpty;

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

        final all = snapshot.data!;

        if (isSearching) {
          final scored = all
              .map((p) => MapEntry(p, _score(p, tokens)))
              .where((e) => e.value > 0)
              .toList()
            ..sort((a, b) {
              final byScore = b.value.compareTo(a.value);
              if (byScore != 0) return byScore;
              return b.key.createdAt.compareTo(a.key.createdAt);
            });

          if (scored.isEmpty) {
            return const Center(child: Text('No matching posts yet.'));
          }

          return ListView.builder(
            itemCount: scored.length,
            itemBuilder: (context, index) {
              return PostCard(
                post: scored[index].key,
                isOwnPost: false,
                initialShowComments: true, // show thread with the match
                forceShowComments: true,
              );
            },
          );
        }

        final posts = all;
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
                initialShowComments: highlightPostId != null && topPosts[index].id == highlightPostId,
              );
            }
            return PostCard(
              post: regularPosts[index - topPosts.length],
              isOwnPost: false,
              initialShowComments: highlightPostId != null &&
                  regularPosts[index - topPosts.length].id == highlightPostId,
            );
          },
        );
      },
    );
  }
}



