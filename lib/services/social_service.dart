import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/social_link.dart';
import '../utils/content_moderation.dart';

class SocialService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createPost({
    required String content,
    List<String> imageUrls = const [],
    String? categoryTag,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final nickname = userDoc.data()?['shortname'] ?? 
                    userDoc.data()?['nickname'] ?? 
                    user.email?.split('@')[0] ?? 
                    'User';

    // Check if post requires approval
    final requiresApproval = ContentModeration.requiresApproval(
      content: content,
      imageUrls: imageUrls,
    );

    // Determine approval status
    // If requires approval, set to 'pending' - user sees it as posted, others don't until approved
    // If doesn't require approval, set to 'approved' - everyone sees it immediately
    final approvalStatus = requiresApproval ? 'pending' : 'approved';

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
      'categoryTag': categoryTag,
      'approvalStatus': approvalStatus,
      'imageBlocked': null,
      'contentBlocked': null,
      'blockedReason': null,
      'flagCount': 0,
      'isFlagged': false,
    });
  }

  Stream<List<Post>> getFeedPosts() {
    final user = _auth.currentUser;
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final posts = <Post>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        // Author always sees their own posts normally
        if (user != null && data['userId'] == user.uid) {
          posts.add(Post.fromMap(data, doc.id));
          continue;
        }
        
        // If post is flagged (2+ flags) and not approved, hide from others
        if (data['isFlagged'] == true && 
            data['approvalStatus'] != 'approved' && 
            data['approvalStatus'] != 'partially_approved') {
          continue; // Don't show to others
        }
        
        // Check approval status
        if (data['approvalStatus'] == 'approved' && 
            data['imageBlocked'] != true && 
            data['contentBlocked'] != true) {
          posts.add(Post.fromMap(data, doc.id));
        }
      }
      
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
        // Removed orderBy to avoid requiring composite index
        // Sorting is done in memory below
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
      
      // Sort: pinned posts first, then by creation date (descending)
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
    final postData = postDoc.data();
    
    if (postData == null) return;
    
    final isOwnPost = postData['userId'] == user.uid;
    
    // Check if user already upvoted today (or once for own posts)
    final today = DateTime.now().toIso8601String().split('T')[0];
    final upvotesRef = postRef.collection('upvotes').doc(user.uid);
    final upvoteDoc = await upvotesRef.get();
    
    if (upvoteDoc.exists) {
      final lastUpvoteDate = upvoteDoc.data()?['date'] as String?;
      if (isOwnPost) {
        // Own posts: only once total
        return;
      } else {
        // Other posts: once per day
        if (lastUpvoteDate == today) {
          return; // Already upvoted today
        }
      }
    }
    
    // Record the upvote
    await upvotesRef.set({'date': today});
    await postRef.update({
      'upvotes': FieldValue.increment(1),
    });
  }

  Future<void> downvotePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final postDoc = await postRef.get();
    final postData = postDoc.data();
    
    if (postData == null) return;
    
    if (postData['userId'] == user.uid) return; // Can't downvote own post

    // Check if user already downvoted (one per post, doesn't renew)
    final downvotesRef = postRef.collection('downvotes').doc(user.uid);
    final downvoteDoc = await downvotesRef.get();
    
    if (downvoteDoc.exists) {
      return; // Already downvoted
    }
    
    // Record the downvote
    await downvotesRef.set({'date': DateTime.now().toIso8601String()});
    await postRef.update({
      'downvotes': FieldValue.increment(1),
    });
  }

  Future<void> viewPost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    
    // Check if user already viewed this post (one per user per post)
    final viewsRef = postRef.collection('views').doc(user.uid);
    final viewDoc = await viewsRef.get();
    
    if (!viewDoc.exists) {
      // First time viewing - increment count and record
      await viewsRef.set({'date': DateTime.now().toIso8601String()});
      await postRef.update({
        'views': FieldValue.increment(1),
      });
    }
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

    // Use timestamp for pinOrder so latest pinned comes first
    final order = isPinned ? DateTime.now().millisecondsSinceEpoch : 0;

    await _firestore.collection('posts').doc(postId).update({
      'isPinned': isPinned,
      'pinOrder': order,
    });
  }

  Stream<List<Post>> getTopPosts({String? categoryTag}) {
    final user = _auth.currentUser;
    return _firestore
        .collection('posts')
        .snapshots()
        .map((snapshot) {
      final posts = <Post>[];
      
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          
          // Author always sees their own posts normally
          if (user != null && data['userId'] == user.uid) {
            posts.add(Post.fromMap(data, doc.id));
            continue;
          }
          
          // If post is flagged (2+ flags) and not approved, hide from others
          if (data['isFlagged'] == true && 
              data['approvalStatus'] != 'approved' && 
              data['approvalStatus'] != 'partially_approved') {
            continue; // Don't show to others
          }
          
          // Check approval status
          if (data['approvalStatus'] == 'approved' && 
              data['imageBlocked'] != true && 
              data['contentBlocked'] != true) {
            posts.add(Post.fromMap(data, doc.id));
          }
        } catch (e) {
          print('Error parsing post ${doc.id}: $e');
        }
      }
      
      // Filter by category if specified
      if (categoryTag != null && categoryTag != 'ALL') {
        posts.removeWhere((post) => post.categoryTag != categoryTag);
      }
      
      // Sort by (upvotes - downvotes) descending
      posts.sort((a, b) {
        final scoreA = a.upvotes - a.downvotes;
        final scoreB = b.upvotes - b.downvotes;
        return scoreB.compareTo(scoreA);
      });
      
      return posts;
    });
      
      // Filter by category if specified
      if (categoryTag != null && categoryTag != 'ALL') {
        posts.removeWhere((post) => post.categoryTag != categoryTag);
      }
      
      // Sort by (upvotes - downvotes) descending
      posts.sort((a, b) {
        final scoreA = a.upvotes - a.downvotes;
        final scoreB = b.upvotes - b.downvotes;
        return scoreB.compareTo(scoreA);
      });
      
      return posts;
    });
  }

  // Social Links Management
  Future<void> saveSocialLinks(String userId, List<SocialLink> links) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != userId) return;

    await _firestore.collection('users').doc(userId).update({
      'socialLinks': links.map((link) => link.toMap()).toList(),
    });
  }

  Future<List<SocialLink>> getSocialLinks(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return [];

    final data = doc.data();
    final linksData = data?['socialLinks'] as List<dynamic>?;
    if (linksData == null) return [];

    return linksData
        .map((linkMap) => SocialLink.fromMap(Map<String, dynamic>.from(linkMap)))
        .toList();
  }

  Stream<List<SocialLink>> getSocialLinksStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return <SocialLink>[];
      final data = snapshot.data();
      final linksData = data?['socialLinks'] as List<dynamic>?;
      if (linksData == null) return <SocialLink>[];

      return linksData
          .map((linkMap) => SocialLink.fromMap(Map<String, dynamic>.from(linkMap)))
          .toList();
    });
  }

  // Comments Management
  Future<void> createComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final nickname = userDoc.data()?['shortname'] ?? 
                    userDoc.data()?['nickname'] ?? 
                    user.email?.split('@')[0] ?? 
                    'User';

    await _firestore.collection('posts').doc(postId).collection('comments').add({
      'postId': postId,
      'userId': user.uid,
      'userNickname': nickname,
      'userPhotoUrl': userDoc.data()?['photoUrl'],
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
      'upvotes': 0,
      'downvotes': 0,
      'views': 0,
      'parentCommentId': parentCommentId,
    });
  }

  Stream<List<Comment>> getComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              return Comment.fromMap(doc.data(), doc.id);
            } catch (e) {
              print('Error parsing comment ${doc.id}: $e');
              return null;
            }
          })
          .where((comment) => comment != null)
          .cast<Comment>()
          .toList();
    });
  }

  Future<void> upvoteComment(String postId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    final commentDoc = await commentRef.get();
    
    if (commentDoc.data()?['userId'] == user.uid) return; // Can't upvote own comment

    final today = DateTime.now().toIso8601String().split('T')[0];
    final upvotesRef = commentRef.collection('upvotes').doc(user.uid);
    final upvoteDoc = await upvotesRef.get();
    
    if (upvoteDoc.exists) {
      final lastUpvoteDate = upvoteDoc.data()?['date'] as String?;
      if (lastUpvoteDate == today) {
        return; // Already upvoted today
      }
    }
    
    await upvotesRef.set({'date': today});
    await commentRef.update({
      'upvotes': FieldValue.increment(1),
    });
  }

  Future<void> downvoteComment(String postId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    final commentDoc = await commentRef.get();
    
    if (commentDoc.data()?['userId'] == user.uid) return; // Can't downvote own comment

    final downvotesRef = commentRef.collection('downvotes').doc(user.uid);
    final downvoteDoc = await downvotesRef.get();
    
    if (downvoteDoc.exists) {
      return; // Already downvoted
    }
    
    await downvotesRef.set({'date': DateTime.now().toIso8601String()});
    await commentRef.update({
      'downvotes': FieldValue.increment(1),
    });
  }

  Future<void> viewComment(String postId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    
    final viewsRef = commentRef.collection('views').doc(user.uid);
    final viewDoc = await viewsRef.get();
    
    if (!viewDoc.exists) {
      await viewsRef.set({'date': DateTime.now().toIso8601String()});
      await commentRef.update({
        'views': FieldValue.increment(1),
      });
    }
  }
}



