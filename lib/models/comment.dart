import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userNickname;
  final String? userPhotoUrl;
  final String content;
  final DateTime createdAt;
  final int upvotes;
  final int downvotes;
  final int views;
  final String? parentCommentId; // For nested replies
  final bool isAdminAnswer; // True when an app admin answered a question
  final bool disableProfileLink; // True for special admin identities (answrs67/76)

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userNickname,
    this.userPhotoUrl,
    required this.content,
    required this.createdAt,
    this.upvotes = 0,
    this.downvotes = 0,
    this.views = 0,
    this.parentCommentId,
    this.isAdminAnswer = false,
    this.disableProfileLink = false,
  });

  factory Comment.fromMap(Map<String, dynamic> map, String id) {
    return Comment(
      id: id,
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      userNickname: map['userNickname'] ?? '',
      userPhotoUrl: map['userPhotoUrl'],
      content: map['content'] ?? '',
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt']
          : (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      upvotes: map['upvotes'] ?? 0,
      downvotes: map['downvotes'] ?? 0,
      views: map['views'] ?? 0,
      parentCommentId: map['parentCommentId'],
      isAdminAnswer: map['isAdminAnswer'] ?? false,
      disableProfileLink: map['disableProfileLink'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'userNickname': userNickname,
      'userPhotoUrl': userPhotoUrl,
      'content': content,
      'createdAt': createdAt,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'views': views,
      'parentCommentId': parentCommentId,
      'isAdminAnswer': isAdminAnswer,
      'disableProfileLink': disableProfileLink,
    };
  }
}

