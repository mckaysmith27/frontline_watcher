import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for checking user roles and feature access
class UserRoleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// App admin permission tier:
  /// - 'full': can manage promos and other sensitive tools
  /// - 'limited': can access general admin tools but not sensitive ones
  Future<String> getCurrentAppAdminLevel() async {
    final user = _auth.currentUser;
    if (user == null) return 'none';
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final data = userDoc.data() ?? {};
      final raw = data['appAdminLevel'];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim().toLowerCase();
      final roles = (data['userRoles'] is List)
          ? List<String>.from(data['userRoles']).map((e) => e.toLowerCase()).toList()
          : <String>[];
      final legacyIsAdmin = data['role'] == 'admin' || data['isAdmin'] == true;
      if (roles.contains('app admin') || legacyIsAdmin) {
        await _firestore.collection('users').doc(user.uid).set(
          {'appAdminLevel': 'full'},
          SetOptions(merge: true),
        );
        return 'full';
      }
    } catch (_) {}
    return 'none';
  }

  Future<bool> isFullAppAdmin() async {
    final roles = await getCurrentUserRoles();
    if (!roles.contains('app admin')) return false;
    final level = await getCurrentAppAdminLevel();
    return level != 'limited';
  }

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
      final existingRaw = userData?['userRoles'];
      final existing = (existingRaw is List)
          ? existingRaw.map((r) => r.toString().toLowerCase()).toSet()
          : <String>{};
      final next = normalized.toSet();
      if (existing.isEmpty || existing.length != next.length || !existing.containsAll(next)) {
        await _firestore.collection('users').doc(user.uid).set(
          {'userRoles': normalized},
          SetOptions(merge: true),
        );
      }

      // Default app admin level if missing (for app admins only).
      if (normalized.contains('app admin')) {
        final rawLevel = userData?['appAdminLevel'];
        if (rawLevel is! String || rawLevel.trim().isEmpty) {
          await _firestore.collection('users').doc(user.uid).set(
            {'appAdminLevel': 'full'},
            SetOptions(merge: true),
          );
        }
      }

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
  /// - 'admin_promos': ['app admin (full only)']
  /// - 'admin_site_improvements': ['app admin']
  /// - 'admin_growth_sticky': ['app admin']
  /// - 'admin_growth_viral': ['app admin']
  /// - 'admin_growth_paid': ['app admin']
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
      'admin_promos': ['app admin'],
      'admin_site_improvements': ['app admin'],
      'admin_growth_sticky': ['app admin'],
      'admin_growth_viral': ['app admin'],
      'admin_growth_paid': ['app admin'],
    };

    final allowedRoles = featureRoleMap[feature] ?? [];
    final hasRole = allowedRoles.any((role) => userRoles.contains(role));
    if (!hasRole) return false;
    if (feature == 'admin_promos') {
      final level = await getCurrentAppAdminLevel();
      return level != 'limited';
    }
    return true;
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
      accessibleFeatures.addAll([
        'admin_approvals',
        'admin_orders',
        'admin_roles',
        'admin_site_improvements',
        'admin_growth_sticky',
        'admin_growth_viral',
        'admin_growth_paid',
      ]);

      final level = await getCurrentAppAdminLevel();
      if (level != 'limited') {
        accessibleFeatures.add('admin_promos');
      }
    }

    return accessibleFeatures.toSet().toList(); // Remove duplicates
  }
}
