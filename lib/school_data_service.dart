import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

class SchoolDataService extends ChangeNotifier {
  static final SchoolDataService _instance = SchoolDataService._internal();
  factory SchoolDataService() => _instance;

  final Box _box = Hive.box('school_database');

  SchoolDataService._internal() {
    _loadDataFromHive();
  }

  // --- Master Lists (NO DUMMY DATA) ---
  List<Map<String, String>> activeStudents = [];
  List<Map<String, String>> previousStudents = [];
  List<Map<String, dynamic>> feeVouchers = [];
  List<Map<String, String>> admissionsInquiries = [];
  List<Map<String, String>> admissionApplications = [];
  List<Map<String, String>> teachersList = []; 
  List<Map<String, String>> academicSubjects = [];
  List<Map<String, String>> staffAttendance = [];
  List<Map<String, String>> staffPayroll = [];

  // --- SaaS Settings Global Configuration ---
  Map<String, String> schoolSettings = {
    'schoolName': 'Smart School System',
    'address': 'Main Campus, Bahawalpur, Punjab, Pakistan',
    'phone': '+92 300 0000000',
    'email': 'admin@school.com',
    'academicYear': '2026-2027',
    'currency': 'PKR',
  };

  // --- HIVE: Load Data on Startup ---
  void _loadDataFromHive() {
    activeStudents = _getListFromBox('activeStudents');
    previousStudents = _getListFromBox('previousStudents');
    feeVouchers = _getDynamicListFromBox('feeVouchers');
    admissionsInquiries = _getListFromBox('admissionsInquiries');
    admissionApplications = _getListFromBox('admissionApplications');
    teachersList = _getListFromBox('teachersList');
    academicSubjects = _getListFromBox('academicSubjects');
    staffAttendance = _getListFromBox('staffAttendance');
    staffPayroll = _getListFromBox('staffPayroll');

    var loadedSettings = _box.get('schoolSettings');
    if (loadedSettings != null) {
      schoolSettings = Map<String, String>.from(loadedSettings as Map);
    }
  }

  List<Map<String, String>> _getListFromBox(String key) {
    var data = _box.get(key, defaultValue: []);
    return (data as List).map((e) => Map<String, String>.from(e as Map)).toList();
  }

