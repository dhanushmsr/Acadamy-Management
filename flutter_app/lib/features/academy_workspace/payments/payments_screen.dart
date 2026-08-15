import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/api_client.dart';
import '../../../shared/widgets/chess_loading.dart';
import 'new_payment_screen.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late final ApiClient _api;
  List<PaymentSummary> _payments = [];
  List<StudentSummary> _students = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final payments = await _api.getPayments();
      final students = await _api.getStudents();
      setState(() {
        _payments = payments;
        _students = students;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load fees: $e';
        _loading = false;
      });
    }
  }

  Future<void> _changeStatus(PaymentSummary p, String status) async {
    if (status == 'partial') {
      final amount = await _askAmount(p);
      if (amount == null) return;
      await _applyStatus(p, status, amountPaid: amount);
      return;
    }
    await _applyStatus(p, status);
  }

  Future<void> _applyStatus(PaymentSummary p, String status, {int? amountPaid}) async {
    try {
      await _api.updatePaymentStatus(p.id, status, amountPaid: amountPaid);
      await _load();
      if (status == 'paid' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked paid — receipt emailed if parent email exists!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<int?> _askAmount(PaymentSummary p) async {
    final controller = TextEditingController(
      text: p.amountPaid > 0 ? '${p.amountPaid}' : '',
    );
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Amount paid so far (of ₹${p.amount})'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(prefixText: '₹ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  Future<void> _sendInvoiceEmail(PaymentSummary p) async {
    try {
      await _api.sendPaymentEmail(p.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice email sent directly for ${p.studentName ?? "student"}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // If email is missing, offer a dialog to type email
        _promptEmailAndSend(p);
      }
    }
  }

  void _promptEmailAndSend(PaymentSummary p) {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.email, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Send Fee Receipt / Invoice', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter recipient email address for ${p.studentName ?? "student"}:'),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Parent / Student Email',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Send Email'),
            onPressed: () async {
              final targetEmail = emailCtrl.text.trim();
              if (targetEmail.isEmpty || !targetEmail.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid email address')),
                );
                return;
              }
              Navigator.pop(c);
              try {
                await _api.sendPaymentEmail(p.id, targetEmail: targetEmail);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Receipt emailed successfully to $targetEmail!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (err) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to send email: $err'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _sendWhatsAppReminder(PaymentSummary p) async {
    StudentSummary? sMatch;
    for (final s in _students) {
      if (s.id == p.studentId || (p.studentName != null && s.name.toLowerCase() == p.studentName!.toLowerCase())) {
        sMatch = s;
        break;
      }
    }

    final phone = sMatch?.parentPhone ?? '';
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final msg = Uri.encodeComponent(
      'Hello, reminder from Academy regarding fee payment of ₹${p.amount} for ${p.studentName ?? "student"}. Status: ${p.status.toUpperCase()}. Thank you!',
    );

    final String waUrl = cleanPhone.isNotEmpty
        ? 'https://wa.me/$cleanPhone?text=$msg'
        : 'https://wa.me/?text=$msg';

    final Uri uri = Uri.parse(waUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp app')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fees & Payments')),
      body: _loading
          ? const ChessLoadingScreen(message: 'Loading fees...')
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _payments.isEmpty
                  ? const Center(child: Text('No fees recorded yet — tap + to add one'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: _payments.length,
                      itemBuilder: (context, index) {
                        final p = _payments[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(
                              p.studentName ?? 'Unknown student',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              p.status == 'partial'
                                  ? '₹${p.amountPaid} of ₹${p.amount} paid • ${p.planType}'
                                  : '₹${p.amount} • ${p.planType}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.message_outlined, color: Colors.green),
                                  tooltip: 'Send WhatsApp Reminder',
                                  onPressed: () => _sendWhatsAppReminder(p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.email_outlined, color: Colors.indigo),
                                  tooltip: 'Send Email Receipt',
                                  onPressed: () => _sendInvoiceEmail(p),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: _statusColor(p.status).withValues(alpha: 0.5)),
                                    borderRadius: BorderRadius.circular(20),
                                    color: _statusColor(p.status).withValues(alpha: 0.1),
                                  ),
                                  child: DropdownButton<String>(
                                    value: p.status,
                                    underline: const SizedBox.shrink(),
                                    style: TextStyle(color: _statusColor(p.status), fontWeight: FontWeight.bold, fontSize: 13),
                                    items: const [
                                      DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                                      DropdownMenuItem(value: 'partial', child: Text('Partial')),
                                      DropdownMenuItem(value: 'paid', child: Text('Paid')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) _changeStatus(p, v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Fee'),
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => NewPaymentScreen(students: _students)),
          );
          if (added == true) _load();
        },
      ),
    );
  }
}
