import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'super_admin_login_screen.dart';
import 'payment_config_service.dart';
import 'dashboard_screen.dart';
import 'school_data_service.dart';
import 'auth_service.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Payment Settings Form Controllers
  final TextEditingController _bankNameCtrl = TextEditingController();
  final TextEditingController _accountTitleCtrl = TextEditingController();
  final TextEditingController _accountNumberCtrl = TextEditingController();
  final TextEditingController _jazzCashCtrl = TextEditingController();
  final TextEditingController _easyPaisaCtrl = TextEditingController();
  final TextEditingController _adminWhatsAppCtrl = TextEditingController();
  final TextEditingController _monthlyFeeCtrl = TextEditingController();
  final TextEditingController _annualFeeCtrl = TextEditingController();
  bool _isSavingPaymentConfig = false;
  bool _isPaymentConfigLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPaymentConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountTitleCtrl.dispose();
    _accountNumberCtrl.dispose();
    _jazzCashCtrl.dispose();
    _easyPaisaCtrl.dispose();
    _adminWhatsAppCtrl.dispose();
    _monthlyFeeCtrl.dispose();
    _annualFeeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentConfig() async {
    final config = await PaymentConfigService.fetchPaymentConfig();
    if (!mounted) return;
    _bankNameCtrl.text = config.bankName;
    _accountTitleCtrl.text = config.accountTitle;
    _accountNumberCtrl.text = config.accountNumber;
    _jazzCashCtrl.text = config.jazzCashNumber;
    _easyPaisaCtrl.text = config.easyPaisaNumber;
    _adminWhatsAppCtrl.text = config.adminWhatsApp;
    _monthlyFeeCtrl.text = config.monthlyFee;
    _annualFeeCtrl.text = config.annualFee;
    setState(() => _isPaymentConfigLoaded = true);
  }

  Future<void> _savePaymentConfig() async {
    setState(() => _isSavingPaymentConfig = true);
    final newConfig = PaymentConfig(
      bankName: _bankNameCtrl.text.trim(),
      accountTitle: _accountTitleCtrl.text.trim(),
      accountNumber: _accountNumberCtrl.text.trim(),
      jazzCashNumber: _jazzCashCtrl.text.trim(),
      easyPaisaNumber: _easyPaisaCtrl.text.trim(),
      adminWhatsApp: _adminWhatsAppCtrl.text.trim(),
      monthlyFee: _monthlyFeeCtrl.text.trim(),
      annualFee: _annualFeeCtrl.text.trim(),
    );

    try {
      await PaymentConfigService.savePaymentConfig(newConfig);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment configuration updated and live across all customer portals!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving payment settings: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isSavingPaymentConfig = false);
    }
  }

  Future<void> _signOutAdmin() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SuperAdminLoginScreen()),
      (route) => false,
    );
  }

  Future<void> _showApprovalDialog(BuildContext context, String uid, Map<String, dynamic> schoolData) async {
    String schoolName = schoolData['schoolName'] ?? 'School';
    String schoolEmail = schoolData['email'] ?? (schoolData['ownerEmail'] ?? '');
    String schoolPhone = schoolData['phone'] ?? '';
    String selectedDuration = '30 Days (Monthly SaaS)';

    await showDialog(
      context: context,
      builder: (dlgContext) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Approve & Activate $schoolName',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Owner: $schoolEmail', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  if (schoolPhone.isNotEmpty)
                    Text('Phone: $schoolPhone', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 18),
                  const Text('Select Subscription Validity:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF0F172A),
                    initialValue: selectedDuration,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                    ),
                    items: const [
                      DropdownMenuItem(value: '30 Days (Monthly SaaS)', child: Text('30 Days (Monthly SaaS)')),
                      DropdownMenuItem(value: '90 Days (Quarterly SaaS)', child: Text('90 Days (Quarterly SaaS)')),
                      DropdownMenuItem(value: '1 Year (Annual SaaS)', child: Text('1 Year (Annual SaaS)')),
                      DropdownMenuItem(value: 'Lifetime License', child: Text('Lifetime License (No Expiry)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedDuration = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(dlgContext);
                    await _activateSchool(uid, schoolName, schoolEmail, schoolPhone, selectedDuration);
                  },
                  icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  label: const Text('Confirm Activation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _activateSchool(String uid, String schoolName, String schoolEmail, String schoolPhone, String duration) async {
    DateTime now = DateTime.now();
    DateTime? expDate;
    String plan = 'Monthly SaaS';

    if (duration.contains('30 Days')) {
      expDate = now.add(const Duration(days: 30));
      plan = 'Monthly SaaS';
    } else if (duration.contains('90 Days')) {
      expDate = now.add(const Duration(days: 90));
      plan = 'Quarterly SaaS';
    } else if (duration.contains('1 Year')) {
      expDate = now.add(const Duration(days: 365));
      plan = 'Annual SaaS';
    } else if (duration.contains('Lifetime')) {
      expDate = null;
      plan = 'Lifetime License';
    }

    try {
      final updateData = {
        'subscriptionStatus': 'active',
        'planType': plan,
        'expiryDate': expDate?.toIso8601String() ?? 'lifetime',
        'approvedAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      await FirebaseFirestore.instance.collection('schools').doc(uid).set(updateData, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$schoolName activated successfully!'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Send WhatsApp',
            textColor: Colors.yellow,
            onPressed: () => _sendActivationWhatsApp(schoolName, schoolEmail, schoolPhone),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to activate school: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _suspendSchool(String uid, String schoolName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Confirm Suspension', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to suspend $schoolName? They will not be able to access the dashboard.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Yes, Suspend School', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('schools').doc(uid).set({
        'subscriptionStatus': 'suspended',
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$schoolName suspended.'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suspension error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _sendActivationWhatsApp(String schoolName, String email, String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number registered for this school.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final message = "Assalam-o-Alaikum!\n"
        "Your Smart SMS account for $schoolName has been approved and activated.\n"
        "You can now log in at https://smart-sms-45169.web.app using your registered Gmail ($email).";

    final launched = await PaymentConfigService.launchWhatsApp(phone: phone, message: message);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open WhatsApp for $phone.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield, color: Colors.amber, size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart SMS | Super Admin Control Center',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Multi-Tenant Platform & Monetization Management',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.lightBlueAccent,
              side: const BorderSide(color: Colors.lightBlueAccent, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.school, size: 16, color: Colors.lightBlueAccent),
            label: const Text(
              'Open School Portal',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent),
            ),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null && !SchoolDataService().isInitialized) {
                var profile = await AuthService().fetchSchoolProfile(user.uid);
                profile ??= {
                  'schoolName': 'Smart SMS Model School',
                  'address': 'Smart Campus, Main Boulevard',
                  'phone': '03336387744',
                  'email': user.email ?? '',
                  'subscriptionStatus': 'active',
                  'planType': 'Lifetime License',
                };
                await SchoolDataService().initForUser(user.uid, initialSettings: profile);
              }
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
                (route) => false,
              );
            },
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: const Row(
              children: [
                Icon(Icons.person_pin, color: Colors.amber, size: 16),
                SizedBox(width: 6),
                Text(
                  kSuperAdminEmail,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Sign Out Admin',
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: _signOutAdmin,
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions), text: 'Pending Approvals'),
            Tab(icon: Icon(Icons.check_circle_outline), text: 'Active Schools'),
            Tab(icon: Icon(Icons.domain), text: 'All Schools'),
            Tab(icon: Icon(Icons.payments_outlined), text: 'Payment Settings'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('schools').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Firestore stream notice: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }

          final allDocs = snapshot.data?.docs ?? [];
          final allSchools = allDocs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            data['uid'] = d.id;
            return data;
          }).toList();

          // Calculate KPI metrics
          final totalCount = allSchools.length;
          final pendingCount = allSchools.where((s) {
            final status = (s['subscriptionStatus'] ?? 'pending_payment').toString().toLowerCase();
            return status == 'pending_payment';
          }).length;
          final activeCount = allSchools.where((s) {
            final status = (s['subscriptionStatus'] ?? '').toString().toLowerCase();
            return status == 'active';
          }).length;
          final suspendedCount = allSchools.where((s) {
            final status = (s['subscriptionStatus'] ?? '').toString().toLowerCase();
            return status == 'suspended';
          }).length;

          return Column(
            children: [
              // KPI Cards Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(child: _buildKpiCard('Total Schools', totalCount.toString(), Icons.school, Colors.blueAccent)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildKpiCard('Pending Approvals', pendingCount.toString(), Icons.pending, Colors.amber)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildKpiCard('Active Subscriptions', activeCount.toString(), Icons.verified, Colors.green)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildKpiCard('Suspended / Inactive', suspendedCount.toString(), Icons.block, Colors.redAccent)),
                  ],
                ),
              ),

              // Search Filter Bar (for lists)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search school by name, email, phone, or address...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.amber),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Tab Views Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Pending Approvals
                    _buildSchoolsList(
                      allSchools.where((s) {
                        final status = (s['subscriptionStatus'] ?? 'pending_payment').toString().toLowerCase();
                        return status == 'pending_payment';
                      }).toList(),
                      isPendingTab: true,
                    ),

                    // Tab 2: Active Schools
                    _buildSchoolsList(
                      allSchools.where((s) {
                        final status = (s['subscriptionStatus'] ?? '').toString().toLowerCase();
                        return status == 'active';
                      }).toList(),
                    ),

                    // Tab 3: All Schools
                    _buildSchoolsList(allSchools),

                    // Tab 4: Payment Settings
                    _buildPaymentSettingsTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 4),
                Text(count, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolsList(List<Map<String, dynamic>> list, {bool isPendingTab = false}) {
    final filtered = list.where((s) {
      if (_searchQuery.isEmpty) return true;
      final name = (s['schoolName'] ?? '').toString().toLowerCase();
      final email = (s['email'] ?? (s['ownerEmail'] ?? '')).toString().toLowerCase();
      final phone = (s['phone'] ?? '').toString().toLowerCase();
      final address = (s['address'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          address.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 54, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text(
              isPendingTab ? 'No pending approval requests!' : 'No schools found matching criteria.',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final school = filtered[index];
        final uid = school['uid'] ?? '';
        final schoolName = school['schoolName'] ?? 'Unnamed School';
        final ownerName = school['ownerName'] ?? 'Owner';
        final email = school['email'] ?? (school['ownerEmail'] ?? 'No email');
        final phone = school['phone'] ?? '';
        final address = school['address'] ?? 'No address provided';
        final status = (school['subscriptionStatus'] ?? 'pending_payment').toString().toLowerCase();
        final plan = school['planType'] ?? 'Monthly SaaS';
        final expiry = school['expiryDate'] ?? 'N/A';

        Color badgeColor = Colors.amber;
        String badgeText = 'PENDING APPROVAL';
        if (status == 'active') {
          badgeColor = Colors.green;
          badgeText = 'ACTIVE ($plan)';
        } else if (status == 'suspended') {
          badgeColor = Colors.redAccent;
          badgeText = 'SUSPENDED';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              CircleAvatar(
                radius: 24,
                backgroundColor: badgeColor.withValues(alpha: 0.15),
                child: Icon(Icons.school, color: badgeColor, size: 26),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          schoolName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        Text(ownerName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 14),
                        const Icon(Icons.email, color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        Text(email, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(width: 14),
                          const Icon(Icons.phone, color: Colors.white54, size: 14),
                          const SizedBox(width: 4),
                          Text(phone, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📍 $address | 📅 Expiry: $expiry',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Approve / Activate Button
                  ElevatedButton.icon(
                    onPressed: () => _showApprovalDialog(context, uid, school),
                    icon: const Icon(Icons.check_circle, size: 16, color: Colors.white),
                    label: Text(status == 'active' ? 'Extend Plan' : 'Approve & Activate', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // WhatsApp Contact Button
                  if (phone.isNotEmpty)
                    IconButton(
                      tooltip: 'Send Activation Message via WhatsApp',
                      icon: const Icon(Icons.chat, color: Color(0xFF22C55E), size: 20),
                      onPressed: () => _sendActivationWhatsApp(schoolName, email, phone),
                    ),

                  // Suspend Button
                  if (status != 'suspended')
                    IconButton(
                      tooltip: 'Suspend School',
                      icon: const Icon(Icons.block, color: Colors.redAccent, size: 20),
                      onPressed: () => _suspendSchool(uid, schoolName),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentSettingsTab() {
    if (!_isPaymentConfigLoaded) {
      return const Center(child: CircularProgressIndicator(color: Colors.amber));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.payments, color: Colors.amber, size: 26),
                  SizedBox(width: 12),
                  Text(
                    'Configure Official Payment Channels',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Changes made here immediately update the billing information shown to all new registering schools.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Form fields
              _buildAdminTextField('Bank Name', _bankNameCtrl, Icons.account_balance),
              const SizedBox(height: 14),
              _buildAdminTextField('Account Title', _accountTitleCtrl, Icons.badge),
              const SizedBox(height: 14),
              _buildAdminTextField('Account Number / IBAN', _accountNumberCtrl, Icons.numbers),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _buildAdminTextField('JazzCash Account Number', _jazzCashCtrl, Icons.phone_android)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildAdminTextField('EasyPaisa Account Number', _easyPaisaCtrl, Icons.mobile_friendly)),
                ],
              ),
              const SizedBox(height: 14),
              _buildAdminTextField('Super Admin WhatsApp Number (for receipts)', _adminWhatsAppCtrl, Icons.chat),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _buildAdminTextField('Monthly Subscription Fee', _monthlyFeeCtrl, Icons.monetization_on)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildAdminTextField('Annual Subscription Fee', _annualFeeCtrl, Icons.savings)),
                ],
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSavingPaymentConfig ? null : _savePaymentConfig,
                  icon: _isSavingPaymentConfig
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 2))
                      : const Icon(Icons.save, color: Colors.black87),
                  label: Text(
                    _isSavingPaymentConfig ? 'Saving Settings...' : 'Save Payment Configuration',
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminTextField(String label, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.amber, size: 20),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.amber)),
        isDense: true,
      ),
    );
  }
}
