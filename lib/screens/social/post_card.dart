import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/post.dart';
import '../../models/comment.dart';
import '../../providers/auth_provider.dart';
import '../../services/social_service.dart';
import 'comment_card.dart';
import 'comment_composer.dart';
import 'user_page_viewer.dart';

class PostCard extends StatefulWidget {
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
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final SocialService _socialService = SocialService();
  bool _showComments = false;

  String? _normalizeCategoryTag(String? tag) {
    if (tag == null) return null;
    if (tag == 'random-thought') return 'question';
    if (tag == 'happy') return null; // removed
    return tag;
  }

  @override
  Widget build(BuildContext context) {
    final normalizedTag = _normalizeCategoryTag(widget.post.categoryTag);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: widget.isTopPost ? Colors.amber[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        userId: widget.post.userId,
                        isOwnPage: widget.post.userId == Provider.of<AuthProvider>(context, listen: false).user?.uid,
                      ),
                    );
                  },
                  child: CircleAvatar(
                    backgroundImage: widget.post.userPhotoUrl != null
                        ? NetworkImage(widget.post.userPhotoUrl!)
                        : null,
                    child: widget.post.userPhotoUrl == null
                        ? Text(widget.post.userNickname[0].toUpperCase())
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.userNickname,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatDate(widget.post.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isOwnPost)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          widget.post.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                          color: widget.post.isPinned ? Colors.amber : null,
                        ),
                        onPressed: () {
                          // Toggle pin - only affects order on My Page
                          _socialService.togglePinPost(
                            widget.post.id,
                            !widget.post.isPinned,
                            0, // Order is calculated in service
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
                            await _socialService.deletePost(widget.post.id);
                          }
                        },
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Show category tag if present
            if (normalizedTag != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getCategoryEmoji(normalizedTag),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      normalizedTag.replaceAll('-', ' '),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Text(widget.post.content),
            if (widget.post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...widget.post.imageUrls.map((url) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Image.network(url),
                );
              }),
            ],
            const Divider(),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: widget.isOwnPost
                      ? null
                      : () => _socialService.upvotePost(widget.post.id),
                ),
                Text('${widget.post.upvotes}'),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: widget.isOwnPost
                      ? null
                      : () => _socialService.downvotePost(widget.post.id),
                ),
                Text('${widget.post.downvotes}'),
                IconButton(
                  icon: Icon(_showComments ? Icons.comment : Icons.comment_outlined),
                  onPressed: () {
                    setState(() {
                      _showComments = !_showComments;
                    });
                  },
                ),
                const Spacer(),
                Icon(Icons.visibility, size: 20),
                Text('${widget.post.views}'),
              ],
            ),
            // Comments Section
            if (_showComments) ...[
              const Divider(),
              CommentComposer(
                postId: widget.post.id,
                onCommentAdded: () {
                  setState(() {}); // Refresh to show new comment
                },
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<Comment>>(
                stream: _socialService.getComments(widget.post.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No comments yet'),
                    );
                  }
                  
                  final comments = snapshot.data!;
                  return Column(
                    children: comments.map((comment) {
                      // Track view when comment is displayed
                      _socialService.viewComment(widget.post.id, comment.id);
                      return CommentCard(
                        comment: comment,
                        postId: widget.post.id,
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getCategoryEmoji(String categoryTag) {
    const emojis = {
      'funny': '😂',
      'question': '🤔',
      'heart-warming': '😄',
      'sad': '😢',
    };
    return emojis[categoryTag] ?? '';
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



