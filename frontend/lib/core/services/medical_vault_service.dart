import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/profile_service.dart';

class MedicalVaultService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _familyId = '00000000-0000-0000-0000-000000000000';

  Stream<List<Map<String, dynamic>>> getRecordsStream() {
    final profile = profileService.activeProfile;
    if (profile == null) return Stream.value([]);

    final query = _supabase
        .from('medical_records')
        .stream(primaryKey: ['id'])
        .eq('family_id', _familyId);

    return query.map((records) {
      return records.where((record) {
        final isPrivate = record['is_private'] ?? false;
        final patientId = record['patient_id'];
        final relationship = record['metadata']?['patient_relationship']; // We should store this

        // Admin sees everything
        if (profile.isAdmin) return true;

        // Owner sees their own private data
        if (patientId == profile.id) return true;

        // Everyone sees public data
        if (!isPrivate) return true;

        // Father's data is always public (handled by isPrivate being false or explicit check)
        if (relationship == 'Father') return true;

        return false;
      }).toList()..sort((a, b) => (b['record_date'] ?? '').compareTo(a['record_date'] ?? ''));
    });
  }
}

final medicalVaultService = MedicalVaultService();
