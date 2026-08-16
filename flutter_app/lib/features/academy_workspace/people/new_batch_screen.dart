import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/api_client.dart';
import '../../../shared/utils/time_utils.dart';
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
      _startTimeController.text = format12HourAMPM(widget.batchToEdit!.startTime);
      _endTimeController.text = format12HourAMPM(widget.batchToEdit!.endTime);
    }
  }

  Future<void> _selectTime(TextEditingController ctrl, {required int defaultHour}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: defaultHour, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        ctrl.text = formatTimeOfDay12Hour(picked);
      });
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final startStr = _startTimeController.text.trim().isEmpty ? null : _startTimeController.text.trim();
      final endStr = _endTimeController.text.trim().isEmpty ? null : _endTimeController.text.trim();

      if (widget.batchToEdit == null) {
        await _api.createBatch(
          name: _nameController.text.trim(),
          startTime: startStr,
          endTime: endStr,
        );
      } else {
        await _api.updateBatch(widget.batchToEdit!.id, {
          'name': _nameController.text.trim(),
          'start_time': startStr,
          'end_time': endStr,
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
              labelText: 'Batch Name *',
              hintText: 'e.g. King Chess Junior Batch',
              prefixIcon: Icon(Icons.groups_rounded),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Batch Timings (12-Hour AM/PM)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startTimeController,
                  readOnly: true,
                  onTap: () => _selectTime(_startTimeController, defaultHour: 18),
                  decoration: const InputDecoration(
                    labelText: 'Start Time',
                    hintText: 'e.g. 6:00 PM',
                    prefixIcon: Icon(Icons.access_time_rounded, color: Colors.indigo),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endTimeController,
                  readOnly: true,
                  onTap: () => _selectTime(_endTimeController, defaultHour: 20),
                  decoration: const InputDecoration(
                    labelText: 'End Time',
                    hintText: 'e.g. 8:00 PM',
                    prefixIcon: Icon(Icons.access_time_filled_rounded, color: Colors.indigo),
                  ),
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
            label: _saving ? 'Saving...' : 'Save Batch',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
