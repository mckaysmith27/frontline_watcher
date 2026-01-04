import 'package:flutter/material.dart';
import '../../models/post.dart';
import '../../services/social_service.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final bool isOwnPost;
  final bool isTopPost;

  const PostCard({
    super.key,
    required this.post,
    this.isOwnPost = false,
    this.isTopPost = false,
  });

  @override
  Widget build(BuildContext context) {
    final socialService = SocialService();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isTopPost ? Colors.amber[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: post.userPhotoUrl != null
                      ? NetworkImage(post.userPhotoUrl!)
                      : null,
                  child: post.userPhotoUrl == null
                      ? Text(post.userNickname[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userNickname,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatDate(post.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOwnPost)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          post.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                          color: post.isPinned ? Colors.amber : null,
                        ),
                        onPressed: () {
                          // Toggle pin
                          socialService.togglePinPost(
                            post.id,
                            !post.isPinned,
                            post.isPinned ? 0 : 1,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Post'),
                              content: const Text(
                                'Are you sure you want to delete this post?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            await socialService.deletePost(post.id);
                          }
                        },
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.content),
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...post.imageUrls.map((url) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Image.network(url),
                );
              }),
            ],
            const Divider(),
            if (post.isPinned || isTopPost)
              Row(
                children: [
                  Icon(Icons.arrow_upward, size: 20, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('${post.upvotes}'),
                  const SizedBox(width: 16),
                  Icon(Icons.arrow_downward, size: 20, color: Colors.red),
                  const SizedBox(width: 4),
                  Text('${post.downvotes}'),
                  const SizedBox(width: 16),
                  Icon(Icons.visibility, size: 20),
                  const SizedBox(width: 4),
                  Text('${post.views}'),
                ],
              )
            else
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: isOwnPost
                        ? null
                        : () => socialService.upvotePost(post.id),
                  ),
                  Text('${post.upvotes}'),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: isOwnPost
                        ? null
                        : () => socialService.downvotePost(post.id),
                  ),
                  Text('${post.downvotes}'),
                  const Spacer(),
                  Icon(Icons.visibility, size: 20),
                  Text('${post.views}'),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.month}/${date.day}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}



