import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for checking user roles and feature access
class UserRoleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user's roles
  Future<List<String>> getCurrentUserRoles() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final roles = <String>[];

      // Preferred: new schema `userRoles: string[]`
      final rawUserRoles = userData?['userRoles'];
      if (rawUserRoles is List) {
        roles.addAll(rawUserRoles.map((r) => r.toString()));
      } else if (rawUserRoles is String && rawUserRoles.trim().isNotEmpty) {
        // Defensive: if someone stored a single role as a string
        roles.add(rawUserRoles.trim());
      }

      // Backwards compatibility: older schema might have `userRole` or `role`
      if (roles.isEmpty) {
        final legacyUserRole = userData?['userRole'];
        if (legacyUserRole is String && legacyUserRole.trim().isNotEmpty) {
          roles.add(legacyUserRole.trim());
        }
      }

      if (roles.isEmpty) {
        final legacyRole = userData?['role'];
        final legacyIsAdmin = userData?['isAdmin'] == true;

        // If legacy admin flags exist, preserve admin capability.
        if (legacyRole == 'admin' || legacyIsAdmin) {
          roles.add('app admin');
        } else if (legacyRole is String && legacyRole.trim().isNotEmpty) {
          roles.add(legacyRole.trim());
        }
      }

      // Final fallback: existing users (pre-roles system) should behave like subs by default.
      if (roles.isEmpty) {
        roles.add('sub');
      }

      // Normalize / dedupe
      final normalized = roles.map((r) => r.toLowerCase()).toSet().toList();

      // Persist back to Firestore so the UI is stable next launch.
      // (Do not auto-add app admin unless legacy admin fields already implied it above.)
      await _firestore.collection('users').doc(user.uid).set(
        {'userRoles': normalized},
        SetOptions(merge: true),
      );

      return normalized;
    } catch (e) {
      print('Error getting user roles: $e');
      return [];
    }
  }

  /// Check if current user has a specific role
  Future<bool> hasRole(String role) async {
    final roles = await getCurrentUserRoles();
    return roles.contains(role);
  }

  /// Check if current user has any of the specified roles
  Future<bool> hasAnyRole(List<String> roles) async {
    final userRoles = await getCurrentUserRoles();
    return roles.any((role) => userRoles.contains(role));
  }

  /// Check if current user has access to a feature
  /// Features are mapped to roles:
  /// - 'notifications': ['sub']
  /// - 'filters': ['sub']
  /// - 'schedule': ['sub']
  /// - 'community': ['sub', 'teacher', 'administration']
  /// - 'business_card': ['sub', 'teacher', 'administration']
  /// - 'profile': ['sub', 'teacher', 'administration']
  /// - 'admin_approvals': ['app admin']
  /// - 'admin_orders': ['app admin']
  /// - 'admin_roles': ['app admin']
  Future<bool> hasFeatureAccess(String feature) async {
    final userRoles = await getCurrentUserRoles();
    
    // Feature to role mapping
    final featureRoleMap = {
      'notifications': ['sub'],
      'filters': ['sub'],
      'schedule': ['sub'],
      'community': ['sub', 'teacher', 'administration'],
      'business_card': ['sub', 'teacher', 'administration'],
      'profile': ['sub', 'teacher', 'administration'],
      'admin_approvals': ['app admin'],
      'admin_orders': ['app admin'],
      'admin_roles': ['app admin'],
    };

    final allowedRoles = featureRoleMap[feature] ?? [];
    return allowedRoles.any((role) => userRoles.contains(role));
  }

  /// Get list of features accessible to current user
  Future<List<String>> getAccessibleFeatures() async {
    final userRoles = await getCurrentUserRoles();
    final accessibleFeatures = <String>[];

    // Check each feature
    if (userRoles.contains('sub')) {
      accessibleFeatures.addAll(['notifications', 'filters', 'schedule']);
    }
    
    if (userRoles.any((r) => ['sub', 'teacher', 'administration'].contains(r))) {
      accessibleFeatures.addAll(['community', 'business_card', 'profile']);
    }
    
    if (userRoles.contains('app admin')) {
      accessibleFeatures.addAll(['admin_approvals', 'admin_orders', 'admin_roles']);
    }

    return accessibleFeatures.toSet().toList(); // Remove duplicates
  }
}
