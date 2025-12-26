import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';

final unitsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(apiServiceProvider).getUnits();
});

class UnitsScreen extends ConsumerWidget {
  const UnitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(unitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jednostki'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showUnitDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Dodaj jednostkę'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: unitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Błąd: $err')),
        data: (units) => units.isEmpty
            ? const Center(child: Text('Brak jednostek. Dodaj pierwszą!'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: units.length,
                itemBuilder: (context, index) {
                  final unit = units[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(unit['abbreviation'] ?? '?'),
                      ),
                      title: Text(unit['name'] ?? ''),
                      subtitle: Text('Skrót: ${unit['abbreviation']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showUnitDialog(context, ref, unit: unit),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteUnit(context, ref, unit['id']),
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

  void _showUnitDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? unit}) {
    final isEdit = unit != null;
    final nameController = TextEditingController(text: unit?['name']);
    final abbreviationController = TextEditingController(text: unit?['abbreviation']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edytuj jednostkę' : 'Dodaj jednostkę'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nazwa',
                hintText: 'np. gram, litr, sztuka',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: abbreviationController,
              decoration: const InputDecoration(
                labelText: 'Skrót',
                hintText: 'np. g, l, szt',
              ),
            ),
          ],
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
                'abbreviation': abbreviationController.text,
              };

              if (isEdit) {
                await api.updateUnit(unit['id'], data);
              } else {
                await api.createUnit(data);
              }

              ref.invalidate(unitsProvider);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(isEdit ? 'Zapisz' : 'Dodaj'),
          ),
        ],
      ),
    );
  }

  void _deleteUnit(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń jednostkę'),
        content: const Text('Czy na pewno chcesz usunąć tę jednostkę?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(apiServiceProvider).deleteUnit(id);
              ref.invalidate(unitsProvider);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
  }
}
