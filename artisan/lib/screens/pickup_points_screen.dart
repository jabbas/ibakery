import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';

final pickupPointsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(apiServiceProvider).getPickupPoints();
});

class PickupPointsScreen extends ConsumerWidget {
  const PickupPointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickupPointsAsync = ref.watch(pickupPointsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Punkty odbioru'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showPickupPointDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Dodaj punkt'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: pickupPointsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Blad: $err')),
        data: (points) => points.isEmpty
            ? const Center(child: Text('Brak punktow odbioru. Dodaj pierwszy!'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: points.length,
                itemBuilder: (context, index) {
                  final point = points[index];
                  final isActive = point['is_active'] ?? true;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isActive ? Colors.green : Colors.grey,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        point['name'] ?? '',
                        style: TextStyle(
                          decoration: isActive ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(point['address'] ?? ''),
                          if (point['description'] != null && point['description'].toString().isNotEmpty)
                            Text(
                              point['description'],
                              style: const TextStyle(fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                      isThreeLine: point['description'] != null && point['description'].toString().isNotEmpty,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showPickupPointDialog(context, ref, point: point),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deletePickupPoint(context, ref, point['id']),
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

  void _showPickupPointDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? point}) {
    final isEdit = point != null;
    final nameController = TextEditingController(text: point?['name']);
    final addressController = TextEditingController(text: point?['address']);
    final descriptionController = TextEditingController(text: point?['description']);
    bool isActive = point?['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEdit ? 'Edytuj punkt odbioru' : 'Dodaj punkt odbioru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nazwa',
                    hintText: 'np. Piekarnia Centrum',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Adres',
                    hintText: 'np. ul. Glowna 1, 00-001 Warszawa',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Opis (opcjonalnie)',
                    hintText: 'np. Odbior 8:00-18:00, parking pod budynkiem',
                  ),
                  maxLines: 3,
                ),
                if (isEdit) ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Aktywny'),
                    subtitle: const Text('Nieaktywne punkty nie sa widoczne dla klientow'),
                    value: isActive,
                    onChanged: (value) => setState(() => isActive = value),
                  ),
                ],
              ],
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
                  'address': addressController.text,
                  'description': descriptionController.text.isEmpty ? null : descriptionController.text,
                  'is_active': isActive,
                };

                if (isEdit) {
                  await api.updatePickupPoint(point['id'], data);
                } else {
                  await api.createPickupPoint(data);
                }

                ref.invalidate(pickupPointsProvider);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(isEdit ? 'Zapisz' : 'Dodaj'),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePickupPoint(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Usun punkt odbioru'),
        content: const Text('Czy na pewno chcesz usunac ten punkt odbioru? Jesli istnieja zamowienia z tym punktem, operacja sie nie powiedzie.'),
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
                await ref.read(apiServiceProvider).deletePickupPoint(id);
                ref.invalidate(pickupPointsProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Blad: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Usun'),
          ),
        ],
      ),
    );
  }
}
