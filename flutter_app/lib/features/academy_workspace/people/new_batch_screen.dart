import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/api_client.dart';
import '../../../shared/widgets/app_button.dart';

class NewBatchScreen extends StatefulWidget {
  final BatchSummary? batchToEdit;

  const NewBatchScreen({super.key, this.batchToEdit});

  @override
  State<NewBatchScreen> createState() => _NewBatchScreenState();
}

class _NewBatchScreenState extends State<NewBatchScreen> {
  late final ApiClient _api;
  final _nameController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();

    if (widget.batchToEdit != null) {
      _nameController.text = widget.batchToEdit!.name;
      _startTimeController.text = widget.batchToEdit!.startTime ?? '';
      _endTimeController.text = widget.batchToEdit!.endTime ?? '';
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.batchToEdit == null) {
        await _api.createBatch(
          name: _nameController.text.trim(),
          startTime: _startTimeController.text.trim().isEmpty ? null : _startTimeController.text.trim(),
          endTime: _endTimeController.text.trim().isEmpty ? null : _endTimeController.text.trim(),
        );
      } else {
        await _api.updateBatch(widget.batchToEdit!.id, {
          'name': _nameController.text.trim(),
          'start_time': _startTimeController.text.trim().isEmpty ? null : _startTimeController.text.trim(),
          'end_time': _endTimeController.text.trim().isEmpty ? null : _endTimeController.text.trim(),
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.batchToEdit != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Batch' : 'New Batch')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Batch Name',
              hintText: 'e.g. King Chess Junior Batch',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startTimeController,
                  decoration: const InputDecoration(labelText: 'Start Time', hintText: '18:30'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endTimeController,
                  decoration: const InputDecoration(labelText: 'End Time', hintText: '20:30'),
                ),
              ),
            ],
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
