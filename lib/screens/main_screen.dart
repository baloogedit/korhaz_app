import 'package:flutter/material.dart';
import 'package:korhaz_app/tabs/home_tab.dart';
import 'package:korhaz_app/tabs/program_tab.dart';
import 'package:korhaz_app/tabs/profile_tab.dart';
import 'package:korhaz_app/constants/colors.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // These are the 3 tabs that the bottom navigation will switch between
  final List<Widget> _tabs = [
    const HomeTab(),
    const ProgramTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgTeal, // Light greyish background
      body: _tabs[_currentIndex],
      
      // Modern Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppColors.cardWhite,
          indicatorColor: AppColors.navIndicator,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.primaryTeal),
              label: 'Főoldal',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_month, color: AppColors.primaryTeal),
              label: 'Progr.',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.primaryTeal),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}