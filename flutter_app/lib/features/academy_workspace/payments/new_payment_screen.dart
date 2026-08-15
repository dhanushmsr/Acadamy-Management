import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/api_client.dart';
import '../../../shared/widgets/app_button.dart';

class NewPaymentScreen extends StatefulWidget {
  final List<StudentSummary> students;
  const NewPaymentScreen({super.key, required this.students});

  @override
  State<NewPaymentScreen> createState() => _NewPaymentScreenState();
}

class _NewPaymentScreenState extends State<NewPaymentScreen> {
  late final ApiClient _api;
  final _amountController = TextEditingController(text: '500');
  String? _studentId;
  String _planType = 'monthly';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (_studentId == null || amount == null) {
      setState(() => _error = 'Pick a student and enter a valid amount');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.createPayment(studentId: _studentId!, planType: _planType, amount: amount);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Fee')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _studentId,
            decoration: const InputDecoration(labelText: 'Student'),
            items: widget.students
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: (v) => setState(() => _studentId = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _planType,
            decoration: const InputDecoration(labelText: 'Plan'),
            items: const [
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
              DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
            ],
            onChanged: (v) => setState(() => _planType = v ?? 'monthly'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount', prefixText: 'Rs. '),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: _saving ? 'Saving...' : 'Save',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
