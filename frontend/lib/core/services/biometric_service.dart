import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:logging/logging.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final Logger _logger = Logger('BiometricService');

  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (e) {
      _logger.severe('Check biometrics error: $e');
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to access your medical records',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allows PIN fallback if biometrics fail
        ),
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Zdorovya Security',
            fingerprintHint: 'Verify your ID',
          ),
          IOSAuthMessages(
            cancelButton: 'No thanks',
          ),
        ],
      );
      return didAuthenticate;
    } catch (e) {
      _logger.severe('Authentication error: $e');
      return false;
    }
  }
}

final biometricService = BiometricService();
