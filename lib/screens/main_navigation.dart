import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'filters/filters_screen.dart';
import 'schedule/schedule_screen.dart';
import 'social/social_screen.dart';
import 'profile/profile_screen.dart';
import 'profile/business_card_screen.dart';
import 'admin/post_approvals_screen.dart';
import 'admin/business_card_orders_queue_screen.dart';
import '../services/admin_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  int _adminIndex = 0; // For admin navigation
  bool _showAdminScreen = false; // Whether to show admin screen overlay
  final GlobalKey<NavigatorState> _socialNavigatorKey = GlobalKey<NavigatorState>();
  final AdminService _adminService = AdminService();
  bool _isAdmin = false;

  late final List<Widget> _screens;
  late final List<Widget> _adminScreens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const FiltersScreen(),
      const ScheduleScreen(),
      SocialScreen(
        onNavigateToMyPage: () {
          // Switch to Social tab and My Page
          setState(() {
            _currentIndex = 2;
          });
        },
      ),
      const BusinessCardScreen(),
      const ProfileScreen(),
    ];
    _adminScreens = [
      const PostApprovalsScreen(),
      const BusinessCardOrdersQueueScreen(),
    ];
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _adminService.isAdmin();
    setState(() {
      _isAdmin = isAdmin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showAdminScreen
          ? IndexedStack(
              index: _adminIndex,
              children: _adminScreens,
            )
          : IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main navigation bar
          NavigationBar(
            selectedIndex: _showAdminScreen ? null : _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
                _showAdminScreen = false; // Hide admin screen when switching main tabs
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.filter_list),
                label: 'Filters',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today),
                label: 'Schedule',
              ),
              NavigationDestination(
                icon: Icon(Icons.people),
                label: 'Community',
              ),
              NavigationDestination(
                icon: Icon(Icons.badge),
                label: 'ID Card',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
          // Admin navigation bar (only shown for admins)
          if (_isAdmin)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: NavigationBar(
                height: 60,
                selectedIndex: _showAdminScreen ? _adminIndex : null,
                onDestinationSelected: (index) {
                  setState(() {
                    _adminIndex = index;
                    _showAdminScreen = true; // Show admin screen
                  });
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.verified_user),
                    selectedIcon: Icon(Icons.verified_user),
                    label: 'Approvals',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.shopping_cart),
                    selectedIcon: Icon(Icons.shopping_cart),
                    label: 'Orders',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}



