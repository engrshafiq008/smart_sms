import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'school_data_service.dart';

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  final SchoolDataService _dataService = SchoolDataService();

  final List<String> _classes = ['Nursery/KG', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'];
  final List<String> _sections = ['Section A', 'Section B', 'Section C', 'Section D'];
  final List<String> _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  List<String> _getYearsList() {
    List<String> years = [];
    for (int i = 2024; i <= 2040; i++) {
      years.add(i.toString());
    }
    return years;
  }

  String _getMonthNumber(String monthName) {
    int index = _months.indexOf(monthName) + 1;
    return index.toString().padLeft(2, '0');
  }

  // ==========================================
  // ACTION 1: Register New Student Dialog
  // ==========================================
  void _showRegisterStudentDialog() {
    final nameCtrl = TextEditingController();
    final fatherCtrl = TextEditingController();
    final cnicCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    
    String gender = 'Male';
    String selectedClass = '1';
    String selectedSection = 'Section A';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Quick Student Registration', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Student Full Name *', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedClass,
                              decoration: const InputDecoration(labelText: 'Assign Class', border: OutlineInputBorder()),
                              items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c == 'Nursery/KG' ? c : 'Class $c'))).toList(),
                              onChanged: (v) => setDialogState(() => selectedClass = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedSection,
                              decoration: const InputDecoration(labelText: 'Assign Section', border: OutlineInputBorder()),
                              items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setDialogState(() => selectedSection = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: gender,
                              decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                              items: ['Male', 'Female'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                              onChanged: (v) => setDialogState(() => gender = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: fatherCtrl, decoration: const InputDecoration(labelText: 'Father Name *', border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                              decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: cnicCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13)],
                              decoration: const InputDecoration(labelText: 'B-Form / CNIC', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Residential Address', border: OutlineInputBorder())),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty && fatherCtrl.text.isNotEmpty) {
                      _dataService.enrollStudent(
                        name: nameCtrl.text,
                        gender: gender,
                        grade: selectedClass,
                        section: selectedSection,
                        father: fatherCtrl.text,
                        cnic: cnicCtrl.text,
                        phone: phoneCtrl.text,
                        address: addressCtrl.text,
                        enrollmentDate: DateTime.now().toString().split(' ')[0],
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${nameCtrl.text} Registered Successfully!'), backgroundColor: Colors.green));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  child: const Text('Register Student', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // ACTION 2: Generate Fee Voucher Dialog
  // ==========================================
  void _showGenerateVoucherDialog() {
    String selectedClass = '1';
    String selectedSection = 'Section A';
    String selectedYear = DateTime.now().year.toString();
    String selectedMonth = _months[DateTime.now().month - 1]; // Current Month Default
    
    Map<String, String>? selectedStudent;

    final tuitionCtrl = TextEditingController(text: '3000');
    final admissionCtrl = TextEditingController(text: '0');
    final fineCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            // Auto-update due date string based on selected month/year
            String monthNum = _getMonthNumber(selectedMonth);
            String autoDueDate = '$selectedYear-$monthNum-10';
            
            // Fetch students based on current selection
            List<Map<String, String>> availableStudents = _dataService.getStudentsByClassAndSection(selectedClass, selectedSection);
            
            // Ensure selected student is valid for current list, otherwise reset
            if (selectedStudent != null && !availableStudents.any((s) => s['regNo'] == selectedStudent!['regNo'])) {
              selectedStudent = null;
            }

            return AlertDialog(
              title: const Text('Quick Fee Voucher Generation', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 550,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Class & Section Filters
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedClass,
                              decoration: const InputDecoration(labelText: 'Select Class', border: OutlineInputBorder()),
                              items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c == 'Nursery/KG' ? c : 'Class $c'))).toList(),
                              onChanged: (v) => setDialogState(() => selectedClass = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedSection,
                              decoration: const InputDecoration(labelText: 'Select Section', border: OutlineInputBorder()),
                              items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setDialogState(() => selectedSection = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Student Selection
                      DropdownButtonFormField<Map<String, String>>(
                        value: selectedStudent,
                        decoration: const InputDecoration(
                          labelText: 'Select Student', 
                          border: OutlineInputBorder(),
                          hintText: 'Choose a student from the selected class',
                        ),
                        items: availableStudents.map((s) => DropdownMenuItem(value: s, child: Text('${s['name']} (${s['regNo']}) - Father: ${s['father']}', overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setDialogState(() => selectedStudent = v),
                        isExpanded: true,
                      ),
                      if (availableStudents.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0, left: 4.0),
                          child: Text('No students found in this class/section.', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),

                      // Billing Month & Year
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedMonth,
                              decoration: const InputDecoration(labelText: 'Billing Month', border: OutlineInputBorder()),
                              items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                              onChanged: (v) => setDialogState(() => selectedMonth = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedYear,
                              decoration: const InputDecoration(labelText: 'Billing Year', border: OutlineInputBorder()),
                              items: _getYearsList().map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                              onChanged: (v) => setDialogState(() => selectedYear = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Fee Amounts
                      Row(
                        children: [
                          Expanded(child: TextField(controller: tuitionCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tuition Fee (Rs.)', border: OutlineInputBorder()))),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: admissionCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Admission (Rs.)', border: OutlineInputBorder()))),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: fineCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Arrears (Rs.)', border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Auto Due Date Display
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.2))),
                        child: Text('Auto Due Date: $autoDueDate (Late Fee: Rs. 100/day after this date)', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (selectedStudent == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a student first!'), backgroundColor: Colors.redAccent));
                      return;
                    }

                    _dataService.generateVoucher(
                      regNo: selectedStudent!['regNo']!,
                      studentName: selectedStudent!['name']!,
                      className: selectedStudent!['class']!,
                      section: selectedStudent!['section']!,
                      month: '$selectedMonth $selectedYear',
                      tuitionFee: tuitionCtrl.text.isEmpty ? '0' : tuitionCtrl.text,
                      admissionFee: admissionCtrl.text.isEmpty ? '0' : admissionCtrl.text,
                      fine: fineCtrl.text.isEmpty ? '0' : fineCtrl.text,
                      dueDate: autoDueDate,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Voucher Generated for ${selectedStudent!['name']}!'), backgroundColor: Colors.green));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text('Generate Voucher', style: TextStyle(color: Colors.white)),
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
        // --- REAL DATA CALCULATIONS ---
        int totalStudents = _dataService.activeStudents.length;
        int totalStaff = _dataService.teachersList.length;

        double totalRevenue = 0;
        for (var voucher in _dataService.feeVouchers) {
          if (voucher['status'] == 'Paid') {
            totalRevenue += double.tryParse(voucher['totalAmount'].toString()) ?? 0;
          }
        }

        String todayStr = DateTime.now().toString().split(' ')[0];
        int presentCount = 0;
        int totalMarked = 0;
        for (var att in _dataService.staffAttendance.where((a) => a['date'] == todayStr)) {
          totalMarked++;
          if (att['status'] == 'Present') presentCount++;
        }
        double attendanceRate = totalMarked == 0 ? 100 : (presentCount / totalMarked) * 100;

        Map<String, int> classDistribution = {};
        for (var s in _dataService.activeStudents) {
          String c = (s['class'] ?? 'Unknown').replaceAll('Class ', '').trim();
          classDistribution[c] = (classDistribution[c] ?? 0) + 1;
        }

        Map<String, int> staffDistribution = {};
        for (var t in _dataService.teachersList) {
          String r = t['role'] ?? 'Teacher';
          staffDistribution[r] = (staffDistribution[r] ?? 0) + 1;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Executive Overview & School Analytics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 24),

              // --- TOP SUMMARY CARDS ---
              Row(
                children: [
                  _buildStatCard('Total Students', totalStudents.toString(), Icons.school, Colors.blueAccent),
                  const SizedBox(width: 16),
                  _buildStatCard('Active Staff', totalStaff.toString(), Icons.badge, Colors.purple),
                  const SizedBox(width: 16),
                  _buildStatCard('Total Revenue', 'Rs $totalRevenue', Icons.account_balance_wallet, Colors.green),
                  const SizedBox(width: 16),
                  _buildStatCard('Staff Attendance', '${attendanceRate.toStringAsFixed(1)}%', Icons.fact_check, Colors.orange),
                ],
              ),
              const SizedBox(height: 24),

              // --- QUICK ACTION BUTTONS ---
              Row(
                children: [
                  _buildQuickAction(
                    'Register New Student', 
                    Icons.person_add, 
                    Colors.blue.shade50, 
                    Colors.blueAccent,
                    _showRegisterStudentDialog, // Opens Add Student Dialog
                  ),
                  const SizedBox(width: 16),
                  _buildQuickAction(
                    'Generate Fee Voucher', 
                    Icons.receipt_long, 
                    Colors.teal.shade50, 
                    Colors.teal,
                    _showGenerateVoucherDialog, // Opens Custom Fee Voucher Dialog
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- CHARTS / ANALYTICS SECTION ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Students Distribution by Class', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          classDistribution.isEmpty 
                            ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No students enrolled yet.', style: TextStyle(color: Colors.black54))))
                            : Column(
                                children: classDistribution.entries.map((e) {
                                  double percentage = totalStudents == 0 ? 0 : (e.value / totalStudents);
                                  return _buildProgressBar('Class ${e.key}', e.value, percentage, Colors.blueAccent);
                                }).toList(),
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Staff Distribution by Role', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          staffDistribution.isEmpty 
                            ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No staff members registered.', style: TextStyle(color: Colors.black54))))
                            : Column(
                                children: staffDistribution.entries.map((e) {
                                  double percentage = totalStaff == 0 ? 0 : (e.value / totalStaff);
                                  return _buildProgressBar(e.key, e.value, percentage, Colors.teal);
                                }).toList(),
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 13)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(String title, IconData icon, Color bgColor, Color iconColor, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: iconColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(String label, int count, double percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('$count (${(percentage * 100).toStringAsFixed(0)}%)', style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}