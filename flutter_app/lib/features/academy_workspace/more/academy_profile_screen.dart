import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/api_client.dart';
import '../../../core/auth/auth_state.dart';
import '../../../shared/widgets/chess_loading.dart';

class AcademyProfileScreen extends StatefulWidget {
  const AcademyProfileScreen({super.key});

  @override
  State<AcademyProfileScreen> createState() => _AcademyProfileScreenState();
}

class _AcademyProfileScreenState extends State<AcademyProfileScreen> {
  late final ApiClient _api;
  DashboardStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final stats = await _api.getDashboardStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load profile: $e';
          _loading = false;
        });
      }
    }
  }

  void _showResetPasswordDialog() {
    final passCtrl = TextEditingController();
    bool obfuscate = true;
    bool saving = false;
    final academyId = context.read<AuthState>().academyId;

    if (academyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Academy ID not found. Please log in again.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Colors.deepOrange),
              SizedBox(width: 8),
              Text('Reset Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter a new password for your Academy Admin account:',
                style: TextStyle(fontSize: 13, color: Colors.black87),
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
              label: Text(saving ? 'Updating...' : 'Reset Password'),
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
                        await _api.resetAcademyPassword(academyId, newPass);
                        if (mounted) {
                          Navigator.pop(c);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Academy Admin password reset successfully!'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academy Profile & Security'),
      ),
      body: _loading
          ? const ChessLoadingScreen()
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: Colors.indigo.shade50,
                              backgroundImage: (_stats?.academyLogoUrl != null && _stats!.academyLogoUrl!.isNotEmpty)
                                  ? NetworkImage(
                                      _stats!.academyLogoUrl!.startsWith('http')
                                          ? _stats!.academyLogoUrl!
                                          : '${ApiClient.baseUrl}${_stats!.academyLogoUrl!}',
                                    )
                                  : null,
                              child: (_stats?.academyLogoUrl == null || _stats!.academyLogoUrl!.isEmpty)
                                  ? const Icon(Icons.school, size: 36, color: Colors.indigo)
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _stats?.academyName ?? 'Academy Workspace',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _stats?.academyEmail ?? '',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.indigo),
                                SizedBox(width: 8),
                                Text('Academy Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(height: 20),
                            _detailRow(Icons.phone, 'Phone', _stats?.academyPhone ?? 'Not set'),
                            const SizedBox(height: 10),
                            _detailRow(Icons.email, 'Email', _stats?.academyEmail ?? 'Not set'),
                            const SizedBox(height: 10),
                            _detailRow(Icons.location_on, 'Address', _stats?.academyAddress ?? 'Not set'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.security, color: Colors.deepOrange),
                                SizedBox(width: 8),
                                Text('Account Security & Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(height: 20),
                            const Text(
                              'Reset your Academy Admin login password here. Changes will take effect immediately for future logins.',
                              style: TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepOrange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.lock_reset),
                                label: const Text('Reset Academy Password', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _showResetPasswordDialog,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not set' : value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
