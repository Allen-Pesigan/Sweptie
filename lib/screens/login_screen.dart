import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sweptie/services/auth_service.dart';
import 'package:sweptie/screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF060D1A),
                        const Color(0xFF0D2040),
                        const Color(0xFF1A237E),
                      ]
                    : [
                        const Color(0xFF0D47A1),
                        const Color(0xFF1565C0),
                        const Color(0xFF1E88E5),
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Decorative blobs
          Positioned(
            top: -60,
            right: -60,
            child: _Blob(size: 240, color: Colors.white.withAlpha(13)),
          ),
          Positioned(
            top: 140,
            left: -80,
            child: _Blob(size: 200, color: Colors.white.withAlpha(8)),
          ),
          Positioned(
            bottom: -50,
            right: -30,
            child: _Blob(size: 190, color: Colors.white.withAlpha(10)),
          ),
          Positioned(
            bottom: 80,
            left: -40,
            child: _Blob(size: 140, color: Colors.white.withAlpha(6)),
          ),
          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(22),
                        border: Border.all(
                            color: Colors.white.withAlpha(55), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(50),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome_mosaic_rounded,
                          size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sweptie',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your screenshot organiser',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.white60,
                          letterSpacing: 0.2),
                    ),
                    const SizedBox(height: 48),
                    // Glassmorphism card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withAlpha(18)
                                : Colors.white.withAlpha(235),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withAlpha(28)
                                  : Colors.white.withAlpha(210),
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.all(28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Welcome back',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0D47A1),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Sign in to continue',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _InputField(
                                  controller: _emailCtrl,
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  isDark: isDark,
                                  validator: (v) =>
                                      (v == null || !v.contains('@'))
                                          ? 'Enter a valid email'
                                          : null,
                                ),
                                const SizedBox(height: 14),
                                _InputField(
                                  controller: _passwordCtrl,
                                  label: 'Password',
                                  icon: Icons.lock_outline_rounded,
                                  isDark: isDark,
                                  obscureText: _obscure,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.grey.shade400,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                  validator: (v) => (v == null || v.length < 6)
                                      ? 'Minimum 6 characters'
                                      : null,
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline_rounded,
                                            size: 16,
                                            color: Colors.red.shade700),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                // Gradient sign-in button
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF1565C0),
                                        Color(0xFF1E88E5),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withAlpha(90),
                                        blurRadius: 14,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: FilledButton(
                                    onPressed: _isLoading ? null : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 15),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white),
                                          )
                                        : const Text(
                                            'Sign In',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Don't have an account?",
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey.shade600),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const RegisterScreen()),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        foregroundColor:
                                            const Color(0xFF1E88E5),
                                      ),
                                      child: const Text(
                                        'Sign Up',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isDark;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.isDark,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor =
        isDark ? Colors.white.withAlpha(14) : Colors.grey.shade50;
    final borderColor =
        isDark ? Colors.white.withAlpha(22) : Colors.grey.shade200;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white54 : Colors.grey.shade500,
        ),
        prefixIcon: Icon(icon,
            size: 20,
            color: isDark ? Colors.white38 : Colors.grey.shade400),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF1E88E5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
