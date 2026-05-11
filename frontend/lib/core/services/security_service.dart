import 'package:encrypt/encrypt.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SecurityService {
  late final Fernet _fernet;
  late final Encrypter _encrypter;

  SecurityService() {
    final keyStr = dotenv.env['ENCRYPTION_KEY'] ?? 'fallback_key_if_needed';
    final key = Key.fromBase64(keyStr);
    _fernet = Fernet(key);
    _encrypter = Encrypter(_fernet);
  }

  String decrypt(String? encryptedText) {
    if (encryptedText == null || encryptedText.isEmpty) return '';
    try {
      // Fernet in the 'encrypt' package expects an Encrypted object
      // which handles the base64 conversion
      return _encrypter.decrypt(Encrypted.fromBase64(encryptedText));
    } catch (e) {
      // If decryption fails, return the raw text (might be legacy or not encrypted)
      return encryptedText;
    }
  }

  String encrypt(String? text) {
    if (text == null || text.isEmpty) return '';
    try {
      return _encrypter.encrypt(text).base64;
    } catch (e) {
      return text ?? '';
    }
  }
}

final securityService = SecurityService();
