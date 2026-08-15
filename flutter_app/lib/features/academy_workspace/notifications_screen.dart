import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<NotificationSummary> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiClient>().getNotifications();
      setState(() => _notifications = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await context.read<ApiClient>().markNotificationRead(id);
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _markAllRead() async {
    for (final n in _notifications.where((item) => !item.isRead)) {
      try {
        await context.read<ApiClient>().markNotificationRead(n.id);
      } catch (_) {}
    }
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('No notifications'))
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    return Card(
                      color: n.isRead ? null : Colors.blue.shade50,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Icon(
                          n.type == 'platform_fee_due' ? Icons.warning : Icons.receipt_long,
                          color: n.type == 'platform_fee_due' ? Colors.orange : Colors.green,
                        ),
                        title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                        subtitle: Text(n.body ?? ''),
                        trailing: n.isRead
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.check),
                                onPressed: () => _markRead(n.id),
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}
