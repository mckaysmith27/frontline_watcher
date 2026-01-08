import 'package:flutter/material.dart';
import '../../services/social_service.dart';

class CommentComposer extends StatefulWidget {
  final String postId;
  final VoidCallback? onCommentAdded;

  const CommentComposer({
    super.key,
    required this.postId,
    this.onCommentAdded,
  });

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final TextEditingController _controller = TextEditingController();
  final SocialService _socialService = SocialService();
  bool _isPosting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _isPosting = true);

    try {
      await _socialService.createComment(
        postId: widget.postId,
        content: _controller.text.trim(),
      );

      _controller.clear();
      if (widget.onCommentAdded != null) {
        widget.onCommentAdded!();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Write a comment...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _postComment(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: _isPosting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          onPressed: _isPosting ? null : _postComment,
        ),
      ],
    );
  }
}

