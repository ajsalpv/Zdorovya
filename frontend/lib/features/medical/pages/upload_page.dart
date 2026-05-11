import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/services/storage_service.dart';
import '../../../core/services/family_service.dart';
import '../../../core/services/security_service.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _extractedData;
  File? _selectedFile;
  final ImagePicker _picker = ImagePicker();
  
  String? _selectedPatientId;
  List<Map<String, dynamic>> _members = [];
  bool _isPrivate = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(
      source: source,
      imageQuality: 70,
    );
    if (photo != null) _setFile(File(photo.path));
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result != null && result.files.single.path != null) {
      _setFile(File(result.files.single.path!));
    }
  }

  void _setFile(File file) {
    setState(() {
      _selectedFile = file;
      _isLoading = true;
    });
    _processFile();
  }

  Future<void> _processFile() async {
    if (_selectedFile == null) return;
    
    try {
      final response = await apiService.processReport(
        PlatformFile(
          name: _selectedFile!.path.split('/').last,
          size: await _selectedFile!.length(),
          path: _selectedFile!.path,
        ),
        patientId: _selectedPatientId,
      );
      final data = response['data'];
      final embedding = response['embedding'];
      setState(() {
        _extractedData = Map<String, dynamic>.from(data);
        _extractedData!['embedding'] = embedding;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Processing Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadMembers() async {
    final members = await familyService.getMembers();
    setState(() {
      _members = members;
      // Default to active profile or first member
      final activeId = profileService.activeProfile?.id;
      _selectedPatientId = members.any((m) => m['id'] == activeId) 
          ? activeId 
          : (members.isNotEmpty ? members.first['id'] : null);
      
      _updatePrivacyLock();
    });
  }

  void _updatePrivacyLock() {
    final selectedMember = _members.firstWhere((m) => m['id'] == _selectedPatientId, orElse: () => {});
    if (selectedMember['relationship'] == 'Father') {
      setState(() {
        _isPrivate = false; // Father is always public
      });
    }
  }

  Future<void> _saveRecord() async {
    if (_extractedData == null) return;
    
    setState(() => _isLoading = true);
    try {
      // 1. Upload to Storage
      final fileUrl = await storageService.uploadMedicalRecord(_selectedFile!);

      // 2. Save to Database
      final client = Supabase.instance.client;
      final selectedMember = _members.firstWhere((m) => m['id'] == _selectedPatientId);
      
      await client.from('medical_records').insert({
        'family_id': '00000000-0000-0000-0000-000000000000', 
        'patient_id': _selectedPatientId,
        'uploader_id': profileService.activeProfile?.id,
        'type': _extractedData!['type'] ?? 'General',
        'file_url': fileUrl,
        'metadata': {
          ..._extractedData!,
          'patient_name': selectedMember['name'],
          'patient_relationship': selectedMember['relationship'],
        },
        'extracted_text': _extractedData!['summary'],
        'embedding': _extractedData!['embedding'],
        'is_private': _isPrivate,
        'record_date': _extractedData!['date'] ?? DateTime.now().toIso8601String().split('T')[0],
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
      appBar: AppBar(title: const Text('Add Medical Record')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedPatientId,
              decoration: const InputDecoration(labelText: 'Who is this for?', border: OutlineInputBorder()),
              items: _members.map((m) => DropdownMenuItem(
                value: m['id'] as String,
                child: Text('${m['name']} (${m['relationship']})'),
              )).toList(),
              onChanged: (val) {
                setState(() => _selectedPatientId = val);
                _updatePrivacyLock();
              },
            ),
            const SizedBox(height: 20),
            _buildPrivacyToggle(),
            const SizedBox(height: 20),
            _buildUploadCard(),
            const SizedBox(height: 30),
            if (_isLoading) _buildLoadingShimmer(),
            if (_extractedData != null) _buildResultView(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyToggle() {
    final selectedMember = _members.firstWhere((m) => m['id'] == _selectedPatientId, orElse: () => {});
    final isFather = selectedMember['relationship'] == 'Father';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFather ? Colors.orange.withAlpha(20) : Colors.blue.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isFather ? Colors.orange : Colors.blue.withAlpha(100)),
      ),
      child: Row(
        children: [
          Icon(isFather ? Icons.public : (_isPrivate ? Icons.lock : Icons.public), 
               color: isFather ? Colors.orange : Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPrivate ? 'Private Record' : 'Public Record',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  isFather 
                    ? "Father's data is always public." 
                    : (_isPrivate ? 'Only you and Admin can see this.' : 'Visible to all family members.'),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          if (!isFather)
            Switch(
              value: _isPrivate,
              onChanged: (val) => setState(() => _isPrivate = val),
            ),
        ],
      ),
    );
  }


  Widget _buildUploadCard() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: Icons.camera_alt,
                label: 'Take Photo',
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ),
            Expanded(
              child: _actionButton(
                icon: Icons.upload_file,
                label: 'Upload PDF',
                onTap: _pickDocument,
              ),
            ),
          ],
        ),
        if (_selectedFile != null) ...[
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _selectedFile!.path.toLowerCase().endsWith('.pdf')
                ? Container(
                    height: 150,
                    width: double.infinity,
                    color: Colors.red.withAlpha(25),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.picture_as_pdf, color: Colors.red, size: 50),
                        SizedBox(height: 10),
                        Text('PDF Selected', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : Image.file(_selectedFile!, height: 150, width: double.infinity, fit: BoxFit.cover),
          ),
        ],
      ],
    );
  }

  Widget _actionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
          Text(securityService.decrypt(data['summary']), style: TextStyle(color: Colors.black.withAlpha(204))),
          const SizedBox(height: 20),
        ],
        if (data['medicines'] != null && (data['medicines'] as List).isNotEmpty) ...[
          Text('Medicines Found', style: Theme.of(context).textTheme.titleMedium),
          ...(data['medicines'] as List).map((m) => ListTile(
            leading: const Icon(Icons.medication),
            title: Text(m['name']),
            subtitle: Text('${securityService.decrypt(m['dosage'])} - ${m['frequency']}'),
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
