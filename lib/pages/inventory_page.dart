import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final data = await supabase.from('categories').select();
    setState(() {
      _categories = List<Map<String, dynamic>>.from(data);
    });
  }

  void _showAddProductSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Add Product",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "Product Name"),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Category"),
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat['id'].toString(),
                    child: Text(cat['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _saveProduct();
                },
                child: const Text("Add Product"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutriflo - Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome, ${user?.email}'),
            const SizedBox(height: 20),
            const Text(
              'Your inventory is currently empty. Start adding items!',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductSheet,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _saveProduct() async {
    final name = _nameController.text.trim();
    final user = supabase.auth.currentUser;

    if (name.isEmpty || _selectedCategoryId == null || user == null) return;

    try {
      final product = await supabase
          .from('products_catalog')
          .insert({'name': name, 'category_id': _selectedCategoryId})
          .select()
          .single();

      await supabase.from('inventory').insert({
        'user_id': user.id,
        'product_id': product['id'],
        'quantity': 1,
        'expiry_date': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
      });

      if (mounted) {
        _nameController.clear();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product added to inventory!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
