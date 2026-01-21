import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../services/social_service.dart';
import '../social/post_card.dart';

class QuestionQueueScreen extends StatelessWidget {
  const QuestionQueueScreen({
    super.key,
    required this.appAdminLevel,
  });

  final String appAdminLevel; // none|limited|full

  @override
  Widget build(BuildContext context) {
    final social = SocialService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Queue'),
      ),
      body: StreamBuilder<List<Post>>(
        stream: social.getOpenQuestionPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <Post>[];
          if (items.isEmpty) {
            return const Center(child: Text('No unanswered questions right now.'));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final p = items[i];
              final preview = p.content.trim().replaceAll('\n', ' ');
              final short = preview.length > 90 ? '${preview.substring(0, 90)}…' : preview;
              return ListTile(
                leading: const Text('🤔', style: TextStyle(fontSize: 18)),
                title: Text(short),
                subtitle: Text('Asked by ${p.userNickname}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _QuestionDetailScreen(
                        post: p,
                        appAdminLevel: appAdminLevel,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _QuestionDetailScreen extends StatelessWidget {
  const _QuestionDetailScreen({
    required this.post,
    required this.appAdminLevel,
  });

  final Post post;
  final String appAdminLevel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Answer Question')),
      body: ListView(
        children: [
          PostCard(
            post: post,
            isOwnPost: false,
            initialShowComments: true,
            forceShowComments: true,
            appAdminLevel: appAdminLevel,
            enableAdminAnswerComposer: true,
          ),
        ],
      ),
    );
  }
}

