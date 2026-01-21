import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class Post {
  final String id;
  final String userId;
  final String userNickname;
  final String? userPhotoUrl;
  final String content;
  final List<String> imageUrls;
  final DateTime createdAt;
  final int upvotes;
  final int downvotes;
  final int views;
  final bool isPinned;
  final int pinOrder;
  final String? categoryTag; // happy, funny, random-thought, heart-warming, sad
  final String approvalStatus; // 'approved', 'pending', 'rejected', 'partially_approved'
  final bool? imageBlocked; // If true, image is blocked for others but visible to author
  final bool? contentBlocked; // If true, content is blocked for others but visible to author
  final String? blockedReason; // Reason for blocking (if applicable)
  final int flagCount; // Number of users who flagged this post
  final bool isFlagged; // If true, 2+ users have flagged it and it's in admin queue
  final String? questionStatus; // 'open' | 'answered' (only for categoryTag == 'question')
  final bool notifyAskerOnReply; // true for question posts by default

  Post({
    required this.id,
    required this.userId,
    required this.userNickname,
    this.userPhotoUrl,
    required this.content,
    this.imageUrls = const [],
    required this.createdAt,
    this.upvotes = 0,
    this.downvotes = 0,
    this.views = 0,
    this.isPinned = false,
    this.pinOrder = 0,
    this.categoryTag,
    this.approvalStatus = 'approved',
    this.imageBlocked,
    this.contentBlocked,
    this.blockedReason,
    this.flagCount = 0,
    this.isFlagged = false,
    this.questionStatus,
    this.notifyAskerOnReply = true,
  });

  factory Post.fromMap(Map<String, dynamic> map, String id) {
    return Post(
      id: id,
      userId: map['userId'] ?? '',
      userNickname: map['userNickname'] ?? '',
      userPhotoUrl: map['userPhotoUrl'],
      content: map['content'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt']
          : (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      upvotes: map['upvotes'] ?? 0,
      downvotes: map['downvotes'] ?? 0,
      views: map['views'] ?? 0,
      isPinned: map['isPinned'] ?? false,
      pinOrder: map['pinOrder'] ?? 0,
      categoryTag: map['categoryTag'],
      approvalStatus: map['approvalStatus'] ?? 'approved',
      imageBlocked: map['imageBlocked'],
      contentBlocked: map['contentBlocked'],
      blockedReason: map['blockedReason'],
      flagCount: map['flagCount'] ?? 0,
      isFlagged: map['isFlagged'] ?? false,
      questionStatus: map['questionStatus'],
      notifyAskerOnReply: map['notifyAskerOnReply'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userNickname': userNickname,
      'userPhotoUrl': userPhotoUrl,
      'content': content,
      'imageUrls': imageUrls,
      'createdAt': createdAt,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'views': views,
      'isPinned': isPinned,
      'pinOrder': pinOrder,
      'categoryTag': categoryTag,
      'approvalStatus': approvalStatus,
      'imageBlocked': imageBlocked,
      'contentBlocked': contentBlocked,
      'blockedReason': blockedReason,
      'flagCount': flagCount,
      'isFlagged': isFlagged,
      'questionStatus': questionStatus,
      'notifyAskerOnReply': notifyAskerOnReply,
    };
  }
}

