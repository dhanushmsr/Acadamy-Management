import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/api_client.dart';
import '../../../shared/widgets/chess_loading.dart';
import 'student_profile_screen.dart';

class DayAttendanceScreen extends StatefulWidget {
  final String date; // "YYYY-MM-DD"
  final String? initialBatchId;
  const DayAttendanceScreen({super.key, required this.date, this.initialBatchId});

  @override
  State<DayAttendanceScreen> createState() => _DayAttendanceScreenState();
}

class _DayAttendanceScreenState extends State<DayAttendanceScreen> {
  late final ApiClient _api;
  DayAttendance? _data;
  List<BatchSummary> _batchList = [];
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
      final batches = await _api.getBatches();

      setState(() {
        _data = data;
        _batchList = batches;
        _loading = false;
        if (_selectedBatchId == null) {
          if (widget.initialBatchId != null && _data!.batches.any((b) => b.batchId == widget.initialBatchId)) {
            _selectedBatchId = widget.initialBatchId;
          } else if (_data!.batches.isNotEmpty) {
            _selectedBatchId = _data!.batches.first.batchId;
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load attendance data: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _setStatus(String batchId, String studentId, String status) async {
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
    } catch (e) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to mark attendance: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to mark holiday: $e')));
      }
    } finally {
      if (mounted) setState(() => _markingHoliday = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Mark Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: const Color(0xFFF4E8F8),
        elevation: 0,
        actions: [
          if (_data != null && !_data!.isHoliday)
            IconButton(
              icon: _markingHoliday
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple),
                    )
                  : const Icon(Icons.beach_access_outlined, color: Colors.purple),
              tooltip: 'Mark as holiday',
              onPressed: _markingHoliday ? null : _markHoliday,
            ),
        ],
      ),
      body: (_loading && _data == null)
          ? const ChessLoadingScreen(message: 'Loading attendance...')
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _data!.isHoliday
                  ? const Center(child: Text('🏖️ Marked as Holiday - No classes scheduled'))
                  : _data!.batches.isEmpty
                      ? const Center(child: Text('No batches found with active students'))
                      : Column(
                          children: [
                            _buildHeaderCard(),
                            _buildSwipeHintBar(),
                            Expanded(child: _buildStudentSwipeList()),
                          ],
                        ),
    );
  }

  Widget _buildHeaderCard() {
    final batch = _data!.batches.firstWhere(
      (b) => b.batchId == _selectedBatchId,
      orElse: () => _data!.batches.first,
    );

    final totalStudents = batch.students.length;
    final presentCount = batch.students.where((s) => s.status == 'present').length;
    final absentCount = batch.students.where((s) => s.status == 'absent').length;

    BatchSummary? batchMeta;
    try {
      batchMeta = _batchList.firstWhere((b) => b.id == batch.batchId);
    } catch (_) {}

    final timingText = (batchMeta?.startTime != null && batchMeta?.endTime != null)
        ? '${batchMeta!.startTime} - ${batchMeta.endTime}'
        : 'Timing not available';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF4E8F8), Color(0xFFFCE7F3), Color(0xFFFFF1F2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Batch Selector Dropdown if multiple batches exist
          if (_data!.batches.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButton<String>(
                  value: _selectedBatchId,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _data!.batches.map((b) {
                    return DropdownMenuItem(
                      value: b.batchId,
                      child: Text(
                        b.batchName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedBatchId = val);
                  },
                ),
              ),
            ),

          Row(
            children: [
              // Cycle Graph with Fraction (e.g. 10/2)
              _buildCycleGraph(presentCount, absentCount, totalStudents),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        batchMeta?.level ?? 'Chess',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      batch.batchName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1B4B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '$timingText • $totalStudents Students',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Chess Graphic
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.extension, color: Color(0xFF1E1B4B), size: 30),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCycleGraph(int present, int absent, int total) {
    final double presentPct = total > 0 ? (present / total) : 0.0;
    final double absentPct = total > 0 ? (absent / total) : 0.0;

    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.purple.shade50.withValues(alpha: 0.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              value: presentPct + absentPct,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              strokeWidth: 6,
            ),
          ),
          SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              value: presentPct,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              strokeWidth: 6,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$present/$absent',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              Text(
                'P/A',
                style: TextStyle(fontSize: 9, color: Colors.grey.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeHintBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.keyboard_double_arrow_left, size: 18, color: Colors.red.shade400),
              const SizedBox(width: 4),
              Text(
                'To mark Absent\nSwipe left',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'To mark Present\nSwipe right',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_double_arrow_right, size: 18, color: Colors.green.shade400),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSwipeList() {
    final batch = _data!.batches.firstWhere(
      (b) => b.batchId == _selectedBatchId,
      orElse: () => _data!.batches.first,
    );

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: batch.students.length,
      itemBuilder: (context, index) {
        final student = batch.students[index];
        return _buildSwipeableStudentCard(batch.batchId, student);
      },
    );
  }

  Widget _buildSwipeableStudentCard(String batchId, StudentMark student) {
    final isPresent = student.status == 'present';
    final isAbsent = student.status == 'absent';

    Color cardBg = Colors.white;
    Color borderColor = Colors.grey.shade200;
    String statusText = 'Unmarked';
    Color statusColor = Colors.grey.shade600;

    if (isPresent) {
      cardBg = const Color(0xFFF0FDF4);
      borderColor = Colors.green.shade300;
      statusText = 'Present';
      statusColor = Colors.green.shade700;
    } else if (isAbsent) {
      cardBg = const Color(0xFFFEF2F2);
      borderColor = Colors.red.shade300;
      statusText = 'Absent';
      statusColor = Colors.red.shade700;
    }

    return Dismissible(
      key: Key('student_${student.studentId}_${student.status}'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swiped Right -> Mark Present
          _setStatus(batchId, student.studentId, 'present');
        } else if (direction == DismissDirection.endToStart) {
          // Swiped Left -> Mark Absent
          _setStatus(batchId, student.studentId, 'absent');
        }
        return false; // Don't remove tile from list
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Text('MARK PRESENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('MARK ABSENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.cancel, color: Colors.white, size: 28),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1.5),
        ),
        elevation: 1,
        color: cardBg,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: isPresent
              ? Colors.green.shade100
              : (isAbsent ? Colors.red.shade100 : Colors.indigo.shade50),
          child: Text(
            student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isPresent
                  ? Colors.green.shade800
                  : (isAbsent ? Colors.red.shade800 : Colors.indigo.shade800),
            ),
          ),
        ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          statusText,
          style: TextStyle(fontWeight: FontWeight.w600, color: statusColor, fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.cancel,
                color: isAbsent ? Colors.red : Colors.grey.shade400,
                size: 28,
              ),
              onPressed: () => _setStatus(batchId, student.studentId, 'absent'),
            ),
            IconButton(
              icon: Icon(
                Icons.check_circle,
                color: isPresent ? Colors.green : Colors.grey.shade400,
                size: 28,
              ),
              onPressed: () => _setStatus(batchId, student.studentId, 'present'),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentProfileScreen(
                studentId: student.studentId,
                studentName: student.name,
              ),
            ),
          );
        },
      ),
    ),
  );
  }
}
