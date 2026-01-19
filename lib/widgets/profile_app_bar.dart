import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/social/user_page_viewer.dart';

class ProfileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? child;
  final List<Widget>? actions;
  final bool showBackButton;

  const ProfileAppBar({
    super.key,
    this.child,
    this.actions,
    this.showBackButton = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    final canPop = Navigator.of(context).canPop();
    final shouldShowBack = showBackButton && canPop;

    return AppBar(
      leading: shouldShowBack
          ? const BackButton()
          : (user != null
              ? GestureDetector(
                  onTap: () {
                    // Navigate to Social screen and switch to My Page tab
                    _navigateToMyPage(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                      child: user.photoURL == null
                          ? Text(
                              user.email?[0].toUpperCase() ?? 'U',
                              style: const TextStyle(fontSize: 16),
                            )
                          : null,
                    ),
                  ),
                )
              : null),
      title: child,
      actions: actions,
      automaticallyImplyLeading: !shouldShowBack ? false : true,
    );
  }

  void _navigateToMyPage(BuildContext context) {
    // Show user's own page in modal
    // If on Social screen, it will switch to My Page tab instead
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => UserPageViewer(
          userId: authProvider.user!.uid,
          isOwnPage: true,
        ),
      );
    }
  }
}

