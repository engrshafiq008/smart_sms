import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class SchoolDataService extends ChangeNotifier {
  static final SchoolDataService _instance = SchoolDataService._internal();
  factory SchoolDataService() => _instance;

  Box? _box;
  String? _currentUid;
  String? get currentUid => _currentUid;
  bool get isInitialized => _box != null && _box!.isOpen;

  // --- Cloud Sync Status Telemetry ---
  String? lastSyncError;
  bool isSyncing = false;
  DateTime? lastSyncTime;

  SchoolDataService._internal();

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
  List<Map<String, String>> studentAttendance = [];
  List<Map<String, dynamic>> examsList = [];
  List<Map<String, dynamic>> examResults = [];

  // --- SaaS Settings Global Configuration ---
  Map<String, String> schoolSettings = {
    'schoolName': 'Smart School System',
    'address': 'Main Campus, Pakistan',
    'phone': '+92 300 0000000',
    'email': 'admin@school.com',
    'academicYear': '2026-2027',
    'currency': 'PKR',
  };

  // --- Multi-Tenant: Initialize Database for Specific User/School UID ---
  Future<void> initForUser(String uid, {Map<String, String>? initialSettings}) async {
    if (_currentUid == uid && _box != null && _box!.isOpen) {
      if (initialSettings != null && (schoolSettings.isEmpty || schoolSettings['schoolName'] == 'Smart School System')) {
        await saveSchoolSettingsAsync(initialSettings);
      }
      return;
    }

    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }

    _currentUid = uid;
    String boxName = 'school_db_$uid';
    _box = await Hive.openBox(boxName);

    // 1. Load local Hive data first for instant UI response
    _loadDataFromHive(initialSettings: initialSettings);
    notifyListeners();

    // 2. Perform background check on Firestore for cloud pulling or auto-migration
    await _checkAndSyncFirestore();
  }

  // --- Multi-Tenant: Detach on Logout ---
  Future<void> detachUser() async {
    activeStudents.clear();
    previousStudents.clear();
    feeVouchers.clear();
    admissionsInquiries.clear();
    admissionApplications.clear();
    teachersList.clear();
    academicSubjects.clear();
    staffAttendance.clear();
    staffPayroll.clear();
    studentAttendance.clear();
    examsList.clear();
    examResults.clear();
    schoolSettings.clear();
    lastSyncError = null;
    lastSyncTime = null;

    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
    _box = null;
    _currentUid = null;
    notifyListeners();
  }

  // --- HIVE: Load Data from User Box ---
  void _loadDataFromHive({Map<String, String>? initialSettings}) {
    if (_box == null) return;
    activeStudents = _getListFromBox('activeStudents');
    previousStudents = _getListFromBox('previousStudents');
    feeVouchers = _getDynamicListFromBox('feeVouchers');
    admissionsInquiries = _getListFromBox('admissionsInquiries');
    admissionApplications = _getListFromBox('admissionApplications');
    teachersList = _getListFromBox('teachersList');
    academicSubjects = _getListFromBox('academicSubjects');
    staffAttendance = _getListFromBox('staffAttendance');
    staffPayroll = _getListFromBox('staffPayroll');
    studentAttendance = _getListFromBox('studentAttendance');
    examsList = _getDynamicListFromBox('examsList');
    examResults = _getDynamicListFromBox('examResults');

    var loadedSettings = _box?.get('schoolSettings');
    if (loadedSettings != null) {
      schoolSettings = Map<String, String>.from(loadedSettings as Map);
    } else if (initialSettings != null) {
      schoolSettings = Map<String, String>.from(initialSettings);
      _box?.put('schoolSettings', schoolSettings);
    } else {
      schoolSettings = {
        'schoolName': 'Smart School System',
        'address': 'Main Campus',
        'phone': '+92 300 0000000',
        'email': 'admin@school.com',
        'academicYear': '2026-2027',
        'currency': 'PKR',
      };
    }
  }

  List<Map<String, String>> _getListFromBox(String key) {
    if (_box == null) return [];
    var data = _box!.get(key, defaultValue: []);
    return (data as List).map((e) => Map<String, String>.from(e as Map)).toList();
  }

  List<Map<String, dynamic>> _getDynamicListFromBox(String key) {
    if (_box == null) return [];
    var data = _box!.get(key, defaultValue: []);
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _saveData(String key, List data) {
    _box?.put(key, data);
    notifyListeners();
  }

  // ==========================================
  // FIRESTORE CLOUD SYNC & AUTO-MIGRATION
  // ==========================================

  /// Background verification during login: Pulls latest cloud data or auto-migrates local records
  Future<void> _checkAndSyncFirestore() async {
    if (_currentUid == null) return;
    try {
      final schoolRef = FirebaseFirestore.instance.collection('schools').doc(_currentUid);
      final schoolSnap = await schoolRef.get();

      if (!schoolSnap.exists) {
        // Document does NOT exist in Firestore yet!
        // If local Hive already has schoolSettings or records, auto-migrate to Firestore right away.
        bool hasLocalData = (schoolSettings['schoolName'] != null && schoolSettings['schoolName'] != 'Smart School System') ||
            activeStudents.isNotEmpty ||
            teachersList.isNotEmpty;

        if (hasLocalData) {
          debugPrint('Auto-migrating local school data to Firestore for uid: $_currentUid');
          await syncAllToFirestore();
        }
      } else {
        // Document EXISTS in Firestore -> pull latest schoolSettings and all subcollections
        await _pullAllFromFirestoreRef(schoolRef, schoolSnap.data());
      }
    } catch (e) {
      debugPrint('Firestore Sync Error: $e');
      lastSyncError = 'Firestore Sync Error: $e';
      notifyListeners();
    }
  }

  /// Manually or automatically pulls all cloud subcollections into local Hive
  Future<void> _pullAllFromFirestoreRef(DocumentReference schoolRef, Map<String, dynamic>? data) async {
    isSyncing = true;
    notifyListeners();

    try {
      if (data != null) {
        schoolSettings = {
          'schoolName': data['schoolName']?.toString() ?? 'Smart School System',
          'address': data['address']?.toString() ?? '',
          'phone': data['phone']?.toString() ?? '',
          'email': data['email']?.toString() ?? '',
          'academicYear': data['academicYear']?.toString() ?? '2026-2027',
          'currency': data['currency']?.toString() ?? 'PKR',
        };
        if (data.containsKey('ownerName') && data['ownerName'] != null) {
          schoolSettings['ownerName'] = data['ownerName'].toString();
        }
        _box?.put('schoolSettings', schoolSettings);
      }

      // 1. active_students
      final activeSnap = await schoolRef.collection('active_students').get();
      if (activeSnap.docs.isNotEmpty) {
        activeStudents = activeSnap.docs.map((d) => Map<String, String>.from(d.data().map((k, v) => MapEntry(k, v?.toString() ?? '')))).toList();
        _box?.put('activeStudents', activeStudents);
      }

      // 2. previous_students
      final prevSnap = await schoolRef.collection('previous_students').get();
      if (prevSnap.docs.isNotEmpty) {
        previousStudents = prevSnap.docs.map((d) => Map<String, String>.from(d.data().map((k, v) => MapEntry(k, v?.toString() ?? '')))).toList();
        _box?.put('previousStudents', previousStudents);
      }

      // 3. admissions_inquiries
      final inqSnap = await schoolRef.collection('admissions_inquiries').get();
      if (inqSnap.docs.isNotEmpty) {
        admissionsInquiries = inqSnap.docs.map((d) => Map<String, String>.from(d.data().map((k, v) => MapEntry(k, v?.toString() ?? '')))).toList();
        _box?.put('admissionsInquiries', admissionsInquiries);
      }

      // 4. admission_applications
      final appSnap = await schoolRef.collection('admission_applications').get();
      if (appSnap.docs.isNotEmpty) {
        admissionApplications = appSnap.docs.map((d) => Map<String, String>.from(d.data().map((k, v) => MapEntry(k, v?.toString() ?? '')))).toList();
        _box?.put('admissionApplications', admissionApplications);
      }

      // 5. staff (teachersList)
      final staffSnap = await schoolRef.collection('staff').get();
      if (staffSnap.docs.isNotEmpty) {
        teachersList = staffSnap.docs.map((d) => Map<String, String>.from(d.data().map((k, v) => MapEntry(k, v?.toString() ?? '')))).toList();
        _box?.put('teachersList', teachersList);
      }

      // 6. academic_subjects
      final subSnap = await schoolRef.collection('academic_subjects').get();
      if (subSnap.docs.isNotEmpty) {
        academicSubjects = subSnap.docs.map((d) => Map<String, String>.from(d.data().map((k, v) => MapEntry(k, v?.toString() ?? '')))).toList();
        _box?.put('academicSubjects', academicSubjects);
      }

      // 7. staff_attendance
      final staffAttSnap = await schoolRef.collection('staff_attendance').get();
      if (staffAttSnap.docs.isNotEmpty) {
        staffAttendance = staffAttSnap.docs.map((d) => Map<String, String>.from(d.data().map((k, v) => MapEntry(k, v?.toString() ?? '')))).toList();
        _box?.put('staffAttendance', staffAttendance);
      }

      // 8. staff_payroll
      final payrollSnap = await schoolRef.collection('staff_payroll').get();
      if (payrollSnap.docs.isNotEmpty) {
        staffPayroll = payrollSnap.docs.map((d) => Map<String, String>.from(d.data().map((k, v) => MapEntry(k, v?.toString() ?? '')))).toList();
        _box?.put('staffPayroll', staffPayroll);
      }

      // 9. fee_vouchers
      final voucherSnap = await schoolRef.collection('fee_vouchers').get();
      if (voucherSnap.docs.isNotEmpty) {
        feeVouchers = voucherSnap.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();
        _box?.put('feeVouchers', feeVouchers);
      }

      // 10. student_attendance
      final stuAttSnap = await schoolRef.collection('student_attendance').get();
      if (stuAttSnap.docs.isNotEmpty) {
        studentAttendance = stuAttSnap.docs.map((d) => Map<String, String>.from(d.data().map((k, v) => MapEntry(k, v?.toString() ?? '')))).toList();
        _box?.put('studentAttendance', studentAttendance);
      }

      // 11. exams
      final examsSnap = await schoolRef.collection('exams').get();
      if (examsSnap.docs.isNotEmpty) {
        examsList = examsSnap.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();
        _box?.put('examsList', examsList);
      }

      // 12. exam_results
      final resultsSnap = await schoolRef.collection('exam_results').get();
      if (resultsSnap.docs.isNotEmpty) {
        examResults = resultsSnap.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();
        _box?.put('examResults', examResults);
      }

      // Catch-up check: If local Hive had data while Firestore was empty, push local records to Firestore
      bool firestoreMissingRecords = activeSnap.docs.isEmpty && activeStudents.isNotEmpty;
      if (firestoreMissingRecords) {
        await syncAllToFirestore();
      } else {
        lastSyncTime = DateTime.now();
        lastSyncError = null;
      }
    } catch (e) {
      debugPrint('Firestore Sync Error: $e');
      lastSyncError = 'Firestore Sync Error: $e';
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  /// Pushes all local Hive records and settings to Cloud Firestore under schools/{uid}
  Future<void> syncAllToFirestore() async {
    if (_currentUid == null) {
      throw Exception('No user is currently logged in.');
    }

    isSyncing = true;
    lastSyncError = null;
    notifyListeners();

    try {
      final schoolRef = FirebaseFirestore.instance.collection('schools').doc(_currentUid);

      // 1. Sync Document schools/{uid}
      final Map<String, dynamic> schoolDoc = {
        'schoolName': schoolSettings['schoolName'] ?? '',
        'address': schoolSettings['address'] ?? '',
        'phone': schoolSettings['phone'] ?? '',
        'email': schoolSettings['email'] ?? '',
        'academicYear': schoolSettings['academicYear'] ?? '2026-2027',
        'currency': schoolSettings['currency'] ?? 'PKR',
        'ownerUid': _currentUid,
        'ownerEmail': schoolSettings['email'] ?? '',
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (schoolSettings.containsKey('ownerName') && (schoolSettings['ownerName'] ?? '').isNotEmpty) {
        schoolDoc['ownerName'] = schoolSettings['ownerName'];
      }
      if (schoolSettings.containsKey('createdAt') && (schoolSettings['createdAt'] ?? '').isNotEmpty) {
        schoolDoc['createdAt'] = schoolSettings['createdAt'];
      }
      await schoolRef.set(schoolDoc, SetOptions(merge: true));

      // 2. Upload Subcollections in atomic batches (max 400 per batch)
      await _uploadListInBatches(schoolRef, 'active_students', activeStudents, (item) => item['regNo'] ?? '');
      await _uploadListInBatches(schoolRef, 'previous_students', previousStudents, (item) => item['regNo'] ?? '');
      await _uploadListInBatches(schoolRef, 'admissions_inquiries', admissionsInquiries, (item) => item['id'] ?? '');
      await _uploadListInBatches(schoolRef, 'admission_applications', admissionApplications, (item) => item['id'] ?? '');
      await _uploadListInBatches(schoolRef, 'staff', teachersList, (item) => item['id'] ?? '');
      await _uploadListInBatches(schoolRef, 'academic_subjects', academicSubjects, (item) => item['id'] ?? '');
      await _uploadListInBatches(schoolRef, 'staff_attendance', staffAttendance, (item) => item['id'] ?? '');
      await _uploadListInBatches(schoolRef, 'staff_payroll', staffPayroll, (item) => item['id'] ?? '');
      await _uploadListInBatches(schoolRef, 'fee_vouchers', feeVouchers, (item) => item['voucherNo'] ?? '');
      await _uploadListInBatches(
        schoolRef,
        'student_attendance',
        studentAttendance,
        (item) => (item['id'] != null && (item['id'] as String).isNotEmpty)
            ? item['id']
            : '${item['date']}_${item['className']}_${item['section']}_${item['regNo']}',
      );
      await _uploadListInBatches(schoolRef, 'exams', examsList, (item) => item['id'] ?? '');
      await _uploadListInBatches(
        schoolRef,
        'exam_results',
        examResults,
        (item) => (item['id'] != null && (item['id'] as String).isNotEmpty)
            ? item['id']
            : '${item['examId']}_${item['regNo']}',
      );

      lastSyncTime = DateTime.now();
      lastSyncError = null;
      debugPrint('Firestore Sync Success: All records synced to schools/$_currentUid');
    } catch (e) {
      debugPrint('Firestore Sync Error: $e');
      lastSyncError = 'Firestore Sync Error: $e';
      rethrow;
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  /// Helper to upload items in Firestore batches (max 400 items per batch)
  Future<void> _uploadListInBatches(
    DocumentReference schoolRef,
    String subcollection,
    List list,
    String Function(dynamic item) getId,
  ) async {
    if (list.isEmpty) return;
    const int batchLimit = 400;
    for (int i = 0; i < list.length; i += batchLimit) {
      final chunk = list.sublist(i, (i + batchLimit > list.length) ? list.length : i + batchLimit);
      final batch = FirebaseFirestore.instance.batch();
      for (var item in chunk) {
        final id = getId(item);
        if (id.isNotEmpty) {
          final docRef = schoolRef.collection(subcollection).doc(id);
          final mapData = Map<String, dynamic>.from(item as Map);
          batch.set(docRef, mapData, SetOptions(merge: true));
        }
      }
      await batch.commit();
    }
  }

  /// Mirrors a single document addition/update to Firestore in the background
  void _setFirestoreDoc(String subcollection, String docId, Map<String, dynamic> data) {
    if (_currentUid == null || docId.isEmpty) return;
    FirebaseFirestore.instance
        .collection('schools')
        .doc(_currentUid)
        .collection(subcollection)
        .doc(docId)
        .set(data, SetOptions(merge: true))
        .then((_) {
          lastSyncError = null;
        })
        .catchError((e) {
          debugPrint('Firestore Sync Error on [$subcollection/$docId]: $e');
          lastSyncError = 'Firestore Sync Error: $e';
          notifyListeners();
        });
  }

  /// Mirrors a single document deletion to Firestore in the background
  void _deleteFirestoreDoc(String subcollection, String docId) {
    if (_currentUid == null || docId.isEmpty) return;
    FirebaseFirestore.instance
        .collection('schools')
        .doc(_currentUid)
        .collection(subcollection)
        .doc(docId)
        .delete()
        .then((_) {
          lastSyncError = null;
        })
        .catchError((e) {
          debugPrint('Firestore Sync Error deleting [$subcollection/$docId]: $e');
          lastSyncError = 'Firestore Delete Error: $e';
          notifyListeners();
        });
  }

  // ==========================================
  // SETTINGS METHODS
  // ==========================================

  /// Async update for settings with direct Firestore await
  Future<void> saveSchoolSettingsAsync(Map<String, String> newSettings) async {
    schoolSettings = Map<String, String>.from(newSettings);
    _box?.put('schoolSettings', schoolSettings);
    notifyListeners();

    if (_currentUid != null) {
      final docData = {
        'schoolName': schoolSettings['schoolName'] ?? '',
        'address': schoolSettings['address'] ?? '',
        'phone': schoolSettings['phone'] ?? '',
        'email': schoolSettings['email'] ?? '',
        'academicYear': schoolSettings['academicYear'] ?? '2026-2027',
        'currency': schoolSettings['currency'] ?? 'PKR',
        'ownerUid': _currentUid,
        'ownerEmail': schoolSettings['email'] ?? '',
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (schoolSettings.containsKey('ownerName')) {
        docData['ownerName'] = schoolSettings['ownerName']!;
      }
      try {
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(_currentUid)
            .set(docData, SetOptions(merge: true));
        lastSyncError = null;
        lastSyncTime = DateTime.now();
      } catch (e) {
        debugPrint('Firestore Sync Error on settings: $e');
        lastSyncError = 'Settings Sync Error: $e';
        rethrow;
      }
    }
  }

  void updateSchoolSettings(Map<String, String> newSettings) {
    saveSchoolSettingsAsync(newSettings).catchError((e) {
      debugPrint('Firestore updateSchoolSettings error: $e');
    });
  }

  // --- Factory Reset (Clear All Data for Current Tenant) ---
  void factoryResetDatabase() {
    _box?.clear();
    activeStudents.clear();
    previousStudents.clear();
    feeVouchers.clear();
    admissionsInquiries.clear();
    admissionApplications.clear();
    teachersList.clear();
    academicSubjects.clear();
    staffAttendance.clear();
    staffPayroll.clear();
    studentAttendance.clear();
    examsList.clear();
    examResults.clear();
    notifyListeners();
  }

  // ==========================================
  // ADMISSION METHODS
  // ==========================================
  void addInquiry({required String parentName, required String studentName, required String grade, required String phone, required String notes}) {
    String id = 'INQ-${admissionsInquiries.length + 101}';
    final item = {
      'id': id, 'parentName': parentName, 'studentName': studentName.isEmpty ? 'N/A' : studentName,
      'grade': grade, 'phone': phone, 'status': 'New', 'notes': notes.isEmpty ? 'No notes' : notes,
    };
    admissionsInquiries.add(item);
    _saveData('admissionsInquiries', admissionsInquiries);
    _setFirestoreDoc('admissions_inquiries', id, item);
  }

  void deleteInquiry(String id) {
    admissionsInquiries.removeWhere((i) => i['id'] == id);
    _saveData('admissionsInquiries', admissionsInquiries);
    _deleteFirestoreDoc('admissions_inquiries', id);
  }

  void addApplication(Map<String, String> appData) {
    admissionApplications.add(appData);
    _saveData('admissionApplications', admissionApplications);
    _setFirestoreDoc('admission_applications', appData['id'] ?? '', appData);
  }

  void deleteApplication(String id) {
    admissionApplications.removeWhere((a) => a['id'] == id);
    _saveData('admissionApplications', admissionApplications);
    _deleteFirestoreDoc('admission_applications', id);
  }

  void updateApplicationStatus(String id, String status) {
    int index = admissionApplications.indexWhere((a) => a['id'] == id);
    if (index != -1) {
      admissionApplications[index]['status'] = status;
      _saveData('admissionApplications', admissionApplications);
      _setFirestoreDoc('admission_applications', id, admissionApplications[index]);
    }
  }

  // ==========================================
  // HR, TEACHER & ACADEMICS METHODS
  // ==========================================
  void addTeacher({required String name, required String gender, required String father, required String cnic, required String phone, required String address, required String joiningDate}) {
    String id = 'TCH-${teachersList.length + 101}';
    final teacher = {
      'id': id, 'name': name, 'gender': gender, 'father': father,
      'cnic': cnic, 'phone': phone, 'address': address, 'joiningDate': joiningDate,
      'role': 'Teacher', 'basicSalary': '0',
    };
    teachersList.add(teacher);
    _saveData('teachersList', teachersList);
    _setFirestoreDoc('staff', id, teacher);
  }

  void updateTeacher(String id, Map<String, String> updatedData) {
    int index = teachersList.indexWhere((t) => t['id'] == id);
    if (index != -1) {
      teachersList[index] = updatedData;
      _saveData('teachersList', teachersList);
      _setFirestoreDoc('staff', id, updatedData);
    }
  }

  void deleteTeacher(String id) {
    int index = teachersList.indexWhere((t) => t['id'] == id);
    if (index != -1) {
      String teacherName = teachersList[index]['name']!;
      teachersList.removeAt(index);
      _saveData('teachersList', teachersList);
      _deleteFirestoreDoc('staff', id);
      
      for (var subject in academicSubjects) {
        if (subject['teacher'] == teacherName) {
          subject['teacher'] = 'Unassigned';
          _setFirestoreDoc('academic_subjects', subject['id'] ?? '', subject);
        }
      }
      _saveData('academicSubjects', academicSubjects);
    }
  }

  void saveAttendance(String date, Map<String, String> attendanceData) {
    staffAttendance.removeWhere((a) => a['date'] == date);
    attendanceData.forEach((staffId, status) {
      final item = {
        'id': 'ATT-${DateTime.now().millisecondsSinceEpoch}-$staffId',
        'date': date,
        'staffId': staffId,
        'status': status,
      };
      staffAttendance.add(item);
      _setFirestoreDoc('staff_attendance', item['id']!, item);
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
    _setFirestoreDoc('staff_payroll', slipData['id']!, slipData);
  }

  void updateSalaryStatus(String slipId, String status) {
    int index = staffPayroll.indexWhere((s) => s['id'] == slipId);
    if (index != -1) {
      staffPayroll[index]['status'] = status;
      _saveData('staffPayroll', staffPayroll);
      _setFirestoreDoc('staff_payroll', slipId, staffPayroll[index]);
    }
  }

  void deleteSalarySlip(String slipId) {
    staffPayroll.removeWhere((s) => s['id'] == slipId);
    _saveData('staffPayroll', staffPayroll);
    _deleteFirestoreDoc('staff_payroll', slipId);
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
      final student = {
        'regNo': regNo, 'name': name, 'gender': gender, 'class': cleanGrade,
        'section': section, 'father': father, 'cnic': cnic, 'phone': phone,
        'address': address, 'enrollmentDate': enrollmentDate, 'fines': '[]',
      };
      activeStudents.add(student);
      _saveData('activeStudents', activeStudents);
      _setFirestoreDoc('active_students', regNo, student);
    }
  }

  int bulkPromoteStudents({required String fromClass, required String toClass}) {
    int count = 0;
    for (var student in activeStudents) {
      String dbClass = (student['class'] ?? '').replaceAll('Class ', '').trim();
      if (dbClass == fromClass) {
        student['class'] = toClass;
        count++;
        _setFirestoreDoc('active_students', student['regNo']!, student);
      }
    }
    if (count > 0) {
      _saveData('activeStudents', activeStudents);
    }
    return count;
  }

  void updateStudent(String regNo, Map<String, String> updatedData) {
    int index = activeStudents.indexWhere((s) => s['regNo'] == regNo);
    if (index != -1) {
      activeStudents[index] = updatedData;
      _saveData('activeStudents', activeStudents);
      _setFirestoreDoc('active_students', regNo, updatedData);
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
      _deleteFirestoreDoc('active_students', regNo);
      _setFirestoreDoc('previous_students', regNo, student);
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
      _deleteFirestoreDoc('previous_students', regNo);
      _setFirestoreDoc('active_students', regNo, student);
    }
  }

  void deletePermanently(String regNo) {
    previousStudents.removeWhere((s) => s['regNo'] == regNo);
    _saveData('previousStudents', previousStudents);
    _deleteFirestoreDoc('previous_students', regNo);
  }

  void addStudentFine(String regNo, String amount, String reason, bool isActive) {
    List<Map<String, String>> targetList = isActive ? activeStudents : previousStudents;
    int index = targetList.indexWhere((s) => s['regNo'] == regNo);
    if (index != -1) {
      List fines = jsonDecode(targetList[index]['fines'] ?? '[]');
      fines.add({'amount': amount, 'reason': reason, 'date': DateTime.now().toString().split(' ')[0]});
      targetList[index]['fines'] = jsonEncode(fines);
      _saveData(isActive ? 'activeStudents' : 'previousStudents', targetList);
      _setFirestoreDoc(isActive ? 'active_students' : 'previous_students', regNo, targetList[index]);
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
        _setFirestoreDoc(isActive ? 'active_students' : 'previous_students', regNo, targetList[index]);
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
    final subject = {
      'id': 'SUB-${academicSubjects.length + 101}', 'name': name, 'code': code,
      'class': className, 'section': section, 'period': period, 'teacher': teacher,
    };
    academicSubjects.add(subject);
    _saveData('academicSubjects', academicSubjects);
    _setFirestoreDoc('academic_subjects', subject['id']!, subject);
  }

  void updateSubject(String id, Map<String, String> updatedData) {
    int index = academicSubjects.indexWhere((s) => s['id'] == id);
    if (index != -1) {
      academicSubjects[index] = updatedData;
      _saveData('academicSubjects', academicSubjects);
      _setFirestoreDoc('academic_subjects', id, updatedData);
    }
  }

  void deleteSubject(String id) {
    academicSubjects.removeWhere((s) => s['id'] == id);
    _saveData('academicSubjects', academicSubjects);
    _deleteFirestoreDoc('academic_subjects', id);
  }

  void generateVoucher({required String regNo, required String studentName, required String className, required String section, required String month, required String tuitionFee, required String admissionFee, required String fine, required String dueDate}) {
    double tuition = double.tryParse(tuitionFee) ?? 0;
    double admission = double.tryParse(admissionFee) ?? 0;
    double f = double.tryParse(fine) ?? 0;
    double total = tuition + admission + f;
    String voucherNo = 'VOUCH-2026-${feeVouchers.length + 101}';
    final voucher = {
      'voucherNo': voucherNo, 'regNo': regNo, 'studentName': studentName,
      'className': className, 'section': section, 'month': month,
      'tuitionFee': tuition.toString(), 'admissionFee': admission.toString(),
      'fine': f.toString(), 'totalAmount': total.toString(), 'dueDate': dueDate,
      'status': 'Unpaid', 'issueDate': DateTime.now().toString().split(' ')[0],
    };
    feeVouchers.add(voucher);
    _saveData('feeVouchers', feeVouchers);
    _setFirestoreDoc('fee_vouchers', voucherNo, voucher);
  }

  void updateVoucherStatus(String voucherNo, String status) {
    int index = feeVouchers.indexWhere((v) => v['voucherNo'] == voucherNo);
    if (index != -1) {
      feeVouchers[index]['status'] = status;
      _saveData('feeVouchers', feeVouchers);
      _setFirestoreDoc('fee_vouchers', voucherNo, feeVouchers[index]);
    }
  }

  void deleteVoucher(String voucherNo) {
    feeVouchers.removeWhere((v) => v['voucherNo'] == voucherNo);
    _saveData('feeVouchers', feeVouchers);
    _deleteFirestoreDoc('fee_vouchers', voucherNo);
  }

  // ==========================================
  // STUDENT ATTENDANCE METHODS
  // ==========================================
  void saveStudentAttendance(String date, String className, String section, Map<String, String> attendanceMap) {
    String cleanClass = className.replaceAll('Class ', '').trim();
    studentAttendance.removeWhere((a) =>
      a['date'] == date &&
      a['className'] == cleanClass &&
      (section == 'All Sections' ? true : a['section'] == section)
    );

    attendanceMap.forEach((regNo, status) {
      final item = {
        'id': 'STU-ATT-${DateTime.now().millisecondsSinceEpoch}-$regNo',
        'date': date,
        'className': cleanClass,
        'section': section,
        'regNo': regNo,
        'status': status,
      };
      studentAttendance.add(item);
      _setFirestoreDoc('student_attendance', item['id']!, item);
    });
    _saveData('studentAttendance', studentAttendance);
  }

  Map<String, String> getStudentAttendance(String date, String className, String section) {
    String cleanClass = className.replaceAll('Class ', '').trim();
    Map<String, String> result = {};
    for (var a in studentAttendance) {
      bool matchDate = a['date'] == date;
      bool matchClass = (cleanClass == 'All Classes') || (a['className'] == cleanClass);
      bool matchSec = (section == 'All Sections') || (a['section'] == section);
      if (matchDate && matchClass && matchSec) {
        result[a['regNo']!] = a['status']!;
      }
    }
    return result;
  }

  double getStudentMonthlyAttendancePercentage(String regNo, int year, int month) {
    String prefix = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    var records = studentAttendance.where((a) => a['regNo'] == regNo && (a['date'] ?? '').startsWith(prefix)).toList();
    if (records.isEmpty) return 0.0;
    int present = records.where((a) => a['status'] == 'Present' || a['status'] == 'Late').length;
    return (present / records.length) * 100.0;
  }

  Map<String, int> getStudentMonthlyAttendanceCounts(String regNo, int year, int month) {
    String prefix = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    var records = studentAttendance.where((a) => a['regNo'] == regNo && (a['date'] ?? '').startsWith(prefix)).toList();
    int present = records.where((a) => a['status'] == 'Present').length;
    int absent = records.where((a) => a['status'] == 'Absent').length;
    int leave = records.where((a) => a['status'] == 'Leave').length;
    int late = records.where((a) => a['status'] == 'Late').length;
    return {
      'total': records.length,
      'present': present,
      'absent': absent,
      'leave': leave,
      'late': late,
    };
  }

  List<Map<String, dynamic>> getClassMonthlyAttendanceReport({required String className, required String section, required int year, required int month}) {
    List<Map<String, String>> students = getStudentsByClassAndSection(className, section);
    List<Map<String, dynamic>> report = [];

    for (var student in students) {
      var counts = getStudentMonthlyAttendanceCounts(student['regNo']!, year, month);
      int total = counts['total'] ?? 0;
      int present = counts['present'] ?? 0;
      int absent = counts['absent'] ?? 0;
      int leave = counts['leave'] ?? 0;
      int late = counts['late'] ?? 0;
      double percentage = total > 0 ? ((present + late) / total) * 100.0 : 0.0;

      report.add({
        'regNo': student['regNo'],
        'name': student['name'],
        'father': student['father'],
        'class': student['class'],
        'section': student['section'],
        'totalDays': total,
        'present': present,
        'absent': absent,
        'leave': leave,
        'late': late,
        'percentage': percentage,
      });
    }

    return report;
  }

  // ==========================================
  // EXAMINATION & REPORT CARDS METHODS
  // ==========================================
  static String calculateGrade(double percentage) {
    if (percentage >= 90.0) return 'A+';
    if (percentage >= 80.0) return 'A';
    if (percentage >= 70.0) return 'B';
    if (percentage >= 60.0) return 'C';
    if (percentage >= 50.0) return 'D';
    return 'F';
  }

  void addExam({
    required String title,
    required String academicYear,
    required String className,
    required List<Map<String, dynamic>> subjects,
    String? startDate,
    String? endDate,
  }) {
    String id = 'EXAM-${DateTime.now().millisecondsSinceEpoch}';
    final exam = {
      'id': id,
      'title': title,
      'academicYear': academicYear,
      'className': className.replaceAll('Class ', '').trim(),
      'startDate': startDate ?? DateTime.now().toString().split(' ')[0],
      'endDate': endDate ?? '',
      'subjects': subjects,
      'createdAt': DateTime.now().toString().split(' ')[0],
    };
    examsList.add(exam);
    _saveData('examsList', examsList);
    _setFirestoreDoc('exams', id, exam);
  }

  void updateExam(String examId, Map<String, dynamic> updatedData) {
    int index = examsList.indexWhere((e) => e['id'] == examId);
    if (index != -1) {
      examsList[index] = updatedData;
      _saveData('examsList', examsList);
      _setFirestoreDoc('exams', examId, updatedData);
    }
  }

  void deleteExam(String examId) {
    examsList.removeWhere((e) => e['id'] == examId);
    final resultsToRemove = examResults.where((r) => r['examId'] == examId).toList();
    for (var r in resultsToRemove) {
      String resId = r['id'] ?? '${r['examId']}_${r['regNo']}';
      _deleteFirestoreDoc('exam_results', resId);
    }
    examResults.removeWhere((r) => r['examId'] == examId);
    _saveData('examsList', examsList);
    _saveData('examResults', examResults);
    _deleteFirestoreDoc('exams', examId);
  }

  void saveExamResult({
    required String examId,
    required String regNo,
    required String studentName,
    required String className,
    required String section,
    required Map<String, double> marks,
    String remarks = '',
  }) {
    int examIndex = examsList.indexWhere((e) => e['id'] == examId);
    List subjects = examIndex != -1 ? (examsList[examIndex]['subjects'] as List? ?? []) : [];

    double totalObtained = 0.0;
    double totalMax = 0.0;
    bool hasFailedSubject = false;

    for (var sub in subjects) {
      String subName = sub['name']?.toString() ?? '';
      double maxM = (sub['totalMarks'] as num?)?.toDouble() ?? 100.0;
      double passM = (sub['passingMarks'] as num?)?.toDouble() ?? 40.0;
      double obt = marks[subName] ?? 0.0;

      totalObtained += obt;
      totalMax += maxM;
      if (obt < passM) {
        hasFailedSubject = true;
      }
    }

    double percentage = totalMax > 0 ? (totalObtained / totalMax) * 100.0 : 0.0;
    String grade = calculateGrade(percentage);
    String status = (percentage >= 50.0 && !hasFailedSubject) ? 'Pass' : 'Fail';

    final result = {
      'id': 'RES-$examId-$regNo',
      'examId': examId,
      'regNo': regNo,
      'studentName': studentName,
      'className': className.replaceAll('Class ', '').trim(),
      'section': section,
      'marks': marks,
      'totalObtained': totalObtained,
      'totalMax': totalMax,
      'percentage': percentage,
      'grade': grade,
      'status': status,
      'remarks': remarks,
      'updatedAt': DateTime.now().toString(),
    };

    examResults.removeWhere((r) => r['examId'] == examId && r['regNo'] == regNo);
    examResults.add(result);
    _saveData('examResults', examResults);
    _setFirestoreDoc('exam_results', result['id'] as String, result);
  }

  void bulkSaveExamResults(List<Map<String, dynamic>> resultsList) {
    for (var res in resultsList) {
      String examId = res['examId'];
      String regNo = res['regNo'];
      examResults.removeWhere((r) => r['examId'] == examId && r['regNo'] == regNo);
      examResults.add(res);
      String id = res['id'] ?? 'RES-$examId-$regNo';
      res['id'] = id;
      _setFirestoreDoc('exam_results', id, res);
    }
    _saveData('examResults', examResults);
  }

  List<Map<String, dynamic>> getExamResults(String examId, {String? section}) {
    var list = examResults.where((r) {
      bool matchExam = r['examId'] == examId;
      bool matchSec = (section == null || section == 'All Sections') ? true : r['section'] == section;
      return matchExam && matchSec;
    }).map((r) => Map<String, dynamic>.from(r)).toList();

    list.sort((a, b) {
      double pA = (a['percentage'] as num?)?.toDouble() ?? 0.0;
      double pB = (b['percentage'] as num?)?.toDouble() ?? 0.0;
      return pB.compareTo(pA);
    });

    for (int i = 0; i < list.length; i++) {
      int pos = i + 1;
      String suffix = 'th';
      if (pos % 10 == 1 && pos % 100 != 11) {
        suffix = 'st';
      } else if (pos % 10 == 2 && pos % 100 != 12) {
        suffix = 'nd';
      } else if (pos % 10 == 3 && pos % 100 != 13) {
        suffix = 'rd';
      }
      list[i]['position'] = '$pos$suffix';
      list[i]['rank'] = pos;
    }
    return list;
  }

  Map<String, dynamic>? getStudentExamResult(String examId, String regNo) {
    final ranked = getExamResults(examId);
    int index = ranked.indexWhere((r) => r['regNo'] == regNo);
    if (index != -1) return ranked[index];
    return null;
  }
}
