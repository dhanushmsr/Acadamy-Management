import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/api_client.dart';
import '../../../shared/widgets/chess_loading.dart';
import '../../../shared/widgets/app_button.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late final ApiClient _api;
  List<ExpenseSummary> _expenses = [];
  int _totalFeesCollected = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final expenses = await _api.getExpenses();
      final stats = await _api.getDashboardStats();
      setState(() {
        _expenses = expenses;
        _totalFeesCollected = stats.totalIncome;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showAddExpenseDialog() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'expense';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) => AlertDialog(
          title: const Text('Log Expense / Investment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('Expense')),
                  DropdownMenuItem(value: 'investment', child: Text('Investment')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setStateSB(() => type = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amt = int.tryParse(amountCtrl.text.trim());
                if (amt == null || descCtrl.text.trim().isEmpty) return;
                try {
                  await _api.addExpense({
                    'amount': amt,
                    'description': descCtrl.text.trim(),
                    'expense_type': type,
                  });
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: const Text('Save'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _expenses.isEmpty) return const ChessLoadingScreen(message: 'Loading finances...');
    if (_error != null && _expenses.isEmpty) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));

    final totalExpenses = _expenses
        .where((e) => e.expenseType == 'expense' || e.expenseType == 'other')
        .fold<int>(0, (sum, item) => sum + item.amount);
    
    final totalInvestments = _expenses
        .where((e) => e.expenseType == 'investment')
        .fold<int>(0, (sum, item) => sum + item.amount);

    final netBalance = _totalFeesCollected - totalExpenses - totalInvestments;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: const Color(0xFF1E2142),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSummaryBox('Fees Collected', _totalFeesCollected, Colors.greenAccent),
                _buildSummaryBox('Investments', totalInvestments, Colors.blueAccent),
                _buildSummaryBox('Expenses', totalExpenses, Colors.orangeAccent),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: const Color(0xFF13152A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Net Balance: ', style: TextStyle(color: Colors.white70, fontSize: 18)),
                Text(
                  '₹$netBalance', 
                  style: TextStyle(
                    color: netBalance >= 0 ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 24, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _expenses.isEmpty
                ? const Center(child: Text('No expenses logged yet.'))
                : ListView.builder(
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) {
                      final e = _expenses[index];
                      final isInvestment = e.expenseType == 'investment';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isInvestment ? Colors.blueAccent.withOpacity(0.2) : Colors.orangeAccent.withOpacity(0.2),
                          child: Icon(
                            isInvestment ? Icons.trending_up : Icons.money_off,
                            color: isInvestment ? Colors.blueAccent : Colors.orangeAccent,
                          ),
                        ),
                        title: Text(e.description),
                        subtitle: Text(e.expenseType.toUpperCase()),
                        trailing: Text(
                          '₹${e.amount}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox(String title, int amount, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Text(
          '₹$amount',
          style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
