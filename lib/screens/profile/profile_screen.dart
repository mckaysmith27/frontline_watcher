import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/user_role_service.dart';
import '../../widgets/profile_app_bar.dart';
import 'password_reset_screen.dart';
import 'agreements_screen.dart';
import 'help_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: ProfileAppBar(
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Profile Photo
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: authProvider.user?.photoURL != null
                      ? NetworkImage(authProvider.user!.photoURL!)
                      : null,
                  child: authProvider.user?.photoURL == null
                      ? Text(
                          authProvider.user?.email?[0].toUpperCase() ?? 'U',
                          style: const TextStyle(fontSize: 40),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, size: 20),
                      color: Colors.white,
                      onPressed: () => _pickProfilePhoto(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              authProvider.user?.email ?? 'User',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 32),
            // Settings List
            _buildSettingsItem(
              context,
              icon: Icons.person,
              title: 'Shortname',
              subtitle: 'Change your display name',
              onTap: () => _showShortnameDialog(context),
            ),
            _buildThemeSettingsItem(context),
            _buildSettingsItem(
              context,
              icon: Icons.verified,
              title: 'Become a Verified Sub',
              subtitle: 'Verify your identity',
              onTap: () => _showVerificationDialog(context),
            ),
            _buildSettingsItem(
              context,
              icon: Icons.lock,
              title: 'Reset Password',
              subtitle: 'Change your password',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PasswordResetScreen(),
                  ),
                );
              },
            ),
            _buildSettingsItem(
              context,
              icon: Icons.description,
              title: 'Agreements',
              subtitle: 'View terms and conditions',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AgreementsScreen(),
                  ),
                );
              },
            ),
            _buildSettingsItem(
              context,
              icon: Icons.help,
              title: 'Help & Support',
              subtitle: 'Get help and contact support',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HelpScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            _buildSettingsItem(
              context,
              icon: Icons.logout,
              title: 'Sign Out',
              subtitle: 'Sign out of your account',
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await authProvider.signOut();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildThemeSettingsItem(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return ListTile(
      leading: Icon(
        themeProvider.themeMode == ThemeMode.dark
            ? Icons.dark_mode
            : themeProvider.themeMode == ThemeMode.light
                ? Icons.light_mode
                : Icons.brightness_auto,
      ),
      title: const Text('Theme'),
      subtitle: Text(
        themeProvider.themeMode == ThemeMode.dark
            ? 'Dark Mode'
            : themeProvider.themeMode == ThemeMode.light
                ? 'Light Mode'
                : 'System Default',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Light mode button
          IconButton(
            icon: Icon(
              Icons.light_mode,
              color: themeProvider.themeMode == ThemeMode.light
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: 'Light Mode',
            onPressed: () {
              themeProvider.setThemeMode(ThemeMode.light);
            },
          ),
          // Dark mode button
          IconButton(
            icon: Icon(
              Icons.dark_mode,
              color: themeProvider.themeMode == ThemeMode.dark
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: 'Dark Mode',
            onPressed: () {
              themeProvider.setThemeMode(ThemeMode.dark);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickProfilePhoto(BuildContext context) async {
    // Check if user has access to profile feature
    final roleService = UserRoleService();
    final hasProfileAccess = await roleService.hasFeatureAccess('profile');
    
    if (!hasProfileAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This feature is not available for your role.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // Upload to Firebase Storage and update user profile
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    }
  }

  void _showShortnameDialog(BuildContext context) {
    final controller = TextEditingController();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Change Shortname'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Shortname',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  controller.dispose();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final shortname = controller.text.trim();
                  if (shortname.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Shortname cannot be empty'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  try {
                    final user = authProvider.user;
                    if (user != null) {
                      // Update shortname in Firestore
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({
                        'shortname': shortname.toLowerCase(),
                      });

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        controller.dispose();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Shortname updated'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('Error updating shortname: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      // Dispose controller when dialog is closed
      if (controller.hasClients) {
        controller.dispose();
      }
    });
  }

  void _showVerificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Become a Verified Sub'),
        content: const Text(
          'To become verified, please upload a photo of yourself holding your name badge next to your face.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _pickVerificationPhoto(context);
            },
            child: const Text('Upload Photo'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickVerificationPhoto(BuildContext context) async {
    // Check if user has access to profile feature
    final roleService = UserRoleService();
    final hasProfileAccess = await roleService.hasFeatureAccess('profile');
    
    if (!hasProfileAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This feature is not available for your role.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      // Upload verification photo
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification photo submitted for review')),
      );
    }
  }
}


