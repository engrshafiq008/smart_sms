import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'school_data_service.dart';
import 'payment_config_service.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SchoolDataService _dataService = SchoolDataService();

  // Filters for Fee Generation
  String _selectedClass = 'All Classes';
  String _selectedSection = 'All Sections';
  String _selectedYear = DateTime.now().year.toString();
  String _selectedMonth = 'August'; // Default month

  // Filters for Vouchers Record
  String _voucherStatusFilter = 'All';

  // Filters for Pending Fee List
  String _pendingClassFilter = 'All Classes';
  String _pendingMonthFilter = 'All Months';
  final TextEditingController _pendingSearchCtrl = TextEditingController();
  String _pendingSearchQuery = '';

  final List<String> _grades = ['All Classes', 'Nursery/KG', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'];
  final List<String> _sections = ['All Sections', 'Section A', 'Section B', 'Section C', 'Section D'];
  final List<String> _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final List<String> _voucherStatuses = ['All', 'Paid', 'Unpaid'];

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

  // --- Dynamic Late Fee Calculator ---
  int _calculateLateFee(String dueDateStr, String status) {
    if (status == 'Paid') return 0; 
    try {
      DateTime dueDate = DateTime.parse(dueDateStr);
      DateTime today = DateTime.now();
      today = DateTime(today.year, today.month, today.day);
      dueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
      
      if (today.isAfter(dueDate)) {
        int daysLate = today.difference(dueDate).inDays;
        return daysLate * 100; // Rs. 100 per late day
      }
    } catch (e) {
      return 0; 
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pendingSearchCtrl.dispose();
    super.dispose();
  }

  // ==========================================
  // BULK GENERATION & PRINTING LOGIC
  // ==========================================
  void _showBulkGenerateDialog(List<Map<String, String>> students) {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students found to generate vouchers for.'), backgroundColor: Colors.redAccent));
      return;
    }

    final tuitionCtrl = TextEditingController(text: '3000');
    final admissionCtrl = TextEditingController(text: '0');
    final fineCtrl = TextEditingController(text: '0');
    
    String monthNum = _getMonthNumber(_selectedMonth);
    String autoDueDate = '$_selectedYear-$monthNum-10';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Bulk Generate: $_selectedClass'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You are about to generate fee challans for ${students.length} students.', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                const SizedBox(height: 16),
                TextField(controller: tuitionCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Default Tuition Fee (Rs.)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: admissionCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Default Admission/Annual (Rs.)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: fineCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Default Arrears/Fine (Rs.)', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                Text('Auto Due Date: $autoDueDate', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                String targetMonth = '$_selectedMonth $_selectedYear';
                List<Map<String, dynamic>> newlyGeneratedOrExisting = [];

                for (var student in students) {
                  var existing = _dataService.feeVouchers.where((v) => v['regNo'] == student['regNo'] && v['month'] == targetMonth).toList();
                  if (existing.isEmpty) {
                    _dataService.generateVoucher(
                      regNo: student['regNo']!,
                      studentName: student['name']!,
                      className: student['class']!,
                      section: student['section']!,
                      month: targetMonth,
                      tuitionFee: tuitionCtrl.text.isEmpty ? '0' : tuitionCtrl.text,
                      admissionFee: admissionCtrl.text.isEmpty ? '0' : admissionCtrl.text,
                      fine: fineCtrl.text.isEmpty ? '0' : fineCtrl.text,
                      dueDate: autoDueDate,
                    );
                    // Add the newly created one to the print list
                    newlyGeneratedOrExisting.add(_dataService.feeVouchers.last);
                  } else {
                    newlyGeneratedOrExisting.add(existing.first);
                  }
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bulk Vouchers Generated Successfully! Opening PDF...'), backgroundColor: Colors.green));
                
                // Trigger PDF generation
                _printBulkChallans(newlyGeneratedOrExisting);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: const Text('Generate & Print All', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- PDF Component for 1 Challan (Scaled for 4-per-page Grid) ---
  pw.Widget _buildSinglePdfChallan(Map<String, dynamic> voucher) {
    int lateFee = _calculateLateFee(voucher['dueDate'], voucher['status']);
    double baseTotal = double.tryParse(voucher['totalAmount'].toString()) ?? 0;
    double finalTotal = baseTotal + lateFee;
    String displayClass = voucher['className'].toString().replaceAll('Class ', '').trim();

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blueAccent, width: 1.5)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(child: pw.Text((_dataService.schoolSettings['schoolName'] ?? 'SMART SCHOOL SYSTEM').toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueAccent))),
          if ((_dataService.schoolSettings['address'] ?? '').isNotEmpty)
            pw.Center(child: pw.Text(_dataService.schoolSettings['address']!, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700))),
          pw.Center(child: pw.Text('FEE CHALLAN FORM', style: const pw.TextStyle(fontSize: 9))),
          pw.SizedBox(height: 5),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 5),
          
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Voucher: ${voucher['voucherNo']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
              pw.Text('Issued: ${voucher['issueDate']}', style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text('Fee Month: ${voucher['month']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 8),
          
          pw.Text('Reg No: ${voucher['regNo']}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Name: ${voucher['studentName']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Text('Class: Class $displayClass (${voucher['section']})', style: const pw.TextStyle(fontSize: 9)),
          
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 0.5),
          pw.SizedBox(height: 5),
          
          _buildPdfRow('Tuition Fee:', voucher['tuitionFee']),
          _buildPdfRow('Admission/Annual:', voucher['admissionFee']),
          _buildPdfRow('Fines/Arrears:', voucher['fine']),
          if (lateFee > 0) _buildPdfRow('Late Fine (Rs.100/day):', lateFee.toString()),
          
          pw.SizedBox(height: 5),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 3),
          
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TOTAL PAYABLE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text('Rs. $finalTotal/-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text('Due Date: ${voucher['dueDate']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.redAccent)),
          
          pw.Spacer(),
          pw.Divider(thickness: 0.5),
          pw.Center(child: pw.Text('Status: ${voucher['status']}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: voucher['status'] == 'Paid' ? PdfColors.green : PdfColors.red))),
        ],
      ),
    );
  }

  pw.Widget _buildPdfRow(String label, String amount) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Rs. $amount', style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  // --- Bulk PDF Generation (4 per page, new page on class change) ---
  Future<void> _printBulkChallans(List<Map<String, dynamic>> vouchers) async {
    final pdf = pw.Document();

    // Group vouchers by Class
    Map<String, List<Map<String, dynamic>>> groupedByClass = {};
    for (var v in vouchers) {
      String c = v['className'];
      groupedByClass.putIfAbsent(c, () => []).add(v);
    }

    // Process each class separately (New page for new class)
    for (var className in groupedByClass.keys) {
      var classVouchers = groupedByClass[className]!;
      
      // Chunk into groups of 4 for 2x2 grid
      for (var i = 0; i < classVouchers.length; i += 4) {
        var chunk = classVouchers.sublist(i, (i + 4 > classVouchers.length) ? classVouchers.length : i + 4);
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return pw.Column(
                children: [
                  pw.Expanded(
                    child: pw.Row(
                      children: [
                        if (chunk.isNotEmpty) pw.Expanded(child: _buildSinglePdfChallan(chunk[0])),
                        pw.SizedBox(width: 20),
                        if (chunk.length > 1) pw.Expanded(child: _buildSinglePdfChallan(chunk[1])) else pw.Expanded(child: pw.Container()),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Expanded(
                    child: pw.Row(
                      children: [
                        if (chunk.length > 2) pw.Expanded(child: _buildSinglePdfChallan(chunk[2])),
                        pw.SizedBox(width: 20),
                        if (chunk.length > 3) pw.Expanded(child: _buildSinglePdfChallan(chunk[3])) else pw.Expanded(child: pw.Container()),
                      ],
                    ),
                  ),
                ],
              );
            },
          )
        );
      }
    }
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Bulk_Fee_Challans');
  }

  // --- Smart Payment Logic with Late Fee Detection ---
  void _markVoucherAsPaidWithDialog(Map<String, dynamic> voucher, int lateFee, String studentName) {
    if (lateFee > 0) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Late Payment Detected!', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            content: Text('This voucher is past the due date (${voucher['dueDate']}).\n\nBase Total: Rs. ${voucher['totalAmount']}\nCalculated Late Fine: Rs. $lateFee\n\nGrand Total to Collect: Rs. ${(double.tryParse(voucher['totalAmount'].toString()) ?? 0) + lateFee}\n\nDo you want to add this fine to the current voucher before marking it as paid?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  // Add late fee permanently and mark paid
                  double currentFine = double.tryParse(voucher['fine'].toString()) ?? 0;
                  double currentTotal = double.tryParse(voucher['totalAmount'].toString()) ?? 0;
                  voucher['fine'] = (currentFine + lateFee).toString();
                  voucher['totalAmount'] = (currentTotal + lateFee).toString();
                  
                  _dataService.updateVoucherStatus(voucher['voucherNo'], 'Paid');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$studentName marked as Paid with late fine!'), backgroundColor: Colors.green));
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                child: const Text('Add Fine & Mark Paid', style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                onPressed: () {
                  // Ignore fine, just mark paid
                  _dataService.updateVoucherStatus(voucher['voucherNo'], 'Paid');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$studentName marked as Paid (Fine Ignored)!'), backgroundColor: Colors.green));
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: const Text('Ignore Fine & Mark Paid', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    } else {
      // No late fee, directly mark as paid
      _dataService.updateVoucherStatus(voucher['voucherNo'], 'Paid');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$studentName marked as Paid!')));
    }
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
                  tabs: const [
                    Tab(icon: Icon(Icons.request_page), text: "Fee Generation & Print"),
                    Tab(icon: Icon(Icons.receipt_long), text: "Vouchers Record"),
                    Tab(icon: Icon(Icons.assignment_late_outlined), text: "Pending Fee List"),
                    Tab(icon: Icon(Icons.analytics), text: "Financial Summary"),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFeeGenerationTab(),
                    _buildVouchersRecordTab(),
                    _buildPendingFeeListTab(),
                    _buildFinancialSummaryTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 1: Fee Generation ---
  Widget _buildFeeGenerationTab() {
    final students = _dataService.getStudentsByClassAndSection(_selectedClass, _selectedSection);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Class-Wise Fee Collection & Bulk Generation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showBulkGenerateDialog(students),
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text('Bulk Generate & Print', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedYear,
                  decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                  items: _getYearsList().map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                  onChanged: (v) => setState(() => _selectedYear = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedMonth,
                  decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
                  items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _selectedMonth = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedClass,
                  decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                  items: _grades.map((c) => DropdownMenuItem(value: c, child: Text(c == 'All Classes' ? c : (c == 'Nursery/KG' ? c : 'Class $c')))).toList(),
                  onChanged: (v) => setState(() => _selectedClass = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedSection,
                  decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder()),
                  items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _selectedSection = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Expanded(
            child: students.isEmpty
                ? const Center(child: Text('No students found for the selected filters.', style: TextStyle(color: Colors.black54)))
                : ListView.separated(
                    itemCount: students.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      String targetMonth = '$_selectedMonth $_selectedYear';
                      
                      var existingVouchers = _dataService.feeVouchers.where((v) => v['regNo'] == student['regNo'] && v['month'] == targetMonth).toList();
                      Map<String, dynamic>? voucher = existingVouchers.isNotEmpty ? existingVouchers.first : null;

                      int lateFee = voucher != null ? _calculateLateFee(voucher['dueDate'], voucher['status']) : 0;

                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.person, color: Colors.white)),
                        title: Text(student['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Reg No: ${student['regNo']} | Class: ${student['class']} (${student['section']})'),
                            if (lateFee > 0)
                              Text('Overdue: Rs. $lateFee Late Fine Detected', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: voucher == null
                            ? ElevatedButton.icon(
                                onPressed: () => _showBulkGenerateDialog([student]), // Single generate
                                icon: const Icon(Icons.add_card, size: 18, color: Colors.white),
                                label: const Text('Generate', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: voucher['status'] == 'Paid' ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: voucher['status'] == 'Paid' ? Colors.green : Colors.red),
                                    ),
                                    child: Text(voucher['status'], style: TextStyle(fontWeight: FontWeight.bold, color: voucher['status'] == 'Paid' ? Colors.green : Colors.red)),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.print, color: Colors.blueAccent),
                                    onPressed: () => _printBulkChallans([voucher]),
                                    tooltip: 'Print Challan',
                                  ),
                                  if (voucher['status'] == 'Unpaid')
                                    IconButton(
                                      icon: const Icon(Icons.check_circle, color: Colors.green),
                                      onPressed: () => _markVoucherAsPaidWithDialog(voucher, lateFee, student['name']!),
                                      tooltip: 'Mark as Paid',
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

  // --- TAB 2: Vouchers Record ---
  Widget _buildVouchersRecordTab() {
    final vouchers = _dataService.feeVouchers.where((v) {
      if (_voucherStatusFilter == 'All') return true;
      return v['status'] == _voucherStatusFilter;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Generated Vouchers Record', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: _voucherStatusFilter,
                  decoration: const InputDecoration(labelText: 'Filter Status', border: OutlineInputBorder(), isDense: true),
                  items: _voucherStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _voucherStatusFilter = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: vouchers.isEmpty
                ? const Center(child: Text('No vouchers found.', style: TextStyle(color: Colors.black54)))
                : ListView.separated(
                    itemCount: vouchers.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final v = vouchers[index];
                      
                      int lateFee = _calculateLateFee(v['dueDate'], v['status']);
                      double finalTotal = (double.tryParse(v['totalAmount'].toString()) ?? 0) + lateFee;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: v['status'] == 'Paid' ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                          child: Icon(v['status'] == 'Paid' ? Icons.check : Icons.warning, color: v['status'] == 'Paid' ? Colors.green : Colors.red),
                        ),
                        title: Text('${v['studentName']} (${v['regNo']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Month: ${v['month']} | Amount: Rs. $finalTotal \nVoucher: ${v['voucherNo']} | Due: ${v['dueDate']}'),
                            if (lateFee > 0)
                              Text('Includes Rs. $lateFee Late Fine Detected', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.print, color: Colors.blueAccent), onPressed: () => _printBulkChallans([v])),
                            if (v['status'] == 'Unpaid')
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                                onPressed: () => _markVoucherAsPaidWithDialog(v, lateFee, v['studentName']),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _dataService.deleteVoucher(v['voucherNo']),
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

  // --- TAB 3: Financial Summary ---
  Widget _buildFinancialSummaryTab() {
    double totalRevenue = 0;
    double pendingDues = 0;
    int paidCount = 0;
    int unpaidCount = 0;

    for (var v in _dataService.feeVouchers) {
      double baseAmount = double.tryParse(v['totalAmount'].toString()) ?? 0;
      if (v['status'] == 'Paid') {
        totalRevenue += baseAmount;
        paidCount++;
      } else {
        int lateFee = _calculateLateFee(v['dueDate'], v['status']);
        pendingDues += (baseAmount + lateFee);
        unpaidCount++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('School Financial Summary', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          Row(
            children: [
              _buildSummaryCard('Total Revenue Collected', 'Rs. $totalRevenue', Icons.account_balance_wallet, Colors.green, '$paidCount Paid Vouchers'),
              const SizedBox(width: 20),
              _buildSummaryCard('Pending / Overdue (Incl. Fines)', 'Rs. $pendingDues', Icons.warning_amber_rounded, Colors.redAccent, '$unpaidCount Unpaid Vouchers'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String amount, IconData icon, Color color, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 36),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 16),
            Text(amount, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: PENDING FEE LIST & WHATSAPP COOLDOWN
  // ==========================================
  Widget _buildPendingFeeListTab() {
    // 1. Filter vouchers (only unpaid/pending)
    final pendingVouchers = _dataService.feeVouchers.where((v) {
      if (v['status'] == 'Paid') return false;

      if (_pendingClassFilter != 'All Classes') {
        String cleanClass = (v['className'] ?? '').toString().replaceAll('Class ', '').trim();
        String targetClass = _pendingClassFilter.replaceAll('Class ', '').trim();
        if (cleanClass != targetClass) return false;
      }

      if (_pendingMonthFilter != 'All Months') {
        String monthStr = (v['month'] ?? '').toString();
        if (!monthStr.contains(_pendingMonthFilter)) return false;
      }

      if (_pendingSearchQuery.isNotEmpty) {
        String name = (v['studentName'] ?? '').toString().toLowerCase();
        String regNo = (v['regNo'] ?? '').toString().toLowerCase();
        String phone = _dataService.getStudentPhone(v['regNo'] ?? '').toLowerCase();
        if (!name.contains(_pendingSearchQuery) &&
            !regNo.contains(_pendingSearchQuery) &&
            !phone.contains(_pendingSearchQuery)) {
          return false;
        }
      }

      return true;
    }).toList();

    // 2. Compute metrics for summary strip
    int totalPending = pendingVouchers.length;
    double totalDue = 0;
    int remindedCount = 0;
    int unremindedCount = 0;

    for (var v in pendingVouchers) {
      int lateFee = _calculateLateFee(v['dueDate'] ?? '', v['status'] ?? '');
      double base = double.tryParse(v['totalAmount']?.toString() ?? '0') ?? 0;
      totalDue += (base + lateFee);

      final cooldown = _dataService.getRemainingReminderCooldown(v);
      if (cooldown != null) {
        remindedCount++;
      } else {
        unremindedCount++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header & Print Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.assignment_late, color: Colors.redAccent, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Pending Fee Recovery & WhatsApp Reminders',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: pendingVouchers.isEmpty ? null : () => _printPendingCallingList(pendingVouchers),
                icon: const Icon(Icons.print, color: Colors.white, size: 18),
                label: const Text('Print Pending List (PDF)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters Row
          Row(
            children: [
              // Class Filter
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _pendingClassFilter,
                  decoration: const InputDecoration(labelText: 'Filter Class', border: OutlineInputBorder(), isDense: true),
                  items: _grades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) => setState(() => _pendingClassFilter = val!),
                ),
              ),
              const SizedBox(width: 12),

              // Month Filter
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _pendingMonthFilter,
                  decoration: const InputDecoration(labelText: 'Filter Month', border: OutlineInputBorder(), isDense: true),
                  items: ['All Months', ..._months].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) => setState(() => _pendingMonthFilter = val!),
                ),
              ),
              const SizedBox(width: 12),

              // Search Bar
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _pendingSearchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Search by Student Name, Reg No, or Phone',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _pendingSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _pendingSearchCtrl.clear();
                              setState(() => _pendingSearchQuery = '');
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _pendingSearchQuery = val.trim().toLowerCase()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Compact Summary Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(child: _buildMiniStat('Pending Students', '$totalPending Students', Icons.groups, Colors.redAccent)),
                Container(height: 32, width: 1, color: Colors.grey.shade300),
                Expanded(child: _buildMiniStat('Total Pending Dues', 'Rs. ${totalDue.toStringAsFixed(0)}', Icons.payments, Colors.red.shade700)),
                Container(height: 32, width: 1, color: Colors.grey.shade300),
                Expanded(child: _buildMiniStat('Reminded (24h)', '$remindedCount Sent', Icons.check_circle, Colors.green)),
                Container(height: 32, width: 1, color: Colors.grey.shade300),
                Expanded(child: _buildMiniStat('Remaining to Alert', '$unremindedCount Left', Icons.schedule, Colors.orange)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Student Rows List
          Expanded(
            child: pendingVouchers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 48, color: Colors.green.withValues(alpha: 0.3)),
                        const SizedBox(height: 10),
                        const Text(
                          'No pending fee records found! All dues are clear.',
                          style: TextStyle(color: Colors.black54, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: pendingVouchers.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final v = pendingVouchers[index];
                      final regNo = v['regNo']?.toString() ?? '';
                      final studentName = v['studentName']?.toString() ?? '';
                      final fatherName = _dataService.getStudentFatherName(regNo);
                      final className = (v['className']?.toString() ?? '').replaceAll('Class ', '').trim();
                      final sec = v['section']?.toString() ?? '';
                      final studentPhone = _dataService.getStudentPhone(regNo);
                      final month = v['month']?.toString() ?? '';

                      int lateFee = _calculateLateFee(v['dueDate'] ?? '', v['status'] ?? '');
                      double baseTotal = double.tryParse(v['totalAmount']?.toString() ?? '0') ?? 0;
                      double finalTotal = baseTotal + lateFee;

                      final cooldown = _dataService.getRemainingReminderCooldown(v);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          child: const Icon(Icons.person_outline, color: Colors.redAccent),
                        ),
                        title: Row(
                          children: [
                            Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(width: 8),
                            Text('($regNo)', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                            if (fatherName.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text('s/d of $fatherName', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('Class $className ($sec)', style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Icon(Icons.phone, size: 13, color: studentPhone.isNotEmpty ? Colors.green : Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                studentPhone.isNotEmpty ? studentPhone : 'No phone saved',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: studentPhone.isNotEmpty ? Colors.black87 : Colors.redAccent,
                                  fontWeight: studentPhone.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text('Month: $month', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                              const SizedBox(width: 14),
                              Text(
                                'Due: Rs. ${finalTotal.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent),
                              ),
                              if (lateFee > 0) ...[
                                const SizedBox(width: 6),
                                Text('(incl. Rs. $lateFee late fine)', style: const TextStyle(fontSize: 11, color: Colors.red, fontStyle: FontStyle.italic)),
                              ],
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // WhatsApp Alert Button with 24-Hour Cooldown
                            if (cooldown == null)
                              ElevatedButton.icon(
                                onPressed: () => _sendFeeWhatsAppReminder(v, finalTotal),
                                icon: const Icon(Icons.chat, color: Colors.white, size: 15),
                                label: const Text('Send Alert', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF22C55E),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              )
                            else
                              ElevatedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.check_circle, color: Colors.black38, size: 15),
                                label: Text(
                                  cooldown.inHours > 0
                                      ? 'Sent (${cooldown.inHours}h ${cooldown.inMinutes % 60}m)'
                                      : 'Sent (${cooldown.inMinutes % 60}m)',
                                  style: const TextStyle(color: Colors.black45, fontSize: 11),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade200,
                                  disabledBackgroundColor: Colors.grey.shade200,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            const SizedBox(width: 8),

                            // Print single challan
                            IconButton(
                              tooltip: 'Print Fee Challan',
                              icon: const Icon(Icons.print, color: Colors.blueAccent, size: 20),
                              onPressed: () => _printBulkChallans([v]),
                            ),

                            // Mark as Paid
                            IconButton(
                              tooltip: 'Mark Paid',
                              icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                              onPressed: () => _markVoucherAsPaidWithDialog(v, lateFee, studentName),
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

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ],
    );
  }

  // --- Send WhatsApp Reminder with 24-Hour Cooldown ---
  Future<void> _sendFeeWhatsAppReminder(Map<String, dynamic> voucher, double finalTotal) async {
    final regNo = voucher['regNo']?.toString() ?? '';
    final studentName = voucher['studentName']?.toString() ?? 'Student';
    final className = (voucher['className']?.toString() ?? '').replaceAll('Class ', '').trim();
    final month = voucher['month']?.toString() ?? '';
    final voucherNo = voucher['voucherNo']?.toString() ?? '';
    final schoolName = _dataService.schoolSettings['schoolName'] ?? 'Smart School System';
    final studentPhone = _dataService.getStudentPhone(regNo);

    if (studentPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ No phone number registered for $studentName ($regNo). Please update in student profile.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final message = "Assalam-o-Alaikum, this is a fee reminder from $schoolName. "
        "The fee for $studentName (Class $className) for the month of $month is pending. "
        "Total Due: Rs. ${finalTotal.toStringAsFixed(0)}. "
        "Please submit the fee at your earliest. Thank you.";

    final launched = await PaymentConfigService.launchWhatsApp(
      phone: studentPhone,
      message: message,
    );

    if (launched) {
      await _dataService.markFeeReminderSent(voucherNo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fee reminder sent to $studentName ($studentPhone)! 24-hour cooldown activated.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open WhatsApp for $studentPhone. Please check WhatsApp configuration.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // --- Print Pending Fee & Calling List PDF ---
  Future<void> _printPendingCallingList(List<Map<String, dynamic>> pendingVouchers) async {
    final pdf = pw.Document();
    final schoolName = (_dataService.schoolSettings['schoolName'] ?? 'SMART SCHOOL SYSTEM').toUpperCase();
    final address = _dataService.schoolSettings['address'] ?? '';
    final phone = _dataService.schoolSettings['phone'] ?? '';
    final nowStr = DateTime.now().toString().split('.')[0];

    double totalAmount = 0;
    for (var v in pendingVouchers) {
      int lateFee = _calculateLateFee(v['dueDate'] ?? '', v['status'] ?? '');
      double base = double.tryParse(v['totalAmount']?.toString() ?? '0') ?? 0;
      totalAmount += (base + lateFee);
    }

    List<List<String>> tableData = [];
    for (int i = 0; i < pendingVouchers.length; i++) {
      final v = pendingVouchers[i];
      final regNo = v['regNo']?.toString() ?? '';
      final studentName = v['studentName']?.toString() ?? '';
      final fatherName = _dataService.getStudentFatherName(regNo);
      final className = (v['className']?.toString() ?? '').replaceAll('Class ', '').trim();
      final sec = v['section']?.toString() ?? '';
      final studentPhone = _dataService.getStudentPhone(regNo);
      final month = v['month']?.toString() ?? '';
      int lateFee = _calculateLateFee(v['dueDate'] ?? '', v['status'] ?? '');
      double base = double.tryParse(v['totalAmount']?.toString() ?? '0') ?? 0;
      double finalTotal = base + lateFee;

      tableData.add([
        '${i + 1}',
        regNo,
        studentName,
        fatherName.isNotEmpty ? fatherName : '-',
        '$className ($sec)',
        studentPhone.isNotEmpty ? studentPhone : 'N/A',
        month,
        'Rs. ${finalTotal.toStringAsFixed(0)}',
        '', // Space for calling notes
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        schoolName,
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                      if (address.isNotEmpty)
                        pw.Text(address, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      if (phone.isNotEmpty)
                        pw.Text('Contact: $phone', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.red50,
                          border: pw.Border.all(color: PdfColors.red300),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'PENDING FEE & CALLING LIST',
                          style: pw.TextStyle(color: PdfColors.red900, fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Filter: Class [$_pendingClassFilter] | Month [$_pendingMonthFilter]',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                      ),
                      pw.Text('Generated: $nowStr', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 6),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.TableHelper.fromTextArray(
              headers: ['Sr#', 'Reg No', 'Student Name', 'Father Name', 'Class/Sec', 'Phone Number', 'Month', 'Due Amount', 'Call / Remarks'],
              data: tableData,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                4: pw.Alignment.center,
                6: pw.Alignment.center,
                7: pw.Alignment.centerRight,
              },
              columnWidths: {
                0: const pw.FixedColumnWidth(26),
                1: const pw.FixedColumnWidth(75),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FixedColumnWidth(60),
                5: const pw.FixedColumnWidth(80),
                6: const pw.FixedColumnWidth(65),
                7: const pw.FixedColumnWidth(60),
                8: const pw.FlexColumnWidth(2.5),
              },
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Pending Students: ${pendingVouchers.length}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                  ),
                  pw.Text(
                    'Grand Total Due: Rs. ${totalAmount.toStringAsFixed(0)}/-',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red900),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(width: 150, height: 1, color: PdfColors.grey600),
                    pw.SizedBox(height: 4),
                    pw.Text('Accountant Signature', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(width: 150, height: 1, color: PdfColors.grey600),
                    pw.SizedBox(height: 4),
                    pw.Text('Principal Signature', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Pending_Fee_Calling_List_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}