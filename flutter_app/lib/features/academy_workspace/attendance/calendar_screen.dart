import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/api_client.dart';
import '../../../shared/widgets/chess_loading.dart';
import 'day_attendance_screen.dart';

/// The real "Attendance" tab body - shows the current month with each
/// day's student-present count and holiday marking, matching the
/// manager's ask: see the current date, see how many students showed
/// up per day, mark holidays. Tapping a day opens attendance marking
/// for that date.
///
/// No Scaffold/AppBar here on purpose - this sits inside AcademyShell's
/// existing AppBar as a tab body, same as the other tabs. Month
/// navigation lives inline in the body instead.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final ApiClient _api;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<CalendarDay> _days = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final days = await _api.getCalendar(_month.year, _month.month);
      setState(() {
        _days = days;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load calendar';
        _loading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ChessLoadingScreen(message: 'Loading calendar...');
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    final today = DateTime.now();
    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // DateTime.weekday is 1=Mon..7=Sun; shift so the grid starts on Sunday.
    final leadingBlanks = firstOfMonth.weekday % 7;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
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
              final cellWidth = constraints.maxWidth / 7;
              final cellHeight = constraints.maxHeight / rows;
              final aspectRatio = cellWidth / (cellHeight > 0 ? cellHeight : 1);

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: aspectRatio,
                ),
                itemCount: leadingBlanks + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < leadingBlanks) return const SizedBox.shrink();
                  final dayNum = index - leadingBlanks + 1;
                  final date = DateTime(_month.year, _month.month, dayNum);
                  final dateStr = _isoDate(date);
                  final match = _days.where((d) => d.date == dateStr);
                  final info = match.isNotEmpty ? match.first : null;
                  final isToday = date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;

                  return _DayCell(
                    day: dayNum,
                    present: info?.studentsPresent ?? 0,
                    absent: info?.studentsAbsent ?? 0,
                    unmarked: info?.studentsUnmarked ?? 0,
                    isHoliday: info?.isHoliday ?? false,
                    isToday: isToday,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DayAttendanceScreen(date: dateStr),
                        ),
                      );
                      _load();
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

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _monthLabel(DateTime m) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[m.month - 1]} ${m.year}';
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Row(
      children: labels
          .map(
            (l) => Expanded(
              child: Center(
                child: Text(l, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final int present;
  final int absent;
  final int unmarked;
  final bool isHoliday;
  final bool isToday;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.present,
    required this.absent,
    required this.unmarked,
    required this.isHoliday,
    required this.isToday,
    required this.onTap,
  });

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isHoliday
              ? Colors.red.withOpacity(0.08)
              : isToday
                  ? const Color(0xFFEAF1FB)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday ? const Color(0xFF1E2142) : Colors.grey.shade200,
            width: isToday ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                color: isHoliday ? Colors.red[700] : const Color(0xFF1E2142),
              ),
            ),
            if (isHoliday)
              const Icon(Icons.beach_access, size: 12, color: Colors.red)
            else ...[
              const SizedBox(height: 2),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 2,
                runSpacing: 2,
                children: [
                  if (present > 0) _buildBadge('P:$present', const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
                  if (absent > 0) _buildBadge('A:$absent', const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
                  if (unmarked > 0) _buildBadge('U:$unmarked', const Color(0xFFF3F4F6), const Color(0xFF4B5563)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
