import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'school_data_service.dart';

class StudentActions {
  // Standard Classes List (Nursery/KG to 12)
  static final List<String> standardClasses = [
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

  static List<String> getYearsList() {
    List<String> years = [];
    for (int i = 1947; i <= 3047; i++) {
      years.add(i.toString());
    }
    return years;
  }

  static int calculateTotalFine(String? finesJson) {
    if (finesJson == null || finesJson.isEmpty) return 0;
    try {
      List fines = jsonDecode(finesJson);
      double total = 0;
      for (var f in fines) {
        total += double.tryParse(f['amount'].toString()) ?? 0;
      }
      return total.toInt();
    } catch (e) {
      return 0;
    }
  }

  static String formatClassSectionShort(String? className, String? sectionName) {
    if (className == null) return 'N/A';
    String cCode = className;
    String sCode = (sectionName ?? 'A').replaceAll('Section ', '').trim();
    return 'Class $cCode-$sCode';
  }

  // --- PDF: Print Directory Sheet ---
  static Future<void> printDirectorySheet(List<Map<String, String>> studentsList, String classFilter, String sectionFilter) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        build: (pw.Context context) {
          final headers = ['S.#', 'Reg No', 'Reg Date', 'Student Name', 'Gen', 'Father Name', 'CNIC / B-Form', 'Class & Sec', 'Contact', 'Address'];

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('SMART SCHOOL SYSTEM', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Student Directory Report: $classFilter ($sectionFilter)', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Text('Total Students: ${studentsList.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 6),
              pw.Expanded(
                child: pw.Table(
                  columnWidths: const {
                    0: pw.FixedColumnWidth(22),
                    1: pw.FixedColumnWidth(110),
                    2: pw.FixedColumnWidth(65),
                    3: pw.FixedColumnWidth(100),
                    4: pw.FixedColumnWidth(30),
                    5: pw.FixedColumnWidth(100),
                    6: pw.FixedColumnWidth(85),
                    7: pw.FixedColumnWidth(55),
                    8: pw.FixedColumnWidth(70),
                    9: pw.FlexColumnWidth(),
                  },
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.blueAccent),
                      children: headers.map((header) {
                        return pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                          child: pw.Text(header, maxLines: 1, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8)),
                        );
                      }).toList(),
                    ),
                    ...studentsList.asMap().entries.map((entry) {
                      final student = entry.value;
                      final rowData = [
                        '${entry.key + 1}',
                        student['regNo'] ?? student['rollNo'] ?? 'N/A',
                        student['enrollmentDate'] ?? 'N/A',
                        student['name'] ?? 'N/A',
                        student['gender'] ?? 'N/A',
                        student['father'] ?? 'N/A',
                        student['cnic'] ?? 'N/A',
                        formatClassSectionShort(student['class'], student['section']),
                        student['phone'] ?? 'N/A',
                        student['address'] ?? 'N/A',
                      ];
                      return pw.TableRow(
                        children: rowData.map((cellText) {
                          return pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
                            child: pw.Text(cellText, maxLines: 1, style: const pw.TextStyle(fontSize: 7.5)),
                          );
                        }).toList(),
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Directory_Report');
  }

  // --- PDF: Print Leaving Certificate ---
  static Future<void> printLeavingCertificate(Map<String, String> student) async {
    final pdf = pw.Document();
    int totalFine = calculateTotalFine(student['fines']);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blueAccent, width: 3)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('SMART SCHOOL SYSTEM', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blueAccent)),
                pw.Text('OFFICIAL SCHOOL LEAVING CERTIFICATE (SLC)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 20),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('This is to certify that the student whose particulars are given below has been a bonafide student of this institution:'),
                ),
                pw.SizedBox(height: 20),
                _buildPdfRow('Registration No:', student['regNo'] ?? 'N/A'),
                _buildPdfRow('Student Full Name:', student['name'] ?? 'N/A'),
                _buildPdfRow('Father Name:', student['father'] ?? 'N/A'),
                _buildPdfRow('Leaving Date:', student['exitDate'] ?? 'N/A'),
                _buildPdfRow('Reason for Leaving:', student['exitReason'] ?? 'N/A'),
                _buildPdfRow('Outstanding Dues:', totalFine > 0 ? 'Rs. $totalFine Pending' : 'Cleared'),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(children: [pw.Container(width: 120, height: 1, color: PdfColors.black), pw.Text('Principal Signature')]),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'SLC_${student['regNo']}');
  }

  static pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  // --- Dialog: Comprehensive Edit Student (Admission Form Style) ---
  static void showEditDialog(BuildContext context, Map<String, String> student, List<String> sections) {
    final nameCtrl = TextEditingController(text: student['name']);
    final fatherCtrl = TextEditingController(text: student['father']);
    final cnicCtrl = TextEditingController(text: student['cnic']);
    final phoneCtrl = TextEditingController(text: student['phone']);
    final addressCtrl = TextEditingController(text: student['address']);
    
    String selectedGender = student['gender'] ?? 'Male';
    String selectedClass = student['class'] ?? '1';
    String selectedSection = student['section'] ?? 'Section A';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Student: ${student['regNo']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Student Full Name', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedGender,
                              decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                              items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                              onChanged: (v) => setDialogState(() => selectedGender = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: standardClasses.contains(selectedClass) ? selectedClass : '1',
                              decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                              items: standardClasses.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                              onChanged: (v) => setDialogState(() => selectedClass = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: sections.contains(selectedSection) ? selectedSection : 'Section A',
                              decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder()),
                              items: sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setDialogState(() => selectedSection = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: fatherCtrl, decoration: const InputDecoration(labelText: 'Father Name', border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: cnicCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'B-Form / CNIC', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    final updatedData = Map<String, String>.from(student);
                    updatedData['name'] = nameCtrl.text;
                    updatedData['gender'] = selectedGender;
                    updatedData['class'] = selectedClass;
                    updatedData['section'] = selectedSection;
                    updatedData['father'] = fatherCtrl.text;
                    updatedData['cnic'] = cnicCtrl.text;
                    updatedData['phone'] = phoneCtrl.text;
                    updatedData['address'] = addressCtrl.text;
                    
                    SchoolDataService().updateStudent(student['regNo']!, updatedData);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student Record Updated Successfully!')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Dialog: Transfer Out ---
  static void showTransferDialog(BuildContext context, Map<String, String> student) {
    String reason = 'Transferred / SLC Issued';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Transfer Out / Left Student'),
              content: DropdownButtonFormField<String>(
                value: reason,
                decoration: const InputDecoration(labelText: 'Exit Reason', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Transferred / SLC Issued', child: Text('Transferred / SLC Issued')),
                  DropdownMenuItem(value: 'Passed Out / Graduated', child: Text('Passed Out / Graduated')),
                  DropdownMenuItem(value: 'Left School (Personal Reason)', child: Text('Left School (Personal Reason)')),
                ],
                onChanged: (v) => setDialogState(() => reason = v!),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    SchoolDataService().transferOutStudent(student['regNo']!, reason: reason);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student moved to Previous Students list!')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Dialog: Manage Fines ---
  static void showFineDialog(BuildContext context, Map<String, String> student, bool isActive) {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            List fines = [];
            try { fines = jsonDecode(student['fines'] ?? '[]'); } catch (_) {}
            
            return AlertDialog(
              title: Text('Manage Fines: ${student['name']}'),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (fines.isNotEmpty) 
                      ...fines.asMap().entries.map((e) => ListTile(
                        dense: true,
                        title: Text('Rs. ${e.value['amount']} - ${e.value['reason']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                          onPressed: () {
                            SchoolDataService().removeStudentFine(student['regNo']!, e.key, isActive);
                            setDialogState(() { fines.removeAt(e.key); student['fines'] = jsonEncode(fines); });
                          },
                        ),
                      )),
                    const Divider(),
                    TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fine Amount', border: OutlineInputBorder(), isDense: true)),
                    const SizedBox(height: 8),
                    TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder(), isDense: true)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                ElevatedButton(
                  onPressed: () {
                    if (amountCtrl.text.isNotEmpty) {
                      SchoolDataService().addStudentFine(student['regNo']!, amountCtrl.text, reasonCtrl.text, isActive);
                      setDialogState(() {
                        fines.add({'amount': amountCtrl.text, 'reason': reasonCtrl.text, 'date': DateTime.now().toString().split(' ')[0]});
                        student['fines'] = jsonEncode(fines);
                        amountCtrl.clear();
                        reasonCtrl.clear();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fine Added!')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Add Fine', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}