import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'school_data_service.dart';
import 'student_action_helpers.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SchoolDataService _dataService = SchoolDataService();

  // Tab 2: Marks Entry State
  String? _selectedExamId;
  String _selectedSection = 'Section A';
  Map<String, Map<String, TextEditingController>> _marksControllers = {};
  Map<String, TextEditingController> _remarksControllers = {};
  bool _hasUnsavedMarks = false;

  // Tab 3: Report Cards State
  String? _reportExamId;
  String _reportSection = 'All Sections';

  final List<String> _sections = [
    'Section A', 'Section B', 'Section C', 'Section D'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    if (_dataService.examsList.isNotEmpty) {
      _selectedExamId = _dataService.examsList.first['id'];
      _reportExamId = _dataService.examsList.first['id'];
    }
    _initMarksControllers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeMarksControllers();
    super.dispose();
  }

  void _disposeMarksControllers() {
    for (var studentMap in _marksControllers.values) {
      for (var ctrl in studentMap.values) {
        ctrl.dispose();
      }
    }
    _marksControllers.clear();

    for (var ctrl in _remarksControllers.values) {
      ctrl.dispose();
    }
    _remarksControllers.clear();
  }

  void _initMarksControllers() {
    _disposeMarksControllers();

    if (_selectedExamId == null) return;
    int examIndex = _dataService.examsList.indexWhere((e) => e['id'] == _selectedExamId);
    if (examIndex == -1) return;

    final exam = _dataService.examsList[examIndex];
    String className = exam['className'] ?? '';
    List subjects = exam['subjects'] as List? ?? [];
    List<Map<String, String>> students = _dataService.getStudentsByClassAndSection(className, _selectedSection);

    Map<String, Map<String, TextEditingController>> newMarks = {};
    Map<String, TextEditingController> newRemarks = {};

    for (var s in students) {
      String regNo = s['regNo']!;
      var existingResult = _dataService.getStudentExamResult(_selectedExamId!, regNo);
      Map existingMarks = (existingResult != null && existingResult['marks'] != null)
          ? existingResult['marks'] as Map
          : {};

      Map<String, TextEditingController> subControllers = {};
      for (var sub in subjects) {
        String subName = sub['name']?.toString() ?? '';
        var val = existingMarks[subName];
        subControllers[subName] = TextEditingController(text: val != null ? val.toString() : '');
      }
      newMarks[regNo] = subControllers;
      newRemarks[regNo] = TextEditingController(text: existingResult?['remarks']?.toString() ?? '');
    }

    setState(() {
      _marksControllers = newMarks;
      _remarksControllers = newRemarks;
      _hasUnsavedMarks = false;
    });
  }

  void _saveAllMarks() {
    if (_selectedExamId == null) return;
    int examIndex = _dataService.examsList.indexWhere((e) => e['id'] == _selectedExamId);
    if (examIndex == -1) return;

    final exam = _dataService.examsList[examIndex];
    String className = exam['className'] ?? '';
    List<Map<String, String>> students = _dataService.getStudentsByClassAndSection(className, _selectedSection);

    for (var s in students) {
      String regNo = s['regNo']!;
      var subMap = _marksControllers[regNo];
      if (subMap == null) continue;

      Map<String, double> marks = {};
      subMap.forEach((subName, ctrl) {
        double val = double.tryParse(ctrl.text.trim()) ?? 0.0;
        marks[subName] = val;
      });

      String remarks = _remarksControllers[regNo]?.text.trim() ?? '';

      _dataService.saveExamResult(
        examId: _selectedExamId!,
        regNo: regNo,
        studentName: s['name']!,
        className: className,
        section: _selectedSection,
        marks: marks,
        remarks: remarks,
      );
    }

    setState(() {
      _hasUnsavedMarks = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All student examination marks saved and rankings updated!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // --- DIALOG: Create New Exam ---
  void _showCreateExamDialog() {
    final titleCtrl = TextEditingController(text: 'Mid Term Examination');
    String selectedClass = '1';
    String session = _dataService.schoolSettings['academicYear'] ?? '2026-2027';
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 7));

    // Default standard subjects for the exam
    List<Map<String, dynamic>> examSubjects = [
      {'name': 'English', 'totalMarks': 100.0, 'passingMarks': 40.0},
      {'name': 'Urdu', 'totalMarks': 100.0, 'passingMarks': 40.0},
      {'name': 'Mathematics', 'totalMarks': 100.0, 'passingMarks': 40.0},
      {'name': 'General Science', 'totalMarks': 100.0, 'passingMarks': 40.0},
      {'name': 'Islamiat', 'totalMarks': 50.0, 'passingMarks': 20.0},
      {'name': 'Social Studies', 'totalMarks': 50.0, 'passingMarks': 20.0},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Create New Examination', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Exam Title (e.g. Mid Term Exam) *', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedClass,
                              decoration: const InputDecoration(labelText: 'Target Class *', border: OutlineInputBorder()),
                              items: StudentActions.standardClasses.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                              onChanged: (v) => setDialogState(() => selectedClass = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(labelText: 'Academic Session', border: OutlineInputBorder()),
                              controller: TextEditingController(text: session),
                              onChanged: (v) => session = v,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Examination Subjects & Passing Criteria:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),

                      // Subjects List
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          children: [
                            ...List.generate(examSubjects.length, (index) {
                              final sub = examSubjects[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(sub['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text('Max: ${sub['totalMarks']}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text('Pass: ${sub['passingMarks']}', style: const TextStyle(fontSize: 13, color: Colors.teal)),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 20),
                                      onPressed: () {
                                        setDialogState(() {
                                          examSubjects.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const Divider(),
                            TextButton.icon(
                              onPressed: () {
                                _showAddSubjectDialog(context, (name, total, pass) {
                                  setDialogState(() {
                                    examSubjects.add({'name': name, 'totalMarks': total, 'passingMarks': pass});
                                  });
                                });
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Custom Subject'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty || examSubjects.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter an exam title and at least one subject.')),
                      );
                      return;
                    }
                    _dataService.addExam(
                      title: titleCtrl.text.trim(),
                      academicYear: session,
                      className: selectedClass,
                      subjects: examSubjects,
                      startDate: startDate.toString().split(' ')[0],
                      endDate: endDate.toString().split(' ')[0],
                    );
                    Navigator.pop(context);
                    setState(() {
                      if (_selectedExamId == null && _dataService.examsList.isNotEmpty) {
                        _selectedExamId = _dataService.examsList.last['id'];
                        _reportExamId = _selectedExamId;
                      }
                    });
                    _initMarksControllers();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('New Exam Created Successfully!'), backgroundColor: Colors.green),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  child: const Text('Create Exam', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddSubjectDialog(BuildContext context, Function(String name, double total, double pass) onAdd) {
    final nameCtrl = TextEditingController();
    final totalCtrl = TextEditingController(text: '100');
    final passCtrl = TextEditingController(text: '40');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Subject'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Subject Name *')),
              const SizedBox(height: 10),
              TextField(controller: totalCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Marks *')),
              const SizedBox(height: 10),
              TextField(controller: passCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Passing Marks *')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  double total = double.tryParse(totalCtrl.text) ?? 100.0;
                  double pass = double.tryParse(passCtrl.text) ?? 40.0;
                  onAdd(nameCtrl.text.trim(), total, pass);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // --- PDF: Generate Single or Bulk Report Cards ---
  Future<void> _printReportCards({Map<String, dynamic>? singleResult, required String examId, String? section}) async {
    int examIndex = _dataService.examsList.indexWhere((e) => e['id'] == examId);
    if (examIndex == -1) return;

    final exam = _dataService.examsList[examIndex];
    final settings = _dataService.schoolSettings;

    List<Map<String, dynamic>> resultsList;
    if (singleResult != null) {
      resultsList = [singleResult];
    } else {
      resultsList = _dataService.getExamResults(examId, section: section);
    }

    if (resultsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No exam results recorded to print report cards.')),
      );
      return;
    }

    final pdf = pw.Document();

    for (var res in resultsList) {
      String regNo = res['regNo'] ?? '';
      var activeStudent = _dataService.activeStudents.firstWhere(
        (s) => s['regNo'] == regNo,
        orElse: () => {'father': 'N/A'},
      );

      // Fetch monthly attendance summary for the student
      var attCounts = _dataService.getStudentMonthlyAttendanceCounts(regNo, DateTime.now().year, DateTime.now().month);
      int attTotal = attCounts['total'] ?? 0;
      int attPresent = attCounts['present'] ?? 0;
      double attPct = attTotal > 0 ? (attPresent / attTotal) * 100.0 : 100.0;

      Map marks = res['marks'] as Map? ?? {};
      List subjects = exam['subjects'] as List? ?? [];

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey800, width: 2),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // School Header
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          (settings['schoolName'] ?? 'SMART SCHOOL SYSTEM').toUpperCase(),
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(settings['address'] ?? '', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text('Phone: ${settings['phone'] ?? ''} | Academic Session: ${exam['academicYear'] ?? settings['academicYear']}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                        pw.SizedBox(height: 10),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blueGrey800,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            'OFFICIAL STUDENT REPORT CARD & TRANSCRIPT',
                            style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(exam['title'] ?? 'Examination', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.blueAccent700)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Divider(thickness: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 10),

                  // Student Details Grid
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfInfoRow('Student Full Name:', res['studentName'] ?? ''),
                          _buildPdfInfoRow('Father / Guardian:', activeStudent['father'] ?? 'N/A'),
                          _buildPdfInfoRow('Registration No:', regNo),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfInfoRow('Target Class:', 'Class ${res['className']} (${res['section']})'),
                          _buildPdfInfoRow('Class Position / Rank:', res['position'] ?? 'N/A'),
                          _buildPdfInfoRow('Final Status:', res['status'] ?? 'Pass'),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),

                  // Subject-wise Marks Table
                  pw.Text('Academic Performance Breakdown:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(height: 8),

                  pw.TableHelper.fromTextArray(
                    headers: ['Subject Name', 'Total Marks', 'Passing Marks', 'Obtained Marks', 'Grade', 'Remarks'],
                    data: subjects.map((sub) {
                      String subName = sub['name']?.toString() ?? '';
                      double maxM = (sub['totalMarks'] as num?)?.toDouble() ?? 100.0;
                      double passM = (sub['passingMarks'] as num?)?.toDouble() ?? 40.0;
                      double obt = (marks[subName] as num?)?.toDouble() ?? 0.0;
                      double pct = maxM > 0 ? (obt / maxM) * 100.0 : 0.0;
                      String subGrade = SchoolDataService.calculateGrade(pct);
                      String rem = obt >= passM ? 'Pass' : 'Fail';

                      return [
                        subName,
                        maxM.toStringAsFixed(0),
                        passM.toStringAsFixed(0),
                        obt.toStringAsFixed(0),
                        subGrade,
                        rem,
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    cellAlignment: pw.Alignment.center,
                    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                  ),
                  pw.SizedBox(height: 14),

                  // Overall Results Summary Box
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _buildPdfSummaryItem('Max Marks', (res['totalMax'] as num?)?.toStringAsFixed(0) ?? '0'),
                        _buildPdfSummaryItem('Obtained Marks', (res['totalObtained'] as num?)?.toStringAsFixed(0) ?? '0'),
                        _buildPdfSummaryItem('Percentage', '${((res['percentage'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)}%'),
                        _buildPdfSummaryItem('Final Grade', res['grade'] ?? 'N/A'),
                        _buildPdfSummaryItem('Result', res['status'] ?? 'Pass'),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 14),

                  // Attendance & Remarks
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Attendance Box
                      pw.Expanded(
                        flex: 1,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Attendance Record:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                              pw.SizedBox(height: 4),
                              pw.Text('Attended: $attPresent / $attTotal Days (${attPct.toStringAsFixed(0)}%)', style: const pw.TextStyle(fontSize: 8)),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      // Remarks Box
                      pw.Expanded(
                        flex: 2,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Teacher / Principal Remarks:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                (res['remarks'] != null && res['remarks'].toString().isNotEmpty)
                                    ? res['remarks']
                                    : 'Satisfactory performance. Keep working hard towards academic excellence.',
                                style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  pw.Spacer(),
                  // Signatures Footer
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        children: [
                          pw.Container(width: 130, height: 1, color: PdfColors.grey600),
                          pw.SizedBox(height: 4),
                          pw.Text('Class Teacher Signature', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Container(width: 130, height: 1, color: PdfColors.grey600),
                          pw.SizedBox(height: 4),
                          pw.Text('Exam Controller Signature', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Container(width: 130, height: 1, color: PdfColors.grey600),
                          pw.SizedBox(height: 4),
                          pw.Text('Principal / Stamp', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: singleResult != null
          ? 'ReportCard_${singleResult['regNo']}'
          : 'ReportCards_${exam['className']}_${exam['title']}',
    );
  }

  pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey800)),
          pw.SizedBox(width: 6),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dataService,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.black54,
                indicatorColor: Colors.blueAccent,
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.tune), text: 'Exam Setup'),
                  Tab(icon: Icon(Icons.edit_note), text: 'Marks Entry'),
                  Tab(icon: Icon(Icons.military_tech), text: 'Report Cards & Merit List'),
                ],
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildExamSetupTab(),
              _buildMarksEntryTab(),
              _buildReportCardsTab(),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 1: Exam Setup
  // ==========================================
  Widget _buildExamSetupTab() {
    final exams = _dataService.examsList;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Examination Schedules & Subject Configuration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showCreateExamDialog,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Create New Exam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: exams.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('No examinations scheduled yet.', style: TextStyle(color: Colors.black54, fontSize: 16)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _showCreateExamDialog,
                          child: const Text('Create Your First Exam'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: exams.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final exam = exams[index];
                      List subjects = exam['subjects'] as List? ?? [];
                      double totalMaxMarks = 0;
                      for (var sub in subjects) {
                        totalMaxMarks += (sub['totalMarks'] as num?)?.toDouble() ?? 0;
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                              child: const Icon(Icons.assignment, color: Colors.blueAccent),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(exam['title'] ?? 'Exam', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Class: Class ${exam['className']} | Session: ${exam['academicYear']}\nSubjects (${subjects.length}): ${subjects.map((s) => s['name']).join(', ')}',
                                    style: const TextStyle(color: Colors.black87, height: 1.4, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('Total Marks: ${totalMaxMarks.toStringAsFixed(0)}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () {
                                _dataService.deleteExam(exam['id']);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Exam deleted.')),
                                );
                              },
                              tooltip: 'Delete Exam',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: Marks Entry
  // ==========================================
  Widget _buildMarksEntryTab() {
    final exams = _dataService.examsList;

    if (exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_late, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Please create an Exam first in the Exam Setup tab.', style: TextStyle(color: Colors.black54, fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('Go to Exam Setup'),
            ),
          ],
        ),
      );
    }

    int currentExamIndex = exams.indexWhere((e) => e['id'] == _selectedExamId);
    if (currentExamIndex == -1 && exams.isNotEmpty) {
      _selectedExamId = exams.first['id'];
      currentExamIndex = 0;
    }
    final currentExam = currentExamIndex != -1 ? exams[currentExamIndex] : null;
    String className = currentExam?['className'] ?? '';
    List subjects = currentExam?['subjects'] as List? ?? [];
    List<Map<String, String>> students = _dataService.getStudentsByClassAndSection(className, _selectedSection);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Row(
              children: [
                // Select Exam
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedExamId,
                    decoration: const InputDecoration(labelText: 'Select Examination', border: OutlineInputBorder(), isDense: true),
                    items: exams.map((e) => DropdownMenuItem(value: e['id'] as String, child: Text('${e['title']} (Class ${e['className']})'))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedExamId = v);
                        _initMarksControllers();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Select Section
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSection,
                    decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder(), isDense: true),
                    items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedSection = v);
                        _initMarksControllers();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Save All Marks Button
                ElevatedButton.icon(
                  onPressed: _saveAllMarks,
                  icon: const Icon(Icons.save, color: Colors.white, size: 18),
                  label: Text(_hasUnsavedMarks ? 'Save All Marks *' : 'Marks Saved', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasUnsavedMarks ? Colors.blueAccent : Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Marks Input Grid / List
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: students.isEmpty
                  ? const Center(
                      child: Text('No active students found in this Class & Section.', style: TextStyle(color: Colors.black54, fontSize: 16)),
                    )
                  : ListView.separated(
                      itemCount: students.length,
                      separatorBuilder: (context, index) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final student = students[index];
                        String regNo = student['regNo']!;
                        var studentSubControllers = _marksControllers[regNo] ?? {};

                        // Calculate live totals
                        double totalObt = 0;
                        double totalMax = 0;
                        bool hasFailed = false;

                        for (var sub in subjects) {
                          String subName = sub['name']?.toString() ?? '';
                          double maxM = (sub['totalMarks'] as num?)?.toDouble() ?? 100.0;
                          double passM = (sub['passingMarks'] as num?)?.toDouble() ?? 40.0;
                          double obt = double.tryParse(studentSubControllers[subName]?.text ?? '0') ?? 0.0;

                          totalObt += obt;
                          totalMax += maxM;
                          if (obt < passM) hasFailed = true;
                        }

                        double pct = totalMax > 0 ? (totalObt / totalMax) * 100.0 : 0.0;
                        String grade = SchoolDataService.calculateGrade(pct);
                        bool isPassed = pct >= 50.0 && !hasFailed;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                                  child: Text((index + 1).toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                                ),
                                const SizedBox(width: 10),
                                Text(student['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(width: 8),
                                Text('(${student['regNo']})', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isPassed ? Colors.green : Colors.red).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: (isPassed ? Colors.green : Colors.red).withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    '${totalObt.toStringAsFixed(0)} / ${totalMax.toStringAsFixed(0)}  •  ${pct.toStringAsFixed(1)}%  •  Grade: $grade  •  ${isPassed ? "PASS" : "FAIL"}',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: isPassed ? Colors.green : Colors.red, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Inputs for each subject
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: subjects.map((sub) {
                                String subName = sub['name']?.toString() ?? '';
                                double maxM = (sub['totalMarks'] as num?)?.toDouble() ?? 100.0;
                                var ctrl = studentSubControllers[subName];

                                return SizedBox(
                                  width: 140,
                                  child: TextField(
                                    controller: ctrl,
                                    keyboardType: TextInputType.number,
                                    onChanged: (val) {
                                      setState(() {
                                        _hasUnsavedMarks = true;
                                      });
                                    },
                                    decoration: InputDecoration(
                                      labelText: '$subName (Max $maxM)',
                                      labelStyle: const TextStyle(fontSize: 11),
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: Report Cards & Merit List
  // ==========================================
  Widget _buildReportCardsTab() {
    final exams = _dataService.examsList;

    if (exams.isEmpty) {
      return const Center(child: Text('No exams found.', style: TextStyle(color: Colors.black54)));
    }

    if (_reportExamId == null && exams.isNotEmpty) {
      _reportExamId = exams.first['id'];
    }

    final rankedResults = _reportExamId != null
        ? _dataService.getExamResults(_reportExamId!, section: _reportSection)
        : <Map<String, dynamic>>[];

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter & Actions Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Row(
              children: [
                // Exam Selector
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _reportExamId,
                    decoration: const InputDecoration(labelText: 'Select Exam', border: OutlineInputBorder(), isDense: true),
                    items: exams.map((e) => DropdownMenuItem(value: e['id'] as String, child: Text('${e['title']} (Class ${e['className']})'))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _reportExamId = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Section Selector
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _reportSection,
                    decoration: const InputDecoration(labelText: 'Section Filter', border: OutlineInputBorder(), isDense: true),
                    items: ['All Sections', ..._sections].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _reportSection = v);
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Bulk Print Button
                ElevatedButton.icon(
                  onPressed: rankedResults.isEmpty
                      ? null
                      : () => _printReportCards(examId: _reportExamId!, section: _reportSection),
                  icon: const Icon(Icons.print, color: Colors.white, size: 18),
                  label: const Text('Print All Class Report Cards (PDF)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Merit List & Results Table
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: rankedResults.isEmpty
                  ? const Center(
                      child: Text('No results entered yet for this exam. Use "Marks Entry" tab to enter student marks.', style: TextStyle(color: Colors.black54, fontSize: 16)),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 20,
                          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
                          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                          columns: const [
                            DataColumn(label: Text('Rank')),
                            DataColumn(label: Text('Reg No')),
                            DataColumn(label: Text('Student Name')),
                            DataColumn(label: Text('Class & Sec')),
                            DataColumn(label: Text('Total Marks')),
                            DataColumn(label: Text('Obtained')),
                            DataColumn(label: Text('% Score')),
                            DataColumn(label: Text('Grade')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Action')),
                          ],
                          rows: List.generate(rankedResults.length, (index) {
                            final res = rankedResults[index];
                            int rank = res['rank'] ?? (index + 1);
                            double pct = (res['percentage'] as num?)?.toDouble() ?? 0.0;
                            String status = res['status'] ?? 'Pass';

                            // Badge for top 3 positions
                            Widget rankWidget;
                            if (rank == 1) {
                              rankWidget = const Chip(
                                avatar: Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                                label: Text('1st', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                                visualDensity: VisualDensity.compact,
                              );
                            } else if (rank == 2) {
                              rankWidget = const Chip(
                                avatar: Icon(Icons.emoji_events, color: Colors.grey, size: 16),
                                label: Text('2nd', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                visualDensity: VisualDensity.compact,
                              );
                            } else if (rank == 3) {
                              rankWidget = const Chip(
                                avatar: Icon(Icons.emoji_events, color: Colors.brown, size: 16),
                                label: Text('3rd', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                                visualDensity: VisualDensity.compact,
                              );
                            } else {
                              rankWidget = Text(res['position'] ?? '$rank');
                            }

                            return DataRow(
                              cells: [
                                DataCell(rankWidget),
                                DataCell(Text(res['regNo'] ?? '')),
                                DataCell(Text(res['studentName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text('Class ${res['className']} (${res['section']})')),
                                DataCell(Text((res['totalMax'] as num?)?.toStringAsFixed(0) ?? '0')),
                                DataCell(Text((res['totalObtained'] as num?)?.toStringAsFixed(0) ?? '0', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text('${pct.toStringAsFixed(1)}%')),
                                DataCell(Text(res['grade'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(
                                  Text(
                                    status,
                                    style: TextStyle(
                                      color: status == 'Pass' ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.print, color: Colors.blueAccent),
                                    tooltip: 'Print Report Card',
                                    onPressed: () => _printReportCards(singleResult: res, examId: _reportExamId!),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
