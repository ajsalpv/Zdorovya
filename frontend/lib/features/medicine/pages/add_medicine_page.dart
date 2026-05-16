import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/services/medicine_service.dart';
import '../../../core/services/family_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/security_service.dart';

class AddMedicinePage extends StatefulWidget {
  const AddMedicinePage({super.key});

  @override
  State<AddMedicinePage> createState() => _AddMedicinePageState();
}

class _AddMedicinePageState extends State<AddMedicinePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _quantityController = TextEditingController(text: '30');
  
  bool _isPrivate = false;
  String _frequency = 'Daily';
  String? _selectedMemberId;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  void _updatePrivacyLock() {
    final selectedMember = _members.firstWhere((m) => m['id'] == _selectedMemberId, orElse: () => {});
    if (selectedMember['relationship'] == 'Father') {
      setState(() {
        _isPrivate = false; // Father is always public
      });
    }
  }

  Future<void> _loadMembers() async {
    final members = await familyService.getMembers();
    setState(() {
      _members = members;
      if (members.isNotEmpty) _selectedMemberId = members.first['id'];
    });
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate() || _selectedMemberId == null) return;

    setState(() => _isLoading = true);
    try {
      final String _familyId = dotenv.env['FAMILY_ID'] ?? '';
      
      // 1. Save Medicine
      await medicineService.addMedicine({
        'family_id': _familyId,
        'patient_id': _selectedMemberId,
        'name': _nameController.text,
        'dosage': securityService.encrypt(_dosageController.text),
        'frequency': _frequency,
        'stock_quantity': int.parse(_quantityController.text),
        'is_private': _isPrivate,
      });

      // 2. Schedule Alarm (for demo we just schedule one for today/tomorrow at selected time)
      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, _selectedTime.hour, _selectedTime.minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await notificationService.scheduleInsistentAlarm(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: 'Time for Medicine: ${_nameController.text}',
        body: 'Take ${_dosageController.text} now.',
        scheduledTime: scheduledDate,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medicine added and alarm set!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Medicine')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedMemberId,
                    decoration: const InputDecoration(labelText: 'For Family Member', border: OutlineInputBorder()),
                    items: _members.map((m) => DropdownMenuItem(
                      value: m['id'] as String,
                      child: Text('${m['name']} (${m['relationship']})'),
                    )).toList(),
                    onChanged: (val) {
                      setState(() => _selectedMemberId = val);
                      _updatePrivacyLock();
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildPrivacyToggle(),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Medicine Name', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),

                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _dosageController,
                    decoration: const InputDecoration(labelText: 'Dosage (e.g. 1 Tablet, 5ml)', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _frequency,
                    decoration: const InputDecoration(labelText: 'Frequency', border: OutlineInputBorder()),
                    items: ['Daily', 'Twice a Day', 'Every 8 Hours'].map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(f),
                    )).toList(),
                    onChanged: (val) => setState(() => _frequency = val!),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    title: const Text('Reminder Time'),
                    trailing: Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
                    onTap: () async {
                      final time = await showTimePicker(context: context, initialTime: _selectedTime);
                      if (time != null) setState(() => _selectedTime = time);
                    },
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _saveMedicine,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: const Text('Save & Set Alarm'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildPrivacyToggle() {
    final selectedMember = _members.firstWhere((m) => m['id'] == _selectedMemberId, orElse: () => {});
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
                  _isPrivate ? 'Private Medicine' : 'Public Medicine',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  isFather 
                    ? "Father's medicine is always public." 
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
}
