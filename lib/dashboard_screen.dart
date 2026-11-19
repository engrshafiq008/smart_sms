import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'school_data_service.dart';
import 'main.dart';
import 'admissions_screen.dart';
import 'students_screen.dart';
import 'student_attendance_screen.dart';
import 'academics_screen.dart';
import 'exams_screen.dart';
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
  final SchoolDataService _dataService = SchoolDataService();

  // Sidebar items for School Management
  final List<Map<String, dynamic>> _menuItems = [
    {'title': 'Dashboard', 'icon': Icons.dashboard},
    {'title': 'Admissions', 'icon': Icons.person_add},
    {'title': 'Students', 'icon': Icons.school},
    {'title': 'Attendance', 'icon': Icons.how_to_reg},
    {'title': 'Academics', 'icon': Icons.book},
    {'title': 'Exams & Results', 'icon': Icons.assignment},
    {'title': 'Finance & Fees', 'icon': Icons.attach_money},
    {'title': 'HR & Staff', 'icon': Icons.badge},
    {'title': 'Settings', 'icon': Icons.settings},
  ];

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return AnimatedBuilder(
      animation: _dataService,
      builder: (context, _) {
        final currentSchoolName = _dataService.schoolSettings['schoolName'] ?? 'Smart School System';

        return Scaffold(
          body: Row(
            children: [
              // Left Sidebar for Desktop & Web
              Container(
                width: 260,
                color: const Color(0xFF1E293B),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic School Brand Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.school, color: Colors.blueAccent, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentSchoolName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  'Smart SMS Portal',
                                  style: TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ],
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
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const AuthWrapper()),
                          (route) => false,
                        );
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  currentSchoolName,
                                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 14),
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
                            ? const DashboardHomeScreen()
                            : _selectedIndex == 1
                                ? const AdmissionsScreen()
                                : _selectedIndex == 2
                                    ? const StudentsScreen()
                                    : _selectedIndex == 3
                                        ? const StudentAttendanceScreen()
                                        : _selectedIndex == 4
                                            ? const AcademicsScreen()
                                            : _selectedIndex == 5
                                                ? const ExamsScreen()
                                                : _selectedIndex == 6
                                                    ? const FinanceScreen()
                                                    : _selectedIndex == 7
                                                        ? const HrScreen()
                                                        : const SettingsScreen(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
