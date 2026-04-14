import 'dart:async';
import 'package:dio/dio.dart';
import 'dart:developer' as developer;

class KeepAliveService {
  final String _healthUrl = 'https://zdorovya.onrender.com/health';
  final Dio _dio = Dio();
  Timer? _timer;

  void start() {
    // Ping immediately on start
    _ping();
    
    // Ping every 10 minutes (600 seconds)
    _timer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _ping();
    });
    
    developer.log('KeepAliveService started with 10-minute interval');
  }

  void stop() {
    _timer?.cancel();
    developer.log('KeepAliveService stopped');
  }

  Future<void> _ping() async {
    try {
      final response = await _dio.get(_healthUrl);
      if (response.statusCode == 200) {
        developer.log('Keep-alive ping successful: ${response.data}');
      }
    } catch (e) {
      developer.log('Keep-alive ping failed: $e');
    }
  }
}

final keepAliveService = KeepAliveService();
