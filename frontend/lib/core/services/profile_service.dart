import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';

class ProfileService {
  static const String _activeProfileKey = 'active_profile_id';
  
  // Hardcoded Profiles as per requirements
  final List<UserProfile> familyProfiles = [
    UserProfile(id: '00000000-0000-0000-0000-000000000001', name: 'Ajsal', relationship: 'Brother', isAdmin: true),
    UserProfile(id: '00000000-0000-0000-0000-000000000002', name: 'Father', relationship: 'Father'),
    UserProfile(id: '00000000-0000-0000-0000-000000000003', name: 'Mother', relationship: 'Mother'),
    UserProfile(id: '00000000-0000-0000-0000-000000000004', name: 'Ansil', relationship: 'Brother'),
    UserProfile(id: '00000000-0000-0000-0000-000000000005', name: 'Ashhal', relationship: 'Brother'),
  ];



  UserProfile? _activeProfile;

  UserProfile? get activeProfile => _activeProfile;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = prefs.getString(_activeProfileKey);
    if (profileId != null) {
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
}

final profileService = ProfileService();
