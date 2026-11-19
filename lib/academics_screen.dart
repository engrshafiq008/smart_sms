import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'school_data_service.dart';

class AcademicsScreen extends StatefulWidget {
  const AcademicsScreen({super.key});

  @override
  State<AcademicsScreen> createState() => _AcademicsScreenState();
}

class _AcademicsScreenState extends State<AcademicsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SchoolDataService _dataService = SchoolDataService();

  final List<String> _grades = ['Nursery/KG', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'];
  final List<String> _sections = ['Section A', 'Section B', 'Section C', 'Section D'];
  final List<String> _periods = ['Period 1', 'Period 2', 'Period 3', 'Period 4', 'Period 5', 'Period 6', 'Period 7', 'Period 8', 'Period 9', 'Period 10'];
  
  // Standard Subjects List
  final List<String> _standardSubjects = [
    'Islamiat', 'English', 'Urdu', 'Pak Study', 'Social Study', 
    'General Science', 'Mathematics', 'Physics', 'Chemistry', 
    'Biology', 'Computer Science', 'General Knowledge'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Dialog: Add Teacher ---
  void _showAddTeacherDialog() {
    final nameCtrl = TextEditingController();
    final fatherCtrl = TextEditingController();
    final cnicCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: DateTime.now().toString().split(' ')[0]);
    String gender = 'Male';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Teacher / Staff Member', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Teacher Full Name *', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: gender,
                              decoration: const InputDecoration(labelText: 'Gender *', border: OutlineInputBorder()),
                              items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                              onChanged: (v) => setDialogState(() => gender = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: fatherCtrl, decoration: const InputDecoration(labelText: 'Father / Husband Name *', border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cnicCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13)],
                              decoration: const InputDecoration(labelText: 'CNIC Number (13 Digits) *', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                              decoration: const InputDecoration(labelText: 'Mobile Phone (11 Digits) *', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Residential Address *', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Joining Date (YYYY-MM-DD)', border: OutlineInputBorder())),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                      _dataService.addTeacher(
                        name: nameCtrl.text,
                        gender: gender,
                        father: fatherCtrl.text,
                        cnic: cnicCtrl.text,
                        phone: phoneCtrl.text,
                        address: addressCtrl.text,
                        joiningDate: dateCtrl.text,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teacher Added Successfully!')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  child: const Text('Save Teacher', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Dialog: Add / Edit Subject with Logic ---
  void _showAddEditSubjectDialog([Map<String, String>? existingSubject]) {
    bool isEdit = existingSubject != null;

    String selectedClass = isEdit ? existingSubject['class']! : _grades.first;
    String selectedSection = isEdit ? existingSubject['section']! : _sections.first;
    String selectedPeriod = isEdit ? existingSubject['period']! : _periods.first;
    String selectedSubject = isEdit ? existingSubject['name']! : _standardSubjects.first;
    
    // Setup Teacher List (Include "Unassigned" for empty spots)
    List<String> teacherNames = ['Unassigned'];
    teacherNames.addAll(_dataService.teachersList.map((t) => t['name']!));
    
    String selectedTeacher = isEdit ? existingSubject['teacher']! : (teacherNames.length > 1 ? teacherNames[1] : 'Unassigned');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {

            // Dynamic Subject Filtering Logic: Jo subject pehle assign ho chuka us class ko, wo dobara show na ho
            List<String> availableSubjects = _standardSubjects.where((sub) {
              bool alreadyAssigned = _dataService.academicSubjects.any((s) => 
                s['class'] == selectedClass && 
                s['section'] == selectedSection && 
                s['name'] == sub && 
                (isEdit ? s['id'] != existingSubject['id'] : true)
              );
              return !alreadyAssigned;
            }).toList();

            // If editing, make sure the current subject is still in the dropdown
            if (isEdit && !availableSubjects.contains(existingSubject['name'])) {
              availableSubjects.add(existingSubject['name']!);
            }

            if (availableSubjects.isEmpty) {
              availableSubjects = ['No Subjects Available'];
            }
            if (!availableSubjects.contains(selectedSubject)) {
              selectedSubject = availableSubjects.first;
            }

            return AlertDialog(
              title: Text(isEdit ? 'Edit Assignment' : 'Assign Subject, Class & Period', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedClass,
                              decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                              items: _grades.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                              onChanged: (v) => setDialogState(() => selectedClass = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedSection,
                              decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder()),
                              items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setDialogState(() => selectedSection = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Filtered Subject Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedSubject,
                        decoration: const InputDecoration(labelText: 'Subject Name', border: OutlineInputBorder()),
                        items: availableSubjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: availableSubjects.contains('No Subjects Available') ? null : (v) => setDialogState(() => selectedSubject = v!),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedPeriod,
                              decoration: const InputDecoration(labelText: 'Period Number', border: OutlineInputBorder()),
                              items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                              onChanged: (v) => setDialogState(() => selectedPeriod = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedTeacher,
                              decoration: const InputDecoration(labelText: 'Assign Teacher', border: OutlineInputBorder()),
                              items: teacherNames.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (v) => setDialogState(() => selectedTeacher = v!),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (selectedSubject == 'No Subjects Available') return;

                    // CONFLICT CHECK LOGIC
                    bool hasConflict = false;
                    String conflictMsg = '';

                    // 1. Check if Class+Section already has a class in this Period
                    bool classBusy = _dataService.academicSubjects.any((s) => 
                      s['class'] == selectedClass && 
                      s['section'] == selectedSection && 
                      s['period'] == selectedPeriod &&
                      (isEdit ? s['id'] != existingSubject['id'] : true)
                    );

                    if (classBusy) {
                      hasConflict = true;
                      conflictMsg = 'Class $selectedClass ($selectedSection) already has a subject assigned in $selectedPeriod!';
                    }

                    // 2. Check if Teacher is busy in another class in this Period
                    if (!hasConflict && selectedTeacher != 'Unassigned') {
                      bool teacherBusy = _dataService.academicSubjects.any((s) => 
                        s['teacher'] == selectedTeacher && 
                        s['period'] == selectedPeriod &&
                        (isEdit ? s['id'] != existingSubject['id'] : true)
                      );
                      
                      if (teacherBusy) {
                        hasConflict = true;
                        conflictMsg = '$selectedTeacher is already teaching another class in $selectedPeriod!';
                      }
                    }

                    // Show error if conflict exists
                    if (hasConflict) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(conflictMsg), backgroundColor: Colors.redAccent));
                      return;
                    }

                    // Automatic Code Generation (e.g. PHY-101)
                    String subCode = '${selectedSubject.substring(0, 3).toUpperCase()}-101';

                    if (isEdit) {
                      final updatedData = Map<String, String>.from(existingSubject!);
                      updatedData['name'] = selectedSubject;
                      updatedData['code'] = subCode;
                      updatedData['class'] = selectedClass;
                      updatedData['section'] = selectedSection;
                      updatedData['period'] = selectedPeriod;
                      updatedData['teacher'] = selectedTeacher;
                      _dataService.updateSubject(existingSubject['id']!, updatedData);
                    } else {
                      _dataService.addSubject(
                        name: selectedSubject,
                        code: subCode,
                        className: selectedClass,
                        section: selectedSection,
                        period: selectedPeriod,
                        teacher: selectedTeacher,
                      );
                    }
                    
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved Successfully!'), backgroundColor: Colors.green));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: Text(isEdit ? 'Update' : 'Save Curriculum', style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- PDF Print: Master Timetable ---
  Future<void> _printMasterTimetable() async {
    if (_dataService.academicSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No timetable data to print.')));
      return;
    }
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SMART SCHOOL SYSTEM', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('Complete School Master Timetable', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['Subject Code', 'Subject Name', 'Class & Sec', 'Period', 'Assigned Teacher'],
                data: _dataService.academicSubjects.map((s) => [
                  s['code'] ?? '',
                  s['name'] ?? '',
                  'Class ${s['class']} (${s['section']})',
                  s['period'] ?? '',
                  s['teacher'] ?? '',
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueAccent),
                cellPadding: const pw.EdgeInsets.all(6),
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Master_Timetable');
  }

  // --- PDF Print: Teacher Timetable ---
  Future<void> _printTeacherTimetable(String teacherName) async {
    final teacherSubjects = _dataService.academicSubjects.where((s) => s['teacher'] == teacherName).toList();
    if (teacherSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$teacherName has no assigned periods.')));
      return;
    }
    
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SMART SCHOOL SYSTEM', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Teacher Schedule & Routine: $teacherName', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 15),
                pw.Table.fromTextArray(
                  headers: ['Period', 'Subject Name', 'Class & Section', 'Subject Code'],
                  data: teacherSubjects.map((s) => [
                    s['period'] ?? '',
                    s['name'] ?? '',
                    'Class ${s['class']} (${s['section']})',
                    s['code'] ?? '',
                  ]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                  cellPadding: const pw.EdgeInsets.all(8),
                ),
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Timetable_$teacherName');
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
                  controller: _tabController,
                  labelColor: Colors.blueAccent,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: Colors.blueAccent,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(icon: const Icon(Icons.badge), text: "Staff & Teachers (${_dataService.teachersList.length})"),
                    Tab(icon: const Icon(Icons.book), text: "Curriculum & Subjects (${_dataService.academicSubjects.length})"),
                    Tab(icon: const Icon(Icons.schedule), text: "Timetable & Routine"),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStaffTab(),
                    _buildCurriculumTab(),
                    _buildTimetableTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 1: Staff & Teachers ---
  Widget _buildStaffTab() {
    final staff = _dataService.teachersList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Teachers & Staff Directory', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: _showAddTeacherDialog,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Add Teacher', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
            child: staff.isEmpty
                ? const Center(child: Text('No teachers added yet.', style: TextStyle(color: Colors.black54)))
                : ListView.separated(
                    itemCount: staff.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final t = staff[index];
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.blueAccent.withOpacity(0.1), child: const Icon(Icons.person, color: Colors.blueAccent)),
                        title: Text('${t['name']} (${t['id']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Father: ${t['father']} | Phone: ${t['phone']}\nCNIC: ${t['cnic']} | Address: ${t['address']}'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.print, color: Colors.teal),
                              onPressed: () => _printTeacherTimetable(t['name']!),
                              tooltip: 'Print Teacher Timetable',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _dataService.deleteTeacher(t['id']!),
                              tooltip: 'Delete Teacher',
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
  }

  // --- TAB 2: Curriculum & Subject Assignment ---
  Widget _buildCurriculumTab() {
    final subjects = _dataService.academicSubjects;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Curriculum, Classes & Teacher Assignment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () => _showAddEditSubjectDialog(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Assign Subject', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
            child: subjects.isEmpty
                ? const Center(child: Text('No subjects assigned yet.', style: TextStyle(color: Colors.black54)))
                : ListView.separated(
                    itemCount: subjects.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final sub = subjects[index];
                      bool isUnassigned = sub['teacher'] == 'Unassigned';

                      return ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.teal.withOpacity(0.1), child: const Icon(Icons.book, color: Colors.teal)),
                        title: Text('${sub['name']} (${sub['code']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
                            children: [
                              TextSpan(text: 'Target Class: Class ${sub['class']} (${sub['section']}) | ${sub['period']}\nAssigned Teacher: '),
                              TextSpan(text: isUnassigned ? 'Unassigned (Please Assign)' : sub['teacher'], style: TextStyle(color: isUnassigned ? Colors.redAccent : Colors.black, fontWeight: isUnassigned ? FontWeight.bold : FontWeight.normal)),
                            ]
                          )
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueAccent),
                              onPressed: () => _showAddEditSubjectDialog(sub),
                              tooltip: 'Edit Assignment',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _dataService.deleteSubject(sub['id']!),
                              tooltip: 'Delete Assignment',
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
  }

  // --- TAB 3: Timetable & Routine Printing ---
  Widget _buildTimetableTab() {
    final teachers = _dataService.teachersList;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Timetable & Schedule Printing Hub', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _printMasterTimetable,
                icon: const Icon(Icons.print, color: Colors.white),
                label: const Text('Print Master Timetable', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Select a teacher to print their individual timetable/routine for distribution:', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          Expanded(
            child: teachers.isEmpty
                ? const Center(child: Text('No teachers available.'))
                : ListView.separated(
                    itemCount: teachers.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final t = teachers[index];
                      return ListTile(
                        leading: const Icon(Icons.person, color: Colors.blueAccent),
                        title: Text(t['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Phone: ${t['phone']} | CNIC: ${t['cnic']}'),
                        trailing: ElevatedButton.icon(
                          onPressed: () => _printTeacherTimetable(t['name']!),
                          icon: const Icon(Icons.print, size: 16, color: Colors.white),
                          label: const Text('Print Routine', style: TextStyle(fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}