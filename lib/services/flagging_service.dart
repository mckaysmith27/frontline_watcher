import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service for flagging posts as inappropriate
class FlaggingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Check if current user has flagged a post
  Future<bool> hasUserFlagged(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final flagDoc = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('flags')
        .doc(user.uid)
        .get();

    return flagDoc.exists && flagDoc.data()?['flagged'] == true;
  }

  /// Toggle flag on a post (flag or unflag)
  Future<void> toggleFlag(String postId, bool isFlagged) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be authenticated');

    try {
      final callable = _functions.httpsCallable('togglePostFlag');
      await callable.call({
        'postId': postId,
        'isFlagged': isFlagged,
      });
    } catch (e) {
      throw Exception('Failed to toggle flag: $e');
    }
  }

  /// Get stream of whether user has flagged a post
  Stream<bool> hasUserFlaggedStream(String postId) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(false);
    }

    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('flags')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists && doc.data()?['flagged'] == true);
  }
}
