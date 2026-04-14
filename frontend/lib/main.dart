import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/theme/app_colors.dart';
import 'features/medical/pages/upload_page.dart';
import 'features/medicine/pages/medicine_dashboard.dart';
import 'features/reminders/pages/reminders_page.dart';
import 'features/chat/pages/chat_page.dart';
import 'features/health/pages/trends_page.dart';
import 'features/emergency/pages/emergency_page.dart';
import 'features/health/pages/family_members_page.dart';
import 'features/medical/pages/medical_vault_page.dart';
import 'core/services/keep_alive_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://jlrzzrhxqvpzrltolkbf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impscnp6cmh4cXZwenJsdG9sa2JmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMDU0NTQsImV4cCI6MjA5MTY4MTQ1NH0.8Y3-zKl1AZqTolXeDto1aHsvIzu4e0o88q0a4wjeRXM',
  );

  // Initialize Notifications
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Start Keep-Alive (Ping Render)
  keepAliveService.start();

  runApp(const ZdorovyaApp());
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
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        textTheme: GoogleFonts.outfitTextTheme().copyWith(
          displayLarge: TextStyle(color: AppColors.textPrimary),
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textPrimary),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const MainNavigation(),
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
    'Zdorovya Pharmacy',
    'Daily Alarms',
    'Health Copilot',
    'Health Trends',
    'Medical Vault'
  ];
  
  final List<Widget> _pages = [
    const MedicineDashboard(),
    const RemindersPage(),
    const ChatPage(),
    const TrendsPage(),
    const MedicalVaultPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.family_restroom),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageFamilyPage())),
            tooltip: 'Manage Family',
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
          NavigationDestination(icon: Icon(Icons.analytics_outlined), label: 'Trends'),
          NavigationDestination(icon: Icon(Icons.folder_shared_outlined), label: 'Vault'),
        ],
      ),
    );
  }
}

// Temporary placeholders for structure
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_moon, size: 80, color: Color(0xFF1E88E5)),
                const SizedBox(height: 20),
                const Text('Zdorovya', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                Text('Secure Family Vault', style: TextStyle(color: Colors.black.withAlpha(153))),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Login with Email/OTP'),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyPage())),
              icon: const Icon(Icons.emergency, color: Colors.redAccent),
              label: const Text('EMERGENCY SOS ACCESS', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Vault')),
      body: const Center(child: Text('Coming Soon')),
    );
  }
}
