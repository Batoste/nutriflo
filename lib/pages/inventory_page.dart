import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _weightController = TextEditingController(text: "1");
  final _barcodeController = TextEditingController();

  String _selectedUnit = 'unit';
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

  Future<List<Map<String, dynamic>>> _fetchInventory() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    return await supabase
        .from('v_inventory')
        .select()
        .eq('user_id', user.id)
        .order('expiry_date', ascending: true);
  }

  Future<void> _fetchFromOpenFoodFacts(
    String barcode,
    StateSetter setModalState,
  ) async {
    final code = barcode.trim();
    if (code.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Searching for product... 🔍")),
    );

    try {
      // On utilise le serveur FR qui est souvent plus rapide pour nous
      final url = Uri.parse(
        'https://fr.openfoodfacts.org/api/v0/product/$code.json?fields=product_name,product_name_en,product_name_fr,quantity',
      );

      // On ajoute un Timeout de 5 secondes pour éviter que l'app plante
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 1) {
          final product = data['product'];
          final name =
              product['product_name_fr'] ??
              product['product_name_en'] ??
              product['product_name'] ??
              'Unknown';
          final quantityStr = product['quantity'] ?? '1';

          setModalState(() {
            _nameController.text = name;

            final numericRegex = RegExp(r'[\d.,]+');
            final match = numericRegex.firstMatch(quantityStr);
            if (match != null) {
              _weightController.text = match.group(0)!.replaceAll(',', '.');
            }
          });

          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Product found! 🎉"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Product not found. 😕"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Network error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddProductSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
                  const SizedBox(height: 10),
                  TextField(
                    controller: _barcodeController,
                    onSubmitted: (value) =>
                        _fetchFromOpenFoodFacts(value, setModalState),
                    decoration: InputDecoration(
                      labelText: "Barcode (ex: 3017620422003)",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.blue),
                        onPressed: () {
                          _fetchFromOpenFoodFacts(
                            _barcodeController.text,
                            setModalState,
                          );
                        },
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 15),
                  const Divider(),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Product Name",
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Volume (ex: 500)",
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedUnit,
                          items: ['unit', 'g', 'ml', 'cl', 'kg', 'L'].map((u) {
                            return DropdownMenuItem(value: u, child: Text(u));
                          }).toList(),
                          onChanged: (val) =>
                              setModalState(() => _selectedUnit = val!),
                        ),
                      ),
                    ],
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
                    onChanged: (value) =>
                        setModalState(() => _selectedCategoryId = value),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _saveProduct(),
                    child: const Text("Add to Fridge"),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutriflo - Fridge'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async => await supabase.auth.signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchInventory(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 300),
                  Center(
                    child: Text("Your fridge is empty. Tap + to add items!"),
                  ),
                ],
              );
            }

            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                final name = item['product_name'] ?? 'Unknown';
                final weight = item['weight_volume'] ?? '';
                final unit = item['unit'] ?? '';
                final expiry = item['expiry_date'].toString().split('T')[0];

                return ListTile(
                  leading: const Icon(Icons.fastfood, color: Colors.green),
                  title: Text("$name ($weight $unit)"),
                  subtitle: Text("Expires on: $expiry"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await supabase
                          .from('inventory')
                          .delete()
                          .eq('id', item['id']);
                      setState(() {});
                    },
                  ),
                );
              },
            );
          },
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
          .insert({
            'name': name,
            'category_id': _selectedCategoryId,
            'unit': _selectedUnit,
            'weight_volume': double.tryParse(_weightController.text) ?? 1.0,
          })
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
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Item added successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}
