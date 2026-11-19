import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'school_data_service.dart';

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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
}