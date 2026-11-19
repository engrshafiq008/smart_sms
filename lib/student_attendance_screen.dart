import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'school_data_service.dart';
import 'student_action_helpers.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SchoolDataService _dataService = SchoolDataService();

  // Tab 1: Daily Marking State
  DateTime _selectedDate = DateTime.now();
  String _selectedClass = '1';
  String _selectedSection = 'Section A';
  Map<String, String> _dailyAttendanceMap = {};
  bool _hasUnsavedChanges = false;

  // Tab 2: Monthly Report State
  String _reportClass = '1';
  String _reportSection = 'Section A';
  int _reportYear = DateTime.now().year;
  int _reportMonth = DateTime.now().month;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  final List<String> _sections = [
    'Section A', 'Section B', 'Section C', 'Section D'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDailyAttendance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _loadDailyAttendance() {
    String dateStr = _formatDate(_selectedDate);
    final saved = _dataService.getStudentAttendance(dateStr, _selectedClass, _selectedSection);
    final students = _dataService.getStudentsByClassAndSection(_selectedClass, _selectedSection);

    Map<String, String> newMap = {};
    for (var s in students) {
      String regNo = s['regNo']!;
      newMap[regNo] = saved[regNo] ?? 'Present'; // Default to Present for quick convenience
    }

    setState(() {
      _dailyAttendanceMap = newMap;
      _hasUnsavedChanges = false;
    });
  }

  void _markAll(String status) {
    setState(() {
      for (var regNo in _dailyAttendanceMap.keys) {
        _dailyAttendanceMap[regNo] = status;
      }
      _hasUnsavedChanges = true;
    });
  }

  void _saveAttendance() {
    String dateStr = _formatDate(_selectedDate);
    _dataService.saveStudentAttendance(dateStr, _selectedClass, _selectedSection, _dailyAttendanceMap);
    setState(() {
      _hasUnsavedChanges = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Attendance for Class $_selectedClass ($_selectedSection) on $dateStr saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadDailyAttendance();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Present':
        return Colors.green;
      case 'Absent':
        return Colors.red;
      case 'Leave':
        return Colors.orange;
      case 'Late':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // --- PDF EXPORT: Monthly Attendance Sheet ---
  Future<void> _printMonthlyAttendanceSheet() async {
    final reportData = _dataService.getClassMonthlyAttendanceReport(
      className: _reportClass,
      section: _reportSection,
      year: _reportYear,
      month: _reportMonth,
    );

    if (reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No student records found for the selected class and section.')),
      );
      return;
    }

    final settings = _dataService.schoolSettings;
    String monthName = _months[_reportMonth - 1];

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        (settings['schoolName'] ?? 'SMART SCHOOL SYSTEM').toUpperCase(),
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                      ),
                      pw.Text(settings['address'] ?? '', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Phone: ${settings['phone'] ?? ''} | Session: ${settings['academicYear'] ?? ''}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blueAccent,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'MONTHLY ATTENDANCE REGISTER',
                      style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 8),

              // Filter details banner
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Month: $monthName $_reportYear', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text('Class: Class $_reportClass ($_reportSection)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text('Total Students: ${reportData.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                ],
              ),
              pw.SizedBox(height: 12),

              // Attendance Table
              pw.Expanded(
                child: pw.TableHelper.fromTextArray(
                  headers: [
                    'Sr#',
                    'Reg No',
                    'Student Name',
                    'Father Name',
                    'Total Days',
                    'Present',
                    'Absent',
                    'Leave',
                    'Late',
                    '% Attendance'
                  ],
                  data: List.generate(reportData.length, (index) {
                    final item = reportData[index];
                    double pct = (item['percentage'] as num?)?.toDouble() ?? 0.0;
                    return [
                      (index + 1).toString(),
                      item['regNo'] ?? '',
                      item['name'] ?? '',
                      item['father'] ?? '',
                      item['totalDays'].toString(),
                      item['present'].toString(),
                      item['absent'].toString(),
                      item['leave'].toString(),
                      item['late'].toString(),
                      '${pct.toStringAsFixed(1)}%',
                    ];
                  }),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                ),
              ),

              pw.SizedBox(height: 20),
              // Footer Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 160, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      pw.Text('Class In-Charge Signature', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Text('Generated: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.Column(
                    children: [
                      pw.Container(width: 160, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      pw.Text('Principal / Headmaster Signature', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Attendance_${_reportClass}_${_reportSection}_${monthName}_$_reportYear',
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
                  Tab(icon: Icon(Icons.check_circle_outline), text: 'Mark Daily Attendance'),
                  Tab(icon: Icon(Icons.assessment_outlined), text: 'Monthly Attendance Report'),
                ],
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildDailyAttendanceTab(),
              _buildMonthlyReportTab(),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 1: Mark Daily Attendance
  // ==========================================
  Widget _buildDailyAttendanceTab() {
    final students = _dataService.getStudentsByClassAndSection(_selectedClass, _selectedSection);

    // Compute live counters
    int presentCount = 0;
    int absentCount = 0;
    int leaveCount = 0;
    int lateCount = 0;

    for (var s in students) {
      String status = _dailyAttendanceMap[s['regNo']] ?? 'Present';
      if (status == 'Present') presentCount++;
      if (status == 'Absent') absentCount++;
      if (status == 'Leave') leaveCount++;
      if (status == 'Late') lateCount++;
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter & Action Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Date Selector
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.blueAccent, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Date: ${_formatDate(_selectedDate)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_drop_down, color: Colors.black54),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Class Dropdown
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedClass,
                        decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder(), isDense: true),
                        items: StudentActions.standardClasses.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedClass = v);
                            _loadDailyAttendance();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Section Dropdown
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSection,
                        decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder(), isDense: true),
                        items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedSection = v);
                            _loadDailyAttendance();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Quick Toggle: Mark All Present
                    ElevatedButton.icon(
                      onPressed: () => _markAll('Present'),
                      icon: const Icon(Icons.done_all, color: Colors.white, size: 18),
                      label: const Text('Mark All Present', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Save Button
                    ElevatedButton.icon(
                      onPressed: _saveAttendance,
                      icon: const Icon(Icons.save, color: Colors.white, size: 18),
                      label: Text(_hasUnsavedChanges ? 'Save Changes *' : 'Saved', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasUnsavedChanges ? Colors.blueAccent : Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Live Summary Counters
                Row(
                  children: [
                    _buildSummaryBadge('Total: ${students.length}', Colors.blueGrey),
                    const SizedBox(width: 8),
                    _buildSummaryBadge('Present: $presentCount', Colors.green),
                    const SizedBox(width: 8),
                    _buildSummaryBadge('Absent: $absentCount', Colors.red),
                    const SizedBox(width: 8),
                    _buildSummaryBadge('Leave: $leaveCount', Colors.orange),
                    const SizedBox(width: 8),
                    _buildSummaryBadge('Late: $lateCount', Colors.blue),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Students Attendance Register List
          Expanded(
            child: Container(
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: students.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final student = students[index];
                        String regNo = student['regNo']!;
                        String currentStatus = _dailyAttendanceMap[regNo] ?? 'Present';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(currentStatus).withValues(alpha: 0.15),
                            child: Text(
                              (index + 1).toString(),
                              style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(currentStatus)),
                            ),
                          ),
                          title: Text(student['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Text('RegNo: $regNo | Father: ${student['father']} | Class: ${student['class']} (${student['section']})'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: ['Present', 'Absent', 'Leave', 'Late'].map((status) {
                              bool isSelected = currentStatus == status;
                              Color color = _getStatusColor(status);

                              return Padding(
                                padding: const EdgeInsets.only(left: 6.0),
                                child: ChoiceChip(
                                  label: Text(
                                    status,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : color,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: color,
                                  backgroundColor: color.withValues(alpha: 0.08),
                                  side: BorderSide(color: isSelected ? color : color.withValues(alpha: 0.3)),
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _dailyAttendanceMap[regNo] = status;
                                        _hasUnsavedChanges = true;
                                      });
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  // ==========================================
  // TAB 2: Monthly Attendance Report
  // ==========================================
  Widget _buildMonthlyReportTab() {
    final reportData = _dataService.getClassMonthlyAttendanceReport(
      className: _reportClass,
      section: _reportSection,
      year: _reportYear,
      month: _reportMonth,
    );

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
                // Month Dropdown
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    initialValue: _reportMonth,
                    decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder(), isDense: true),
                    items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_months[i]))),
                    onChanged: (v) {
                      if (v != null) setState(() => _reportMonth = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Year Dropdown
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    initialValue: _reportYear,
                    decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder(), isDense: true),
                    items: [2024, 2025, 2026, 2027, 2028].map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _reportYear = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Class Dropdown
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _reportClass,
                    decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder(), isDense: true),
                    items: StudentActions.standardClasses.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _reportClass = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Section Dropdown
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _reportSection,
                    decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder(), isDense: true),
                    items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _reportSection = v);
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Print Attendance Sheet Button
                ElevatedButton.icon(
                  onPressed: _printMonthlyAttendanceSheet,
                  icon: const Icon(Icons.print, color: Colors.white, size: 18),
                  label: const Text('Print Attendance Sheet', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Monthly Data Table View
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: reportData.isEmpty
                  ? const Center(
                      child: Text('No attendance records or students found for this period.', style: TextStyle(color: Colors.black54, fontSize: 16)),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 24,
                          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
                          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                          columns: const [
                            DataColumn(label: Text('Sr#')),
                            DataColumn(label: Text('Reg No')),
                            DataColumn(label: Text('Student Name')),
                            DataColumn(label: Text('Father Name')),
                            DataColumn(label: Text('Total Marked')),
                            DataColumn(label: Text('Present')),
                            DataColumn(label: Text('Absent')),
                            DataColumn(label: Text('Leave')),
                            DataColumn(label: Text('Late')),
                            DataColumn(label: Text('% Attendance')),
                          ],
                          rows: List.generate(reportData.length, (index) {
                            final row = reportData[index];
                            double pct = (row['percentage'] as num?)?.toDouble() ?? 0.0;
                            Color pctColor = pct >= 80 ? Colors.green : (pct >= 60 ? Colors.orange : Colors.red);

                            return DataRow(
                              cells: [
                                DataCell(Text((index + 1).toString())),
                                DataCell(Text(row['regNo'] ?? '')),
                                DataCell(Text(row['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text(row['father'] ?? '')),
                                DataCell(Text(row['totalDays'].toString())),
                                DataCell(Text(row['present'].toString(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                                DataCell(Text(row['absent'].toString(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                                DataCell(Text(row['leave'].toString(), style: const TextStyle(color: Colors.orange))),
                                DataCell(Text(row['late'].toString(), style: const TextStyle(color: Colors.blue))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 50,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: pct / 100.0,
                                            backgroundColor: Colors.grey.shade200,
                                            color: pctColor,
                                            minHeight: 6,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: pctColor)),
                                    ],
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
