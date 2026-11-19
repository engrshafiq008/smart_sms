import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'admissions_screen.dart';
import 'students_screen.dart';
import 'academics_screen.dart'; // <-- AcademicsScreen yahan import ho gayi
import 'finance_screen.dart';
import 'hr_screen.dart';
import 'settings_screen.dart';
import 'dashboard_home_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();

  // Sidebar items for School Management
  final List<Map<String, dynamic>> _menuItems = [
    {'title': 'Dashboard', 'icon': Icons.dashboard},
    {'title': 'Admissions', 'icon': Icons.person_add},
    {'title': 'Students', 'icon': Icons.school},
    {'title': 'Academics', 'icon': Icons.book},
    {'title': 'Finance & Fees', 'icon': Icons.attach_money},
    {'title': 'HR & Staff', 'icon': Icons.badge},
    {'title': 'Settings', 'icon': Icons.settings},
  ];

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar for Desktop
          Container(
            width: 260,
            color: const Color(0xFF1E293B),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Logo / Title Header
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      const Icon(Icons.school, color: Colors.blueAccent, size: 30),
                      const SizedBox(width: 12),
                      const Text(
                        'Smart SMS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                
                // Navigation Menu List
                Expanded(
                  child: ListView.builder(
                    itemCount: _menuItems.length,
                    itemBuilder: (context, index) {
                      final item = _menuItems[index];
                      final isSelected = _selectedIndex == index;
                      return ListTile(
                        leading: Icon(
                          item['icon'],
                          color: isSelected ? Colors.blueAccent : Colors.white70,
                        ),
                        title: Text(
                          item['title'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedTileColor: Colors.white10,
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                      );
                    },
                  ),
                ),
                
                // Logout Button at bottom
                const Divider(color: Colors.white24, height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    await _authService.signOut();
                  },
                ),
              ],
            ),
          ),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _menuItems[_selectedIndex]['title'],
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                            child: user?.photoURL == null ? const Icon(Icons.person) : null,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            user?.displayName ?? user?.email ?? 'Administrator',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Dynamic Screen View based on Selection
                Expanded(
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    child: _selectedIndex == 0
    ? const DashboardHomeScreen() // <-- Main Dashboard Home View
                    : _selectedIndex == 1
                        ? const AdmissionsScreen() // Admissions Form
                        : _selectedIndex == 2
                            ? const StudentsScreen() // Students Directory
                            : _selectedIndex == 3
                                ? const AcademicsScreen() // Academics & Timetable Module
                                : _selectedIndex == 4
                                    ? const FinanceScreen() // Finance Module
                                    : _selectedIndex == 5
                                        ? const HrScreen() // HR & Staff Management Module
                                        : _selectedIndex == 6
                                            ? const SettingsScreen() // Settings & Profile Module
                                            : Center(
                                                child: Text(
                                                  'Welcome to ${_menuItems[_selectedIndex]['title']} Module',
                                      style: const TextStyle(fontSize: 24, color: Colors.black54),
                                    ),
                                  ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}