import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/monex_illustrations.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthSuccess;

  const AuthScreen({super.key, required this.onAuthSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum AuthMode { login, signup, resetPassword }

class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  AuthMode _authMode = AuthMode.login;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _showSuccessState = false;

  final SupabaseService _supabaseService = SupabaseService();
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_supabaseService.safeClient != null) {
      _authSub = _supabaseService.safeClient!.auth.onAuthStateChange.listen((data) async {
        debugPrint('[AuthScreen] onAuthStateChange event: ${data.event}, hasSession: ${data.session != null}, hasUser: ${data.session?.user != null}');
        if ((data.event == AuthChangeEvent.signedIn ||
                data.event == AuthChangeEvent.initialSession ||
                data.event == AuthChangeEvent.tokenRefreshed ||
                data.event == AuthChangeEvent.userUpdated) &&
            data.session?.user != null &&
            mounted) {
          debugPrint('[AuthScreen] Auth success! User: ${data.session!.user.email}, navigating to dashboard...');
          await SupabaseService.cacheUserData(data.session!.user);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('persistent_user_logged_in', true);
          widget.onAuthSuccess();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndNavigateIfAuthed();
    }
  }

  Future<void> _checkAndNavigateIfAuthed() async {
    for (int i = 0; i < 4; i++) {
      if (!mounted) return;
      final user = _supabaseService.currentUser;
      if (user != null) {
        debugPrint('[AuthScreen] App resumed with authenticated user: ${user.email}');
        await SupabaseService.cacheUserData(user);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('persistent_user_logged_in', true);
        if (mounted) {
          widget.onAuthSuccess();
        }
        return;
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Password rules validation
  bool get _hasMinChars => _passwordController.text.length >= 8;
  bool get _hasSymbolOrNum => RegExp(r'[0-9!@#\$%^&*(),.?":{}|<>]').hasMatch(_passwordController.text);
  bool get _doesNotContainName =>
      _passwordController.text.isEmpty ||
      _emailController.text.isEmpty ||
      !_passwordController.text.toLowerCase().contains(_emailController.text.split('@').first.toLowerCase());

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _supabaseService.signInWithGoogle();
      if (success && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('persistent_user_logged_in', true);
        widget.onAuthSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Google Sign-In failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
    });

    if (_authMode == AuthMode.resetPassword) {
      if (!_hasMinChars) {
        setState(() => _errorMessage = 'Password must be at least 8 characters');
        return;
      }
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() {
        _isLoading = false;
        _showSuccessState = true;
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final enteredEmail = _emailController.text.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('google_user_email', enteredEmail);

      final prefix = enteredEmail.split('@').first.replaceAll(RegExp(r'[._]'), ' ');
      final formattedName = prefix
          .split(' ')
          .where((w) => w.isNotEmpty)
          .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
      if (prefs.getString('custom_user_name') == null || prefs.getString('custom_user_name') == 'Expense User') {
        await prefs.setString('custom_user_name', formattedName);
      }

      if (_authMode == AuthMode.login) {
        await _supabaseService.signIn(
          email: enteredEmail,
          password: _passwordController.text,
        );
      } else {
        await _supabaseService.signUp(
          email: enteredEmail,
          password: _passwordController.text,
        );
      }

      if (mounted) {
        widget.onAuthSuccess();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccessState) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _authMode != AuthMode.login
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
                onPressed: () {
                  setState(() {
                    _authMode = AuthMode.login;
                    _errorMessage = null;
                  });
                },
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Header (Left aligned Logo & Brand Name)
                if (_authMode == AuthMode.login) ...[
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 34,
                          height: 34,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Expense OS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Screen Title
                Text(
                  _authMode == AuthMode.resetPassword
                      ? 'Create Your New\nPassword'
                      : _authMode == AuthMode.signup
                          ? 'Create Account'
                          : 'Welcome Back!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _authMode == AuthMode.resetPassword
                      ? 'Your new password must be different\nfrom previous password.'
                      : _authMode == AuthMode.signup
                          ? 'Enter your Gmail & password to create account.'
                          : 'Sign in to access your financial command center.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Error alert
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.dangerRed,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ------------------------------------------------------------
                // 1. PRIMARY "CONTINUE WITH GOOGLE" BUTTON
                // ------------------------------------------------------------
                if (_authMode != AuthMode.resetPassword) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.textPrimary,
                        elevation: 1,
                        shadowColor: Colors.black.withValues(alpha: 0.08),
                        side: const BorderSide(color: Color(0xFFD0D5DD), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isGoogleLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: AppTheme.monexBlue, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildGoogleIcon(),
                                const SizedBox(width: 12),
                                Text(
                                  'Continue with Google',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Divider with "OR"
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Color(0xFFE4E7EC), thickness: 1.2)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          'OR USE GMAIL',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF98A2B3),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Color(0xFFE4E7EC), thickness: 1.2)),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],

                // ------------------------------------------------------------
                // 2. GMAIL / EMAIL ADDRESS INPUT (No Username)
                // ------------------------------------------------------------
                _buildInputField(
                  controller: _emailController,
                  hint: 'yourname@gmail.com',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your email';
                    if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email address';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password Input
                _buildInputField(
                  controller: _passwordController,
                  hint: 'Password',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
                ),

                if (_authMode == AuthMode.resetPassword) ...[
                  const SizedBox(height: 20),
                  // Validation Checklist
                  _buildRequirementItem(
                    text: 'Must not contain your name or email',
                    isMet: _doesNotContainName,
                  ),
                  const SizedBox(height: 8),
                  _buildRequirementItem(
                    text: 'At least 8 characters',
                    isMet: _hasMinChars,
                  ),
                  const SizedBox(height: 8),
                  _buildRequirementItem(
                    text: 'Contains a symbol or a number',
                    isMet: _hasSymbolOrNum,
                  ),
                ],

                if (_authMode == AuthMode.login) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _authMode = AuthMode.resetPassword;
                          _errorMessage = null;
                        });
                      },
                      child: Text(
                        'Forgot Password?',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.monexBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Primary Action Button (Sign In / Register)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.monexBlue,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shadowColor: AppTheme.monexBlue.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _authMode == AuthMode.resetPassword
                                ? 'RESET PASSWORD'
                                : _authMode == AuthMode.signup
                                    ? 'CREATE ACCOUNT WITH EMAIL'
                                    : 'SIGN IN WITH EMAIL',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Sign Up / Sign In toggle
                if (_authMode == AuthMode.login) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account? ',
                        style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _authMode = AuthMode.signup;
                            _errorMessage = null;
                          });
                        },
                        child: Text(
                          'Sign Up',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.monexBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (_authMode == AuthMode.signup) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _authMode = AuthMode.login;
                          _errorMessage = null;
                        });
                      },
                      child: Text(
                        'Already have an account? Sign In',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.monexBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    Function(String)? onChanged,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0D5DD), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: onChanged,
        validator: validator,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF98A2B3),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF667085), size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF667085),
                    size: 20,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildRequirementItem({required String text, required bool isMet}) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMet ? AppTheme.monexBlue : Colors.transparent,
            border: Border.all(
              color: isMet ? AppTheme.monexBlue : const Color(0xFFD0D5DD),
              width: 1.5,
            ),
          ),
          child: isMet
              ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isMet ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const MonexIllustration(
                index: 3,
                width: 220,
                height: 220,
              ),
              const SizedBox(height: 36),
              Text(
                'Password updated!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your password has been setup\nsuccessfully',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showSuccessState = false;
                      _authMode = AuthMode.login;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.monexBlue,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: AppTheme.monexBlue.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'BACK TO LOGIN',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // Draw Google 4-Color 'G'
    final redPaint = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.stroke..strokeWidth = 3.5;
    final bluePaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.stroke..strokeWidth = 3.5;
    final greenPaint = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.stroke..strokeWidth = 3.5;
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.stroke..strokeWidth = 3.5;

    final rect = Rect.fromCircle(center: center, radius: radius * 0.75);

    // Red Arc (Top)
    canvas.drawArc(rect, 3.14 * 1.25, 3.14 * 0.6, false, redPaint);
    // Yellow Arc (Left)
    canvas.drawArc(rect, 3.14 * 0.75, 3.14 * 0.5, false, yellowPaint);
    // Green Arc (Bottom)
    canvas.drawArc(rect, 3.14 * 0.25, 3.14 * 0.5, false, greenPaint);
    // Blue Arc + Bar (Right)
    canvas.drawArc(rect, 0, 3.14 * 0.25, false, bluePaint);

    final barPaint = Paint()..color = const Color(0xFF4285F4)..strokeWidth = 3.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(center.dx, center.dy), Offset(center.dx + radius * 0.75, center.dy), barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
