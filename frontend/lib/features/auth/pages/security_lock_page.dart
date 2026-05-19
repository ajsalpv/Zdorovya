import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class SecurityLockPage extends StatefulWidget {
  final Widget? child;
  final VoidCallback? onAuthenticated;
  const SecurityLockPage({super.key, this.child, this.onAuthenticated});

  @override
  State<SecurityLockPage> createState() => _SecurityLockPageState();
}

class _SecurityLockPageState extends State<SecurityLockPage> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isAuthenticated = false;
  bool _obscureText = true;

  static const String _hashedAdminPassword =
      '17182b9991fd551690a6e7506f80436d69e29d2763d4dd37c56d96759730d466';

  void _handleSuccess() {
    if (widget.onAuthenticated != null) {
      widget.onAuthenticated!();
    } else {
      setState(() => _isAuthenticated = true);
    }
  }

  void _verifyPassword() {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes).toString();

    if (hash == _hashedAdminPassword) {
      _handleSuccess();
    } else {
      _passwordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect password'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated && widget.child != null) return widget.child!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.primary.withAlpha(20),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.security, size: 80, color: AppColors.primary),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Verification Required',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Please confirm your identity to continue',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      hintText: 'Enter Password',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscureText = !_obscureText),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _verifyPassword(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _verifyPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Verify', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

