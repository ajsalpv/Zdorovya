import 'package:flutter/material.dart';
import '../../../core/services/medicine_service.dart';
import '../../../core/services/profile_service.dart';
import 'package:intl/intl.dart';

class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: medicineService.getPendingRemindersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildAllCaughtUp();
          }

          final reminders = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reminders.length,
            itemBuilder: (context, index) {
              final reminder = reminders[index];
              return _buildReminderTile(context, reminder);
            },
          );
        },
      ),
    );
  }

  Widget _buildAllCaughtUp() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Opacity(opacity: 0.3, child: Icon(Icons.check_circle_outline, size: 100, color: Colors.green)),
          const SizedBox(height: 20),
          const Text('All medicines taken!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('Next dose starts at 7:00 AM tomorrow', style: TextStyle(color: Colors.black.withAlpha(128))),
        ],
      ),
    );
  }

  Widget _buildReminderTile(BuildContext context, Map<String, dynamic> reminder) {
    // Assuming reminder has medicine name via a join or manual query
    final medName = reminder['medicine_name'] ?? 'Pill';
    final timeStr = reminder['scheduled_time'] ?? '00:00';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(50),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.alarm, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(medName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Scheduled for $timeStr'),
        trailing: ElevatedButton(
          onPressed: () => _markAsTaken(context, reminder['id']),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Taken'),
        ),
      ),
    );
  }

  Future<void> _markAsTaken(BuildContext context, String id) async {
    final profileId = profileService.activeProfile?.id ?? '';
    try {
      await medicineService.markDoseAsTaken(id, profileId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dose recorded. Family notified!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
