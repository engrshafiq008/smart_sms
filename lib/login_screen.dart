import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'school_data_service.dart';
import 'school_signup_screen.dart';
import 'dashboard_screen.dart';
import 'payment_pending_screen.dart';
import 'super_admin_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoadingGoogleLogin = false;
  bool _isLoadingRegister = false;
  bool _showEmailLogin = false;

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _isLoadingEmail = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _routeUserWithProfile(String uid, Map<String, String> profile) async {
    final status = (profile['subscriptionStatus'] ?? 'pending_payment').toLowerCase();
    final expiry = profile['expiryDate'];
    bool isExpired = false;
    if (expiry != null && expiry.isNotEmpty && expiry != 'lifetime') {
      final exp = DateTime.tryParse(expiry);
      if (exp != null && exp.isBefore(DateTime.now())) {
        isExpired = true;
      }
    }

    if (status == 'active' && !isExpired) {
      await SchoolDataService().initForUser(uid, initialSettings: profile);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => PaymentPendingScreen(initialProfile: profile)),
        (route) => false,
      );
    }
  }

  // --- 1. Login with Google (Existing School Owners) ---
  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoadingGoogleLogin = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        final profile = await _authService.fetchSchoolProfile(user.uid);
        if (!mounted) return;

        if (profile != null) {
          await _routeUserWithProfile(user.uid, profile);
        } else {
          // If first-time user clicks login, forward to onboarding
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SchoolSignupScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      String message = AuthService.getReadableErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoadingGoogleLogin = false);
    }
  }

  // --- 2. Register New School with Google ---
  Future<void> _handleGoogleRegister() async {
    setState(() => _isLoadingRegister = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        final profile = await _authService.fetchSchoolProfile(user.uid);
        if (!mounted) return;

        if (profile != null) {
          // User already has an existing school registered!
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account already registered! Logging you into your school portal...'),
              backgroundColor: Colors.green,
            ),
          );
          await _routeUserWithProfile(user.uid, profile);
        } else {
          // New School Owner -> Navigate directly to Onboarding
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SchoolSignupScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      String message = AuthService.getReadableErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoadingRegister = false);
    }
  }

  // --- 3. Email & Password Sign In ---
  Future<void> _handleEmailSignIn() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password.')),
      );
      return;
    }
    setState(() => _isLoadingEmail = true);
    try {
      final user = await _authService.signInWithEmail(_emailCtrl.text, _passCtrl.text);
      if (user != null && mounted) {
        final profile = await _authService.fetchSchoolProfile(user.uid);
        if (!mounted) return;

        if (profile != null) {
          await _routeUserWithProfile(user.uid, profile);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SchoolSignupScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      String message = AuthService.getReadableErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoadingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Modern SaaS Dark Theme
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Brand Logo Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school, size: 48, color: Colors.blueAccent),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Smart SMS Enterprise',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Cloud-Powered Multi-Tenant School Management Portal',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Primary Button: Login with Google
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: (_isLoadingGoogleLogin || _isLoadingRegister) ? null : _handleGoogleLogin,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoadingGoogleLogin
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildGoogleIcon(),
                              const SizedBox(width: 12),
                              const Text(
                                'Login with Google',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 14),

                // Secondary Button: New School? Sign Up / Register with Google
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: (_isLoadingGoogleLogin || _isLoadingRegister) ? null : _handleGoogleRegister,
                    icon: _isLoadingRegister
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.domain_add, color: Colors.white, size: 20),
                    label: Text(
                      _isLoadingRegister ? 'Signing Up...' : 'New School? Register with Google',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB), // Vibrant Blue
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Divider Or
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 14),

                // Toggle Email/Password Section
                TextButton(
                  onPressed: () {
                    setState(() => _showEmailLogin = !_showEmailLogin);
                  },
                  child: Text(
                    _showEmailLogin ? 'Hide Email Login' : 'Sign In with Email & Password',
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600),
                  ),
                ),

                if (_showEmailLogin) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Admin Email',
                      prefixIcon: Icon(Icons.email, size: 20),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock, size: 20),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _isLoadingEmail ? null : _handleEmailSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoadingEmail
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Sign In with Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                const Divider(color: Colors.black12),
                const SizedBox(height: 12),

                // Subtle Super Admin Portal Link
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SuperAdminLoginScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 15, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Text(
                          'Super Admin Login',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
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

// Crisp Vector Google "G" Logo Painter
class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final redPaint = Paint()..color = const Color(0xFFEA4335);
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    final greenPaint = Paint()..color = const Color(0xFF34A853);
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);

    // Draw Google 4-color arc
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    canvas.drawCircle(center, radius, bluePaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -0.8, 1.6, true, redPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 0.8, 1.6, true, yellowPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 2.4, 1.6, true, greenPaint);

    final whiteInner = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.65, whiteInner);

    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(center.dx, center.dy - radius * 0.2, radius * 0.95, radius * 0.4), barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
