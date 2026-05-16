import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/family_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/medical_vault_service.dart';
import '../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';

class FamilySocialPage extends StatefulWidget {
  const FamilySocialPage({super.key});

  @override
  State<FamilySocialPage> createState() => _FamilySocialPageState();
}

class _FamilySocialPageState extends State<FamilySocialPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Family Circle', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
              centerTitle: false,
            ),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final profile = profileService.familyProfiles[index];
                  return _buildSocialCard(profile);
                },
                childCount: profileService.familyProfiles.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialCard(var profile) {
    return GestureDetector(
      onTap: () => _showProfileDetail(profile),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary.withAlpha(30),
              child: Icon(_getIconForRelationship(profile.relationship), size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(profile.name, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(profile.relationship, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showProfileDetail(var profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 30),
            CircleAvatar(
              radius: 60,
              backgroundColor: AppColors.primary.withAlpha(30),
              child: Icon(_getIconForRelationship(profile.relationship), size: 60, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(profile.name, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold)),
            Text(profile.relationship, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const Divider(height: 40, indent: 40, endIndent: 40),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('MEDICAL HISTORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: medicalVaultService.getMemberRecordsStream(profile.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final records = snapshot.data ?? [];
                  if (records.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_off_outlined, size: 40, color: Colors.grey),
                          SizedBox(height: 10),
                          Text('No public records shared yet.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final r = records[index];
                      return Card(
                        elevation: 0,
                        color: Colors.grey[50],
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), shape: BoxShape.circle),
                            child: Icon(Icons.description_outlined, color: AppColors.primary, size: 20),
                          ),
                          title: Text(r['type'] ?? 'Report', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(r['record_date'] ?? 'No date', style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right, size: 16),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (profileService.isAdmin && profile.id == profileService.activeProfile?.id)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: ElevatedButton.icon(
                  onPressed: _showChangePinDialog,
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Change Admin Password'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      trailing: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  void _showChangePinDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Admin Password'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new 4-digit PIN'),
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.length == 4) {
                await profileService.setAdminPin(controller.text);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin PIN updated!')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForRelationship(String rel) {
    switch (rel) {
      case 'Father': return Icons.face;
      case 'Mother': return Icons.face_3;
      default: return Icons.person;
    }
  }
}
