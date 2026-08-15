import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/api_client.dart';
import '../../../shared/widgets/chess_loading.dart';
import 'new_payment_screen.dart';

/// Fee monitoring, not a payment processor - there's no gateway
/// anywhere in this screen. The manager records what a fee is and sets
/// its status (unpaid/partial/paid) based on what actually happened
/// outside the app (cash, bank transfer, etc). Marking something fully
/// "paid" is what triggers the receipt email.
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
        _error = 'Could not load fees';
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
            content: Text('Marked paid — receipt emailed if the parent has an email on file'),
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
        title: Text('Amount paid so far (of Rs. ${p.amount})'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(prefixText: 'Rs. '),
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
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send email: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fees')),
      body: _loading
          ? const ChessLoadingScreen(message: 'Loading fees...')
          : _error != null
              ? Center(child: Text(_error!))
              : _payments.isEmpty
                  ? const Center(child: Text('No fees recorded yet — tap + to add one'))
                  : ListView.builder(
                      itemCount: _payments.length,
                      itemBuilder: (context, index) {
                        final p = _payments[index];
                        return ListTile(
                          title: Text(p.studentName ?? 'Unknown student'),
                          subtitle: Text(
                            p.status == 'partial'
                                ? 'Rs. ${p.amountPaid} of Rs. ${p.amount} paid · ${p.planType}'
                                : 'Rs. ${p.amount} · ${p.planType}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.email_outlined, color: Color(0xFF1E2142)),
                                tooltip: 'Send Invoice Email',
                                onPressed: () => _sendInvoiceEmail(p),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: _statusColor(p.status).withOpacity(0.4)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: DropdownButton<String>(
                                  value: p.status,
                                  underline: const SizedBox.shrink(),
                                  style: TextStyle(color: _statusColor(p.status), fontSize: 13),
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
