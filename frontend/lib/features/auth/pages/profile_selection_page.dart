import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/profile.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/theme/app_colors.dart';
import 'security_lock_page.dart';

class ProfileSelectionPage extends StatelessWidget {
  const ProfileSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withAlpha(50),
              AppColors.background,
              AppColors.secondary.withAlpha(30),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              Text(
                'Who is using Zdorovya?',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Select your profile to continue',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 60),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 30,
                    crossAxisSpacing: 30,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: profileService.familyProfiles.length,
                  itemBuilder: (context, index) {
                    final profile = profileService.familyProfiles[index];
                    return _ProfileCard(profile: profile);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserProfile profile;
  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (profile.isAdmin) {
          // Admin requires PIN lock
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SecurityLockPage(
                onAuthenticated: () async {
                  await profileService.setActiveProfile(profile);
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/home');
                  }
                },
              ),
            ),
          );
        } else {
          // Others enter directly
          await profileService.setActiveProfile(profile);
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      },
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _getIconForRelationship(profile.relationship),
                  size: 50,
                  color: profile.isAdmin ? AppColors.primary : AppColors.secondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForRelationship(String rel) {
    switch (rel) {
      case 'Admin': return Icons.admin_panel_settings;
      case 'Father': return Icons.face;
      case 'Mother': return Icons.face_3;
      case 'Brother': return Icons.person;
      default: return Icons.account_circle;
    }
  }
}
