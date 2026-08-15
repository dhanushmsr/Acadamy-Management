import 'package:flutter/material.dart';

import '../messages/send_message_screen.dart';
import '../payments/payments_screen.dart';
import '../tournaments/tournaments_screen.dart';
import '../materials/materials_screen.dart';
import '../reports/reports_screen.dart';

/// Replaces the placeholder "More" tab. Send WhatsApp Message is wired
/// up for real; the rest mirror the sections from the existing King
/// Chess Academy app and are left as stubs for later phases.
class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MoreMenuTile(
          icon: Icons.message_outlined,
          title: 'Send WhatsApp Message',
          subtitle: 'Custom message to selected or all students',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SendMessageScreen()),
          ),
        ),
        _MoreMenuTile(
          icon: Icons.emoji_events_outlined,
          title: 'Tournaments',
          subtitle: 'Manage academy tournaments',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TournamentsScreen()),
          ),
        ),
        _MoreMenuTile(
          icon: Icons.shopping_cart_outlined,
          title: 'Materials',
          subtitle: 'Inventory and material sales',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MaterialsScreen()),
          ),
        ),
        _MoreMenuTile(
          icon: Icons.receipt_long_outlined,
          title: 'Fees',
          subtitle: 'Track unpaid, partial, and paid — no gateway, you set the status',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaymentsScreen()),
          ),
        ),
        _MoreMenuTile(
          icon: Icons.bar_chart_outlined,
          title: 'Reports',
          subtitle: 'Academy analytics and statistics',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportsScreen()),
          ),
        ),
      ],
    );
  }
}

class _MoreMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _MoreMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
        enabled: onTap != null,
        onTap: onTap,
      ),
    );
  }
}
