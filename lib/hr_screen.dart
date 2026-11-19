import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'school_data_service.dart';

class HrScreen extends StatefulWidget {
  const HrScreen({super.key});

  @override
  State<HrScreen> createState() => _HrScreenState();
}

class _HrScreenState extends State<HrScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SchoolDataService _dataService = SchoolDataService();

  // Attendance State
  DateTime _selectedDate = DateTime.now();
  Map<String, String> _attendanceState = {};

  // Payroll State
  String _selectedMonth = 'August';
  String _selectedYear = DateTime.now().year.toString();
  
  final List<String> _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final List<String> _roles = ['Principal', 'Admin', 'Teacher', 'Accountant', 'Support Staff', 'Security Guard'];

  List<String> _getYearsList() {
    List<String> years = [];
    for (int i = 2024; i <= 2040; i++) {
      years.add(i.toString());
    }
    return years;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAttendanceForDate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Load Attendance logic ---
  void _loadAttendanceForDate() {
    String dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    _attendanceState = _dataService.getAttendanceForDate(dateStr);
    
    // Default fill missing with Present
    for (var staff in _dataService.teachersList) {
      if (!_attendanceState.containsKey(staff['id'])) {
        _attendanceState[staff['id']!] = 'Present';
      }
    }
    setState(() {});
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadAttendanceForDate();
    }
  }

  // --- Dialog: Assign Role & Basic Salary ---
  void _showRoleSalaryDialog(Map<String, String> staff) {
    String selectedRole = staff['role'] ?? 'Teacher';
    if (!_roles.contains(selectedRole)) selectedRole = 'Teacher';
    
    final salaryCtrl = TextEditingController(text: staff['basicSalary'] ?? '0');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Setup Profile: ${staff['name']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Staff Role / Designation', border: OutlineInputBorder()),
                    items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setDialogState(() => selectedRole = v!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: salaryCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Basic Salary (Rs.)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    final updated = Map<String, String>.from(staff);
                    updated['role'] = selectedRole;
                    updated['basicSalary'] = salaryCtrl.text.isEmpty ? '0' : salaryCtrl.text;
                    _dataService.updateTeacher(staff['id']!, updated);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated Successfully!'), backgroundColor: Colors.green));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text('Update Profile', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Dialog: Generate Salary Slip (With Auto Deduction) ---
  void _showGeneratePayslipDialog(Map<String, String> staff) {
    String targetMonth = '$_selectedMonth $_selectedYear';
    
    // Auto calculate absences
    int absentCount = 0;
    String monthPrefix = '$_selectedYear-${(_months.indexOf(_selectedMonth) + 1).toString().padLeft(2, '0')}';

    for(var a in _dataService.staffAttendance) {
      if(a['staffId'] == staff['id'] && a['date']!.startsWith(monthPrefix) && a['status'] == 'Absent') {
        absentCount++;
      }
    }

    double basic = double.tryParse(staff['basicSalary'] ?? '0') ?? 0;
    double deductionPerDay = basic / 30;
    double suggestedDeduction = absentCount * deductionPerDay;

    final basicCtrl = TextEditingController(text: basic.toStringAsFixed(0));
    final allowanceCtrl = TextEditingController(text: '0');
    final deductionCtrl = TextEditingController(text: suggestedDeduction.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Generate Payslip: ${staff['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Salary Month: $targetMonth', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                const SizedBox(height: 8),
                Text('System detected $absentCount absences this month.', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                const SizedBox(height: 16),
                TextField(controller: basicCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Basic Salary (Rs.)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: allowanceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bonus / Allowances (Rs.)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                  controller: deductionCtrl, 
                  keyboardType: TextInputType.number, 
                  decoration: const InputDecoration(labelText: 'Deductions (Rs.)', border: OutlineInputBorder(), helperText: 'Auto-calculated based on Absences')
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                double b = double.tryParse(basicCtrl.text) ?? 0;
                double a = double.tryParse(allowanceCtrl.text) ?? 0;
                double d = double.tryParse(deductionCtrl.text) ?? 0;
                double net = b + a - d;

                _dataService.generateSalarySlip({
                  'staffId': staff['id']!,
                  'staffName': staff['name']!,
                  'role': staff['role'] ?? 'Staff',
                  'month': targetMonth,
                  'basicSalary': b.toStringAsFixed(0),
                  'allowance': a.toStringAsFixed(0),
                  'deduction': d.toStringAsFixed(0),
                  'netSalary': net.toStringAsFixed(0),
                  'status': 'Unpaid',
                  'issueDate': DateTime.now().toString().split(' ')[0],
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payslip Generated!'), backgroundColor: Colors.green));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Generate Slip', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- PDF Print Payslip ---
  Future<void> _printPayslip(Map<String, String> slip) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.teal, width: 2)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text((_dataService.schoolSettings['schoolName'] ?? 'SMART SCHOOL SYSTEM').toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal))),
                pw.Center(child: pw.Text('OFFICIAL STAFF PAYSLIP', style: const pw.TextStyle(fontSize: 12))),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 10),
                
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Slip ID: ${slip['id']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text('Issue Date: ${slip['issueDate']}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Text('Salary Month: ${slip['month']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.SizedBox(height: 15),
                
                pw.Text('Staff ID: ${slip['staffId']}'),
                pw.Text('Staff Name: ${slip['staffName']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text('Designation: ${slip['role']}'),
                
                pw.SizedBox(height: 15),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 10),
                
                _buildPdfRow('Basic Salary:', slip['basicSalary']!),
                _buildPdfRow('Bonus & Allowances:', slip['allowance']!),
                _buildPdfRow('Deductions (Leaves/Advance):', '- ${slip['deduction']}'),
                
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 5),
                
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('NET PAYABLE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Text('Rs. ${slip['netSalary']}/-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  ],
                ),
                
                pw.Spacer(),
                pw.Divider(thickness: 0.5),
                pw.Center(child: pw.Text('Payment Status: ${slip['status']}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: slip['status'] == 'Paid' ? PdfColors.green : PdfColors.red))),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Payslip_${slip['id']}');
  }

  pw.Widget _buildPdfRow(String label, String amount) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          pw.Text('Rs. $amount', style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
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
                  labelColor: Colors.teal,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: Colors.teal,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(icon: Icon(Icons.badge), text: "Staff Directory"),
                    Tab(icon: Icon(Icons.fact_check), text: "Daily Attendance"),
                    Tab(icon: Icon(Icons.account_balance_wallet), text: "Payroll & Salary"),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStaffDirectoryTab(),
                    _buildAttendanceTab(),
                    _buildPayrollTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 1: Staff Directory ---
  Widget _buildStaffDirectoryTab() {
    final staffList = _dataService.teachersList;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Staff Profiles & Role Assignment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: staffList.isEmpty
                ? const Center(child: Text('No staff members registered. Add them from Academics/Staff section.', style: TextStyle(color: Colors.black54)))
                : ListView.separated(
                    itemCount: staffList.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final staff = staffList[index];
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.teal.withValues(alpha: 0.1), child: const Icon(Icons.person, color: Colors.teal)),
                        title: Text('${staff['name']} (${staff['id']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Designation: ${staff['role']}\nBasic Salary: Rs. ${staff['basicSalary']} | Phone: ${staff['phone']}'),
                        isThreeLine: true,
                        trailing: ElevatedButton.icon(
                          onPressed: () => _showRoleSalaryDialog(staff),
                          icon: const Icon(Icons.manage_accounts, size: 16, color: Colors.white),
                          label: const Text('Setup Profile', style: TextStyle(color: Colors.white)),
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

  // --- TAB 2: Attendance Tracking ---
  Widget _buildAttendanceTab() {
    final staffList = _dataService.teachersList;
    String dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mark Daily Attendance ($dateStr)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(context),
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Change Date'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      _dataService.saveAttendance(dateStr, _attendanceState);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance Saved!'), backgroundColor: Colors.green));
                    },
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('Save Attendance', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: staffList.isEmpty
                ? const Center(child: Text('No staff members to mark attendance.', style: TextStyle(color: Colors.black54)))
                : ListView.separated(
                    itemCount: staffList.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final staff = staffList[index];
                      String currentStatus = _attendanceState[staff['id']] ?? 'Present';

                      return ListTile(
                        title: Text(staff['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(staff['role']!),
                        trailing: Wrap(
                          spacing: 8,
                          children: ['Present', 'Absent', 'Leave'].map((status) {
                            bool isSelected = currentStatus == status;
                            Color chipColor = status == 'Present' ? Colors.green : (status == 'Absent' ? Colors.red : Colors.orange);
                            return ChoiceChip(
                              label: Text(status, style: TextStyle(color: isSelected ? Colors.white : Colors.black87)),
                              selected: isSelected,
                              selectedColor: chipColor,
                              onSelected: (val) {
                                if (val) setState(() => _attendanceState[staff['id']!] = status);
                              },
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: Payroll & Salary ---
  Widget _buildPayrollTab() {
    final staffList = _dataService.teachersList;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Staff Payroll & Salary Slips', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedYear,
                  decoration: const InputDecoration(labelText: 'Select Year', border: OutlineInputBorder()),
                  items: _getYearsList().map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                  onChanged: (v) => setState(() => _selectedYear = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedMonth,
                  decoration: const InputDecoration(labelText: 'Select Month', border: OutlineInputBorder()),
                  items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _selectedMonth = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: staffList.isEmpty
                ? const Center(child: Text('No staff members available.', style: TextStyle(color: Colors.black54)))
                : ListView.separated(
                    itemCount: staffList.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final staff = staffList[index];
                      String targetMonth = '$_selectedMonth $_selectedYear';
                      
                      var existingSlips = _dataService.staffPayroll.where((s) => s['staffId'] == staff['id'] && s['month'] == targetMonth).toList();
                      Map<String, String>? slip = existingSlips.isNotEmpty ? existingSlips.first : null;

                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.account_balance_wallet, color: Colors.white)),
                        title: Text(staff['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Role: ${staff['role']}\nBasic: Rs. ${staff['basicSalary']}'),
                        isThreeLine: true,
                        trailing: slip == null
                            ? ElevatedButton.icon(
                                onPressed: () => _showGeneratePayslipDialog(staff),
                                icon: const Icon(Icons.add_card, size: 16, color: Colors.white),
                                label: const Text('Generate Slip', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: slip['status'] == 'Paid' ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: slip['status'] == 'Paid' ? Colors.green : Colors.red),
                                    ),
                                    child: Text(slip['status']!, style: TextStyle(fontWeight: FontWeight.bold, color: slip['status'] == 'Paid' ? Colors.green : Colors.red)),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.print, color: Colors.blueAccent),
                                    onPressed: () => _printPayslip(slip),
                                    tooltip: 'Print Payslip',
                                  ),
                                  if (slip['status'] == 'Unpaid')
                                    IconButton(
                                      icon: const Icon(Icons.check_circle, color: Colors.green),
                                      onPressed: () {
                                        _dataService.updateSalaryStatus(slip['id']!, 'Paid');
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${staff['name']} marked as Paid!')));
                                      },
                                      tooltip: 'Mark as Paid',
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                    onPressed: () => _dataService.deleteSalarySlip(slip['id']!),
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
}