import 'package:flutter/material.dart';
import 'school_data_service.dart';
import 'active_students_tab.dart';
import 'previous_students_tab.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> with SingleTickerProviderStateMixin {
  late TabController _directoryTabController;
  final SchoolDataService _dataService = SchoolDataService();

  @override
  void initState() {
    super.initState();
    _directoryTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _directoryTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dataService,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                child: TabBar(
                  controller: _directoryTabController,
                  labelColor: Colors.blueAccent,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: Colors.blueAccent,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(icon: const Icon(Icons.people), text: "Active Students (${_dataService.activeStudents.length})"),
                    Tab(icon: const Icon(Icons.history), text: "Previous / Left Students (${_dataService.previousStudents.length})"),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: TabBarView(
                  controller: _directoryTabController,
                  children: const [
                    ActiveStudentsTab(),
                    PreviousStudentsTab(),
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