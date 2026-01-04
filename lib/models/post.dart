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
    };
  }
}

