import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/theme/app_colors.dart';
import 'upload_page.dart';

class MedicalVaultPage extends StatefulWidget {
  const MedicalVaultPage({super.key});

  @override
  State<MedicalVaultPage> createState() => _MedicalVaultPageState();
}

class _MedicalVaultPageState extends State<MedicalVaultPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _familyId = '00000000-0000-0000-0000-000000000000';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('medical_records')
            .stream(primaryKey: ['id'])
            .eq('family_id', _familyId)
            .order('record_date', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadPage())),
            child: const Text('Upload your first record'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final metadata = record['metadata'] as Map<String, dynamic>? ?? {};
    final type = record['type'] ?? 'Unknown';
    final date = record['record_date'] ?? 'No Date';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: _buildTypeIcon(type),
        title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(date),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (metadata['patient_name'] != null)
                  _detailRow('Patient', metadata['patient_name']),
                if (metadata['doctor_name'] != null)
                  _detailRow('Provider', metadata['doctor_name']),
                const SizedBox(height: 12),
                Text('AI Summary:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                Text(record['extracted_text'] ?? 'No summary available.'),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _viewImage(record['file_url']),
                      icon: const Icon(Icons.image),
                      label: const Text('View Original'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _downloadPdf(record),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Download PDF'),
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
