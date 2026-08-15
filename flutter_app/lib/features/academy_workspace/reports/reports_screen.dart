import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/api_client.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportSummaryData? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await context.read<ApiClient>().getReportSummary();
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Analytics')),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _summary == null
              ? const Center(child: CircularProgressIndicator())
              : GridView.count(
                  padding: const EdgeInsets.all(16),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildStatCard('Total Students', _summary!.totalStudents.toString(), Icons.people, Colors.blue),
                    _buildStatCard('Total Revenue', '₹${_summary!.totalRevenue}', Icons.attach_money, Colors.green),
                    _buildStatCard('Total Expenses', '₹${_summary!.totalExpenses}', Icons.money_off, Colors.red),
                    _buildStatCard('Net Profit', '₹${_summary!.netProfit}', Icons.account_balance_wallet, _summary!.netProfit >= 0 ? Colors.green : Colors.red),
                    _buildStatCard('Avg Attendance', '${_summary!.averageAttendancePercentage}%', Icons.check_circle, Colors.orange),
                  ],
                ),
    );
  }
}
