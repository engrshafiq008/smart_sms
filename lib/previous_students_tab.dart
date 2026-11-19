import 'package:flutter/material.dart';
import 'school_data_service.dart';
import 'student_action_helpers.dart';

class PreviousStudentsTab extends StatefulWidget {
  const PreviousStudentsTab({super.key});

  @override
  State<PreviousStudentsTab> createState() => _PreviousStudentsTabState();
}

class _PreviousStudentsTabState extends State<PreviousStudentsTab> {
  final SchoolDataService _dataService = SchoolDataService();
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  String _selectedYearFilter = 'All Years';
  String _selectedClassFilter = 'All Classes';
  String _selectedSectionFilter = 'All Sections';

  // Classes List (Nursery/KG to 12)
  final List<String> _classList = [
    'All Classes',
    'Nursery/KG',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
  ];

  final List<String> _sectionList = ['All Sections', 'Section A', 'Section B', 'Section C', 'Section D'];

  // Generate Years from 1947 to 3047
  List<String> _getYearsList() {
    List<String> years = ['All Years'];
    for (int i = 1947; i <= 3047; i++) {
      years.add(i.toString());
    }
    return years;
  }

  @override
  Widget build(BuildContext context) {
    final availableYears = _getYearsList();

    return AnimatedBuilder(
      animation: _dataService,
      builder: (context, child) {
        final list = _dataService.previousStudents.where((s) {
          final q = _searchQuery.toLowerCase();
          
          // Search query check (Admission / RegNo, Name, Father Name, Phone)
          bool matchesSearch = q.isEmpty ||
              (s['regNo'] ?? '').toLowerCase().contains(q) ||
              (s['name'] ?? '').toLowerCase().contains(q) ||
              (s['father'] ?? '').toLowerCase().contains(q) ||
              (s['phone'] ?? '').toLowerCase().contains(q);

          // Year filter check based on exitDate
          String studentYear = '';
          if (s['exitDate'] != null && s['exitDate']!.isNotEmpty) {
            studentYear = s['exitDate']!.split('-')[0];
          }
          bool matchesYear = _selectedYearFilter == 'All Years' || studentYear == _selectedYearFilter;

          // Class filter check
          bool matchesClass = _selectedClassFilter == 'All Classes' || s['class'] == _selectedClassFilter;

          // Section filter check
          bool matchesSection = _selectedSectionFilter == 'All Sections' || s['section'] == _selectedSectionFilter;

          return matchesSearch && matchesYear && matchesClass && matchesSection;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Previous / Left Students Record Archive', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 16),

            // Filters Row (Year, Class, Section)
            Row(
              children: [
                // Year Filter Dropdown (1947 to 3047)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedYearFilter,
                    decoration: InputDecoration(
                      labelText: 'Filter by Year',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      isDense: true,
                    ),
                    items: availableYears.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                    onChanged: (v) => setState(() => _selectedYearFilter = v!),
                  ),
                ),
                const SizedBox(width: 12),

                // Class Filter Dropdown (Nursery/KG to 12)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedClassFilter,
                    decoration: InputDecoration(
                      labelText: 'Filter by Class',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      isDense: true,
                    ),
                    items: _classList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _selectedClassFilter = v!),
                  ),
                ),
                const SizedBox(width: 12),

                // Section Filter Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSectionFilter,
                    decoration: InputDecoration(
                      labelText: 'Filter by Section',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      isDense: true,
                    ),
                    items: _sectionList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _selectedSectionFilter = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar for Admission Number / Reg No, Name, etc.
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by Admission Number / Reg No, Student Name, Father Name...',
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // List Display Container
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
                child: list.isEmpty
                    ? const Center(child: Text('No matching previous/left student records found.', style: TextStyle(color: Colors.black54)))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final student = list[index];
                          int totalFine = StudentActions.calculateTotalFine(student['fines']);

                          return ListTile(
                            leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.person_off, color: Colors.white)),
                            title: Row(
                              children: [
                                Text('${student['name']} (${student['regNo']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(student['exitReason'] ?? 'Left', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                                  backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'Father: ${student['father']} | Class: ${student['class']} (${student['section']})\nExit Date: ${student['exitDate']} | Dues: Rs. $totalFine ${totalFine > 0 ? "" : "(Clear)"}',
                              style: const TextStyle(height: 1.3),
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.monetization_on, color: Colors.orange),
                                  onPressed: () => StudentActions.showFineDialog(context, student, false),
                                  tooltip: 'Manage Fines',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.card_membership, color: Colors.blueAccent),
                                  onPressed: () => StudentActions.printLeavingCertificate(student),
                                  tooltip: 'Print School Leaving Certificate',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.restore, color: Colors.green),
                                  onPressed: () {
                                    _dataService.restoreStudent(student['regNo']!);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${student['name']} Retained to Active Directory!')));
                                  },
                                  tooltip: 'Retain / Restore Student',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                  onPressed: () {
                                    _dataService.deletePermanently(student['regNo']!);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record Permanently Deleted')));
                                  },
                                  tooltip: 'Delete Permanently',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}