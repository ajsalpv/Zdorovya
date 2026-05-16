import 'package:flutter/material.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/theme/app_colors.dart';

class SecurityLockPage extends StatefulWidget {
  final Widget? child;
  final VoidCallback? onAuthenticated;
  const SecurityLockPage({super.key, this.child, this.onAuthenticated});

  @override
  State<SecurityLockPage> createState() => _SecurityLockPageState();
}

class _SecurityLockPageState extends State<SecurityLockPage> {
  bool _isAuthenticated = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  void _handleSuccess() {
    if (widget.onAuthenticated != null) {
      widget.onAuthenticated!();
    } else {
      setState(() => _isAuthenticated = true);
    }
  }

  Future<void> _checkBiometrics() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      final bool canCheck = await biometricService.canCheckBiometrics();
      if (!canCheck) {
        _handleSuccess();
        return;
      }
      
      final bool success = await biometricService.authenticate();
      if (success) {
        _handleSuccess();
      }
    } catch (e) {
      debugPrint('Biometric error: $e');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  final TextEditingController _pinController = TextEditingController();
  bool _showPinField = false;

  Future<void> _verifyPin() async {
    final storedPin = await profileService.getAdminPin();
    if (_pinController.text == storedPin) {
      _handleSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated && widget.child != null) return widget.child!;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.onAuthenticated != null ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ) : null,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                'Admin Access Required',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              if (_isChecking)
                const CircularProgressIndicator(color: Colors.white)
              else if (!_showPinField) ...[
                ElevatedButton.icon(
                  onPressed: _checkBiometrics,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Unlock with Biometrics'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _showPinField = true),
                  child: const Text('Use Security PIN', style: TextStyle(color: Colors.white70)),
                ),
              ] else ...[
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 32, letterSpacing: 10),
                  decoration: const InputDecoration(
                    hintText: '••••',
                    hintStyle: TextStyle(color: Colors.white30),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 2)),
                  ),
                  onSubmitted: (_) => _verifyPin(),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _verifyPin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Verify Admin PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () => setState(() => _showPinField = false),
                  child: const Text('Back to Biometrics', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

