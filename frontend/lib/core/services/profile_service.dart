import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';

class ProfileService {
  static const String _activeProfileKey = 'active_profile_id';
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<UserProfile> familyProfiles = [];
  UserProfile? _activeProfile;
  UserProfile? get activeProfile => _activeProfile;

  static const String _appVersionKey = 'app_version';
  static const String currentVersion = '1.2.0';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Clear active profile on fresh install or update to force asking who is using the app
    final storedVersion = prefs.getString(_appVersionKey);
    if (storedVersion != currentVersion) {
      await prefs.remove(_activeProfileKey);
      await prefs.setString(_appVersionKey, currentVersion);
    }
    
    // Fetch members from DB instead of hardcoding
    try {
      final familyId = dotenv.env['FAMILY_ID'];
      final response = await _supabase
          .from('family_members')
          .select()
          .eq('family_id', familyId ?? '')
          .order('name');
      
      familyProfiles = (response as List).map((json) {
        return UserProfile(
          id: json['id'],
          name: json['name'],
          relationship: json['relationship'],
          // Ajsal is the admin (hardcoded name as per user request)
          isAdmin: json['name'] == 'Ajsal',
        );
      }).toList();
    } catch (e) {
      print('Error fetching profiles: $e');
      // Fallback or handle error
    }

    final profileId = prefs.getString(_activeProfileKey);
    if (profileId != null && familyProfiles.isNotEmpty) {
      _activeProfile = familyProfiles.firstWhere(
        (p) => p.id == profileId,
        orElse: () => familyProfiles[0],
      );
    }
  }

  Future<void> setActiveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, profile.id);
    _activeProfile = profile;
  }

  Future<void> clearActiveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeProfileKey);
    _activeProfile = null;
  }

  bool get isAdmin => _activeProfile?.isAdmin ?? false;

  Future<String> getAdminPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('admin_pin') ?? '1234';
  }

  Future<void> setAdminPin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_pin', newPin);
  }
}

final profileService = ProfileService();
