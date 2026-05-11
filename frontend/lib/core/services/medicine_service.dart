import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_service.dart';

class MedicineService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _familyId = '00000000-0000-0000-0000-000000000000';

  Future<List<Map<String, dynamic>>> getMedicines() async {
    final profile = profileService.activeProfile;
    if (profile == null) return [];

    final response = await _supabase
        .from('medicines')
        .select('*, family_members(name, relationship)')
        .eq('family_id', _familyId);
    
    final allMeds = List<Map<String, dynamic>>.from(response);

    // Apply Privacy Logic
    return allMeds.where((med) {
      final isPrivate = med['is_private'] ?? false;
      final patientId = med['patient_id'];
      final patientRel = med['family_members']?['relationship'];

      if (profile.isAdmin) return true;
      if (patientId == profile.id) return true;
      if (!isPrivate) return true;
      if (patientRel == 'Father') return true;
      return false;
    }).toList();
  }

  Future<void> addMedicine(Map<String, dynamic> medicineData) async {
    await _supabase.from('medicines').insert({
      ...medicineData,
      'family_id': _familyId,
    });
  }

  Future<void> markDoseAsTaken(String reminderId, String profileId) async {
    await _supabase
        .from('medicine_reminders')
        .update({
          'status': 'taken',
          'taken_at': DateTime.now().toIso8601String(),
          'confirmed_by_id': profileId,
        })
        .eq('id', reminderId);
  }

  Stream<List<Map<String, dynamic>>> getPendingRemindersStream() {
    return _supabase
        .from('medicine_reminders')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('scheduled_time')
        .map((maps) => maps.toList());
  }
}

final medicineService = MedicineService();

