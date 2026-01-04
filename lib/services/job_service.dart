import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/job.dart';

class JobService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<Job>> getScheduledJobs() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('scheduledJobs')
          .get();

      return snapshot.docs
          .map((doc) => Job.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error fetching scheduled jobs: $e');
      return [];
    }
  }

  Future<List<Job>> getPastJobs() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('pastJobs')
          .get();

      return snapshot.docs
          .map((doc) => Job.fromMap({...doc.data(), 'id': doc.id, 'isPast': true}))
          .toList();
    } catch (e) {
      print('Error fetching past jobs: $e');
      return [];
    }
  }

  Future<void> cancelJob(String jobId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // This would call the backend service to cancel the job
      // For now, we'll just remove it from Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('scheduledJobs')
          .doc(jobId)
          .delete();
    } catch (e) {
      print('Error canceling job: $e');
      rethrow;
    }
  }

  Future<void> submitTime(String jobId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'timeSubmittedIds': FieldValue.arrayUnion([jobId]),
      });
    } catch (e) {
      print('Error submitting time: $e');
      rethrow;
    }
  }

  Future<void> submitReview(String jobId, String review, int stars) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('pastJobs')
          .doc(jobId)
          .update({
        'review': review,
        'stars': stars,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error submitting review: $e');
      rethrow;
    }
  }
}



