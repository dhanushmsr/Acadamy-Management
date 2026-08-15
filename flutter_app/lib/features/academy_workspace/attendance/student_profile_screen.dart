import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/api_client.dart';
import '../../../shared/widgets/chess_loading.dart';

class StudentProfileScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final StudentSummary? studentDetails;

  const StudentProfileScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.studentDetails,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  late final ApiClient _api;
  StudentAttendanceSummary? _attendanceSummary;
  List<PaymentSummary> _studentPayments = [];
  StudentSummary? _student;
  
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _student = widget.studentDetails;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // 1. Load full student list to extract details if not provided
      if (_student == null) {
        final allStudents = await _api.getStudents();
        _student = allStudents.firstWhere(
          (s) => s.id == widget.studentId,
          orElse: () => StudentSummary(id: widget.studentId, name: widget.studentName),
        );
      }

      // 2. Load attendance for selected month
      final att = await _api.getStudentAttendance(
        widget.studentId,
        _selectedDate.year,
        _selectedDate.month,
      );

      // 3. Load payments for student
      final allPayments = await _api.getPayments();
      final studentPayments = allPayments.where((p) => p.studentId == widget.studentId).toList();

      if (mounted) {
        setState(() {
          _attendanceSummary = att;
          _studentPayments = studentPayments;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load student profile: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteStudent() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Delete Student Record?'),
          ],
        ),
        content: Text(
          'Choose how you want to remove ${widget.studentName}:\n\n'
          '• Soft Delete: Deactivates student. Preserves fee & attendance history.\n'
          '• Permanent Delete: Completely purges student and all attendance/payment logs.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, null),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
            onPressed: () => Navigator.pop(c, 'soft'),
            child: const Text('Soft Delete'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, 'hard'),
            child: const Text('Permanent Delete'),
          ),
        ],
      ),
    );

    if (choice != null && mounted) {
      try {
        if (choice == 'soft') {
          await _api.deleteStudent(widget.studentId);
        } else if (choice == 'hard') {
          await _api.hardDeleteStudent(widget.studentId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Student ${widget.studentName} deleted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentName),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Student',
            onPressed: _deleteStudent,
          ),
        ],
      ),
      body: _loading
          ? const ChessLoadingScreen()
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 16),
                      _buildParentCard(),
                      const SizedBox(height: 16),
                      _buildAttendanceSection(),
                      const SizedBox(height: 16),
                      _buildFeesSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    final batchText = _student?.batchName ?? 'No Batch Assigned';
    final level = _student?.level ?? 'Standard';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFF1E293B),
              child: Text(
                widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : 'S',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.studentName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.class_outlined, size: 16, color: Colors.indigo),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          batchText,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Text(
                      'Level: $level',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParentCard() {
    final parentName = _student?.parentName ?? 'Not specified';
    final parentPhone = _student?.parentPhone ?? 'Not specified';
    final parentEmail = _student?.parentEmail ?? 'Not specified';
    final parentAddress = _student?.parentAddress ?? 'Not specified';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.family_restroom, color: Colors.indigo),
                SizedBox(width: 8),
                Text('Parent & Location Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            _infoRow(Icons.person, 'Parent Name', parentName),
            const SizedBox(height: 8),
            _infoRow(Icons.phone, 'Parent Phone', parentPhone),
            const SizedBox(height: 8),
            _infoRow(Icons.email, 'Parent Email', parentEmail),
            const SizedBox(height: 8),
            _infoRow(Icons.location_on, 'Place / Address', parentAddress),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceSection() {
    final present = _attendanceSummary?.daysPresent ?? 0;
    final absent = _attendanceSummary?.daysAbsent ?? 0;
    final total = _attendanceSummary?.totalMarked ?? (present + absent);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calendar_month, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Attendance Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                DropdownButton<DateTime>(
                  value: DateTime(_selectedDate.year, _selectedDate.month),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down),
                  items: List.generate(12, (index) {
                    final d = DateTime.now();
                    final m = DateTime(d.year, d.month - index, 1);
                    return DropdownMenuItem(
                      value: m,
                      child: Text(_monthLabel(m), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedDate = val);
                      _load();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '* Unmarked class days automatically count as Absent for this month.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatBox(label: 'Present (P)', value: '$present', color: Colors.green),
                const SizedBox(width: 10),
                _StatBox(label: 'Absent (A)', value: '$absent', color: Colors.red),
                const SizedBox(width: 10),
                _StatBox(label: 'Total Sessions', value: '$total', color: const Color(0xFF1E293B)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeesSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.payments, color: Colors.indigo),
                SizedBox(width: 8),
                Text('Month-Wise Fee Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            _studentPayments.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text('No fee payment records found for this student.', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                : Column(
                    children: _studentPayments.map((p) {
                      final isPaid = p.status == 'paid';
                      final isPartial = p.status == 'partial';
                      final color = isPaid ? Colors.green : (isPartial ? Colors.orange : Colors.red);
                      final amountPaid = p.amountPaid ?? (isPaid ? p.amount : 0);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Plan: ${p.planType.toUpperCase()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                if (p.dueDate != null)
                                  Text(
                                    'Due: ${p.dueDate}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${p.amount}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isPartial
                                        ? 'Partial (₹$amountPaid paid)'
                                        : p.status.toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  String _monthLabel(DateTime m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          ],
        ),
      ),
    );
  }
}
