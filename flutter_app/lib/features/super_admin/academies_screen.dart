import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/api_client.dart';

class AcademiesScreen extends StatefulWidget {
  const AcademiesScreen({super.key});

  @override
  State<AcademiesScreen> createState() => _AcademiesScreenState();
}

class _AcademiesScreenState extends State<AcademiesScreen> {
  bool _loading = true;
  List<dynamic> _academies = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiClient>().getAcademies();
      setState(() => _academies = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleStatus(dynamic academy) async {
    final api = context.read<ApiClient>();
    try {
      if (academy['status'] == 'active') {
        await api.suspendAcademy(academy['id']);
      } else {
        await api.activateAcademy(academy['id']);
      }
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Academy?'),
        content: const Text('This will soft delete the academy.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await context.read<ApiClient>().deleteAcademy(id);
        _loadData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final adminNameCtrl = TextEditingController();
    final adminEmailCtrl = TextEditingController();
    final adminPasswordCtrl = TextEditingController();
    String category = 'any';

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Create Academy'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Academy Name')),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'chess', child: Text('Chess')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                    DropdownMenuItem(value: 'any', child: Text('Any')),
                  ],
                  onChanged: (val) {
                    if (val != null) setStateDialog(() => category = val);
                  },
                ),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                const Divider(),
                const Text('Admin Account', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: adminNameCtrl, decoration: const InputDecoration(labelText: 'Admin Name')),
                TextField(controller: adminEmailCtrl, decoration: const InputDecoration(labelText: 'Admin Email')),
                TextField(controller: adminPasswordCtrl, decoration: const InputDecoration(labelText: 'Admin Password')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await context.read<ApiClient>().createAcademy({
                    'name': nameCtrl.text,
                    'category': category,
                    'address': addressCtrl.text,
                    'phone': phoneCtrl.text,
                    'email': emailCtrl.text,
                    'admin_name': adminNameCtrl.text,
                    'admin_email': adminEmailCtrl.text,
                    'admin_password': adminPasswordCtrl.text,
                  });
                  if (mounted) {
                    Navigator.pop(c);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Academy Created Successfully!')));
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(dynamic academy) {
    final nameCtrl = TextEditingController(text: academy['name']);
    final addressCtrl = TextEditingController(text: academy['address']);
    final phoneCtrl = TextEditingController(text: academy['phone']);
    final emailCtrl = TextEditingController(text: academy['email']);
    final taglineCtrl = TextEditingController(text: academy['tagline'] ?? '');
    String category = academy['category'] ?? 'any';
    
    // Ensure category matches one of the values to avoid dropdown error
    if (!['chess', 'other', 'any'].contains(category)) {
      category = 'any';
    }

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Edit Academy'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Academy Name')),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'chess', child: Text('Chess')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                    DropdownMenuItem(value: 'any', child: Text('Any')),
                  ],
                  onChanged: (val) {
                    if (val != null) setStateDialog(() => category = val);
                  },
                ),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                TextField(controller: taglineCtrl, decoration: const InputDecoration(labelText: 'Tagline')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await context.read<ApiClient>().updateAcademy(academy['id'], {
                    'name': nameCtrl.text.trim(),
                    'category': category,
                    'address': addressCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'tagline': taglineCtrl.text.trim(),
                  });
                  if (mounted) {
                    Navigator.pop(c);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Academy Updated!')));
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      body: ListView.builder(
        itemCount: _academies.length,
        itemBuilder: (context, index) {
          final ac = _academies[index];
          final isActive = ac['status'] == 'active';
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.school)),
            title: Text(ac['name']),
            subtitle: Text('Status: ${ac['status']} | Students: ${ac['student_count']}'),
            trailing: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') _showEditDialog(ac);
                if (val == 'toggle') _toggleStatus(ac);
                if (val == 'delete') _delete(ac['id']);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(isActive ? 'Block (Suspend)' : 'Unblock (Activate)'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
