import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/profile_service.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class MedicalVaultService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _familyId = dotenv.env['FAMILY_ID'] ?? '';

  Stream<List<Map<String, dynamic>>> getRecordsStream() {
    return _filterStream(null);
  }

  Stream<List<Map<String, dynamic>>> getMemberRecordsStream(String memberId) {
    return _filterStream(memberId);
  }

  Stream<List<Map<String, dynamic>>> _filterStream(String? targetMemberId) {
    final profile = profileService.activeProfile;
    if (profile == null) return Stream.value([]);

    var stream = _supabase
        .from('medical_records')
        .stream(primaryKey: ['id']);

    return stream.map((records) {
      return records.where((record) {
        // Filter by family_id and optionally targetMemberId manually in stream
        if (record['family_id'] != _familyId) return false;
        if (targetMemberId != null && record['patient_id'] != targetMemberId) return false;

        final isPrivate = record['is_private'] ?? false;
        final patientId = record['patient_id'];
        final relationship = record['metadata']?['patient_relationship'];

        if (profile.isAdmin) return true;
        if (patientId == profile.id) return true;
        if (!isPrivate) return true;
        if (relationship == 'Father') return true;
        return false;
      }).toList()..sort((a, b) => (b['record_date'] ?? '').compareTo(a['record_date'] ?? ''));
    });
  }
}

final medicalVaultService = MedicalVaultService();
