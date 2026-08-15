import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/api_client.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/chess_loading.dart';

/// Lets a trainer type a custom message and send it over WhatsApp to
/// one, several, or all of the academy's students (via each student's
/// parent phone number). Talks to POST /messages/broadcast.
class SendMessageScreen extends StatefulWidget {
  const SendMessageScreen({super.key});

  @override
  State<SendMessageScreen> createState() => _SendMessageScreenState();
}

class _SendMessageScreenState extends State<SendMessageScreen> {
  late final ApiClient _api;
  final _bodyController = TextEditingController();

  List<StudentSummary> _students = [];
  final Set<String> _selectedIds = {};
  bool _selectAll = false;
  bool _loadingStudents = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _bodyController.addListener(() => setState(() {}));
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final students = await _api.getStudents();
      setState(() {
        _students = students;
        _loadingStudents = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load students';
        _loadingStudents = false;
      });
    }
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      _selectedIds.clear();
      if (_selectAll) {
        _selectedIds.addAll(
          _students.where((s) => (s.parentPhone ?? '').isNotEmpty).map((s) => s.id),
        );
      }
    });
  }

  void _toggleStudent(String id, bool? value) {
    setState(() {
      if (value ?? false) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
      final selectable = _students.where((s) => (s.parentPhone ?? '').isNotEmpty).length;
      _selectAll = selectable > 0 && _selectedIds.length == selectable;
    });
  }

  Future<void> _send() async {
    if (_bodyController.text.trim().isEmpty || _selectedIds.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _api.sendBroadcast(
        body: _bodyController.text.trim(),
        studentIds: _selectAll ? null : _selectedIds.toList(),
        sendToAll: _selectAll,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message queued for sending')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = 'Failed to send: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  void _sendViaDirectWhatsApp() {
    final text = _bodyController.text.trim();
    if (text.isEmpty || _selectedIds.isEmpty) return;

    final selectedStudents = _students.where((s) => _selectedIds.contains(s.id)).toList();
    for (final s in selectedStudents) {
      if ((s.parentPhone ?? '').isNotEmpty) {
        final cleanPhone = s.parentPhone!.replaceAll(RegExp(r'[^0-9+]'), '');
        final formattedPhone = cleanPhone.startsWith('+') ? cleanPhone.substring(1) : cleanPhone;
        final url = 'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(text)}';
        html.window.open(url, '_blank');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = !_sending && _selectedIds.isNotEmpty && _bodyController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Send WhatsApp Message')),
      body: _loadingStudents
          ? const ChessLoadingScreen(message: 'Loading students...')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _bodyController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Type your message to parents...',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                CheckboxListTile(
                  title: Text('Select all (${_students.length} students)'),
                  value: _selectAll,
                  onChanged: _students.isEmpty ? null : _toggleSelectAll,
                ),
                const Divider(height: 1),
                Expanded(
                  child: _students.isEmpty
                      ? const Center(child: Text('No students found'))
                      : ListView.builder(
                          itemCount: _students.length,
                          itemBuilder: (context, index) {
                            final s = _students[index];
                            final hasPhone = (s.parentPhone ?? '').isNotEmpty;
                            return CheckboxListTile(
                              title: Text(s.name),
                              subtitle: Text(hasPhone ? s.parentPhone! : 'No parent phone on file'),
                              value: _selectedIds.contains(s.id),
                              onChanged: hasPhone ? (v) => _toggleStudent(s.id, v) : null,
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.send_rounded),
                        label: Text('Open in WhatsApp Web/App (100% Free - Unlimited)'),
                        onPressed: canSend ? _sendViaDirectWhatsApp : null,
                      ),
                      const SizedBox(height: 8),
                      AppButton(
                        label: _sending
                            ? 'Sending Cloud API...'
                            : 'Send via Meta Cloud API (${_selectedIds.length})',
                        onPressed: canSend ? _send : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
