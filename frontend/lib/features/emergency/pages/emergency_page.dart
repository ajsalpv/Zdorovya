import 'package:flutter/material.dart';

class EmergencyPage extends StatelessWidget {
  const EmergencyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB71C1C), // Deep Red for Emergency
      appBar: AppBar(
        title: const Text('EMERGENCY INFO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white24,
              child: Icon(Icons.emergency, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 30),
            _buildInfoCard(context, 'BLOOD GROUP', 'O Negative', Icons.bloodtype, Colors.red),
            const SizedBox(height: 16),
            _buildInfoCard(context, 'CONDITIONS', 'Type 2 Diabetes\nHypertension', Icons.warning_amber, Colors.orange),
            const SizedBox(height: 16),
            _buildInfoCard(context, 'MEDICATIONS', 'Metformin 500mg\nLisinopril 10mg', Icons.medication, Colors.blue),
            const SizedBox(height: 30),
            const Divider(color: Colors.white24),
            const SizedBox(height: 20),
            Text('CRITICAL CONTACTS', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)),
            const SizedBox(height: 10),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: const Text('Admin (Son)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('+91 98765 43210', style: TextStyle(color: Colors.white70)),
              trailing: IconButton(icon: const Icon(Icons.phone, color: Colors.white), onPressed: () {}),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.description),
              label: const Text('View Latest ECG'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFB71C1C),
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String value, IconData icon, Color iconColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Icon(icon, size: 40, color: iconColor),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
