import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _familyId = '00000000-0000-0000-0000-000000000000';

  Future<List<Map<String, dynamic>>> getMembers() async {
    final response = await _supabase
        .from('family_members')
        .select('*')
        .eq('family_id', _familyId)
        .eq('is_active', true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addMember(Map<String, dynamic> memberData) async {
    await _supabase.from('family_members').insert({
      ...memberData,
      'family_id': _familyId,
    });
  }

  Future<void> deactivateMember(String memberId) async {
    await _supabase
        .from('family_members')
        .update({'is_active': false})
        .eq('id', memberId);
  }
}

final familyService = FamilyService();
