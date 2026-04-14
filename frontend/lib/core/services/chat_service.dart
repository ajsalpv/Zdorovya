import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

class ChatService {
  final String _baseUrl = 'https://zdorovya.onrender.com';
  final Dio _dio = Dio();
  final String _sessionId = Uuid().v4();

  Future<Map<String, dynamic>> sendMessage(String message) async {
    try {
      final response = await _dio.post(
        "$_baseUrl/api/v1/copilot/chat",
        data: {
          "message": message,
          "session_id": _sessionId,
        },
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