  List<Map<String, dynamic>> _getDynamicListFromBox(String key) {
    var data = _box.get(key, defaultValue: []);
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _saveData(String key, List data) {
    _box.put(key, data);
    notifyListeners();
  }

  // --- Settings Update Method ---
  void updateSchoolSettings(Map<String, String> newSettings) {
    schoolSettings = newSettings;
    _box.put('schoolSettings', schoolSettings);
    notifyListeners();
  }

  // --- Factory Reset (Clear All Data) ---
  void factoryResetDatabase() {
    _box.clear();
    activeStudents.clear();
    previousStudents.clear();
    feeVouchers.clear();
    admissionsInquiries.clear();
    admissionApplications.clear();
    teachersList.clear();
    academicSubjects.clear();
    staffAttendance.clear();
    staffPayroll.clear();
    notifyListeners();
  }

  // ==========================================
  // ADMISSION METHODS
  // ==========================================
  void addInquiry({required String parentName, required String studentName, required String grade, required String phone, required String notes}) {
    String id = 'INQ-${admissionsInquiries.length + 101}';
    admissionsInquiries.add({
      'id': id, 'parentName': parentName, 'studentName': studentName.isEmpty ? 'N/A' : studentName,
      'grade': grade, 'phone': phone, 'status': 'New', 'notes': notes.isEmpty ? 'No notes' : notes,
    });
    _saveData('admissionsInquiries', admissionsInquiries);
  }

  void deleteInquiry(String id) {
    admissionsInquiries.removeWhere((i) => i['id'] == id);
    _saveData('admissionsInquiries', admissionsInquiries);
  }

  void addApplication(Map<String, String> appData) {
    admissionApplications.add(appData);
    _saveData('admissionApplications', admissionApplications);
  }

  void deleteApplication(String id) {
    admissionApplications.removeWhere((a) => a['id'] == id);
    _saveData('admissionApplications', admissionApplications);
  }

  void updateApplicationStatus(String id, String status) {
    int index = admissionApplications.indexWhere((a) => a['id'] == id);
    if (index != -1) {
      admissionApplications[index]['status'] = status;
      _saveData('admissionApplications', admissionApplications);
    }
  }

  // ==========================================
  // HR, TEACHER & ACADEMICS METHODS
  // ==========================================
  void addTeacher({required String name, required String gender, required String father, required String cnic, required String phone, required String address, required String joiningDate}) {
    String id = 'TCH-${teachersList.length + 101}';
    teachersList.add({
      'id': id, 'name': name, 'gender': gender, 'father': father,
      'cnic': cnic, 'phone': phone, 'address': address, 'joiningDate': joiningDate,
      'role': 'Teacher', 'basicSalary': '0',
    });
    _saveData('teachersList', teachersList);
  }

  void updateTeacher(String id, Map<String, String> updatedData) {
    int index = teachersList.indexWhere((t) => t['id'] == id);
    if (index != -1) {
      teachersList[index] = updatedData;
      _saveData('teachersList', teachersList);
    }
  }

  void deleteTeacher(String id) {
    int index = teachersList.indexWhere((t) => t['id'] == id);
    if (index != -1) {
      String teacherName = teachersList[index]['name']!;
      teachersList.removeAt(index);
      _saveData('teachersList', teachersList);
      
      for (var subject in academicSubjects) {
        if (subject['teacher'] == teacherName) {
          subject['teacher'] = 'Unassigned';
        }
      }
      _saveData('academicSubjects', academicSubjects);
    }
  }

  void saveAttendance(String date, Map<String, String> attendanceData) {
    staffAttendance.removeWhere((a) => a['date'] == date);
    attendanceData.forEach((staffId, status) {
      staffAttendance.add({
        'id': 'ATT-${DateTime.now().millisecondsSinceEpoch}-$staffId',
        'date': date,
        'staffId': staffId,
        'status': status,
      });
    });
    _saveData('staffAttendance', staffAttendance);
  }

  Map<String, String> getAttendanceForDate(String date) {
    Map<String, String> result = {};
    for (var a in staffAttendance.where((a) => a['date'] == date)) {
      result[a['staffId']!] = a['status']!;
    }
    return result;
  }

  void generateSalarySlip(Map<String, String> slipData) {
    slipData['id'] = 'PAY-${DateTime.now().millisecondsSinceEpoch}';
    staffPayroll.add(slipData);
    _saveData('staffPayroll', staffPayroll);
  }

  void updateSalaryStatus(String slipId, String status) {
    int index = staffPayroll.indexWhere((s) => s['id'] == slipId);
    if (index != -1) {
      staffPayroll[index]['status'] = status;
      _saveData('staffPayroll', staffPayroll);
    }
  }

  void deleteSalarySlip(String slipId) {
    staffPayroll.removeWhere((s) => s['id'] == slipId);
    _saveData('staffPayroll', staffPayroll);
  }

  // ==========================================
  // STUDENT METHODS
  // ==========================================
  String _generateSmartRegistrationNumber(String grade, String section) {
    String classCode = grade.replaceAll('Class ', '').trim();
    String secCode = section.replaceAll('Section ', '').trim();
    int rollCounter = activeStudents.length + previousStudents.length + 101;
    String yearShort = DateTime.now().year.toString().substring(2);
    return 'SMART-C$classCode-$secCode-$rollCounter-$yearShort';
  }

  void enrollStudent({required String name, required String gender, required String grade, required String section, required String father, required String cnic, required String phone, required String address, required String enrollmentDate}) {
    String regNo = _generateSmartRegistrationNumber(grade, section);
    bool exists = activeStudents.any((s) => s['name'] == name && s['father'] == father);
    String cleanGrade = grade.replaceAll('Class ', '').trim();

    if (!exists) {
      activeStudents.add({
        'regNo': regNo, 'name': name, 'gender': gender, 'class': cleanGrade,
        'section': section, 'father': father, 'cnic': cnic, 'phone': phone,
        'address': address, 'enrollmentDate': enrollmentDate, 'fines': '[]',
      });
      _saveData('activeStudents', activeStudents);
    }
  }

  void updateStudent(String regNo, Map<String, String> updatedData) {
    int index = activeStudents.indexWhere((s) => s['regNo'] == regNo);
    if (index != -1) {
      activeStudents[index] = updatedData;
      _saveData('activeStudents', activeStudents);
    }
  }

  void transferOutStudent(String regNo, {required String reason}) {
    int index = activeStudents.indexWhere((s) => s['regNo'] == regNo);
    if (index != -1) {
      var student = Map<String, String>.from(activeStudents[index]);
      student['exitDate'] = DateTime.now().toString().split(' ')[0];
      student['exitReason'] = reason;
      previousStudents.add(student);
      activeStudents.removeAt(index);
      _saveData('activeStudents', activeStudents);
      _saveData('previousStudents', previousStudents);
    }
  }

  void restoreStudent(String regNo) {
    int index = previousStudents.indexWhere((s) => s['regNo'] == regNo);
    if (index != -1) {
      var student = Map<String, String>.from(previousStudents[index]);
      student.remove('exitDate');
      student.remove('exitReason');
      activeStudents.add(student);
      previousStudents.removeAt(index);
      _saveData('activeStudents', activeStudents);
      _saveData('previousStudents', previousStudents);
    }
  }

  void deletePermanently(String regNo) {
    previousStudents.removeWhere((s) => s['regNo'] == regNo);
    _saveData('previousStudents', previousStudents);
  }

  void addStudentFine(String regNo, String amount, String reason, bool isActive) {
    List<Map<String, String>> targetList = isActive ? activeStudents : previousStudents;
    int index = targetList.indexWhere((s) => s['regNo'] == regNo);
    if (index != -1) {
      List fines = jsonDecode(targetList[index]['fines'] ?? '[]');
      fines.add({'amount': amount, 'reason': reason, 'date': DateTime.now().toString().split(' ')[0]});
      targetList[index]['fines'] = jsonEncode(fines);
      _saveData(isActive ? 'activeStudents' : 'previousStudents', targetList);
    }
  }

  void removeStudentFine(String regNo, int fineIndex, bool isActive) {
    List<Map<String, String>> targetList = isActive ? activeStudents : previousStudents;
    int index = targetList.indexWhere((s) => s['regNo'] == regNo);
    if (index != -1) {
      List fines = jsonDecode(targetList[index]['fines'] ?? '[]');
      if (fineIndex >= 0 && fineIndex < fines.length) {
        fines.removeAt(fineIndex);
        targetList[index]['fines'] = jsonEncode(fines);
        _saveData(isActive ? 'activeStudents' : 'previousStudents', targetList);
      }
    }
  }

  List<Map<String, String>> getStudentsByClassAndSection(String className, String sectionName) {
    return activeStudents.where((student) {
      String dbClass = (student['class'] ?? '').replaceAll('Class ', '').trim();
      String targetClass = className.replaceAll('Class ', '').trim();
      bool matchesClass = (className == 'All Classes') || (dbClass == targetClass);
      bool matchesSection = (sectionName == 'All Sections') || (student['section'] == sectionName);
      return matchesClass && matchesSection;
    }).toList();
  }

  // ==========================================
  // ACADEMIC & FEE VOUCHERS METHODS
  // ==========================================
  void addSubject({required String name, required String code, required String className, required String section, required String period, required String teacher}) {
    academicSubjects.add({
      'id': 'SUB-${academicSubjects.length + 101}', 'name': name, 'code': code,
      'class': className, 'section': section, 'period': period, 'teacher': teacher,
    });
    _saveData('academicSubjects', academicSubjects);
  }

  void updateSubject(String id, Map<String, String> updatedData) {
    int index = academicSubjects.indexWhere((s) => s['id'] == id);
    if (index != -1) {
      academicSubjects[index] = updatedData;
      _saveData('academicSubjects', academicSubjects);
    }
  }

  void deleteSubject(String id) {
    academicSubjects.removeWhere((s) => s['id'] == id);
    _saveData('academicSubjects', academicSubjects);
  }

  void generateVoucher({required String regNo, required String studentName, required String className, required String section, required String month, required String tuitionFee, required String admissionFee, required String fine, required String dueDate}) {
    double tuition = double.tryParse(tuitionFee) ?? 0;
    double admission = double.tryParse(admissionFee) ?? 0;
    double f = double.tryParse(fine) ?? 0;
    double total = tuition + admission + f;
    String voucherNo = 'VOUCH-2026-${feeVouchers.length + 101}';
    feeVouchers.add({
      'voucherNo': voucherNo, 'regNo': regNo, 'studentName': studentName,
      'className': className, 'section': section, 'month': month,
      'tuitionFee': tuition.toString(), 'admissionFee': admission.toString(),
      'fine': f.toString(), 'totalAmount': total.toString(), 'dueDate': dueDate,
      'status': 'Unpaid', 'issueDate': DateTime.now().toString().split(' ')[0],
    });
    _saveData('feeVouchers', feeVouchers);
  }

  void updateVoucherStatus(String voucherNo, String status) {
    int index = feeVouchers.indexWhere((v) => v['voucherNo'] == voucherNo);
    if (index != -1) {
      feeVouchers[index]['status'] = status;
      _saveData('feeVouchers', feeVouchers);
    }
  }

  void deleteVoucher(String voucherNo) {
    feeVouchers.removeWhere((v) => v['voucherNo'] == voucherNo);
    _saveData('feeVouchers', feeVouchers);
  }
}