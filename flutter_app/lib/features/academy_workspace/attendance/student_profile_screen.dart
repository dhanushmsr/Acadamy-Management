import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/api_client.dart';
import '../../../shared/widgets/chess_loading.dart';

/// Reached by tapping a student's name while marking attendance. Shows
/// this calendar month's present/absent counts - scoped to the current
/// year+month, so it automatically reads as a fresh count from the 1st
/// of every new month rather than accumulating forever.
class StudentProfileScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentProfileScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  late final ApiClient _api;
  StudentAttendanceSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    try {
      final summary = await _api.getStudentAttendance(widget.studentId, now.year, now.month);
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load attendance summary';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = _monthLabel(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: Text(widget.studentName)),
      body: _loading
          ? const ChessLoadingScreen()
          : _error != null
              ? Center(child: Text(_error!))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance — $monthLabel',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Resets automatically each month - this covers $monthLabel only.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _StatBox(
                            label: 'Present',
                            value: '${_summary!.daysPresent}',
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          _StatBox(
                            label: 'Absent',
                            value: '${_summary!.daysAbsent}',
                            color: Colors.red,
                          ),
                          const SizedBox(width: 12),
                          _StatBox(
                            label: 'Marked',
                            value: '${_summary!.totalMarked}',
                            color: const Color(0xFF1E2142),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  String _monthLabel(DateTime m) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[m.month - 1]} ${m.year}';
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}
