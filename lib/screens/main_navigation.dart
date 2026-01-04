import 'package:flutter/material.dart';
import 'filters/filters_screen.dart';
import 'schedule/schedule_screen.dart';
import 'social/social_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const FiltersScreen(),
    const ScheduleScreen(),
    const SocialScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
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
            label: 'Social',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}



