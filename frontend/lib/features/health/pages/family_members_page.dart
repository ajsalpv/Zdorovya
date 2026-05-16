import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/family_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/theme/app_colors.dart';

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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildStatTile(Icons.favorite, 'Health Score', '92%'),
                  _buildStatTile(Icons.bloodtype, 'Blood Group', 'O+'),
                  _buildStatTile(Icons.history, 'Recent Activity', 'Blood test uploaded yesterday'),
                ],
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
