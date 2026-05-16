import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  final String _baseUrl = dotenv.env['BACKEND_URL'] ?? 'https://zdorovya.onrender.com';
  final dio.Dio _dio = dio.Dio();

  Future<Map<String, dynamic>> processReport(PlatformFile file, {String? patientId}) async {
    try {
      String fileName = file.name;
      dio.FormData formData = dio.FormData.fromMap({
        "file": await dio.MultipartFile.fromFile(
          file.path!,
          filename: fileName,
        ),
        if (patientId != null) "patient_id": patientId,
      });

      final token = Supabase.instance.client.auth.currentSession?.accessToken;

      var response = await _dio.post(
        "$_baseUrl/api/v1/process-report",
        data: formData,
        options: dio.Options(
          headers: {
            if (token != null) "Authorization": "Bearer $token",
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception("Failed to process report: ${response.statusMessage}");
      }
    } catch (e) {
      throw Exception("Error connecting to backend: $e");
    }
  }
}

final apiService = ApiService();
