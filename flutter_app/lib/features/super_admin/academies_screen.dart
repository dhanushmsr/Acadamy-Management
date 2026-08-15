import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
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
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
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

  void _showResetPasswordDialog(dynamic academy) {
    final passCtrl = TextEditingController();
    bool obfuscate = true;
    bool saving = false;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_reset_rounded, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reset Password: ${academy['name']}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter a new password for the academy admin account:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: obfuscate,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(obfuscate ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setStateDialog(() => obfuscate = !obfuscate),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(saving ? 'Resetting...' : 'Reset Password'),
              onPressed: saving
                  ? null
                  : () async {
                      final newPass = passCtrl.text.trim();
                      if (newPass.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password must be at least 6 characters')),
                        );
                        return;
                      }
                      setStateDialog(() => saving = true);
                      try {
                        await context.read<ApiClient>().resetAcademyPassword(academy['id'], newPass);
                        if (mounted) {
                          Navigator.pop(c);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Password successfully updated for ${academy['name']}!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (mounted) setStateDialog(() => saving = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final taglineCtrl = TextEditingController();
    final adminNameCtrl = TextEditingController();
    final adminEmailCtrl = TextEditingController();
    final adminPasswordCtrl = TextEditingController();
    String category = 'any';

    Uint8List? selectedLogoBytes;
    String? selectedLogoName;
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school, color: Color(0xFF1E293B), size: 28),
                      const SizedBox(width: 10),
                      const Text(
                        'Create Academy Profile',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  
                  // Logo Selection Section
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300, width: 2),
                            image: selectedLogoBytes != null
                                ? DecorationImage(image: MemoryImage(selectedLogoBytes!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: selectedLogoBytes == null
                              ? const Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: Text(selectedLogoName ?? 'Upload Academy Logo'),
                          onPressed: () async {
                            final res = await FilePicker.platform.pickFiles(type: FileType.image);
                            if (res != null && res.files.single.bytes != null) {
                              setStateDialog(() {
                                selectedLogoBytes = res.files.single.bytes;
                                selectedLogoName = res.files.single.name;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Academy Information Header
                  const Text('Academy Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo)),
                  const SizedBox(height: 8),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Academy Name *', prefixIcon: Icon(Icons.business))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category)),
                    items: const [
                      DropdownMenuItem(value: 'chess', child: Text('Chess')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                      DropdownMenuItem(value: 'any', child: Text('Any')),
                    ],
                    onChanged: (val) {
                      if (val != null) setStateDialog(() => category = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on))),
                  const SizedBox(height: 12),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone))),
                  const SizedBox(height: 12),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Academy Email', prefixIcon: Icon(Icons.email))),
                  const SizedBox(height: 12),
                  TextField(controller: taglineCtrl, decoration: const InputDecoration(labelText: 'Tagline', prefixIcon: Icon(Icons.description))),
                  
                  const SizedBox(height: 24),
                  const Text('Admin Account Credentials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo)),
                  const SizedBox(height: 8),
                  TextField(controller: adminNameCtrl, decoration: const InputDecoration(labelText: 'Admin Name *', prefixIcon: Icon(Icons.person))),
                  const SizedBox(height: 12),
                  TextField(controller: adminEmailCtrl, decoration: const InputDecoration(labelText: 'Admin Login Email *', prefixIcon: Icon(Icons.mark_email_read))),
                  const SizedBox(height: 12),
                  TextField(controller: adminPasswordCtrl, decoration: const InputDecoration(labelText: 'Admin Password *', prefixIcon: Icon(Icons.lock))),
                  
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isCreating ? null : () => Navigator.pop(c),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isCreating
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final adminName = adminNameCtrl.text.trim();
                                final adminEmail = adminEmailCtrl.text.trim();
                                final adminPassword = adminPasswordCtrl.text.trim();

                                if (name.isEmpty || adminName.isEmpty || adminEmail.isEmpty || adminPassword.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please fill in all required fields (*)')),
                                  );
                                  return;
                                }

                                setStateDialog(() => isCreating = true);
                                try {
                                  final api = context.read<ApiClient>();
                                  final created = await api.createAcademy({
                                    'name': name,
                                    'category': category,
                                    'address': addressCtrl.text.trim(),
                                    'phone': phoneCtrl.text.trim(),
                                    'email': emailCtrl.text.trim(),
                                    'tagline': taglineCtrl.text.trim(),
                                    'admin_name': adminName,
                                    'admin_email': adminEmail,
                                    'admin_password': adminPassword,
                                  });

                                  // Upload logo if selected
                                  if (selectedLogoBytes != null && created['id'] != null) {
                                    await api.uploadLogo(
                                      created['id'],
                                      selectedLogoBytes!,
                                      selectedLogoName ?? 'logo.png',
                                    );
                                  }

                                  if (mounted) {
                                    Navigator.pop(c);
                                    _loadData();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Academy Created Successfully with Logo!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                                    );
                                  }
                                } finally {
                                  if (mounted) setStateDialog(() => isCreating = false);
                                }
                              },
                        child: isCreating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Create Academy'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
    
    if (!['chess', 'other', 'any'].contains(category)) {
      category = 'any';
    }

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Academy Profile'),
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
        padding: const EdgeInsets.all(12),
        itemCount: _academies.length,
        itemBuilder: (context, index) {
          final ac = _academies[index];
          final isActive = ac['status'] == 'active';
          final logoUrl = ac['logo_url'];
          final baseUrl = ApiClient.baseUrl;

          String? fullLogoUrl;
          if (logoUrl != null && logoUrl.isNotEmpty) {
            fullLogoUrl = logoUrl.startsWith('http') ? logoUrl : '$baseUrl$logoUrl';
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.indigo.shade50,
                    backgroundImage: fullLogoUrl != null ? NetworkImage(fullLogoUrl) : null,
                    child: fullLogoUrl == null
                        ? const Icon(Icons.school_rounded, color: Colors.indigo, size: 28)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ac['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isActive ? Colors.green : Colors.red),
                              ),
                              child: Text(
                                isActive ? 'Active' : 'Suspended',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Students: ${ac['student_count'] ?? 0}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Reset Password',
                        icon: const Icon(Icons.key, color: Colors.deepOrange),
                        onPressed: () => _showResetPasswordDialog(ac),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (val) {
                          if (val == 'edit') _showEditDialog(ac);
                          if (val == 'reset') _showResetPasswordDialog(ac);
                          if (val == 'toggle') _toggleStatus(ac);
                          if (val == 'delete') _delete(ac['id']);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 8),
                                Text('Edit Profile'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'reset',
                            child: Row(
                              children: [
                                Icon(Icons.key, size: 18, color: Colors.deepOrange),
                                SizedBox(width: 8),
                                Text('Reset Password'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(isActive ? Icons.block : Icons.check_circle, size: 18),
                                const SizedBox(width: 8),
                                Text(isActive ? 'Block (Suspend)' : 'Unblock (Activate)'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Academy'),
      ),
    );
  }
}

