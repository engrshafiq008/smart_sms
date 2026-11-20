import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_service.dart';
import 'school_data_service.dart';
import 'payment_config_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class PaymentPendingScreen extends StatefulWidget {
  final Map<String, String>? initialProfile;
  const PaymentPendingScreen({super.key, this.initialProfile});

  @override
  State<PaymentPendingScreen> createState() => _PaymentPendingScreenState();
}

class _PaymentPendingScreenState extends State<PaymentPendingScreen> {
  final AuthService _authService = AuthService();
  bool _isCheckingStatus = false;
  Map<String, String>? _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _loadProfileIfNull();
  }

  Future<void> _loadProfileIfNull() async {
    final user = _authService.currentUser;
    if (user != null) {
      final p = await _authService.fetchSchoolProfile(user.uid);
      if (mounted && p != null) {
        setState(() => _profile = p);
      }
    }
  }

  Future<void> _checkApprovalStatus() async {
    final user = _authService.currentUser;
    if (user == null) {
      _logout();
      return;
    }

    setState(() => _isCheckingStatus = true);
    try {
      final freshProfile = await _authService.fetchSchoolProfile(user.uid);
      if (!mounted) return;

      if (freshProfile != null) {
        setState(() => _profile = freshProfile);
        final status = (freshProfile['subscriptionStatus'] ?? 'pending_payment').toLowerCase();
        final expiry = freshProfile['expiryDate'];
        bool isExpired = false;
        if (expiry != null && expiry.isNotEmpty && expiry != 'lifetime') {
          final expDate = DateTime.tryParse(expiry);
          if (expDate != null && expDate.isBefore(DateTime.now())) {
            isExpired = true;
          }
        }

        if (status == 'active' && !isExpired) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Congratulations! Your subscription has been approved and activated!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          await SchoolDataService().initForUser(user.uid, initialSettings: freshProfile);
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
            (route) => false,
          );
          return;
        } else if (status == 'suspended') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Your account is currently suspended. Please contact Super Admin support.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        } else if (isExpired) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Subscription validity has expired. Please renew your plan.'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⏳ Status: Pending Approval. Our team is verifying your payment screenshot.'),
              backgroundColor: Colors.amber,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification check error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendWhatsAppReceipt(PaymentConfig config) async {
    final schoolName = _profile?['schoolName'] ?? 'Our School';
    final ownerEmail = _profile?['email'] ?? (_authService.currentUser?.email ?? 'N/A');
    final phone = _profile?['phone'] ?? 'N/A';

    final message = "Assalam-o-Alaikum Super Admin!\n"
        "I have transferred the SaaS subscription fee for Smart SMS School Management Portal.\n\n"
        "🏫 School Name: $schoolName\n"
        "📧 Registered Gmail: $ownerEmail\n"
        "📞 Official Phone: $phone\n\n"
        "Please find our payment screenshot attached. Kindly verify and approve our portal. Thank you!";

    final launched = await PaymentConfigService.launchWhatsApp(
      phone: config.adminWhatsApp,
      message: message,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open WhatsApp directly. Please message ${config.adminWhatsApp} manually.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final schoolName = _profile?['schoolName'] ?? 'Smart School Portal';
    final ownerEmail = _profile?['email'] ?? (user?.email ?? '');
    final phone = _profile?['phone'] ?? '';
    final status = (_profile?['subscriptionStatus'] ?? 'pending_payment').toLowerCase();
    final expiry = _profile?['expiryDate'];
    bool isExpired = false;
    if (expiry != null && expiry.isNotEmpty && expiry != 'lifetime') {
      final exp = DateTime.tryParse(expiry);
      if (exp != null && exp.isBefore(DateTime.now())) {
        isExpired = true;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark Executive Slate
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school, color: Colors.blueAccent, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'Smart SMS SaaS',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: const Text(
                'BILLING & VERIFICATION',
                style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
            label: const Text('Sign Out', style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<PaymentConfig>(
        stream: PaymentConfigService.paymentConfigStream,
        builder: (context, snapshot) {
          final config = snapshot.data ?? PaymentConfig.defaults;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 860),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 10)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge Banner
                    _buildStatusBanner(status, isExpired),
                    const SizedBox(height: 24),

                    // School Details Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                            child: const Icon(Icons.domain, color: Colors.blueAccent, size: 30),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  schoolName,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.email_outlined, size: 14, color: Colors.black54),
                                    const SizedBox(width: 4),
                                    Text(ownerEmail, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                    if (phone.isNotEmpty) ...[
                                      const SizedBox(width: 16),
                                      const Icon(Icons.phone_outlined, size: 14, color: Colors.black54),
                                      const SizedBox(width: 4),
                                      Text(phone, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // SaaS Pricing Plans Pills
                    const Text(
                      'Select Your Subscription Plan',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPricingCard(
                            title: 'Monthly Subscription',
                            price: config.monthlyFee,
                            badge: 'STANDARD',
                            badgeColor: Colors.blueAccent,
                            features: 'All modules, unlimited students, PDF reports, monthly renewal',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildPricingCard(
                            title: 'Annual Subscription',
                            price: config.annualFee,
                            badge: 'SAVE 30% - BEST VALUE',
                            badgeColor: Colors.green,
                            features: 'Priority support, 12 months full access, zero setup fees',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Official Payment Accounts Section
                    const Text(
                      'Official Payment Accounts',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Transfer the subscription fee to any of the verified channels below:',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),

                    // Payment Methods Cards Grid
                    _buildPaymentMethodCard(
                      icon: Icons.account_balance,
                      iconColor: Colors.indigo,
                      channel: 'Direct Bank Transfer',
                      bank: config.bankName,
                      title: config.accountTitle,
                      number: config.accountNumber,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentMethodCard(
                            icon: Icons.phone_android,
                            iconColor: Colors.red.shade700,
                            channel: 'JazzCash',
                            bank: 'JazzCash Mobile Account',
                            title: config.accountTitle,
                            number: config.jazzCashNumber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPaymentMethodCard(
                            icon: Icons.mobile_friendly,
                            iconColor: Colors.teal.shade700,
                            channel: 'EasyPaisa',
                            bank: 'EasyPaisa Mobile Account',
                            title: config.accountTitle,
                            number: config.easyPaisaNumber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // WhatsApp Submission Box
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4), // Gentle green
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.chat, color: Colors.green, size: 26),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Send Payment Receipt for Instant Activation',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF14532D)),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Send a screenshot of your bank or mobile transfer to Super Admin WhatsApp. Your account will be activated within minutes.',
                                      style: TextStyle(fontSize: 13, color: Color(0xFF166534)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () => _sendWhatsAppReceipt(config),
                              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                              label: Text(
                                'Send Payment Screenshot on WhatsApp (${config.adminWhatsApp})',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF22C55E),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Bottom Refresh & Status Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isCheckingStatus ? null : _checkApprovalStatus,
                          icon: _isCheckingStatus
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                                )
                              : const Icon(Icons.refresh, size: 18),
                          label: Text(_isCheckingStatus ? 'Verifying with Server...' : 'Refresh / Check Approval Status'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            side: const BorderSide(color: Colors.blueAccent),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout, size: 16, color: Colors.grey),
                          label: const Text('Sign Out / Use Another Account', style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(String status, bool isExpired) {
    Color bannerBg;
    Color borderC;
    IconData icon;
    String title;
    String desc;

    if (status == 'suspended') {
      bannerBg = const Color(0xFFFEF2F2);
      borderC = Colors.redAccent.withValues(alpha: 0.3);
      icon = Icons.block;
      title = 'Account Suspended';
      desc = 'Your portal access has been temporarily suspended by the Super Admin. Please contact support via WhatsApp to resolve.';
    } else if (isExpired) {
      bannerBg = const Color(0xFFFFFBEB);
      borderC = Colors.orangeAccent.withValues(alpha: 0.4);
      icon = Icons.alarm_off;
      title = 'Subscription Expired';
      desc = 'Your current subscription plan has ended. Kindly make a renewal payment to reactivate your portal immediately.';
    } else {
      bannerBg = const Color(0xFFEFF6FF);
      borderC = Colors.blueAccent.withValues(alpha: 0.3);
      icon = Icons.hourglass_top_rounded;
      title = 'Account Pending Payment & Super Admin Approval';
      desc = 'Your school registration is complete! Complete your payment transfer and send the receipt to Super Admin on WhatsApp for account activation.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderC),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: borderC.withValues(alpha: 1.0), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: borderC.withValues(alpha: 1.0)),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard({
    required String title,
    required String price,
    required String badge,
    required Color badgeColor,
    required String features,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(price, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 4),
          Text(features, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required IconData icon,
    required Color iconColor,
    required String channel,
    required String bank,
    required String title,
    required String number,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(channel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: iconColor)),
                    const SizedBox(width: 6),
                    Text('($bank)', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('Title: $title', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                const SizedBox(height: 2),
                SelectableText(
                  'Account / Number: $number',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy Number',
            icon: const Icon(Icons.copy_rounded, size: 20, color: Colors.blueAccent),
            onPressed: () => _copyToClipboard(number, '$channel Number'),
          ),
        ],
      ),
    );
  }
}
