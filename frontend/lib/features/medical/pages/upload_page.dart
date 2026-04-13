import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _extractedData;

  Future<void> _pickAndUpload() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final response = await apiService.processReport(result.files.first);
        setState(() {
          _extractedData = response['data'];
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _saveRecord() async {
    if (_extractedData == null) return;
    
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      await client.from('medical_records').insert({
        'family_id': 'demo-family-id', 
        'type': _extractedData!['type'],
        'file_url': 'tmp_placeholder', 
        'metadata': _extractedData!,
        'extracted_text': _extractedData!['summary'],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to Vault successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUploadCard(),
            const SizedBox(height: 30),
            if (_isLoading) _buildLoadingShimmer(),
            if (_extractedData != null) _buildResultView(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard() {
    return InkWell(
      onTap: _isLoading ? null : _pickAndUpload,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_upload_outlined, size: 50, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            const Text('Upload Prescription or Lab Report', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('PDF, JPG, PNG accepted', style: TextStyle(fontSize: 12, color: Colors.black.withAlpha(178))),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(3, (index) => Container(
          height: 80,
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        )),
      ),
    );
  }

  Widget _buildResultView() {
    final data = _extractedData!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Extracted Insights', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 15),
        _infoTile('Type', data['type']),
        _infoTile('Name', data['patient_name']),
        _infoTile('Date', data['date']),
        _infoTile('Doctor', data['doctor_name']),
        const Divider(height: 30),
        if (data['summary'] != null) ...[
          Text('Summary', style: Theme.of(context).textTheme.titleMedium),
          Text(data['summary'], style: TextStyle(color: Colors.black.withAlpha(204))),
          const SizedBox(height: 20),
        ],
        if (data['medicines'] != null && (data['medicines'] as List).isNotEmpty) ...[
          Text('Medicines Found', style: Theme.of(context).textTheme.titleMedium),
          ...(data['medicines'] as List).map((m) => ListTile(
            leading: const Icon(Icons.medication),
            title: Text(m['name']),
            subtitle: Text('${m['dosage']} - ${m['frequency']}'),
            trailing: m['price'] != null ? Text(m['price'].toString()) : null,
          )),
        ],
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveRecord,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: const Text('Save to Vault'),
          ),
        ),
      ],
    );
  }

  Widget _infoTile(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black.withAlpha(153))),
          Text(value?.toString() ?? 'N/A'),
        ],
      ),
    );
  }
}
