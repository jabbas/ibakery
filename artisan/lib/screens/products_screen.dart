import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../utils/number_utils.dart';
import 'ingredients_screen.dart';

final productsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(apiServiceProvider).getProducts();
});

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final ingredientsAsync = ref.watch(ingredientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produkty'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showProductDialog(
              context, ref,
              ingredientsAsync.value ?? [],
              productsAsync.value ?? [],
            ),
            icon: const Icon(Icons.add),
            label: const Text('Dodaj produkt'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Błąd: $err')),
        data: (products) => products.isEmpty
            ? const Center(child: Text('Brak produktów. Dodaj pierwszy!'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final ingredients = List<Map<String, dynamic>>.from(product['ingredients'] ?? []);

                  // Oblicz koszt składników
                  double totalIngredientCost = 0;
                  for (var ing in ingredients) {
                    final quantity = double.tryParse(ing['quantity']?.toString() ?? '0') ?? 0;
                    final pricePerUnit = double.tryParse(ing['ingredient']?['price_per_unit']?.toString() ?? '0') ?? 0;
                    totalIngredientCost += quantity * pricePerUnit;
                  }

                  final basePrice = double.tryParse(product['base_price']?.toString() ?? '0') ?? 0;
                  final profit = basePrice - totalIngredientCost;
                  final profitColor = profit >= 0 ? Colors.green : Colors.red;

                  final parentProduct = product['parent_product'];
                  final basePercentage = double.tryParse(product['base_percentage']?.toString() ?? '100') ?? 100;
                  final hasParent = parentProduct != null;

                  return Card(
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: hasParent ? Colors.blue.shade100 : null,
                        child: Icon(
                          hasParent ? Icons.account_tree : Icons.bakery_dining,
                          color: hasParent ? Colors.blue : null,
                        ),
                      ),
                      title: Text(product['name'] ?? ''),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasParent)
                            Text(
                              'Bazuje na: ${parentProduct['name']} (${basePercentage.toStringAsFixed(0)}%)',
                              style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                            ),
                          Text('Cena: ${basePrice.toStringAsFixed(2)} PLN'),
                          Text(
                            'Koszt składników: ${totalIngredientCost.toStringAsFixed(2)} PLN  •  '
                            'Zysk: ${profit.toStringAsFixed(2)} PLN',
                            style: TextStyle(color: profitColor, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showProductDialog(
                              context, ref,
                              ingredientsAsync.value ?? [],
                              productsAsync.value ?? [],
                              product: product,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteProduct(context, ref, product['id']),
                          ),
                        ],
                      ),
                      children: [
                        if (product['description'] != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(product['description']),
                          ),
                        // Sizes section
                        if ((product['sizes'] as List?)?.isNotEmpty ?? false) ...[
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const Text('Rozmiary:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          ...List<Map<String, dynamic>>.from(product['sizes'] ?? []).map((size) {
                            final percentage = double.tryParse(size['percentage']?.toString() ?? '100') ?? 100;
                            final sizePrice = basePrice * percentage / 100;
                            final sizeCost = totalIngredientCost * percentage / 100;
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                size['is_default'] == true ? Icons.star : Icons.straighten,
                                color: size['is_default'] == true ? Colors.amber : null,
                              ),
                              title: Text(size['name'] ?? ''),
                              subtitle: Text(
                                '${percentage.toStringAsFixed(0)}% • Cena: ${sizePrice.toStringAsFixed(2)} PLN • Koszt: ${sizeCost.toStringAsFixed(2)} PLN',
                              ),
                            );
                          }),
                        ],
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Składniki:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                'Razem: ${totalIngredientCost.toStringAsFixed(2)} PLN',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        ...ingredients.map((ing) {
                          final ingredient = ing['ingredient'];
                          final quantity = double.tryParse(ing['quantity']?.toString() ?? '0') ?? 0;
                          final pricePerUnit = double.tryParse(ingredient?['price_per_unit']?.toString() ?? '0') ?? 0;
                          final cost = quantity * pricePerUnit;
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.arrow_right),
                            title: Text(ingredient?['name'] ?? 'Nieznany składnik'),
                            subtitle: Text(
                              '${quantity.toStringAsFixed(4)} ${ingredient?['unit']?['abbreviation'] ?? '?'} × '
                              '${pricePerUnit.toStringAsFixed(4)} PLN',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            trailing: Text(
                              '${cost.toStringAsFixed(2)} PLN',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showProductDialog(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> allIngredients,
    List<Map<String, dynamic>> allProducts,
    {Map<String, dynamic>? product}
  ) {
    final isEdit = product != null;
    final nameController = TextEditingController(text: product?['name']);
    final descriptionController = TextEditingController(text: product?['description']);
    final priceController = TextEditingController(
      text: product?['base_price']?.toString() ?? '0',
    );

    // Parent product support
    String? selectedParentId = product?['parent_product_id'];
    double basePercentage = double.tryParse(product?['base_percentage']?.toString() ?? '100') ?? 100;

    List<Map<String, dynamic>> selectedIngredients = [];
    if (product != null && product['ingredients'] != null) {
      for (var ing in product['ingredients']) {
        selectedIngredients.add({
          'ingredient_id': ing['ingredient_id'],
          'quantity': ing['quantity'],
          'name': ing['ingredient']?['name'] ?? '',
        });
      }
    }

    List<Map<String, dynamic>> sizes = [];
    if (product != null && product['sizes'] != null) {
      for (var size in product['sizes']) {
        sizes.add({
          'name': size['name'],
          'percentage': double.tryParse(size['percentage']?.toString() ?? '100') ?? 100,
          'is_default': size['is_default'] ?? false,
          'sort_order': size['sort_order'] ?? 0,
        });
      }
    }

    // Get parent product's ingredients for display
    List<Map<String, dynamic>> getParentIngredients() {
      if (selectedParentId == null) return [];
      final parent = allProducts.firstWhere(
        (p) => p['id'] == selectedParentId,
        orElse: () => {},
      );
      return List<Map<String, dynamic>>.from(parent['ingredients'] ?? []);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final parentIngredients = getParentIngredients();

          return AlertDialog(
            title: Text(isEdit ? 'Edytuj produkt' : 'Dodaj produkt'),
            content: SizedBox(
              width: 550,
              height: 550,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Parent product selection (for new products or editing)
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_tree, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text('Produkt bazowy', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String?>(
                              initialValue: selectedParentId,
                              decoration: const InputDecoration(
                                labelText: 'Bazuj na produkcie',
                                hintText: 'Wybierz produkt bazowy (opcjonalnie)',
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Brak (własne składniki)'),
                                ),
                                ...allProducts
                                    .where((p) => p['id'] != product?['id']) // Exclude current product
                                    .map((p) => DropdownMenuItem<String?>(
                                          value: p['id'] as String,
                                          child: Text(p['name'] ?? ''),
                                        )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedParentId = value;
                                  if (value != null) {
                                    // Auto-fill name suggestion
                                    final parent = allProducts.firstWhere((p) => p['id'] == value);
                                    if (nameController.text.isEmpty) {
                                      nameController.text = '${parent['name']} (wariant)';
                                    }
                                    // Auto-fill price based on percentage
                                    final parentPrice = double.tryParse(parent['base_price']?.toString() ?? '0') ?? 0;
                                    priceController.text = (parentPrice * basePercentage / 100).toStringAsFixed(2);
                                  }
                                });
                              },
                            ),
                            if (selectedParentId != null) ...[
                              const SizedBox(height: 16),
                              Text('Procent bazowy: ${basePercentage.toStringAsFixed(0)}%'),
                              Slider(
                                value: basePercentage,
                                min: 10,
                                max: 200,
                                divisions: 38,
                                label: '${basePercentage.toStringAsFixed(0)}%',
                                onChanged: (value) {
                                  setState(() {
                                    basePercentage = value;
                                    // Update price based on parent price and percentage
                                    final parent = allProducts.firstWhere((p) => p['id'] == selectedParentId);
                                    final parentPrice = double.tryParse(parent['base_price']?.toString() ?? '0') ?? 0;
                                    priceController.text = (parentPrice * basePercentage / 100).toStringAsFixed(2);
                                  });
                                },
                              ),
                              const Text(
                                'Składniki produktu bazowego zostaną przemnożone przez ten procent.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nazwa produktu',
                        hintText: 'np. Chleb żytni',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Opis',
                        hintText: 'Opcjonalny opis produktu',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Cena bazowa (PLN)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    // Show parent ingredients if parent selected
                    if (selectedParentId != null && parentIngredients.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Card(
                        color: Colors.grey.shade100,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Składniki z produktu bazowego:',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              ...parentIngredients.map((ing) {
                                final ingredient = ing['ingredient'];
                                final quantity = double.tryParse(ing['quantity']?.toString() ?? '0') ?? 0;
                                final adjustedQty = quantity * basePercentage / 100;
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.arrow_right, color: Colors.grey),
                                  title: Text(
                                    ingredient?['name'] ?? '',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  trailing: Text(
                                    '${adjustedQty.toStringAsFixed(2)} ${ingredient?['unit']?['abbreviation'] ?? '?'}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedParentId != null ? 'Dodatkowe składniki:' : 'Składniki:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () => _addIngredient(
                            context, setState, allIngredients, selectedIngredients,
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Dodaj'),
                        ),
                      ],
                    ),
                    ...selectedIngredients.asMap().entries.map((entry) {
                      final index = entry.key;
                      final ing = entry.value;
                      return Card(
                        child: ListTile(
                          title: Text(ing['name'] ?? 'Składnik'),
                          subtitle: Text('Ilość: ${ing['quantity']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              setState(() => selectedIngredients.removeAt(index));
                            },
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Rozmiary:', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: () => _addSize(context, setState, sizes),
                          icon: const Icon(Icons.add),
                          label: const Text('Dodaj'),
                        ),
                      ],
                    ),
                    ...sizes.asMap().entries.map((entry) {
                      final index = entry.key;
                      final size = entry.value;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            size['is_default'] == true ? Icons.star : Icons.straighten,
                            color: size['is_default'] == true ? Colors.amber : null,
                          ),
                          title: Text(size['name'] ?? 'Rozmiar'),
                          subtitle: Text('${size['percentage']}%'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (size['is_default'] != true)
                                IconButton(
                                  icon: const Icon(Icons.star_border),
                                  tooltip: 'Ustaw jako domyślny',
                                  onPressed: () {
                                    setState(() {
                                      for (var s in sizes) {
                                        s['is_default'] = false;
                                      }
                                      size['is_default'] = true;
                                    });
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  setState(() => sizes.removeAt(index));
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                onPressed: () async {
                  final api = ref.read(apiServiceProvider);
                  final data = {
                    'name': nameController.text,
                    'description': descriptionController.text.isEmpty ? null : descriptionController.text,
                    'base_price': parseNumberRounded(priceController.text, 0),
                    'parent_product_id': selectedParentId,
                    'base_percentage': basePercentage,
                    'ingredients': selectedIngredients.map((ing) => {
                      'ingredient_id': ing['ingredient_id'],
                      'quantity': ing['quantity'],
                    }).toList(),
                    'sizes': sizes.asMap().entries.map((entry) => {
                      'name': entry.value['name'],
                      'percentage': entry.value['percentage'],
                      'is_default': entry.value['is_default'] ?? false,
                      'sort_order': entry.key,
                    }).toList(),
                  };

                  try {
                    if (isEdit) {
                      await api.updateProduct(product['id'], data);
                    } else {
                      await api.createProduct(data);
                    }
                  } catch (e) {
                    debugPrint('Błąd podczas zapisywania produktu: $e');
                  }

                  ref.invalidate(productsProvider);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(isEdit ? 'Zapisz' : 'Dodaj'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addIngredient(
    BuildContext context,
    StateSetter setState,
    List<Map<String, dynamic>> allIngredients,
    List<Map<String, dynamic>> selectedIngredients,
  ) {
    String? selectedId;
    final quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Dodaj składnik'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedId,
                decoration: const InputDecoration(labelText: 'Składnik'),
                items: allIngredients.map((ing) {
                  return DropdownMenuItem(
                    value: ing['id'] as String,
                    child: Text('${ing['name']} (${ing['unit']?['abbreviation'] ?? '?'})'),
                  );
                }).toList(),
                onChanged: (value) => setDialogState(() => selectedId = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Ilość'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: selectedId == null ? null : () {
                final ingredient = allIngredients.firstWhere((i) => i['id'] == selectedId);
                setState(() {
                  selectedIngredients.add({
                    'ingredient_id': selectedId,
                    'quantity': parseNumberRounded(quantityController.text, 1),
                    'name': ingredient['name'],
                  });
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Dodaj'),
            ),
          ],
        ),
      ),
    );
  }

  void _addSize(
    BuildContext context,
    StateSetter setState,
    List<Map<String, dynamic>> sizes,
  ) {
    final nameController = TextEditingController();
    final percentageController = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dodaj rozmiar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nazwa rozmiaru',
                hintText: 'np. Bochenek, XXL, Foremka',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: percentageController,
              decoration: const InputDecoration(
                labelText: 'Procent rozmiaru bazowego',
                suffixText: '%',
                hintText: '100 = bazowy, 150 = 1.5x',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isEmpty) return;
              setState(() {
                sizes.add({
                  'name': nameController.text,
                  'percentage': parseNumberOr(percentageController.text, 100),
                  'is_default': sizes.isEmpty, // First size is default
                  'sort_order': sizes.length,
                });
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  void _deleteProduct(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Usuń produkt'),
        content: const Text('Czy na pewno chcesz usunąć ten produkt?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await ref.read(apiServiceProvider).deleteProduct(id);
                ref.invalidate(productsProvider);
              } catch (e) {
                // Extract error message from DioException
                String errorMessage = 'Nie udało się usunąć produktu';
                if (e.toString().contains('detail')) {
                  final match = RegExp(r'"detail"\s*:\s*"([^"]+)"').firstMatch(e.toString());
                  if (match != null) {
                    errorMessage = match.group(1) ?? errorMessage;
                  }
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
  }
}
