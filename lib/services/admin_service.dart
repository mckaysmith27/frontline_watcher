import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/post.dart';

/// Service for admin operations on posts
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if current user is an admin
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    
    // Check if user has app admin role in userRoles array
    final userRoles = userData?['userRoles'] as List<dynamic>? ?? [];
    return userRoles.contains('app admin') || 
           userData?['role'] == 'admin' || 
           userData?['isAdmin'] == true;
  }

  Future<String> getCurrentAppAdminLevel() async {
    final user = _auth.currentUser;
    if (user == null) return 'none';
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final raw = userData['appAdminLevel'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim().toLowerCase();
    // Default to full for legacy admins.
    final userRoles = userData['userRoles'] as List<dynamic>? ?? [];
    final legacyIsAdmin = userData['role'] == 'admin' || userData['isAdmin'] == true;
    if (userRoles.contains('app admin') || legacyIsAdmin) return 'full';
    return 'none';
  }

  Future<bool> isFullAppAdmin() async {
    if (!await isAdmin()) return false;
    final level = await getCurrentAppAdminLevel();
    return level != 'limited';
  }
  
  /// Get user roles for a user
  Future<List<String>> getUserRoles(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data();
    final userRoles = userData?['userRoles'] as List<dynamic>? ?? [];
    return userRoles.map((r) => r.toString()).toList();
  }
  
  /// Update user roles (only app admins can do this)
  Future<void> updateUserRoles(String userId, List<String> roles) async {
    if (!await isAdmin()) {
      throw Exception('Only app admins can update user roles');
    }
    
    await _firestore.collection('users').doc(userId).update({
      'userRoles': roles,
    });
  }

  Future<void> updateAppAdminLevel(String userId, String level) async {
    if (!await isFullAppAdmin()) {
      throw Exception('Only full app admins can update app admin level');
    }
    final normalized = level.trim().toLowerCase();
    if (normalized != 'full' && normalized != 'limited') {
      throw Exception('Invalid app admin level');
    }
    await _firestore.collection('users').doc(userId).update({'appAdminLevel': normalized});
  }
  
  /// Search for users by email or username
  Stream<List<Map<String, dynamic>>> searchUsers(String query) {
    if (query.isEmpty) {
      return const Stream.empty();
    }
    
    final lowerQuery = query.toLowerCase();
    
    // Search by email (starts with)
    final emailQuery = _firestore
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: lowerQuery)
        .where('email', isLessThan: lowerQuery + 'z')
        .limit(20)
        .snapshots();
    
    // Search by username (starts with)
    final usernameQuery = _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: lowerQuery)
        .where('username', isLessThan: lowerQuery + 'z')
        .limit(20)
        .snapshots();
    
    // Combine both streams
    return Stream.periodic(const Duration(milliseconds: 100), (_) => null)
        .asyncMap((_) async {
      final emailSnapshot = await emailQuery.first;
      final usernameSnapshot = await usernameQuery.first;
      
      final users = <String, Map<String, dynamic>>{};
      
      for (var doc in emailSnapshot.docs) {
        final data = doc.data();
        users[doc.id] = {
          'id': doc.id,
          'email': data['email'],
          'username': data['username'],
          'userRoles': data['userRoles'] ?? [],
        };
      }
      
      for (var doc in usernameSnapshot.docs) {
        final data = doc.data();
        if (!users.containsKey(doc.id)) {
          users[doc.id] = {
            'id': doc.id,
            'email': data['email'],
            'username': data['username'],
            'userRoles': data['userRoles'] ?? [],
          };
        }
      }
      
      return users.values.toList();
    });
  }

  /// Get all posts pending approval (includes flagged posts)
  Stream<List<Post>> getPendingApprovalPosts() {
    return _firestore
        .collection('posts')
        .where('approvalStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
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
    });
  }

  /// Get all flagged posts (2+ flags)
  Stream<List<Post>> getFlaggedPosts() {
    return _firestore
        .collection('posts')
        .where('isFlagged', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
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
    });
  }

  /// Get all posts with partial approval (partially_approved status)
  Stream<List<Post>> getPartiallyApprovedPosts() {
    return _firestore
        .collection('posts')
        .where('approvalStatus', isEqualTo: 'partially_approved')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
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
    });
  }

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Block user completely (blacklist user and IPs)
  Future<void> blockUser(String postId, String userId) async {
    if (!await isAdmin()) {
      throw Exception('Unauthorized: Admin access required');
    }

    try {
      final callable = _functions.httpsCallable('blockUser');
      await callable.call({
        'postId': postId,
        'userId': userId,
      });
    } catch (e) {
      throw Exception('Failed to block user: $e');
    }
  }

  /// Block image from post (show broken image to others, but user still sees it)
  Future<void> blockImage(String postId) async {
    if (!await isAdmin()) {
      throw Exception('Unauthorized: Admin access required');
    }

    try {
      final callable = _functions.httpsCallable('blockImage');
      await callable.call({
        'postId': postId,
      });
    } catch (e) {
      throw Exception('Failed to block image: $e');
    }
  }

  /// Block message content from post (hide content from others, but user still sees it on their page)
  Future<void> blockContent(String postId) async {
    if (!await isAdmin()) {
      throw Exception('Unauthorized: Admin access required');
    }

    try {
      final callable = _functions.httpsCallable('blockContent');
      await callable.call({
        'postId': postId,
      });
    } catch (e) {
      throw Exception('Failed to block content: $e');
    }
  }

  /// Fully approve post (make visible to everyone)
  Future<void> approvePost(String postId) async {
    if (!await isAdmin()) {
      throw Exception('Unauthorized: Admin access required');
    }

    try {
      final callable = _functions.httpsCallable('approvePost');
      await callable.call({
        'postId': postId,
      });
    } catch (e) {
      throw Exception('Failed to approve post: $e');
    }
  }

  /// Partially approve post (approve but keep some restrictions)
  Future<void> partiallyApprovePost(String postId, {
    bool? imageBlocked,
    bool? contentBlocked,
  }) async {
    if (!await isAdmin()) {
      throw Exception('Unauthorized: Admin access required');
    }

    // For partial approval, we'll use direct Firestore update since it's more flexible
    final updateData = <String, dynamic>{
      'approvalStatus': 'partially_approved',
    };

    if (imageBlocked != null) {
      updateData['imageBlocked'] = imageBlocked;
    }

    if (contentBlocked != null) {
      updateData['contentBlocked'] = contentBlocked;
    }

    await _firestore.collection('posts').doc(postId).update(updateData);
  }
}
