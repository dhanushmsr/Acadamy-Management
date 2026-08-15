import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/api_client.dart';
import '../../../shared/widgets/chess_loading.dart';
import 'student_profile_screen.dart';

/// Opened by tapping a day on the calendar. Lists every batch's active
/// students with a Present/Absent toggle, plus a "mark as holiday"
/// action in the app bar for days with no classes.
class DayAttendanceScreen extends StatefulWidget {
  final String date; // "YYYY-MM-DD"
  const DayAttendanceScreen({super.key, required this.date});

  @override
  State<DayAttendanceScreen> createState() => _DayAttendanceScreenState();
}

class _DayAttendanceScreenState extends State<DayAttendanceScreen> {
  late final ApiClient _api;
  DayAttendance? _data;
  bool _loading = true;
  String? _error;
  bool _markingHoliday = false;
  String? _selectedBatchId;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getDayAttendance(widget.date);
      setState(() {
        _data = data;
        _loading = false;
        if (_data!.batches.isNotEmpty && _selectedBatchId == null) {
          _selectedBatchId = _data!.batches.first.batchId;
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load attendance for this day';
        _loading = false;
      });
    }
  }

  Future<void> _setStatus(String batchId, String studentId, String status) async {
    // Optimistic UI update
    if (_data != null) {
      final batchIndex = _data!.batches.indexWhere((b) => b.batchId == batchId);
      if (batchIndex != -1) {
        final batch = _data!.batches[batchIndex];
        final studentIndex = batch.students.indexWhere((s) => s.studentId == studentId);
        if (studentIndex != -1) {
          setState(() {
            batch.students[studentIndex] = StudentMark(
              studentId: studentId,
              name: batch.students[studentIndex].name,
              status: status,
            );
          });
        }
      }
    }

    try {
      await _api.markAttendance(
        batchId: batchId,
        date: widget.date,
        studentId: studentId,
        status: status,
      );
      // Data is already updated locally, no need to show loading
    } catch (e) {
      _load(); // Revert on failure
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to mark: $e')));
      }
    }
  }

  Future<void> _markHoliday() async {
    setState(() => _markingHoliday = true);
    try {
      await _api.markHoliday(widget.date);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to mark holiday: $e')));
      }
    } finally {
      if (mounted) setState(() => _markingHoliday = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.date),
        actions: [
          if (_data != null && !_data!.isHoliday)
            IconButton(
              icon: _markingHoliday
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.beach_access_outlined),
              tooltip: 'Mark as holiday',
              onPressed: _markingHoliday ? null : _markHoliday,
            ),
        ],
      ),
      body: (_loading && _data == null)
          ? const ChessLoadingScreen(message: 'Loading attendance...')
          : _error != null
              ? Center(child: Text(_error!))
              : _data!.isHoliday
                  ? const Center(child: Text('Marked as a holiday - no attendance for this day'))
                  : _data!.batches.isEmpty
                      ? const Center(child: Text('No batches with students yet'))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: DropdownButtonFormField<String>(
                                value: _selectedBatchId,
                                decoration: const InputDecoration(labelText: 'Select Batch'),
                                items: _data!.batches.map((b) {
                                  return DropdownMenuItem(
                                    value: b.batchId,
                                    child: Text(b.batchName),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedBatchId = val);
                                },
                              ),
                            ),
                            Expanded(
                              child: _buildStudentList(),
                            ),
                          ],
                        ),
    );
  }

  Widget _buildStudentList() {
    final batch = _data!.batches.firstWhere((b) => b.batchId == _selectedBatchId, orElse: () => _data!.batches.first);
    final present = batch.students.where((s) => s.status == 'present').toList();
    final absent = batch.students.where((s) => s.status == 'absent').toList();
    final notMarked = batch.students.where((s) => s.status != 'present' && s.status != 'absent').toList();

    return ListView(
      children: [
        if (notMarked.isNotEmpty) ...[
          _buildSectionHeader('Not Marked (${notMarked.length})', Colors.grey),
          ...notMarked.map((s) => _buildStudentTile(batch.batchId, s)),
        ],
        if (present.isNotEmpty) ...[
          _buildSectionHeader('Present (${present.length})', Colors.green),
          ...present.map((s) => _buildStudentTile(batch.batchId, s)),
        ],
        if (absent.isNotEmpty) ...[
          _buildSectionHeader('Absent (${absent.length})', Colors.red),
          ...absent.map((s) => _buildStudentTile(batch.batchId, s)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withOpacity(0.1),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildStudentTile(String batchId, dynamic s) {
    return ListTile(
      title: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentProfileScreen(
              studentId: s.studentId,
              studentName: s.name,
            ),
          ),
        ),
        child: Text(
          s.name,
          style: const TextStyle(decoration: TextDecoration.underline),
        ),
      ),
      trailing: ToggleButtons(
        isSelected: [s.status == 'absent', s.status == 'present'],
        onPressed: (i) => _setStatus(
          batchId,
          s.studentId,
          i == 0 ? 'absent' : 'present',
        ),
        borderRadius: BorderRadius.circular(20),
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('Absent'),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('Present'),
          ),
        ],
      ),
    );
  }
}
