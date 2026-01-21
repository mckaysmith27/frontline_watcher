import 'package:flutter/material.dart';
import 'notifications/notifications_screen.dart';
import 'filters/filters_screen.dart';
import 'schedule/schedule_screen.dart';
import 'social/social_screen.dart';
import 'profile/business_card_screen.dart';
import 'admin/post_approvals_screen.dart';
import 'admin/business_card_orders_queue_screen.dart';
import 'admin/role_management_screen.dart';
import 'admin/growth/sticky_engine_screen.dart';
import 'admin/growth/viral_engine_screen.dart';
import 'admin/growth/paid_engine_screen.dart';
import 'admin/promo_codes_screen.dart';
import 'admin/site_improvements_screen.dart';
import '../services/admin_service.dart';
import '../services/user_role_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  int _adminIndex = 0; // For admin navigation
  bool _showAdminScreen = false; // Whether to show admin screen overlay
  final AdminService _adminService = AdminService();
  final UserRoleService _roleService = UserRoleService();
  bool _isAdmin = false;
  List<String> _accessibleFeatures = [];
  bool _isLoadingRoles = true;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    setState(() {
      _isLoadingRoles = true;
    });
    
    final isAdmin = await _adminService.isAdmin();
    final accessibleFeatures = await _roleService.getAccessibleFeatures();
    
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _accessibleFeatures = accessibleFeatures;
        _isLoadingRoles = false;
      });
      
      // Reset indices after state is updated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final mainScreens = _buildMainScreens();
          final adminScreens = _buildAdminScreens();
          
          setState(() {
            // Reset indices if out of bounds
            if (_currentIndex >= mainScreens.length && mainScreens.isNotEmpty) {
              _currentIndex = 0;
            }
            if (_adminIndex >= adminScreens.length && adminScreens.isNotEmpty) {
              _adminIndex = 0;
            }
          });
        }
      });
    }
  }
  
  List<Widget> _buildMainScreens() {
    final screens = <Widget>[];
    
    // Notifications - only for 'sub' (first screen)
    if (_accessibleFeatures.contains('notifications')) {
      screens.add(const NotificationsScreen());
    }
    
    // Filters - only for 'sub'
    if (_accessibleFeatures.contains('filters')) {
      screens.add(const FiltersScreen());
    }
    
    // Schedule - only for 'sub'
    if (_accessibleFeatures.contains('schedule')) {
      screens.add(const ScheduleScreen());
    }
    
    // Community - for 'sub', 'teacher', 'administration'
    if (_accessibleFeatures.contains('community')) {
      screens.add(SocialScreen(
        onNavigateToMyPage: () {
          // Find community index
          int communityIndex = 0;
          if (_accessibleFeatures.contains('notifications')) communityIndex++;
          if (_accessibleFeatures.contains('filters')) communityIndex++;
          if (_accessibleFeatures.contains('schedule')) communityIndex++;
          setState(() {
            _currentIndex = communityIndex;
            _showAdminScreen = false;
          });
        },
      ));
    }
    
    // Business Card - for 'sub', 'teacher', 'administration'
    if (_accessibleFeatures.contains('business_card')) {
      screens.add(const BusinessCardScreen());
    }
    
    return screens;
  }
  
  List<NavigationDestination> _buildMainDestinations() {
    final destinations = <NavigationDestination>[];
    
    // Notifications - only for 'sub' (first icon)
    if (_accessibleFeatures.contains('notifications')) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.bolt),
        label: 'Alerts',
      ));
    }
    
    // Filters - only for 'sub'
    if (_accessibleFeatures.contains('filters')) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.filter_list),
        label: 'Filters',
      ));
    }
    
    // Schedule - only for 'sub'
    if (_accessibleFeatures.contains('schedule')) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.calendar_today),
        label: 'Schedule',
      ));
    }
    
    // Community - for 'sub', 'teacher', 'administration'
    if (_accessibleFeatures.contains('community')) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.people),
        label: 'Community',
      ));
    }
    
    // Business Card - for 'sub', 'teacher', 'administration'
    if (_accessibleFeatures.contains('business_card')) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.badge),
        label: 'Biz Card',
      ));
    }
    
    return destinations;
  }
  
  List<NavigationDestination> _buildAdminDestinations() {
    final destinations = <NavigationDestination>[];
    
    if (_accessibleFeatures.contains('admin_approvals')) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.verified_user),
        selectedIcon: Icon(Icons.verified_user),
        label: 'Approvals',
      ));
    }
    
    if (_accessibleFeatures.contains('admin_orders')) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.shopping_cart),
        selectedIcon: Icon(Icons.shopping_cart),
        label: 'Orders',
      ));
    }
    
    if (_accessibleFeatures.contains('admin_roles')) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.admin_panel_settings),
        selectedIcon: Icon(Icons.admin_panel_settings),
        label: 'Roles',
      ));
    }

    if (_accessibleFeatures.contains('admin_promos')) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.local_offer),
        selectedIcon: Icon(Icons.local_offer),
        label: 'Promos',
      ));
    }

    if (_accessibleFeatures.contains('admin_site_improvements')) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.build_circle_outlined),
        selectedIcon: Icon(Icons.build_circle),
        label: 'Improve',
      ));
    }

    // Growth engines (3 icons, 3 pages)
    if (_accessibleFeatures.contains('admin_growth_sticky')) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.loop),
        selectedIcon: Icon(Icons.loop),
        label: 'Sticky',
      ));
    }

    if (_accessibleFeatures.contains('admin_growth_viral')) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.share),
        selectedIcon: Icon(Icons.share),
        label: 'Viral',
      ));
    }

    if (_accessibleFeatures.contains('admin_growth_paid')) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.attach_money),
        selectedIcon: Icon(Icons.attach_money),
        label: 'Paid',
      ));
    }
    
    return destinations;
  }
  
  List<Widget> _buildAdminScreens() {
    final screens = <Widget>[];
    
    if (_accessibleFeatures.contains('admin_approvals')) {
      screens.add(const PostApprovalsScreen());
    }
    
    if (_accessibleFeatures.contains('admin_orders')) {
      screens.add(const BusinessCardOrdersQueueScreen());
    }
    
    if (_accessibleFeatures.contains('admin_roles')) {
      screens.add(RoleManagementScreen(
        onRolesUpdated: () {
          // Refresh roles when they're updated
          _checkAdminStatus();
        },
      ));
    }

    if (_accessibleFeatures.contains('admin_promos')) {
      screens.add(const PromoCodesScreen());
    }

    if (_accessibleFeatures.contains('admin_site_improvements')) {
      screens.add(const SiteImprovementsScreen());
    }

    if (_accessibleFeatures.contains('admin_growth_sticky')) {
      screens.add(const StickyEngineScreen());
    }

    if (_accessibleFeatures.contains('admin_growth_viral')) {
      screens.add(const ViralEngineScreen());
    }

    if (_accessibleFeatures.contains('admin_growth_paid')) {
      screens.add(const PaidEngineScreen());
    }
    
    return screens;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRoles) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Build dynamic screens and destinations based on user roles
    final mainScreens = _buildMainScreens();
    final mainDestinations = _buildMainDestinations();
    final adminScreens = _buildAdminScreens();
    final adminDestinations = _buildAdminDestinations();
    
    return Scaffold(
      body: _showAdminScreen && adminScreens.isNotEmpty
          ? IndexedStack(
              index: _adminIndex < adminScreens.length ? _adminIndex : 0,
              children: adminScreens,
            )
          : mainScreens.isNotEmpty
              ? IndexedStack(
                  index: _currentIndex < mainScreens.length ? _currentIndex : 0,
                  children: mainScreens,
                )
              : const Center(
                  child: Text('No features available for your role'),
                ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main navigation bar (only if there are accessible features)
          if (mainDestinations.isNotEmpty)
            NavigationBar(
              selectedIndex: _showAdminScreen 
                  ? (_currentIndex < mainDestinations.length ? _currentIndex : 0)
                  : (_currentIndex < mainDestinations.length ? _currentIndex : 0),
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                  _showAdminScreen = false; // Hide admin screen when switching main tabs
                });
              },
              destinations: mainDestinations,
            ),
          // Admin navigation bar (only shown for admins with admin features)
          if (_isAdmin && adminDestinations.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: NavigationBar(
                height: 60,
                selectedIndex: _showAdminScreen 
                    ? (_adminIndex < adminDestinations.length ? _adminIndex : 0)
                    : (_adminIndex < adminDestinations.length ? _adminIndex : 0),
                onDestinationSelected: (index) {
                  setState(() {
                    _adminIndex = index;
                    _showAdminScreen = true; // Show admin screen
                  });
                },
                destinations: adminDestinations,
              ),
            ),
        ],
      ),
    );
  }
}



