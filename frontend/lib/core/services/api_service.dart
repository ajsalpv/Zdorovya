import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

class ApiService {
  final String _baseUrl = 'http://10.0.2.2:8000'; // Standard Android Emulator loopback
  final Dio _dio = Dio();

  Future<Map<String, dynamic>> processReport(PlatformFile file) async {
    try {
      String fileName = file.name;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          file.path!,
          filename: fileName,
        ),
      });

      var response = await _dio.post(
        "$_baseUrl/api/v1/process-report",
        data: formData,
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
