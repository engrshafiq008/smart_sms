import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'school_data_service.dart';

class AdmissionsScreen extends StatefulWidget {
  const AdmissionsScreen({super.key});

  @override
  State<AdmissionsScreen> createState() => _AdmissionsScreenState();
}

class _AdmissionsScreenState extends State<AdmissionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SchoolDataService _dataService = SchoolDataService();

  final _formKey = GlobalKey<FormState>();
  final _studentNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _prevSchoolController = TextEditingController();
  final _dateController = TextEditingController();
  final _searchController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedGender = 'Male';
  String _selectedYear = '2026';
  String _selectedGrade = '1';
  String _selectedSection = 'Section A';
  String _searchQuery = '';
  
  final List<String> _genders = ['Male', 'Female', 'Other'];
  
  // Standard Classes List (Nursery/KG to 12)
  final List<String> _grades = [
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

  final List<String> _sections = ['Section A', 'Section B', 'Section C', 'Section D'];
  final List<String> _statusOptions = ['Pending', 'Under Review', 'Approved', 'Rejected'];

  // Generate Years from 1947 to 3047
  List<String> _getYearsList() {
    List<String> years = [];
    for (int i = 1947; i <= 3047; i++) {
      years.add(i.toString());
    }
    return years;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _dateController.text = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _tabController.dispose();
    _studentNameController.dispose();
    _fatherNameController.dispose();
    _cnicController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _prevSchoolController.dispose();
    _dateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectEnrollmentDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Under Review':
        return Colors.blueAccent;
      case 'Rejected':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  // FIXED: Added StatefulBuilder to update dropdown inside Dialog
  void _showAddInquiryDialog() {
    final inqParentController = TextEditingController();
    final inqStudentController = TextEditingController();
    final inqPhoneController = TextEditingController();
    final inqNotesController = TextEditingController();
    String inqGrade = '1';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Record New Admission Inquiry', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: inqParentController, decoration: const InputDecoration(labelText: 'Parent / Visitor Name *', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: inqStudentController, decoration: const InputDecoration(labelText: 'Student Name', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(
                      controller: inqPhoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                      decoration: const InputDecoration(labelText: 'Contact Phone Number (11 Digits) *', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: inqGrade,
                      decoration: const InputDecoration(labelText: 'Target Class / Grade', border: OutlineInputBorder()),
                      // FIXED: Explicitly casting to DropdownMenuItem<String>
                      items: _grades.map((g) => DropdownMenuItem<String>(value: g, child: Text(g == 'Nursery/KG' ? g : 'Class $g'))).toList(),
                      onChanged: (val) => setDialogState(() => inqGrade = val!),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: inqNotesController, decoration: const InputDecoration(labelText: 'Notes / Remarks', border: OutlineInputBorder()), maxLines: 2),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (inqParentController.text.isNotEmpty && inqPhoneController.text.isNotEmpty) {
                      _dataService.addInquiry(
                        parentName: inqParentController.text,
                        studentName: inqStudentController.text,
                        grade: inqGrade,
                        phone: inqPhoneController.text,
                        notes: inqNotesController.text,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inquiry Saved Successfully!')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text('Save Inquiry', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _directPrintSlip(Map<String, String> app) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('SMART SCHOOL SYSTEM', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Admission Acknowledgement Slip', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 8),
                _buildPdfRow('Application ID:', app['id'] ?? 'N/A'),
                _buildPdfRow('Academic Year:', app['year'] ?? 'N/A'),
                _buildPdfRow('Enrollment Date:', app['enrollmentDate'] ?? 'N/A'),
                _buildPdfRow('Student Name:', app['name'] ?? 'N/A'),
                _buildPdfRow('Gender:', app['gender'] ?? 'N/A'),
                _buildPdfRow('Father / Guardian:', app['father'] ?? 'N/A'),
                _buildPdfRow('B-Form / CNIC:', app['cnic'] ?? 'N/A'),
                _buildPdfRow('Grade & Section:', '${app['grade'] == 'Nursery/KG' ? app['grade'] : 'Class ${app['grade']}'} (${app['section']})'),
                _buildPdfRow('Contact Phone:', app['phone'] ?? 'N/A'),
                _buildPdfRow('Address:', app['address'] ?? 'N/A'),
                pw.SizedBox(height: 12),
                pw.Divider(thickness: 0.5),
                pw.Text('Note: Please retain this slip for accounts counter submission.', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Admission_Slip_${app['id']}',
    );
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
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
                  labelColor: Colors.blueAccent,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: Colors.blueAccent,
                  indicatorWeight: 3,
                  tabs: [
                    const Tab(icon: Icon(Icons.person_add), text: "New Admission Form"),
                    Tab(icon: const Icon(Icons.help_outline), text: "Inquiry Log (${_dataService.admissionsInquiries.length})"),
                    Tab(icon: const Icon(Icons.list_alt), text: "Application List & Status (${_dataService.admissionApplications.length})"),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNewAdmissionTab(),
                    _buildInquiryTab(),
                    _buildApplicationsListTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewAdmissionTab() {
    final yearsList = _getYearsList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            const Text('Student Enrollment Form', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _studentNameController,
                    decoration: const InputDecoration(labelText: 'Student Full Name *', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Enter student name' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: const InputDecoration(labelText: 'Gender *', border: OutlineInputBorder()),
                    // FIXED: Explicitly casted to DropdownMenuItem<String>
                    items: _genders.map((g) => DropdownMenuItem<String>(value: g, child: Text(g))).toList(),
                    onChanged: (val) => setState(() => _selectedGender = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _selectedYear,
                    decoration: const InputDecoration(labelText: 'Academic Year *', border: OutlineInputBorder()),
                    // FIXED: Explicitly casted to DropdownMenuItem<String>
                    items: yearsList.map((y) => DropdownMenuItem<String>(value: y, child: Text(y))).toList(),
                    onChanged: (val) => setState(() => _selectedYear = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fatherNameController,
                    decoration: const InputDecoration(labelText: 'Father / Guardian Name *', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Enter father name' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _cnicController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(13),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'B-Form / CNIC Number (13 Digits) *',
                      hintText: 'e.g. 3120212345671',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.length != 13 ? 'Enter exact 13 digits' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Mobile Contact Number (11 Digits) *',
                      hintText: 'e.g. 03001234567',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.length != 11 ? 'Enter exact 11 digits' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGrade,
                    decoration: const InputDecoration(labelText: 'Target Class *', border: OutlineInputBorder()),
                    // FIXED: Explicitly casted to DropdownMenuItem<String>
                    items: _grades.map((g) => DropdownMenuItem<String>(value: g, child: Text(g == 'Nursery/KG' ? g : 'Class $g'))).toList(),
                    onChanged: (val) => setState(() => _selectedGrade = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSection,
                    decoration: const InputDecoration(labelText: 'Section *', border: OutlineInputBorder()),
                    // FIXED: Explicitly casted to DropdownMenuItem<String>
                    items: _sections.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setState(() => _selectedSection = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    onTap: () => _selectEnrollmentDate(context),
                    decoration: InputDecoration(
                      labelText: 'Application Date *',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                        onPressed: () => _selectEnrollmentDate(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Residential Address *', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Enter address' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _prevSchoolController,
              decoration: const InputDecoration(labelText: 'Previous School Name (If any)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final newApp = {
                      'id': 'ADM-$_selectedYear-${_dataService.admissionApplications.length + 101}',
                      'year': _selectedYear,
                      'name': _studentNameController.text,
                      'gender': _selectedGender,
                      'father': _fatherNameController.text,
                      'cnic': _cnicController.text,
                      'grade': _selectedGrade,
                      'section': _selectedSection,
                      'status': 'Pending',
                      'phone': _phoneController.text,
                      'address': _addressController.text,
                      'enrollmentDate': _dateController.text,
                    };

                    _dataService.addApplication(newApp);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Admission Application Submitted!')),
                    );

                    _studentNameController.clear();
                    _fatherNameController.clear();
                    _cnicController.clear();
                    _phoneController.clear();
                    _addressController.clear();
                    _prevSchoolController.clear();
                  }
                },
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: const Text('Submit Application', style: TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInquiryTab() {
    final inquiries = _dataService.admissionsInquiries;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Walk-in & Call Inquiries Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showAddInquiryDialog,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('New Inquiry', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: inquiries.isEmpty
                ? const Center(child: Text('No active inquiries recorded yet.', style: TextStyle(color: Colors.black54)))
                : ListView.separated(
                    itemCount: inquiries.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final inq = inquiries[index];
                      return ListTile(
                        key: ValueKey(inq['id']),
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.withOpacity(0.1),
                          child: Text(inq['id']!.split('-').last, style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                        title: Text('Parent: ${inq['parentName']} (Student: ${inq['studentName']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Class: ${inq['grade'] == 'Nursery/KG' ? inq['grade'] : 'Class ${inq['grade']}'} | Phone: ${inq['phone']} \nNotes: ${inq['notes']}'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                _dataService.addApplication({
                                  'id': 'ADM-${DateTime.now().year}-${_dataService.admissionApplications.length + 101}',
                                  'year': DateTime.now().year.toString(),
                                  'name': inq['studentName']!,
                                  'gender': 'Male',
                                  'father': inq['parentName']!,
                                  'cnic': '',
                                  'grade': inq['grade']!,
                                  'section': 'Section A',
                                  'status': 'Pending',
                                  'phone': inq['phone']!,
                                  'address': '',
                                  'enrollmentDate': _dateController.text,
                                });
                                _dataService.deleteInquiry(inq['id']!);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Converted ${inq['studentName']} to Application List!'), backgroundColor: Colors.teal),
                                );
                              },
                              icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                              label: const Text('Convert', style: TextStyle(fontSize: 12, color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _dataService.deleteInquiry(inq['id']!),
                              tooltip: 'Delete Inquiry',
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

  Widget _buildApplicationsListTab() {
    final applications = _dataService.admissionApplications;
    final filteredApps = applications.where((app) {
      final query = _searchQuery.toLowerCase();
      return app['name']!.toLowerCase().contains(query) ||
          app['father']!.toLowerCase().contains(query) ||
          app['id']!.toLowerCase().contains(query);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search by Name, Father Name, or ID...',
              prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: filteredApps.isEmpty
                ? const Center(child: Text('No admission applications found.', style: TextStyle(color: Colors.black54)))
                : ListView.separated(
                    itemCount: filteredApps.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final app = filteredApps[index];
                      Color statusColor = _getStatusColor(app['status']!);

                      return ListTile(
                        key: ValueKey(app['id']),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          child: Text(app['id']!.split('-').last, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        title: Text('${app['name']} (${app['gender']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Year: ${app['year']} | Father: ${app['father']} | Date: ${app['enrollmentDate'] ?? 'N/A'}\nCNIC: ${app['cnic']} | ${app['grade'] == 'Nursery/KG' ? app['grade'] : 'Class ${app['grade']}'} (${app['section']})\nAddress: ${app['address']}'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.print, color: Colors.blueGrey),
                              onPressed: () => _directPrintSlip(app),
                              tooltip: 'Print Admission Slip',
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withOpacity(0.3)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: app['status'],
                                  icon: Icon(Icons.arrow_drop_down, color: statusColor),
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                                  onChanged: (String? newStatus) {
                                    if (newStatus != null) {
                                      if (newStatus == 'Approved') {
                                        _dataService.enrollStudent(
                                          name: app['name']!,
                                          gender: app['gender'] ?? 'Male',
                                          grade: app['grade']!, // FIXED: raw grade sent without manual prefix
                                          section: app['section'] ?? 'Section A',
                                          father: app['father']!,
                                          cnic: app['cnic'] ?? '',
                                          phone: app['phone']!,
                                          address: app['address'] ?? '',
                                          enrollmentDate: app['enrollmentDate'] ?? '',
                                        );

                                        _dataService.deleteApplication(app['id']!);

                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('${app['name']} Approved & Smart Registration Number Assigned!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } else {
                                        _dataService.updateApplicationStatus(app['id']!, newStatus);
                                      }
                                    }
                                  },
                                  // FIXED: Explicitly casted to DropdownMenuItem<String>
                                  items: _statusOptions.map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value, style: TextStyle(color: _getStatusColor(value))),
                                    );
                                  }).toList(),
                                ),
                              ),
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