import 'package:flutter/material.dart';
import 'school_data_service.dart';
import 'student_action_helpers.dart';

class ActiveStudentsTab extends StatefulWidget {
  const ActiveStudentsTab({super.key});

  @override
  State<ActiveStudentsTab> createState() => _ActiveStudentsTabState();
}

class _ActiveStudentsTabState extends State<ActiveStudentsTab> {
  final SchoolDataService _dataService = SchoolDataService();
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedClassFilter = 'All Classes';
  String _selectedSectionFilter = 'All Sections';
  String _searchQuery = '';

  // Class list exactly in arranged order
  final List<String> _classList = [
    'All Classes',
    'Nursery/KG',
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',
  ];

  final List<String> _sectionList = ['All Sections', 'Section A', 'Section B', 'Section C', 'Section D'];

  // Smart count logic
  int _getClassCount(String c) {
    if (c == 'All Classes') return _dataService.activeStudents.length;
    String filterClass = c.replaceAll('Class ', '').trim();
    
    return _dataService.activeStudents.where((s) {
      String dbClass = (s['class'] ?? '').replaceAll('Class ', '').trim();
      return dbClass == filterClass;
    }).length;
  }

  int _getSectionCount(String s) {
    return _dataService.activeStudents.where((st) {
      String dbClass = (st['class'] ?? '').replaceAll('Class ', '').trim();
      String filterClass = _selectedClassFilter.replaceAll('Class ', '').trim();
      
      bool matchesClass = (_selectedClassFilter == 'All Classes' || dbClass == filterClass);
      bool matchesSection = (s == 'All Sections' || st['section'] == s);
      return matchesClass && matchesSection;
    }).length;
  }

  void _showBulkPromotionDialog() {
    String fromClass = '1';
    String toClass = '2';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Bulk Promote Students', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select source and destination class for promotion.'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: fromClass,
                    decoration: const InputDecoration(labelText: 'Promote From Class', border: OutlineInputBorder()),
                    items: StudentActions.standardClasses.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                    onChanged: (v) => setDialogState(() => fromClass = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: toClass,
                    decoration: const InputDecoration(labelText: 'Promote To Class', border: OutlineInputBorder()),
                    items: StudentActions.standardClasses.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                    onChanged: (v) => setDialogState(() => toClass = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    int count = 0;
                    for (var student in _dataService.activeStudents) {
                      String dbClass = (student['class'] ?? '').replaceAll('Class ', '').trim();
                      if (dbClass == fromClass) {
                        student['class'] = toClass;
                        count++;
                      }
                    }
                    _dataService.notifyListeners();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Successfully promoted $count students!'), backgroundColor: Colors.green),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Confirm Promotion', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dataService,
      builder: (context, child) {
        final filteredList = _dataService.getStudentsByClassAndSection(_selectedClassFilter, _selectedSectionFilter);
        final finalStudentList = filteredList.where((s) {
          final q = _searchQuery.toLowerCase();
          return (s['name'] ?? '').toLowerCase().contains(q) || 
                 (s['regNo'] ?? '').toLowerCase().contains(q) || 
                 (s['father'] ?? '').toLowerCase().contains(q) ||
                 (s['phone'] ?? '').toLowerCase().contains(q);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Action Buttons
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Text('Active Students (${finalStudentList.length})', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showBulkPromotionDialog,
                      icon: const Icon(Icons.upgrade, color: Colors.white, size: 18),
                      label: const Text('Bulk Promote', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (finalStudentList.isNotEmpty) {
                          String printClass = _selectedClassFilter == 'All Classes' ? _selectedClassFilter : 'Class $_selectedClassFilter';
                          StudentActions.printDirectorySheet(finalStudentList, printClass, _selectedSectionFilter);
                        }
                      },
                      icon: const Icon(Icons.print, color: Colors.white, size: 18),
                      label: const Text('Print Sheet', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Dropdown Filters Row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(12), 
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedClassFilter,
                      decoration: const InputDecoration(
                        labelText: 'Filter by Class', 
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school, color: Colors.blueAccent),
                      ),
                      items: _classList.map((c) {
                        String displayName = c == 'All Classes' ? c : (c == 'Nursery/KG' ? c : 'Class $c');
                        int count = _getClassCount(c);
                        return DropdownMenuItem(value: c, child: Text('$displayName ($count)'));
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedClassFilter = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSectionFilter,
                      decoration: const InputDecoration(
                        labelText: 'Filter by Section', 
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label, color: Colors.teal),
                      ),
                      items: _sectionList.map((s) {
                        int count = _getSectionCount(s);
                        return DropdownMenuItem(value: s, child: Text('$s ($count)'));
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedSectionFilter = v!),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _searchController, 
              onChanged: (val) => setState(() => _searchQuery = val), 
              decoration: InputDecoration(
                hintText: 'Search by Admission/Reg No, Student Name, Father Name, Phone...', 
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent), 
                filled: true, 
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
              ),
            ),
            const SizedBox(height: 16),

            // Students List View (Scrollable)
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))]),
                child: finalStudentList.isEmpty
                    ? const Center(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group_off, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No active students found based on the selected filters.', style: TextStyle(color: Colors.black54, fontSize: 16)),
                        ],
                      ))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: finalStudentList.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 60, endIndent: 20),
                        itemBuilder: (context, index) {
                          final student = finalStudentList[index];
                          int totalFine = StudentActions.calculateTotalFine(student['fines']);
                          String displayClass = (student['class'] ?? '').replaceAll('Class ', '').trim();

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.blueAccent.withOpacity(0.1),
                              child: const Icon(Icons.person, color: Colors.blueAccent),
                            ),
                            title: Text(student['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text('RegNo: ${student['regNo']} | Class: $displayClass (${student['section']})\nFather: ${student['father']} | Phone: ${student['phone']}', style: const TextStyle(height: 1.4)),
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (totalFine > 0) 
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                                    child: Text('Fine: Rs.$totalFine', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                Tooltip(
                                  message: 'Apply / Manage Penalty',
                                  child: IconButton(
                                    icon: const Icon(Icons.monetization_on, color: Colors.orange), 
                                    onPressed: () => StudentActions.showFineDialog(context, student, true),
                                  ),
                                ),
                                Tooltip(
                                  message: 'Edit Student Details',
                                  child: IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blueAccent), 
                                    onPressed: () => StudentActions.showEditDialog(context, student, _sectionList),
                                  ),
                                ),
                                Tooltip(
                                  message: 'Transfer Out / Left Student',
                                  child: IconButton(
                                    icon: const Icon(Icons.no_accounts, color: Colors.redAccent), 
                                    onPressed: () => StudentActions.showTransferDialog(context, student),
                                  ),
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