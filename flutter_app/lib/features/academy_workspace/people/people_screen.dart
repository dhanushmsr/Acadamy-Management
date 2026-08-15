import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/api_client.dart';
import '../../../shared/widgets/chess_loading.dart';
import '../attendance/student_profile_screen.dart';
import 'new_batch_screen.dart';
import 'new_student_screen.dart';

/// The real "People" tab body - Students and Batches, each with an
/// inline add action (not a Scaffold FAB, since this embeds inside
/// AcademyShell's existing AppBar rather than owning one).
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ApiClient _api;

  List<StudentSummary> _students = [];
  List<BatchSummary> _batches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _api = context.read<ApiClient>();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final students = await _api.getStudents();
      final batches = await _api.getBatches();
      setState(() {
        _students = students;
        _batches = batches;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load people';
        _loading = false;
      });
    }
  }

  Future<void> _addStudent() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NewStudentScreen(batches: _batches)),
    );
    if (added == true) _load();
  }

  Future<void> _addBatch() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewBatchScreen()),
    );
    if (added == true) _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1E2142),
          tabs: const [Tab(text: 'Students'), Tab(text: 'Batches')],
        ),
      ),
      body: _loading
          ? const ChessLoadingScreen(message: 'Loading people...')
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _StudentsList(students: _students, batches: _batches, onAdd: _addStudent, onRefresh: _load),
                    _BatchesList(batches: _batches, onAdd: _addBatch, onRefresh: _load),
                  ],
                ),
    );
  }
}

class _StudentsList extends StatelessWidget {
  final List<StudentSummary> students;
  final List<BatchSummary> batches;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;
  const _StudentsList({required this.students, required this.batches, required this.onAdd, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${students.length} students', style: TextStyle(color: Colors.grey[600])),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add Student'),
              ),
            ],
          ),
        ),
        Expanded(
          child: students.isEmpty
              ? const Center(child: Text('No students yet'))
              : ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final s = students[index];
                    final subtitleParts = <String>[];
                    if (s.dateOfBirth != null && s.dateOfBirth!.isNotEmpty) {
                      subtitleParts.add('🎂 ${s.formattedDobAndAge}');
                    }
                    if (s.parentName != null && s.parentName!.isNotEmpty) subtitleParts.add(s.parentName!);
                    if (s.parentPhone != null && s.parentPhone!.isNotEmpty) subtitleParts.add(s.parentPhone!);
                    if (s.parentAddress != null && s.parentAddress!.isNotEmpty) subtitleParts.add('📍 ${s.parentAddress}');

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo.shade50,
                        child: Text(
                          s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                        ),
                      ),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        subtitleParts.isEmpty ? 'No parent details' : subtitleParts.join(' • '),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      onTap: () async {
                        final res = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentProfileScreen(
                              studentId: s.id,
                              studentName: s.name,
                              studentDetails: s,
                            ),
                          ),
                        );
                        if (res == true) {
                          onRefresh();
                        }
                      },
                      trailing: PopupMenuButton<String>(
                        onSelected: (val) async {
                          if (val == 'edit') {
                            final updated = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NewStudentScreen(
                                  batches: batches,
                                  studentToEdit: s,
                                ),
                              ),
                            );
                            if (updated == true) {
                              onRefresh();
                            }
                          } else if (val == 'delete_soft') {
                            final api = context.read<ApiClient>();
                            await api.deleteStudent(s.id);
                            onRefresh();
                          } else if (val == 'delete_hard') {
                            final api = context.read<ApiClient>();
                            await api.hardDeleteStudent(s.id);
                            onRefresh();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18, color: Colors.indigo),
                                SizedBox(width: 8),
                                Text('Edit Student'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete_soft',
                            child: Row(
                              children: [
                                Icon(Icons.person_off, size: 18, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Deactivate (Soft Delete)'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete_hard',
                            child: Row(
                              children: [
                                Icon(Icons.delete_forever, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Purge (Permanent Delete)', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _BatchesList extends StatelessWidget {
  final List<BatchSummary> batches;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;
  const _BatchesList({required this.batches, required this.onAdd, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${batches.length} batches', style: TextStyle(color: Colors.grey[600])),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add Batch'),
              ),
            ],
          ),
        ),
        Expanded(
          child: batches.isEmpty
              ? const Center(child: Text('No batches yet'))
              : ListView.builder(
                  itemCount: batches.length,
                  itemBuilder: (context, index) {
                    final b = batches[index];
                    final timing = (b.startTime != null && b.endTime != null)
                        ? '${b.startTime} - ${b.endTime}'
                        : 'Timing not set';
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
                      title: Text(b.name),
                      subtitle: Text(timing),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () async {
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NewBatchScreen(batchToEdit: b),
                            ),
                          );
                          if (updated == true) {
                            onRefresh();
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
