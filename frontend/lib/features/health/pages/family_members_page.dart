import 'package:flutter/material.dart';
import '../../../core/services/family_service.dart';
import '../../../core/theme/app_colors.dart';

class ManageFamilyPage extends StatefulWidget {
  const ManageFamilyPage({super.key});

  @override
  State<ManageFamilyPage> createState() => _ManageFamilyPageState();
}

class _ManageFamilyPageState extends State<ManageFamilyPage> {
  bool _isAdmin = true; // For demo, default to true. Real app uses Supabase Auth roles.
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  String _relationship = 'Parent';
  String _bloodGroup = 'O+';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Family'),
        actions: [
          Switch(
            value: _isAdmin,
            onChanged: (val) => setState(() => _isAdmin = val),
            activeColor: Colors.white,
          ),
          const Center(child: Text('Admin Mode  ', style: TextStyle(fontSize: 10))),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: familyService.getMembers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final members = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return _buildMemberCard(member);
            },
          );
        },
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showAddMemberDialog,
              label: const Text('Add Member'),
              icon: const Icon(Icons.person_add),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Opacity(opacity: 0.2, child: Icon(Icons.people_outline, size: 100)),
          const SizedBox(height: 20),
          const Text('No family members added.'),
          if (_isAdmin)
            TextButton(onPressed: _showAddMemberDialog, child: const Text('Add the first member')),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(50),
          child: Text(member['name'][0].toUpperCase(), style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ),
        title: Text(member['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${member['relationship']} • ${member['blood_group'] ?? 'Blood Group N/A'}'),
        trailing: _isAdmin
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _deleteMember(member['id']),
              )
            : null,
      ),
    );
  }

  Future<void> _showAddMemberDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Family Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            DropdownButtonFormField<String>(
              value: _relationship,
              items: ['Parent', 'Spouse', 'Child', 'Sibling', 'Grandparent']
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (val) => setState(() => _relationship = val!),
              decoration: const InputDecoration(labelText: 'Relationship'),
            ),
            DropdownButtonFormField<String>(
              value: _bloodGroup,
              items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                  .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                  .toList(),
              onChanged: (val) => setState(() => _bloodGroup = val!),
              decoration: const InputDecoration(labelText: 'Blood Group'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: _addMember, child: const Text('Add')),
        ],
      ),
    );
  }

  Future<void> _addMember() async {
    if (_nameController.text.isEmpty) return;
    
    Navigator.pop(context);
    setState(() => _isLoading = true);
    try {
      await familyService.addMember({
        'name': _nameController.text,
        'relationship': _relationship,
        'blood_group': _bloodGroup,
      });
      _nameController.clear();
      setState(() {}); // Refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMember(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member?'),
        content: const Text('This will hide them from the family list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      await familyService.deactivateMember(id);
      setState(() {});
    }
  }
}
