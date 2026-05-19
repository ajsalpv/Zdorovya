import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_colors.dart';
import 'features/medical/pages/upload_page.dart';
import 'features/medicine/pages/medicine_dashboard.dart';
import 'features/reminders/pages/reminders_page.dart';
import 'features/chat/pages/chat_page.dart';
import 'features/health/pages/trends_page.dart';
import 'features/health/pages/family_members_page.dart';
import 'features/medical/pages/medical_vault_page.dart';
import 'core/services/profile_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/keep_alive_service.dart';
import 'features/auth/pages/profile_selection_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
    
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );

    // Initialize Auth first so that Supabase has a valid session for RLS
    await _initializeAuth();

    // Initialize Profile Service
    await profileService.init();

    await notificationService.init();
    keepAliveService.start();

  } catch (e) {
    debugPrint("Initialization error: $e");
  }

  runApp(const ZdorovyaApp());
}

Future<void> _initializeAuth() async {
  try {
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) {
      await auth.signInAnonymously().timeout(const Duration(seconds: 10));
    }
  } catch (e) {
    debugPrint("Auth failed: $e");
  }
}

class ZdorovyaApp extends StatelessWidget {
  const ZdorovyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zdorovya',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.alert,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
      ),
      // If a profile is already active, go to Home, otherwise go to Profile Selection
      initialRoute: profileService.activeProfile != null ? '/home' : '/profiles',
      routes: {
        '/profiles': (context) => const ProfileSelectionPage(),
        '/home': (context) => const MainNavigation(),
      },
    );
  }
}


class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}


class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  
  final List<String> _titles = [
    'Family Pharmacy',
    'Medicine Alarms',
    'Health Copilot',
    'Family Circle',
    'Medical Vault'
  ];
  
  final List<Widget> _pages = [
    const MedicineDashboard(),
    const RemindersPage(),
    const ChatPage(),
    const FamilySocialPage(),
    const MedicalVaultPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final profile = profileService.activeProfile;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titles[_selectedIndex], style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadPage())),
            tooltip: 'Upload Report',
          ),
          IconButton(
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white24,
              child: Icon(_getIconForRelationship(profile?.relationship), size: 16, color: Colors.white),
            ),
            onPressed: () => Navigator.pushReplacementNamed(context, '/profiles'),
            tooltip: 'Switch Profile',
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.medication_outlined), label: 'Pharmacy'),
          NavigationDestination(icon: Icon(Icons.notifications_active_outlined), label: 'Alarms'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), label: 'Copilot'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Circle'),
          NavigationDestination(icon: Icon(Icons.folder_shared_outlined), label: 'Vault'),
        ],
      ),
    );
  }

  IconData _getIconForRelationship(String? rel) {
    switch (rel) {
      case 'Father': return Icons.face;
      case 'Mother': return Icons.face_3;
      default: return Icons.person;
    }
  }

}
