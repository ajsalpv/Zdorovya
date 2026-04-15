import 'package:dio/dio.dart' as dio;
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final String _baseUrl = 'https://zdorovya.onrender.com';
  final dio.Dio _dio = dio.Dio();
  final String _sessionId = Uuid().v4();

  Future<Map<String, dynamic>> sendMessage(String message) async {
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;

      final response = await _dio.post(
        "$_baseUrl/api/v1/copilot/chat",
        data: {
          "message": message,
          "session_id": _sessionId,
        },
        options: dio.Options(
          headers: {
            if (token != null) "Authorization": "Bearer $token",
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception("Failed to chat: ${response.statusMessage}");
      }
    } catch (e) {
      throw Exception("Error connecting to copilot: $e");
    }
  }
}

final chatService = ChatService();
