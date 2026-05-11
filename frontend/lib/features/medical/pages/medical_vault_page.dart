import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/theme/app_colors.dart';
import 'upload_page.dart';
import 'package:intl/intl.dart';
import '../../../core/services/security_service.dart';

import '../../../core/services/medical_vault_service.dart';
import '../../../core/services/profile_service.dart';

class MedicalVaultPage extends StatefulWidget {
  const MedicalVaultPage({super.key});

  @override
  State<MedicalVaultPage> createState() => _MedicalVaultPageState();
}

class _MedicalVaultPageState extends State<MedicalVaultPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: medicalVaultService.getRecordsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final records = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return _buildRecordCard(record);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadPage())),
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Opacity(opacity: 0.2, child: Icon(Icons.folder_open, size: 80)),
          const SizedBox(height: 16),
          const Text('Your Medical Vault is empty'),
          Text(
            profileService.isAdmin ? 'Upload records for any family member.' : 'Upload your own records here.',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadPage())),
            icon: const Icon(Icons.upload),
            label: const Text('Upload Record'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final metadata = record['metadata'] as Map<String, dynamic>? ?? {};
    final type = record['type'] ?? 'Unknown';
    final date = record['record_date'] ?? 'No Date';
    final isPrivate = record['is_private'] ?? false;
    final patientName = metadata['patient_name'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: _buildTypeIcon(type),
        title: Row(
          children: [
            Expanded(child: Text(type, style: const TextStyle(fontWeight: FontWeight.bold))),
            if (isPrivate)
              const Icon(Icons.lock, size: 16, color: Colors.blue),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$patientName • $date', style: const TextStyle(fontSize: 13)),
            Text(
              'Uploaded: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(record['created_at']))}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (metadata['doctor_name'] != null)
                  _detailRow('Provider', metadata['doctor_name']),
                const SizedBox(height: 12),
                Text('AI Summary:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                Text(securityService.decrypt(record['extracted_text'] ?? 'No summary available.')),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isPrivate)
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Text('PRIVATE', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _viewImage(record['file_url']),
                      icon: const Icon(Icons.image),
                      label: const Text('View'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _downloadPdf(record),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('PDF'),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }


  Widget _buildTypeIcon(String type) {
    IconData icon;
    Color color;

    switch (type.toLowerCase()) {
      case 'ecg':
        icon = Icons.monitor_heart;
        color = Colors.red;
        break;
      case 'prescription':
        icon = Icons.medication;
        color = Colors.blue;
        break;
      case 'blood test':
        icon = Icons.bloodtype;
        color = Colors.redAccent;
        break;
      default:
        icon = Icons.description;
        color = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: color.withAlpha(50),
      child: Icon(icon, color: color),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  void _viewImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(title: const Text('Original Photo'), leading: const CloseButton()),
            Image.network(url, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadPdf(Map<String, dynamic> record) async {
    setState(() => _isLoading = true);
    try {
      await pdfService.generateAndShareReport(
        title: record['type'],
        imageUrl: record['file_url'],
        metadata: record['metadata'] ?? {},
        summary: record['extracted_text'] ?? '',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
