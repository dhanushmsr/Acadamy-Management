import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/api_client.dart';
import '../../../shared/widgets/chess_loading.dart';
import 'day_attendance_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final ApiClient _api;
  int _selectedViewIndex = 0; // 0 = Calendar, 1 = Batches

  // Calendar State
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<CalendarDay> _days = [];
  bool _loadingCalendar = true;
  String? _calendarError;

  // Batches State
  List<BatchSummary> _batches = [];
  DayAttendance? _todayAttendance;
  bool _loadingBatches = true;
  String? _batchesError;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _loadCalendar();
    _loadBatches();
  }

  Future<void> _loadCalendar() async {
    setState(() => _loadingCalendar = true);
    try {
      final days = await _api.getCalendar(_month.year, _month.month);
      if (mounted) {
        setState(() {
          _days = days;
          _loadingCalendar = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _calendarError = 'Could not load calendar';
          _loadingCalendar = false;
        });
      }
    }
  }

  Future<void> _loadBatches() async {
    setState(() => _loadingBatches = true);
    try {
      final batches = await _api.getBatches();
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      DayAttendance? todayAtt;
      try {
        todayAtt = await _api.getDayAttendance(todayStr);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _batches = batches;
          _todayAttendance = todayAtt;
          _loadingBatches = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _batchesError = 'Could not load batches';
          _loadingBatches = false;
        });
      }
    }
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _loadCalendar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Filter Switcher (Calendar vs Batches)
        _buildFilterToggle(),
        Expanded(
          child: _selectedViewIndex == 0 ? _buildCalendarView() : _buildBatchesView(),
        ),
      ],
    );
  }

  Widget _buildFilterToggle() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedViewIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedViewIndex == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedViewIndex == 0
                      ? [BoxShadow(color: Colors.purple.withValues(alpha: 0.1), blurRadius: 4, spreadRadius: 1)]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month,
                      size: 18,
                      color: _selectedViewIndex == 0 ? Colors.purple.shade700 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Calendar View',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _selectedViewIndex == 0 ? Colors.purple.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedViewIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedViewIndex == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedViewIndex == 1
                      ? [BoxShadow(color: Colors.purple.withValues(alpha: 0.1), blurRadius: 4, spreadRadius: 1)]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.groups,
                      size: 18,
                      color: _selectedViewIndex == 1 ? Colors.purple.shade700 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Batches View',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _selectedViewIndex == 1 ? Colors.purple.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- CALENDAR VIEW ----
  Widget _buildCalendarView() {
    if (_loadingCalendar) {
      return const ChessLoadingScreen(message: 'Loading calendar...');
    }
    if (_calendarError != null) {
      return Center(child: Text(_calendarError!));
    }

    final today = DateTime.now();
    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
              ),
              Text(
                _monthLabel(_month),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
        ),
        const _WeekdayHeader(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final int rows = (leadingBlanks + daysInMonth) > 35 ? 6 : 5;
              final double itemHeight = (constraints.maxHeight / rows) - 6;

              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  mainAxisExtent: itemHeight > 50 ? itemHeight : 70,
                ),
                itemCount: leadingBlanks + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < leadingBlanks) return const SizedBox();
                  final dayNum = index - leadingBlanks + 1;
                  final dateStr = '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';

                  CalendarDay? cday;
                  for (final d in _days) {
                    if (d.date == dateStr) {
                      cday = d;
                      break;
                    }
                  }

                  final isToday = today.year == _month.year && today.month == _month.month && today.day == dayNum;

                  return _CalendarDayCell(
                    dayNumber: dayNum,
                    dateStr: dateStr,
                    isToday: isToday,
                    cday: cday,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DayAttendanceScreen(date: dateStr)),
                      );
                      _loadCalendar();
                      _loadBatches();
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ---- BATCHES VIEW ----
  Widget _buildBatchesView() {
    if (_loadingBatches) {
      return const ChessLoadingScreen(message: 'Loading batches...');
    }
    if (_batchesError != null) {
      return Center(child: Text(_batchesError!));
    }
    if (_batches.isEmpty) {
      return const Center(child: Text('No active batches found in academy'));
    }

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    return RefreshIndicator(
      onRefresh: _loadBatches,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _batches.length,
        itemBuilder: (context, index) {
          final batch = _batches[index];

          // Compute today stats if available for this batch
          int present = 0;
          int absent = 0;
          int total = batch.studentCount;
          int unmarked = total;

          if (_todayAttendance != null) {
            for (final b in _todayAttendance!.batches) {
              if (b.batchId == batch.id) {
                total = b.students.length;
                present = b.students.where((s) => s.status == 'present').length;
                absent = b.students.where((s) => s.status == 'absent').length;
                unmarked = total - (present + absent);
                break;
              }
            }
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.purple.shade100, width: 1),
            ),
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DayAttendanceScreen(
                      date: todayStr,
                      initialBatchId: batch.id,
                    ),
                  ),
                );
                _loadBatches();
                _loadCalendar();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Batch Cycle Ring Graph (present/absent)
                        _buildBatchCycleGraph(present, absent, total),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      batch.level ?? 'Chess',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple.shade700,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                batch.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E1B4B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      (batch.startTime != null && batch.endTime != null)
                                          ? '${batch.startTime} - ${batch.endTime} • ${batch.scheduleDays ?? "Daily"}'
                                          : (batch.scheduleDays ?? 'Active Schedule'),
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    // Attendance Stats Pills: Total, Present, Absent, Unmarked
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statPill('Total', '$total', Colors.indigo),
                        _statPill('Present', '$present', Colors.green),
                        _statPill('Absent', '$absent', Colors.red),
                        _statPill('Unmarked', '$unmarked', Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBatchCycleGraph(int present, int absent, int total) {
    final double presentPct = total > 0 ? (present / total) : 0.0;
    final double absentPct = total > 0 ? (absent / total) : 0.0;

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.purple.shade50.withValues(alpha: 0.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: CircularProgressIndicator(
              value: presentPct + absentPct,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              strokeWidth: 5,
            ),
          ),
          SizedBox(
            width: 62,
            height: 62,
            child: CircularProgressIndicator(
              value: presentPct,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              strokeWidth: 5,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$present/$absent',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              Text(
                'P/A',
                style: TextStyle(fontSize: 8, color: Colors.grey.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  String _monthLabel(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: days
            .map(
              (d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int dayNumber;
  final String dateStr;
  final bool isToday;
  final CalendarDay? cday;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.dayNumber,
    required this.dateStr,
    required this.isToday,
    required this.cday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isHoliday = cday?.isHoliday ?? false;
    final present = cday?.studentsPresent ?? 0;
    final absent = cday?.studentsAbsent ?? 0;
    final unmarked = cday?.studentsUnmarked ?? 0;
    final hasData = cday != null && (present > 0 || absent > 0 || unmarked > 0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isToday
              ? const Color(0xFFEFF6FF)
              : isHoliday
                  ? const Color(0xFFFFFBEB)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday
                ? const Color(0xFF1E2142)
                : isHoliday
                    ? Colors.amber.shade300
                    : Colors.grey.shade200,
            width: isToday ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$dayNumber',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                color: isToday ? const Color(0xFF1E2142) : Colors.black87,
                fontSize: 13,
              ),
            ),
            if (isHoliday)
              const FittedBox(
                child: Text('🏖️', style: TextStyle(fontSize: 10)),
              )
            else if (hasData)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 2,
                children: [
                  if (present > 0)
                    _pill('P:$present', Colors.green),
                  if (absent > 0)
                    _pill('A:$absent', Colors.red),
                  if (unmarked > 0 && present == 0 && absent == 0)
                    _pill('U:$unmarked', Colors.grey),
                ],
              )
            else
              const SizedBox(),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
