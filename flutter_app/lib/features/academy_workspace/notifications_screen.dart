import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/api_client.dart';
import '../../core/auth/auth_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<NotificationSummary> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<ApiClient>().getNotifications();
      if (mounted) {
        setState(() => _notifications = data);
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('Could not validate credentials') || errStr.contains('401') || errStr.contains('Unauthenticated')) {
        if (mounted) {
          context.read<AuthState>().logout();
        }
        return;
      }
      if (mounted) {
        setState(() => _error = 'Unable to load notifications. Please check connection.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await context.read<ApiClient>().markNotificationRead(id);
      _loadData();
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('Could not validate credentials') || errStr.contains('401')) {
        if (mounted) context.read<AuthState>().logout();
      }
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
          : _error != null
              ? _buildErrorView()
              : _notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No notifications yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    )
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

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.amber),
                const SizedBox(height: 12),
                const Text(
                  'Session / Connection Warning',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Unable to connect to server.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        onPressed: _loadData,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Reset Session'),
                        onPressed: () async {
                          await context.read<AuthState>().logout();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
