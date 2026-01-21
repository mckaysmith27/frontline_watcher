import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/social_service.dart';

class CommentComposer extends StatefulWidget {
  final String postId;
  final VoidCallback? onCommentAdded;
  final String? appAdminLevel; // 'full' | 'limited' | null
  final bool markQuestionAnswered;

  const CommentComposer({
    super.key,
    required this.postId,
    this.onCommentAdded,
    this.appAdminLevel,
    this.markQuestionAnswered = false,
  });

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final TextEditingController _controller = TextEditingController();
  final SocialService _socialService = SocialService();
  bool _isPosting = false;

  String? _adminNickname;
  String? _replyAs; // selected display name (nickname or answrs alias)

  bool get _isAppAdmin => (widget.appAdminLevel ?? '').trim().isNotEmpty && widget.appAdminLevel != 'none';

  @override
  void initState() {
    super.initState();
    if (_isAppAdmin) {
      _loadAdminNickname();
    }
  }

  Future<void> _loadAdminNickname() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final nick = (doc.data()?['nickname'] as String?)?.trim();
      if (!mounted) return;
      setState(() {
        _adminNickname = (nick?.isNotEmpty == true) ? nick : null;
        _replyAs ??= _adminNickname;
      });
    } catch (_) {
      // ignore
    }
  }

  List<String> get _replyAsOptions {
    final out = <String>[];
    final nick = _adminNickname;
    if (nick != null && nick.trim().isNotEmpty) out.add(nick.trim());
    // Admin aliases by tier.
    if (widget.appAdminLevel == 'full') out.add('answrs67');
    if (widget.appAdminLevel == 'limited') out.add('answrs76');
    // Fallback if nickname not loaded yet.
    if (out.isEmpty) out.add('answrs67');
    return out.toSet().toList();
  }

  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _isPosting = true);

    try {
      final selected = _isAppAdmin ? (_replyAs ?? _adminNickname ?? _replyAsOptions.first) : null;
      final isAlias = selected != null && (selected == 'answrs67' || selected == 'answrs76');

      await _socialService.createComment(
        postId: widget.postId,
        content: _controller.text.trim(),
        isAdminAnswer: _isAppAdmin && widget.markQuestionAnswered,
        disableProfileLink: isAlias,
        nicknameOverride: selected,
      );

      if (_isAppAdmin && widget.markQuestionAnswered) {
        await _socialService.markQuestionAnswered(widget.postId);
      }

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isAppAdmin && widget.markQuestionAnswered)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  'Reply as:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: (_replyAsOptions.contains(_replyAs) ? _replyAs : null) ?? _replyAsOptions.first,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    items: _replyAsOptions
                        .map(
                          (v) => DropdownMenuItem<String>(
                            value: v,
                            child: Text(v),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _replyAs = v),
                  ),
                ),
              ],
            ),
          ),
        Row(
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
        ),
      ],
    );
  }
}

