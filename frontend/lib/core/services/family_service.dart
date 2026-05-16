import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'cache_service.dart';

class FamilyService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _familyId = dotenv.env['FAMILY_ID'] ?? '';

  Future<List<Map<String, dynamic>>> getMembers() async {
    // 1. Try Cache first
    final cached = await cacheService.get('family_members');
    if (cached != null) {
      return List<Map<String, dynamic>>.from(cached);
    }

    // 2. Fetch from Supabase
    final response = await _supabase
        .from('family_members')
        .select('*')
        .eq('family_id', _familyId)
        .eq('is_active', true);
    
    final data = List<Map<String, dynamic>>.from(response);
    
    // 3. Update Cache
    await cacheService.set('family_members', data);
    
    return data;
  }

  Future<void> addMember(Map<String, dynamic> memberData) async {
    await _supabase.from('family_members').insert({
      ...memberData,
      'family_id': _familyId,
    });
    await cacheService.invalidate('family_members');
  }

  Future<void> deactivateMember(String memberId) async {
    await _supabase
        .from('family_members')
        .update({'is_active': false})
        .eq('id', memberId);
  }
}

final familyService = FamilyService();
