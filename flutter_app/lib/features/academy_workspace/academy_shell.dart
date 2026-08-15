import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/auth/api_client.dart';
import '../../core/auth/auth_state.dart';
import 'attendance/calendar_screen.dart';
import 'home_screen.dart';
import 'more/more_menu_screen.dart';
import 'people/people_screen.dart';
import 'notifications_screen.dart';
import 'expenses/expenses_screen.dart';

class AcademyShell extends StatefulWidget {
  const AcademyShell({super.key});

  @override
  State<AcademyShell> createState() => _AcademyShellState();
}

class _AcademyShellState extends State<AcademyShell> {
  int _index = 0;
  Map<String, dynamic>? _academy;
  int _unreadCount = 0;
  int _lastNotificationCount = 0;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _loadAcademy();
    _checkNotifications();
    _startNotificationPolling();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _startNotificationPolling() {
    _notificationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkNotifications();
    });
  }

  void _playNotificationChime() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    HapticFeedback.vibrate();
  }

  Future<void> _checkNotifications() async {
    try {
      final list = await context.read<ApiClient>().getNotifications();
      final unread = list.where((n) => !n.isRead).toList();
      final currentUnreadCount = unread.length;

      if (currentUnreadCount > _unreadCount) {
        // New notification arrived! Push chime sound + notification toast
        _playNotificationChime();
        if (mounted && unread.isNotEmpty) {
          final newest = unread.first;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E2142),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(newest.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        if (newest.body != null)
                          Text(newest.body!, style: const TextStyle(fontSize: 12, color: Colors.white70), maxLines: 1),
                      ],
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'VIEW',
                textColor: Colors.amber,
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())).then((_) => _checkNotifications());
                },
              ),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _unreadCount = currentUnreadCount;
        });
      }
    } catch (e) {
      debugPrint('Notification check error: $e');
    }
  }

  Future<void> _loadAcademy() async {
    final authState = context.read<AuthState>();
    final aid = authState.academyId;
    if (aid != null) {
      try {
        final ac = await context.read<ApiClient>().getAcademy(aid);
        if (ac['status'] == 'suspended' || ac['status'] == 'deleted') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Your academy account has been suspended by Super Admin.')),
            );
            authState.logout();
          }
          return;
        }
        if (mounted) setState(() => _academy = ac);
      } catch (e) {
        if (e.toString().toLowerCase().contains('suspended')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Your academy account has been suspended by Super Admin.')),
            );
            authState.logout();
          }
        }
        debugPrint(e.toString());
      }
    }
  }

  Future<void> _uploadLogo() async {
    final aid = context.read<AuthState>().academyId;
    if (aid == null) return;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.bytes != null) {
        await context.read<ApiClient>().uploadLogo(
          aid,
          result.files.single.bytes!,
          result.files.single.name,
        );
        _loadAcademy();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  static const _pages = [
    HomeScreen(),
    PeopleScreen(),
    CalendarScreen(),
    ExpensesScreen(),
    MoreMenuScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _academy != null && _academy!['logo_url'] != null
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.network(ApiClient.baseUrl + _academy!['logo_url'], fit: BoxFit.contain),
              )
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
              ),
        title: Text(_academy?['name'] ?? 'AcD-Man'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Upload Logo',
            onPressed: _uploadLogo,
          ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications),
                if (_unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          '$_unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))
                  .then((_) => _checkNotifications());
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthState>().logout(),
          ),
        ],
      ),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people), label: 'People'),
          NavigationDestination(icon: Icon(Icons.event_available), label: 'Attendance'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
