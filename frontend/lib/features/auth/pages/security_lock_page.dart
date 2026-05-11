import 'package:flutter/material.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/theme/app_colors.dart';

class SecurityLockPage extends StatefulWidget {
  final Widget child;
  const SecurityLockPage({super.key, required this.child});

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

  Future<void> _checkBiometrics() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      final bool canCheck = await biometricService.canCheckBiometrics();
      if (!canCheck) {
        setState(() {
          _isAuthenticated = true;
          _isChecking = false;
        });
        return;
      }
      
      final bool success = await biometricService.authenticate();
      if (success) {
        setState(() => _isAuthenticated = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  final TextEditingController _pinController = TextEditingController();
  bool _showPinField = false;

  void _verifyPin() {
    if (_pinController.text == '1234') { // For demo, default PIN is 1234
      setState(() => _isAuthenticated = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) return widget.child;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                'Zdorovya Locked',
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
                  ),
                ),
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
                  style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 10),
                  decoration: const InputDecoration(
                    hintText: '••••',
                    hintStyle: TextStyle(color: Colors.white30),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  ),
                  onSubmitted: (_) => _verifyPin(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _verifyPin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Verify PIN'),
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
