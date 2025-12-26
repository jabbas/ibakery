import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../utils/number_utils.dart';
import 'units_screen.dart';

final ingredientsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(apiServiceProvider).getIngredients();
});

class IngredientsScreen extends ConsumerWidget {
  const IngredientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final unitsAsync = ref.watch(unitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Składniki'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showIngredientDialog(context, ref, unitsAsync.value ?? []),
            icon: const Icon(Icons.add),
            label: const Text('Dodaj składnik'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ingredientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Błąd: $err')),
        data: (ingredients) => ingredients.isEmpty
            ? const Center(child: Text('Brak składników. Dodaj pierwszy!'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: ingredients.length,
                itemBuilder: (context, index) {
                  final ingredient = ingredients[index];
                  final unit = ingredient['unit'];
                  final unitAbbr = unit?['abbreviation'] ?? '?';
                  final packageQty = ingredient['package_quantity'] ?? 1;
                  final packagePrice = ingredient['package_price'] ?? 0;
                  final pricePerUnit = ingredient['price_per_unit'];

                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.egg)),
                      title: Text(ingredient['name'] ?? ''),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Opakowanie: ${formatNum(packageQty)} $unitAbbr za ${formatNum(packagePrice, 2)} PLN'),
                          Text(
                            'Cena za 1 $unitAbbr: ${formatNum(pricePerUnit)} PLN',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showIngredientDialog(
                              context, ref,
                              unitsAsync.value ?? [],
                              ingredient: ingredient,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteIngredient(context, ref, ingredient['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showIngredientDialog(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> units,
    {Map<String, dynamic>? ingredient}
  ) {
    final isEdit = ingredient != null;
    final nameController = TextEditingController(text: ingredient?['name']);
    final packageQtyController = TextEditingController(
      text: ingredient?['package_quantity']?.toString() ?? '1',
    );
    final packagePriceController = TextEditingController(
      text: ingredient?['package_price']?.toString() ?? '0',
    );
    String? selectedUnitId = ingredient?['unit_id'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Oblicz cenę za jednostkę
          final qty = parseNumberOr(packageQtyController.text, 1);
          final price = parseNumberOr(packagePriceController.text, 0);
          final pricePerUnit = qty > 0 ? (price / qty) : 0;
          final selectedUnit = units.where((u) => u['id'] == selectedUnitId).firstOrNull;
          final unitAbbr = selectedUnit?['abbreviation'] ?? '?';

          return AlertDialog(
            title: Text(isEdit ? 'Edytuj składnik' : 'Dodaj składnik'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nazwa składnika',
                      hintText: 'np. Mąka pszenna',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedUnitId,
                    decoration: const InputDecoration(labelText: 'Jednostka'),
                    items: units.map((unit) {
                      return DropdownMenuItem(
                        value: unit['id'] as String,
                        child: Text('${unit['name']} (${unit['abbreviation']})'),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedUnitId = value),
                  ),
                  const SizedBox(height: 24),
                  const Text('Dane opakowania:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: packageQtyController,
                          decoration: InputDecoration(
                            labelText: 'Ilość w opakowaniu',
                            hintText: 'np. 1000',
                            suffixText: unitAbbr,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: packagePriceController,
                          decoration: const InputDecoration(
                            labelText: 'Cena opakowania',
                            hintText: 'np. 5.00',
                            suffixText: 'PLN',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cena za 1 $unitAbbr: ${pricePerUnit.toStringAsFixed(4)} PLN',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                onPressed: selectedUnitId == null ? null : () async {
                  final api = ref.read(apiServiceProvider);
                  final data = {
                    'name': nameController.text,
                    'unit_id': selectedUnitId,
                    'package_quantity': parseNumberRounded(packageQtyController.text, 1),
                    'package_price': parseNumberRounded(packagePriceController.text, 0),
                  };

                  if (isEdit) {
                    await api.updateIngredient(ingredient['id'], data);
                  } else {
                    await api.createIngredient(data);
                  }

                  ref.invalidate(ingredientsProvider);
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

  void _deleteIngredient(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń składnik'),
        content: const Text('Czy na pewno chcesz usunąć ten składnik?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(apiServiceProvider).deleteIngredient(id);
              ref.invalidate(ingredientsProvider);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
  }
}
