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
      final userRoles = userData?['userRoles'] as List<dynamic>? ?? [];
      return userRoles.map((r) => r.toString()).toList();
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
