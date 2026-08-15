import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/api_client.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  List<AuditLogSummary>? _logs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<ApiClient>().getAuditLogs();
      setState(() {
        _logs = data;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _logs = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_logs == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_logs!.isEmpty) {
      return const Center(child: Text('No audit logs found.'));
    }

    return ListView.builder(
      itemCount: _logs!.length,
      itemBuilder: (context, index) {
        final log = _logs![index];
        final timeStr = DateTime.parse(log.changedAt).toLocal().toString().split('.')[0];
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text('${log.entityType} • ${log.fieldName}'),
            subtitle: Text(
              'Old: ${log.oldValue ?? "None"}\nNew: ${log.newValue ?? "None"}\n'
              'Changed by: ${log.changedByName ?? log.changedBy} on $timeStr',
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
