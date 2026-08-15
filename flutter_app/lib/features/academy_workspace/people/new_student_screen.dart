import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/api_client.dart';
import '../../../shared/widgets/app_button.dart';

class NewStudentScreen extends StatefulWidget {
  final List<BatchSummary> batches;
  final StudentSummary? studentToEdit; // If provided, we are in Edit Mode

  const NewStudentScreen({super.key, required this.batches, this.studentToEdit});

  @override
  State<NewStudentScreen> createState() => _NewStudentScreenState();
}

class _NewStudentScreenState extends State<NewStudentScreen> {
  late final ApiClient _api;
  final _nameController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _parentEmailController = TextEditingController();
  final _parentAddressController = TextEditingController();
  final _defaultFeeController = TextEditingController();
  String? _selectedBatchId;
  String? _selectedLevel;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    
    if (widget.studentToEdit != null) {
      final s = widget.studentToEdit!;
      _nameController.text = s.name;
      _parentNameController.text = s.parentName ?? '';
      _parentPhoneController.text = s.parentPhone ?? '';
      _parentEmailController.text = s.parentEmail ?? '';
      _parentAddressController.text = s.parentAddress ?? '';
      if (s.defaultFee != null) {
        _defaultFeeController.text = s.defaultFee.toString();
      }
      _selectedBatchId = s.batchId;
      _selectedLevel = s.level;
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final defaultFee = int.tryParse(_defaultFeeController.text.trim());

      if (widget.studentToEdit == null) {
        // Create
        await _api.createStudent(
          name: _nameController.text.trim(),
          batchId: _selectedBatchId,
          level: _selectedLevel,
          defaultFee: defaultFee,
          parentName: _parentNameController.text.trim().isEmpty ? null : _parentNameController.text.trim(),
          parentPhone: _parentPhoneController.text.trim().isEmpty ? null : _parentPhoneController.text.trim(),
          parentEmail: _parentEmailController.text.trim().isEmpty ? null : _parentEmailController.text.trim(),
          parentAddress: _parentAddressController.text.trim().isEmpty ? null : _parentAddressController.text.trim(),
        );
      } else {
        // Edit
        await _api.updateStudent(widget.studentToEdit!.id, {
          'name': _nameController.text.trim(),
          'batch_id': _selectedBatchId,
          'level': _selectedLevel,
          'default_fee': defaultFee,
          'parent_name': _parentNameController.text.trim().isEmpty ? null : _parentNameController.text.trim(),
          'parent_phone': _parentPhoneController.text.trim().isEmpty ? null : _parentPhoneController.text.trim(),
          'parent_email': _parentEmailController.text.trim().isEmpty ? null : _parentEmailController.text.trim(),
          'parent_address': _parentAddressController.text.trim().isEmpty ? null : _parentAddressController.text.trim(),
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
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    _parentEmailController.dispose();
    _parentAddressController.dispose();
    _defaultFeeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.studentToEdit != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Student' : 'New Student')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Student Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Student Name *', prefixIcon: Icon(Icons.person)),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedBatchId,
            decoration: const InputDecoration(labelText: 'Batch', prefixIcon: Icon(Icons.class_)),
            items: widget.batches
                .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                .toList(),
            onChanged: (v) => setState(() => _selectedBatchId = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedLevel,
            decoration: const InputDecoration(labelText: 'Level (Optional)', prefixIcon: Icon(Icons.star)),
            items: ['Beginner', 'Intermediate', 'Advanced']
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) => setState(() => _selectedLevel = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _defaultFeeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Default Monthly Fee (₹)',
              prefixIcon: Icon(Icons.currency_rupee),
              helperText: 'Will be used as default when adding fees',
            ),
          ),
          const SizedBox(height: 24),
          const Text('Parent & Address Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _parentNameController,
            decoration: const InputDecoration(labelText: 'Parent Name', prefixIcon: Icon(Icons.family_restroom)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _parentPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Parent Phone (+91...)', prefixIcon: Icon(Icons.phone)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _parentEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Parent Email',
              prefixIcon: Icon(Icons.email),
              helperText: 'Used to send payment receipts',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _parentAddressController,
            decoration: const InputDecoration(
              labelText: 'Place / Address',
              prefixIcon: Icon(Icons.location_on),
              helperText: 'City, area or full address',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: _saving ? 'Saving...' : (isEdit ? 'Update Student' : 'Save Student'),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
