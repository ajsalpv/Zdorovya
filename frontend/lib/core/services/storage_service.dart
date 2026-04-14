import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _bucketName = 'medical-records';

  Future<String> uploadMedicalRecord(File file) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.jpg';
    final path = 'records/$fileName';

    await _supabase.storage.from(_bucketName).upload(
          path,
          file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

    // Get the public URL
    final String publicUrl = _supabase.storage.from(_bucketName).getPublicUrl(path);
    return publicUrl;
  }
}

final storageService = StorageService();
