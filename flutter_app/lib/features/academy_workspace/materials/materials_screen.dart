import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/api_client.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  List<MaterialSummary>? _materials;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    try {
      final list = await context.read<ApiClient>().getMaterials();
      if (mounted) setState(() => _materials = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Material'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name (e.g., T-Shirt)')),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
            TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Initial Stock'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await context.read<ApiClient>().createMaterial({
                  'name': nameCtrl.text,
                  'price': int.tryParse(priceCtrl.text) ?? 0,
                  'stock_quantity': int.tryParse(stockCtrl.text) ?? 0,
                });
                if (mounted) Navigator.pop(ctx);
                _loadMaterials();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Materials & Inventory')),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _materials == null
              ? const Center(child: CircularProgressIndicator())
              : _materials!.isEmpty
                  ? const Center(child: Text('No materials found.'))
                  : ListView.builder(
                      itemCount: _materials!.length,
                      itemBuilder: (ctx, i) {
                        final m = _materials![i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(m.name),
                            subtitle: Text('Price: ₹${m.price} - Stock: ${m.stockQuantity}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.shopping_cart),
                              tooltip: 'Sell Material',
                              onPressed: () {
                                // Real implementation would open a sell dialog
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sell material pending')),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
