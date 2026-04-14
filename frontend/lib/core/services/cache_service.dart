import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _keyPrefix = 'zd_cache_';

  Future<void> set(String key, dynamic data, {Duration ttl = const Duration(hours: 1)}) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = {
      'data': data,
      'expiry': DateTime.now().add(ttl).millisecondsSinceEpoch,
    };
    await prefs.setString('$_keyPrefix$key', jsonEncode(entry));
  }

  Future<dynamic> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final stringData = prefs.getString('$_keyPrefix$key');
    if (stringData == null) return null;

    final entry = jsonDecode(stringData);
    final expiry = entry['expiry'] as int;
    
    if (DateTime.now().millisecondsSinceEpoch > expiry) {
      await prefs.remove('$_keyPrefix$key');
      return null;
    }
    
    return entry['data'];
  }

  Future<void> invalidate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$key');
  }
}

final cacheService = CacheService();
