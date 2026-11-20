import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'super_admin_dashboard.dart';
import 'login_screen.dart';

const String kSuperAdminEmail = 'engrshafiq008@gmail.com';

class SuperAdminLoginScreen extends StatefulWidget {
  const SuperAdminLoginScreen({super.key});

  @override
  State<SuperAdminLoginScreen> createState() => _SuperAdminLoginScreenState();
}

class _SuperAdminLoginScreenState extends State<SuperAdminLoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoadingGoogle = false;
  bool _showEmailLogin = false;
  bool _isLoadingEmail = false;

  final TextEditingController _emailCtrl = TextEditingController(text: kSuperAdminEmail);
  final TextEditingController _passCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleAdminSignIn() async {
    setState(() => _isLoadingGoogle = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (!mounted) return;

      if (user != null) {
        final email = (user.email ?? '').toLowerCase().trim();
        if (email != kSuperAdminEmail.toLowerCase().trim()) {
          // Strictly reject non-superadmin emails!
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⛔ Unauthorized Access: Super Admin portal is restricted to $kSuperAdminEmail only. (Logged in as $email).',
              ),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }

        // Successfully authenticated as Super Admin!
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SuperAdminDashboard()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Super Admin Sign-in Error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoadingGoogle = false);
    }
  }

  Future<void> _handleEmailAdminSignIn() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email != kSuperAdminEmail.toLowerCase().trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unauthorized: Email must match $kSuperAdminEmail'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_passCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter password.')),
      );
      return;
    }

    setState(() => _isLoadingEmail = true);
    try {
      final user = await _authService.signInWithEmail(email, _passCtrl.text.trim());
      if (!mounted) return;
      if (user != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SuperAdminDashboard()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoadingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16), // Executive Obsidian Dark
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(38),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.08),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Super Admin Shield Icon
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 2),
                  ),
                  child: const Icon(Icons.admin_panel_settings, size: 52, color: Colors.amber),
                ),
                const SizedBox(height: 22),

                const Text(
                  'Super Admin Control Portal',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Platform Governance & Monetization Management',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Authorized Account Notice Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user, color: Colors.amber, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Designated Admin: $kSuperAdminEmail',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Primary Google Sign-in Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_isLoadingGoogle || _isLoadingEmail) ? null : _handleGoogleAdminSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    child: _isLoadingGoogle
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildGoogleIcon(),
                              const SizedBox(width: 14),
                              const Text(
                                'Sign in with Super Admin Google',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Toggle Email / Password section
                TextButton(
                  onPressed: () {
                    setState(() => _showEmailLogin = !_showEmailLogin);
                  },
                  child: Text(
                    _showEmailLogin ? 'Hide Password Sign-In' : 'Sign in with Master Password',
                    style: const TextStyle(color: Colors.amber, fontSize: 13),
                  ),
                ),

                if (_showEmailLogin) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Super Admin Email',
                      labelStyle: const TextStyle(color: Colors.white60),
                      prefixIcon: const Icon(Icons.email, color: Colors.amber, size: 20),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.amber),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.white60),
                      prefixIcon: const Icon(Icons.lock, color: Colors.amber, size: 20),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.amber),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _isLoadingEmail ? null : _handleEmailAdminSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoadingEmail
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 2),
                            )
                          : const Text(
                              'Sign in to Admin Dashboard',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),

                // Return to school login
                TextButton.icon(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.white60, size: 16),
                  label: const Text(
                    'Return to School Portal Login',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: CustomPaint(
        painter: GoogleLogoPainter(),
      ),
    );
  }
}
