import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/admin_service.dart';

class RoleManagementScreen extends StatefulWidget {
  final VoidCallback? onRolesUpdated;
  
  const RoleManagementScreen({super.key, this.onRolesUpdated});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<String> _availableRoles = ['sub', 'teacher', 'administration', 'app admin'];
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _users = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use Firestore query directly for search
      final emailQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('email', isLessThan: query.toLowerCase() + 'z')
          .limit(20)
          .get();

      final usernameQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('username', isLessThan: query.toLowerCase() + 'z')
          .limit(20)
          .get();

      final usersMap = <String, Map<String, dynamic>>{};

      for (var doc in emailQuery.docs) {
        final data = doc.data();
        usersMap[doc.id] = {
          'id': doc.id,
          'email': data['email'] ?? '',
          'username': data['username'] ?? '',
          'userRoles': List<String>.from(data['userRoles'] ?? []),
        };
      }

      for (var doc in usernameQuery.docs) {
        final data = doc.data();
        if (!usersMap.containsKey(doc.id)) {
          usersMap[doc.id] = {
            'id': doc.id,
            'email': data['email'] ?? '',
            'username': data['username'] ?? '',
            'userRoles': List<String>.from(data['userRoles'] ?? []),
          };
        }
      }

      setState(() {
        _users = usersMap.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateUserRoles(String userId, List<String> newRoles) async {
    try {
      await _adminService.updateUserRoles(userId, newRoles);
      
      // Update local state immediately for better UX
      setState(() {
        final userIndex = _users.indexWhere((u) => u['id'] == userId);
        if (userIndex != -1) {
          _users[userIndex]['userRoles'] = newRoles;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User roles updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Notify parent to refresh navigation if roles were updated for current user
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == userId || currentUserId == null) {
          // If we updated the current user's roles, refresh navigation
          widget.onRolesUpdated?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating roles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Management'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by email or username',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _users = [];
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _searchUsers(),
              onChanged: (_) {
                if (_searchController.text.isEmpty) {
                  setState(() {
                    _users = [];
                  });
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _searchUsers,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Enter email or username to search'
                              : 'No users found',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final userId = user['id'] as String;
                          final email = user['email'] as String;
                          final username = user['username'] as String;
                          final currentRoles = List<String>.from(user['userRoles'] as List<dynamic>? ?? []);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    email,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  if (username.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Username: $username',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Roles:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ..._availableRoles.map((role) {
                                    final isChecked = currentRoles.contains(role);
                                    final isAppAdmin = role == 'app admin';
                                    final isLocked = isAppAdmin && !isChecked;

                                    return CheckboxListTile(
                                      title: Text(
                                        role == 'sub'
                                            ? 'Substitute Teacher'
                                            : role == 'app admin'
                                                ? 'App Admin'
                                                : role[0].toUpperCase() + role.substring(1),
                                      ),
                                      value: isChecked,
                                      enabled: !isLocked,
                                      secondary: isLocked
                                          ? const Icon(Icons.lock, size: 20)
                                          : null,
                                      onChanged: isLocked
                                          ? null
                                          : (value) {
                                              final newRoles = List<String>.from(currentRoles);
                                              if (value == true) {
                                                if (!newRoles.contains(role)) {
                                                  newRoles.add(role);
                                                }
                                              } else {
                                                newRoles.remove(role);
                                              }
                                              _updateUserRoles(userId, newRoles);
                                            },
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
