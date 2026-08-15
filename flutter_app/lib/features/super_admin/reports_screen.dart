import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/api_client.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  List<PlatformInvoiceSummary> _invoices = [];
  List<dynamic> _academies = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiClient>();
      final invs = await api.getPlatformInvoices();
      final acs = await api.getAcademies();
      setState(() {
        _invoices = invs;
        _academies = acs;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreateDialog() {
    String? selectedAcademyId;
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Create Platform Invoice'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Academy'),
                    value: selectedAcademyId,
                    items: _academies.map((ac) => DropdownMenuItem<String>(
                      value: ac['id'] as String,
                      child: Text(ac['name'] as String),
                    )).toList(),
                    onChanged: (val) => setStateDialog(() => selectedAcademyId = val),
                  ),
                  TextField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedAcademyId == null) return;
                    try {
                      await context.read<ApiClient>().createPlatformInvoice({
                        'academy_id': selectedAcademyId,
                        'amount': int.tryParse(amountCtrl.text) ?? 0,
                      });
                      if (mounted) {
                        Navigator.pop(c);
                        _loadData();
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _toggleStatus(PlatformInvoiceSummary invoice) async {
    final api = context.read<ApiClient>();
    final newStatus = invoice.status == 'cleared' ? 'uncleared' : 'cleared';
    try {
      await api.updatePlatformInvoiceStatus(invoice.id, newStatus);
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _sendNotification(PlatformInvoiceSummary invoice) async {
    final api = context.read<ApiClient>();
    try {
      await api.notifyPlatformInvoice(invoice.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification sent successfully!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      body: ListView.builder(
        itemCount: _invoices.length,
        itemBuilder: (context, index) {
          final inv = _invoices[index];
          final isCleared = inv.status == 'cleared';
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text('${inv.academyName ?? 'Unknown'} - ₹${inv.amount}'),
              subtitle: Text('Status: ${inv.status}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => _toggleStatus(inv),
                    child: Text(isCleared ? 'Mark Uncleared' : 'Mark Cleared'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    tooltip: 'Send Alert/Receipt',
                    onPressed: () => _sendNotification(inv),
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
        label: const Text('Create Bill'),
      ),
    );
  }
}
