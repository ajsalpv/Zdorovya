import 'package:flutter/material.dart';
import '../../../core/services/medicine_service.dart';
import '../../medical/pages/upload_page.dart';
import 'add_medicine_page.dart';
import 'package:intl/intl.dart';

class MedicineDashboard extends StatelessWidget {
  const MedicineDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // For demo, we assume a family_id. In production, this comes from Auth provider.
        future: medicineService.getMedicines('00000000-0000-0000-0000-000000000000'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(context);
          }

          final medicines = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: medicines.length,
            itemBuilder: (context, index) {
              final med = medicines[index];
              return _buildMedicineCard(context, med);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMedicinePage())),
        label: const Text('Add Medicine'),
        icon: const Icon(Icons.medication),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Opacity(opacity: 0.2, child: Icon(Icons.medical_services_outlined, size: 100)),
          const SizedBox(height: 20),
          Text('No medicines tracked yet', style: TextStyle(fontSize: 18, color: Colors.black.withAlpha(128))),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadPage())),
            child: const Text('Scan Prescription'),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(BuildContext context, Map<String, dynamic> med) {
    bool lowStock = (med['stock_quantity'] ?? 0) <= (med['min_stock_alert'] ?? 5);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(50),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.medication, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(med['family_members']?['name'] ?? 'Family Member', style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                if (lowStock)
                  const Chip(
                    label: Text('Low Stock', style: TextStyle(fontSize: 10, color: Colors.white)),
                    backgroundColor: Colors.redAccent,
                  ),
              ],
            ),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statTile('Dosage', med['dosage'] ?? '--'),
                _statTile('Frequency', med['frequency'] ?? '--'),
                _statTile('Stock', '${med['stock_quantity']} left'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.black.withAlpha(128))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
