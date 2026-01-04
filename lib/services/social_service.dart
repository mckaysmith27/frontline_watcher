import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';

class SocialService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createPost({
    required String content,
    List<String> imageUrls = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final nickname = userDoc.data()?['nickname'] ?? user.email?.split('@')[0] ?? 'User';

    await _firestore.collection('posts').add({
      'userId': user.uid,
      'userNickname': nickname,
      'userPhotoUrl': userDoc.data()?['photoUrl'],
      'content': content,
      'imageUrls': imageUrls,
      'createdAt': FieldValue.serverTimestamp(),
      'upvotes': 0,
      'downvotes': 0,
      'views': 0,
      'isPinned': false,
      'pinOrder': 0,
    });
  }

  Stream<List<Post>> getFeedPosts() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs
          .map((doc) => Post.fromMap(doc.data(), doc.id))
          .toList();
      
      // Sort: top 3 by upvotes, then chronological
      posts.sort((a, b) {
        if (a.upvotes > 10 && b.upvotes <= 10) return -1;
        if (a.upvotes <= 10 && b.upvotes > 10) return 1;
        if (a.upvotes > 10 && b.upvotes > 10) {
          return b.upvotes.compareTo(a.upvotes);
        }
        return b.createdAt.compareTo(a.createdAt);
      });

      return posts;
    });
  }

  Stream<List<Post>> getUserPosts(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs
          .map((doc) {
            try {
              return Post.fromMap(doc.data(), doc.id);
            } catch (e) {
              print('Error parsing post ${doc.id}: $e');
              return null;
            }
          })
          .where((post) => post != null)
          .cast<Post>()
          .toList();
      
      // Sort: pinned posts first, then by creation date
      posts.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        if (a.isPinned && b.isPinned) {
          return a.pinOrder.compareTo(b.pinOrder);
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      
      return posts;
    });
  }

  Future<void> upvotePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final postDoc = await postRef.get();
    
    if (postDoc.data()?['userId'] == user.uid) return; // Can't upvote own post

    await postRef.update({
      'upvotes': FieldValue.increment(1),
    });
  }

  Future<void> downvotePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final postDoc = await postRef.get();
    
    if (postDoc.data()?['userId'] == user.uid) return; // Can't downvote own post

    await postRef.update({
      'downvotes': FieldValue.increment(1),
    });
  }

  Future<void> viewPost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Track views per user (simplified - would need a subcollection in production)
    await _firestore.collection('posts').doc(postId).update({
      'views': FieldValue.increment(1),
    });
  }

  Future<void> deletePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postDoc = await _firestore.collection('posts').doc(postId).get();
    if (postDoc.data()?['userId'] != user.uid) return;

    await _firestore.collection('posts').doc(postId).delete();
  }

  Future<void> togglePinPost(String postId, bool isPinned, int pinOrder) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postDoc = await _firestore.collection('posts').doc(postId).get();
    if (postDoc.data()?['userId'] != user.uid) return;

    await _firestore.collection('posts').doc(postId).update({
      'isPinned': isPinned,
      'pinOrder': pinOrder,
    });
  }
}



