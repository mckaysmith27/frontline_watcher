import 'package:flutter/material.dart';
import '../../models/comment.dart';
import '../../services/social_service.dart';
import 'user_page_viewer.dart';

class CommentCard extends StatelessWidget {
  final Comment comment;
  final String postId;

  const CommentCard({
    super.key,
    required this.comment,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    final socialService = SocialService();
    final isOwnComment = false; // Could check against current user

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  // Show user's page in modal
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => UserPageViewer(
                      userId: comment.userId,
                      isOwnPage: false,
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 12,
                  backgroundImage: comment.userPhotoUrl != null
                      ? NetworkImage(comment.userPhotoUrl!)
                      : null,
                  child: comment.userPhotoUrl == null
                      ? Text(
                          comment.userNickname[0].toUpperCase(),
                          style: const TextStyle(fontSize: 12),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userNickname,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _formatDate(comment.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment.content),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: isOwnComment
                    ? null
                    : () => socialService.upvoteComment(postId, comment.id),
              ),
              Text('${comment.upvotes}', style: const TextStyle(fontSize: 12)),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: isOwnComment
                    ? null
                    : () => socialService.downvoteComment(postId, comment.id),
              ),
              Text('${comment.downvotes}', style: const TextStyle(fontSize: 12)),
              const Spacer(),
              Icon(Icons.visibility, size: 14),
              const SizedBox(width: 4),
              Text('${comment.views}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
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

