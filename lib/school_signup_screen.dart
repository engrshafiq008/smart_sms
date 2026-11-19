import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'dashboard_screen.dart';

class SchoolSignupScreen extends StatefulWidget {
  const SchoolSignupScreen({super.key});

  @override
  State<SchoolSignupScreen> createState() => _SchoolSignupScreenState();
}

class _SchoolSignupScreenState extends State<SchoolSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  late TextEditingController _emailController;
  late TextEditingController _ownerNameController;
  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _academicYear = '2026-2027';
  String _currency = 'PKR';
  bool _isLoading = false;

  final List<String> _sessions = [
    '2024-2025', '2025-2026', '2026-2027', '2027-2028', '2028-2029'
  ];

  final List<String> _currencies = [
    'PKR', 'USD', 'EUR', 'GBP', 'AED', 'SAR', 'CAD'
  ];

  @override
  void initState() {
    super.initState();
    final user = _authService.currentUser;
    _emailController = TextEditingController(text: user?.email ?? '');
    _ownerNameController = TextEditingController(text: user?.displayName ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _ownerNameController.dispose();
    _schoolNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please sign in again.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    final schoolProfile = {
      'schoolName': _schoolNameController.text.trim(),
      'ownerName': _ownerNameController.text.trim(),
      'address': _addressController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'academicYear': _academicYear,
      'currency': _currency,
      'ownerUid': user.uid,
      'ownerEmail': user.email ?? _emailController.text.trim(),
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    try {
      // 1. Explicitly await writing the school document to Cloud Firestore
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(user.uid)
          .set(schoolProfile, SetOptions(merge: true));

      // 2. Save profile in authService and initialize SchoolDataService
      await _authService.saveSchoolProfile(user.uid, Map<String, String>.from(
        schoolProfile.map((k, v) => MapEntry(k, v.toString())),
      ));

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Firestore Sync Error on Onboarding: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Onboarding failed: $e\nPlease verify Cloud Firestore rules in Firebase Console.'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium Dark Slate Background
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Container(
            width: 650,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8)),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Banner
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.school, size: 36, color: Colors.blueAccent),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'School Onboarding Setup',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Configure your institution profile to activate your multi-tenant portal',
                              style: TextStyle(color: Colors.black54, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sign Out / Switch Account',
                        icon: const Icon(Icons.logout, color: Colors.grey),
                        onPressed: () async {
                          await _authService.signOut();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Pre-filled Owner Information
                  const Text('Owner / Administrator Credentials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ownerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Owner / Principal Name',
                            prefixIcon: Icon(Icons.person, size: 20),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _emailController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Registered Google Account',
                            prefixIcon: Icon(Icons.verified_user, size: 20, color: Colors.green),
                            border: OutlineInputBorder(),
                            isDense: true,
                            fillColor: Color(0xFFF1F5F9),
                            filled: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // School Profile Information
                  const Text('Institution Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 12),

                  // School Name
                  TextFormField(
                    controller: _schoolNameController,
                    decoration: const InputDecoration(
                      labelText: 'Official School / Institution Name *',
                      hintText: 'e.g. Oxford Cambridge Grammar School',
                      prefixIcon: Icon(Icons.apartment, size: 20),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Please enter school name' : null,
                  ),
                  const SizedBox(height: 16),

                  // Campus Address
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Complete Campus Address *',
                      hintText: 'e.g. Main Campus, University Road, Bahawalpur, Punjab',
                      prefixIcon: Icon(Icons.location_on, size: 20),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Please enter campus address' : null,
                  ),
                  const SizedBox(height: 16),

                  // Official Phone
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Official Contact / WhatsApp Number *',
                      hintText: 'e.g. +92 300 1234567',
                      prefixIcon: Icon(Icons.phone, size: 20),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Please enter contact number' : null,
                  ),
                  const SizedBox(height: 16),

                  // Academic Session & Currency Row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _academicYear,
                          decoration: const InputDecoration(
                            labelText: 'Current Academic Session',
                            prefixIcon: Icon(Icons.date_range, size: 20),
                            border: OutlineInputBorder(),
                          ),
                          items: _sessions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _academicYear = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _currency,
                          decoration: const InputDecoration(
                            labelText: 'Billing Currency',
                            prefixIcon: Icon(Icons.payments, size: 20),
                            border: OutlineInputBorder(),
                          ),
                          items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _currency = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _completeOnboarding,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.rocket_launch, color: Colors.white),
                      label: Text(
                        _isLoading ? 'Setting Up Your School Portal...' : 'Complete Setup & Enter Dashboard',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
