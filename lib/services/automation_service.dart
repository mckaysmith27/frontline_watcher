import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

class AutomationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // This would be your backend API endpoint
  // For now, this is a placeholder structure
  static const String _backendUrl = AppConfig.backendUrl;

  Future<void> startAutomation({
    required List<String> includedWords,
    required List<String> excludedWords,
    required List<String> committedDates,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Store automation configuration (NO credentials - they stay on device)
    // User's Frontline credentials are stored locally in FlutterSecureStorage
    // and used only for job acceptance in-app, never sent to backend
    await _firestore.collection('users').doc(user.uid).update({
      'automationActive': true,
      'automationConfig': {
        'includedWords': includedWords,
        'excludedWords': excludedWords,
        'committedDates': committedDates,
        'startedAt': FieldValue.serverTimestamp(),
      },
      // Required for Cloud Functions Dispatcher
      'districtIds': FieldValue.arrayUnion(['alpine_school_district']), // Add district ID
      'notifyEnabled': true, // Enable notifications
      // Note: essUsername and essPassword are NOT stored here
      // They remain in device keychain (FlutterSecureStorage) only
    });

    // No backend API call needed for automation
    // EC2 scrapers handle job discovery
    // Users accept jobs directly in-app using their local credentials
    print('[AutomationService] Automation preferences saved. Job discovery handled by EC2 scrapers.');
  }

  Future<void> stopAutomation() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'automationActive': false,
      'notifyEnabled': false, // Disable notifications when automation stops
    });

    // No backend API call needed - Cloud Functions will stop sending notifications
    // when automationActive is false
    print('[AutomationService] Automation stopped. Notifications disabled.');
  }

  Future<void> syncJobs() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Call backend API to sync jobs from ESS
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/sync-jobs?userId=${user.uid}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final scheduledJobs = data['scheduledJobs'] as List;
        final pastJobs = data['pastJobs'] as List;

        // Update Firestore with synced jobs
        final batch = _firestore.batch();

        // Clear existing scheduled jobs
        final scheduledSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('scheduledJobs')
            .get();
        for (var doc in scheduledSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // Add new scheduled jobs
        for (var job in scheduledJobs) {
          final jobRef = _firestore
              .collection('users')
              .doc(user.uid)
              .collection('scheduledJobs')
              .doc();
          batch.set(jobRef, job);
        }

        // Clear existing past jobs
        final pastSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('pastJobs')
            .get();
        for (var doc in pastSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // Add new past jobs
        for (var job in pastJobs) {
          final jobRef = _firestore
              .collection('users')
              .doc(user.uid)
              .collection('pastJobs')
              .doc();
          batch.set(jobRef, job);
        }

        await batch.commit();
      }
    } catch (e) {
      print('Error syncing jobs: $e');
      rethrow;
    }
  }

  Future<void> cancelJob(String jobId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Call backend API to cancel job in ESS
    try {
      await http.post(
        Uri.parse('$_backendUrl/api/cancel-job'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': user.uid,
          'jobId': jobId,
        }),
      );
    } catch (e) {
      print('Error canceling job: $e');
      rethrow;
    }
  }

  Future<void> removeExcludedDate(String date) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Call backend API to remove excluded date from ESS
    try {
      await http.post(
        Uri.parse('$_backendUrl/api/remove-excluded-date'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': user.uid,
          'date': date,
        }),
      );
    } catch (e) {
      print('Error removing excluded date: $e');
      rethrow;
    }
  }
}

