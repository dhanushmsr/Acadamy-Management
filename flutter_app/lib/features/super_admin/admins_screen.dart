import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/api_client.dart';

class AdminsScreen extends StatefulWidget {
  const AdminsScreen({super.key});

  @override
  State<AdminsScreen> createState() => _AdminsScreenState();
}

class _AdminsScreenState extends State<AdminsScreen> {
  List<UserSummary>? _users;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<ApiClient>().getUsers();
      setState(() {
        _users = data;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _users = null;
      });
    }
  }

  void _showEditDialog(UserSummary user) {
    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Admin'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'New Password (leave blank to keep current)'),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final payload = <String, dynamic>{
                'name': nameCtrl.text.trim(),
                'email': emailCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
              };
              if (passCtrl.text.isNotEmpty) {
                payload['password'] = passCtrl.text;
              }
              try {
                await context.read<ApiClient>().updateUser(user.id, payload);
                if (mounted) Navigator.pop(ctx);
                _load();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_users == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final superAdmins = _users!.where((u) => u.role == 'super_admin').toList();

    if (superAdmins.isEmpty) {
      return const Center(child: Text('No Super Admin accounts found.'));
    }

    return ListView.builder(
      itemCount: superAdmins.length,
      itemBuilder: (context, index) {
        final user = superAdmins[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(child: Text(user.name.substring(0, 1).toUpperCase())),
            title: Text(user.name),
            subtitle: Text('${user.email} • ${user.role}\nStatus: ${user.isActive ? "Active" : "Blocked"}'),
            trailing: PopupMenuButton<String>(
              onSelected: (val) async {
                final api = context.read<ApiClient>();
                try {
                  if (val == 'edit') {
                    _showEditDialog(user);
                  } else if (val == 'toggle_status') {
                    if (user.isActive) {
                      await api.disableUser(user.id);
                    } else {
                      await api.enableUser(user.id);
                    }
                    _load();
                  } else if (val == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Admin?'),
                        content: const Text('This will soft-delete the user.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await api.deleteUser(user.id);
                      _load();
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'toggle_status',
                  child: Text(user.isActive ? 'Block Access' : 'Unblock Access'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
