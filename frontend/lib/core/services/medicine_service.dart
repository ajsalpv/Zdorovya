import 'package:supabase_flutter/supabase_flutter.dart';

class MedicineService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getMedicines(String familyId) async {
    final response = await _supabase
        .from('medicines')
        .select('*, family_members(name)')
        .eq('family_id', familyId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addMedicine(Map<String, dynamic> medicineData) async {
    await _supabase.from('medicines').insert(medicineData);
  }

  Future<void> markDoseAsTaken(String reminderId) async {
    await _supabase
        .from('medicine_reminders')
        .update({
          'status': 'taken',
          'taken_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reminderId);
  }

  Stream<List<Map<String, dynamic>>> getPendingReminders(String familyId) {
    return _supabase
        .from('medicine_reminders')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('scheduled_time')
        .map((maps) => maps.toList());
  }
}

final medicineService = MedicineService();
