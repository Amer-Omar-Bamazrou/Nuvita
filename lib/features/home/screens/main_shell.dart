import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import '../../../core/theme/app_colors.dart';
import 'home_screen.dart';
import '../../tracking/screens/tracking_screen.dart';
import '../../history/screens/history_screen.dart';
import '../../profile/screens/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // IndexedStack keeps all screens alive — state survives tab switches
  static const _screens = [
    HomeScreen(),
    TrackingScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    // Divider provides a clean 1px separator without a shadow/elevation
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, thickness: 1, color: AppColors.divider),
        BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: const Color(0xFF9AA3AB),
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(IconlyBold.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(IconlyBold.chart),
              label: 'Tracking',
            ),
            BottomNavigationBarItem(
              icon: Icon(IconlyBold.activity),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(IconlyBold.profile),
              label: 'Profile',
            ),
          ],
        ),
      ],
    );
  }
}
