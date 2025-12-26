import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../utils/number_utils.dart';
import 'products_screen.dart';

final offersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(apiServiceProvider).getOffers();
});

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(offersProvider);
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Oferty'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Odśwież',
            onPressed: () => ref.invalidate(offersProvider),
          ),
          IconButton(
            icon: const Icon(Icons.autorenew),
            tooltip: 'Generuj oferty cykliczne',
            onPressed: () => _generateRecurring(context, ref),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _showOfferDialog(context, ref, productsAsync.value ?? []),
            icon: const Icon(Icons.add),
            label: const Text('Dodaj ofertę'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: offersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Błąd: $err')),
        data: (offers) => offers.isEmpty
            ? const Center(child: Text('Brak ofert. Dodaj pierwszą!'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: offers.length,
                itemBuilder: (context, index) {
                  final offer = offers[index];
                  final items = List<Map<String, dynamic>>.from(offer['items'] ?? []);
                  final isActive = offer['is_active'] == true;
                  final isCompleted = offer['is_completed'] == true;
                  final isRecurring = offer['is_recurring'] == true;
                  final isInstance = offer['parent_offer_id'] != null;
                  final recurrenceRule = offer['recurrence_rule'] as String?;
                  final pickupDate = DateTime.tryParse(offer['pickup_date'] ?? '');

                  // Status color and icon
                  Color statusColor;
                  IconData statusIcon;
                  String statusText;
                  if (isRecurring && !isInstance) {
                    // Recurring template
                    statusColor = Colors.purple;
                    statusIcon = Icons.repeat;
                    statusText = 'Szablon';
                  } else if (isCompleted) {
                    statusColor = Colors.blue;
                    statusIcon = Icons.check_circle;
                    statusText = 'Zakończona';
                  } else if (!isActive) {
                    statusColor = Colors.grey;
                    statusIcon = Icons.pause;
                    statusText = 'Nieaktywna';
                  } else {
                    statusColor = Colors.green;
                    statusIcon = Icons.shopping_bag;
                    statusText = 'Aktywna';
                  }

                  return Card(
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: statusColor,
                        child: Icon(statusIcon, color: Colors.white),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(offer['title'] ?? '')),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(fontSize: 12, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isRecurring && !isInstance && recurrenceRule != null)
                            Text(
                              _formatRecurrenceRule(recurrenceRule),
                              style: TextStyle(color: Colors.purple.shade700, fontWeight: FontWeight.w500),
                            )
                          else if (pickupDate != null)
                            Text('Odbiór: ${DateFormat('dd.MM.yyyy').format(pickupDate)} '
                                '${offer['pickup_time_from']} - ${offer['pickup_time_to']}'),
                          if (isInstance)
                            Text('(z szablonu cyklicznego)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          Text('Produktów: ${items.length}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.analytics),
                            tooltip: 'Podsumowanie',
                            onPressed: () => _showSummary(context, ref, offer['id']),
                          ),
                          if (!isCompleted)
                            IconButton(
                              icon: const Icon(Icons.done_all),
                              tooltip: 'Zakończ ofertę',
                              onPressed: () => _completeOffer(context, ref, offer['id']),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showOfferDialog(
                              context, ref,
                              productsAsync.value ?? [],
                              offer: offer,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteOffer(context, ref, offer['id']),
                          ),
                        ],
                      ),
                      children: [
                        if (offer['description'] != null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(offer['description']),
                          ),
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Produkty w ofercie:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ...items.map((item) {
                          final product = item['product'];
                          final productSize = item['product_size'];
                          final sizeName = productSize != null ? ' (${productSize['name']})' : '';
                          final productName = product?['name'] ?? '(usunięty produkt)';
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.arrow_right,
                              color: product == null ? Colors.grey : null,
                            ),
                            title: Text(
                              '$productName$sizeName',
                              style: product == null
                                  ? const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)
                                  : null,
                            ),
                            trailing: Text('${formatNum(item['price'], 2)} PLN'),
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

  void _showOfferDialog(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> allProducts,
    {Map<String, dynamic>? offer}
  ) {
    final isEdit = offer != null;
    final titleController = TextEditingController(text: offer?['title']);
    final descriptionController = TextEditingController(text: offer?['description']);

    DateTime pickupDate = offer != null
        ? DateTime.tryParse(offer['pickup_date'] ?? '') ?? DateTime.now().add(const Duration(days: 1))
        : DateTime.now().add(const Duration(days: 1));
    TimeOfDay pickupTimeFrom = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay pickupTimeTo = const TimeOfDay(hour: 12, minute: 0);
    DateTime orderDeadline = pickupDate.subtract(const Duration(days: 1));

    // Recurrence settings
    bool isRecurring = offer?['is_recurring'] == true;
    Set<String> selectedDays = {};
    if (offer?['recurrence_rule'] != null) {
      final rule = offer!['recurrence_rule'] as String;
      if (rule.startsWith('WEEKLY:')) {
        selectedDays = rule.substring(7).split(',').map((d) => d.trim()).toSet();
      }
    }

    List<Map<String, dynamic>> selectedProducts = [];
    if (offer != null && offer['items'] != null) {
      for (var item in offer['items']) {
        final productSize = item['product_size'];
        selectedProducts.add({
          'product_id': item['product_id'],
          'product_size_id': item['product_size_id'],
          'price': item['price'],
          'max_quantity': item['max_quantity'],
          'name': item['product']?['name'] ?? '',
          'size_name': productSize?['name'],
        });
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEdit ? 'Edytuj ofertę' : 'Dodaj ofertę'),
          content: SizedBox(
            width: 600,
            height: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tytuł oferty',
                      hintText: 'np. Pieczywo na weekend',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Opis',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Data odbioru'),
                          subtitle: Text(DateFormat('dd.MM.yyyy').format(pickupDate)),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: pickupDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) setState(() => pickupDate = date);
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: const Text('Deadline zamówień'),
                          subtitle: Text(DateFormat('dd.MM.yyyy HH:mm').format(orderDeadline)),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: orderDeadline,
                              firstDate: DateTime.now(),
                              lastDate: pickupDate,
                            );
                            if (date != null && context.mounted) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(orderDeadline),
                              );
                              if (time != null) {
                                setState(() {
                                  orderDeadline = DateTime(
                                    date.year, date.month, date.day,
                                    time.hour, time.minute,
                                  );
                                });
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Recurrence settings
                  Card(
                    color: Colors.purple.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.repeat, color: Colors.purple),
                              const SizedBox(width: 8),
                              const Text('Oferta cykliczna', style: TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Switch(
                                value: isRecurring,
                                onChanged: (value) => setState(() => isRecurring = value),
                              ),
                            ],
                          ),
                          if (isRecurring) ...[
                            const SizedBox(height: 8),
                            const Text('Powtarzaj w dni:', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                _buildDayChip('MON', 'Pon', selectedDays, setState),
                                _buildDayChip('TUE', 'Wt', selectedDays, setState),
                                _buildDayChip('WED', 'Śr', selectedDays, setState),
                                _buildDayChip('THU', 'Czw', selectedDays, setState),
                                _buildDayChip('FRI', 'Pt', selectedDays, setState),
                                _buildDayChip('SAT', 'Sob', selectedDays, setState),
                                _buildDayChip('SUN', 'Niedz', selectedDays, setState),
                              ],
                            ),
                            if (isRecurring && selectedDays.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Wybierz przynajmniej jeden dzień',
                                  style: TextStyle(color: Colors.red, fontSize: 12),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Produkty w ofercie:', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: () => _addProductToOffer(
                          context, setState, allProducts, selectedProducts,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Dodaj'),
                      ),
                    ],
                  ),
                  ...selectedProducts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final sizeName = item['size_name'] != null ? ' (${item['size_name']})' : '';
                    return Card(
                      child: ListTile(
                        title: Text('${item['name'] ?? 'Produkt'}$sizeName'),
                        subtitle: Text('Cena: ${formatNum(item['price'], 2)} PLN'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            setState(() => selectedProducts.removeAt(index));
                          },
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
              onPressed: (isRecurring && selectedDays.isEmpty) ? null : () async {
                final api = ref.read(apiServiceProvider);

                // Build recurrence rule
                String? recurrenceRule;
                if (isRecurring && selectedDays.isNotEmpty) {
                  recurrenceRule = 'WEEKLY:${selectedDays.join(',')}';
                }

                final data = {
                  'title': titleController.text,
                  'description': descriptionController.text.isEmpty ? null : descriptionController.text,
                  'pickup_date': DateFormat('yyyy-MM-dd').format(pickupDate),
                  'pickup_time_from': '${pickupTimeFrom.hour.toString().padLeft(2, '0')}:${pickupTimeFrom.minute.toString().padLeft(2, '0')}:00',
                  'pickup_time_to': '${pickupTimeTo.hour.toString().padLeft(2, '0')}:${pickupTimeTo.minute.toString().padLeft(2, '0')}:00',
                  'order_deadline': orderDeadline.toIso8601String(),
                  'is_recurring': isRecurring,
                  'recurrence_rule': recurrenceRule,
                  'items': selectedProducts.map((item) => {
                    'product_id': item['product_id'],
                    'product_size_id': item['product_size_id'],
                    'price': item['price'],
                    'max_quantity': item['max_quantity'],
                  }).toList(),
                };

                try {
                  if (isEdit) {
                    await api.updateOffer(offer['id'], data);
                  } else {
                    await api.createOffer(data);
                  }
                } catch (e) {
                  debugPrint('Błąd podczas zapisywania oferty: $e');
                }

                ref.invalidate(offersProvider);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(isEdit ? 'Zapisz' : 'Dodaj'),
            ),
          ],
        ),
      ),
    );
  }

  void _addProductToOffer(
    BuildContext context,
    StateSetter setState,
    List<Map<String, dynamic>> allProducts,
    List<Map<String, dynamic>> selectedProducts,
  ) {
    String? selectedId;
    String? selectedSizeId;
    final priceController = TextEditingController();
    final maxQuantityController = TextEditingController();
    List<Map<String, dynamic>> availableSizes = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Dodaj produkt do oferty'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedId,
                decoration: const InputDecoration(labelText: 'Produkt'),
                items: allProducts.map((p) {
                  return DropdownMenuItem(
                    value: p['id'] as String,
                    child: Text('${p['name']} (bazowa: ${formatNum(p['base_price'], 2)} PLN)'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    final product = allProducts.firstWhere((p) => p['id'] == value);
                    final basePrice = double.tryParse(product['base_price']?.toString() ?? '0') ?? 0;
                    final sizes = List<Map<String, dynamic>>.from(product['sizes'] ?? []);
                    setDialogState(() {
                      selectedId = value;
                      availableSizes = sizes;
                      selectedSizeId = null;
                      // Find default size or use base price
                      final defaultSize = sizes.where((s) => s['is_default'] == true).firstOrNull;
                      if (defaultSize != null) {
                        selectedSizeId = defaultSize['id'];
                        final percentage = double.tryParse(defaultSize['percentage']?.toString() ?? '100') ?? 100;
                        priceController.text = (basePrice * percentage / 100).toStringAsFixed(2);
                      } else {
                        priceController.text = basePrice.toStringAsFixed(2);
                      }
                    });
                  }
                },
              ),
              if (availableSizes.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  value: selectedSizeId,
                  decoration: const InputDecoration(labelText: 'Rozmiar'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Brak (rozmiar bazowy)'),
                    ),
                    ...availableSizes.map((s) {
                      final percentage = double.tryParse(s['percentage']?.toString() ?? '100') ?? 100;
                      return DropdownMenuItem<String?>(
                        value: s['id'] as String,
                        child: Text('${s['name']} (${percentage.toStringAsFixed(0)}%)'),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    if (selectedId != null) {
                      final product = allProducts.firstWhere((p) => p['id'] == selectedId);
                      final basePrice = double.tryParse(product['base_price']?.toString() ?? '0') ?? 0;
                      double newPrice = basePrice;
                      if (value != null) {
                        final size = availableSizes.firstWhere((s) => s['id'] == value);
                        final percentage = double.tryParse(size['percentage']?.toString() ?? '100') ?? 100;
                        newPrice = basePrice * percentage / 100;
                      }
                      setDialogState(() {
                        selectedSizeId = value;
                        priceController.text = newPrice.toStringAsFixed(2);
                      });
                    }
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Cena w ofercie (PLN)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: maxQuantityController,
                decoration: const InputDecoration(
                  labelText: 'Maksymalna ilość (puste = bez limitu)',
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
              onPressed: selectedId == null ? null : () {
                final product = allProducts.firstWhere((p) => p['id'] == selectedId);
                String? sizeName;
                if (selectedSizeId != null) {
                  final size = availableSizes.firstWhere((s) => s['id'] == selectedSizeId);
                  sizeName = size['name'];
                }
                setState(() {
                  selectedProducts.add({
                    'product_id': selectedId,
                    'product_size_id': selectedSizeId,
                    'price': parseNumberRounded(priceController.text, 0),
                    'max_quantity': maxQuantityController.text.isEmpty
                        ? null
                        : int.tryParse(maxQuantityController.text),
                    'name': product['name'],
                    'size_name': sizeName,
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

  void _showSummary(BuildContext context, WidgetRef ref, String offerId) {
    showDialog(
      context: context,
      builder: (dialogContext) => _SummaryDialog(
        offerId: offerId,
        apiService: ref.read(apiServiceProvider),
      ),
    );
  }
}

class _SummaryDialog extends StatefulWidget {
  final String offerId;
  final ApiService apiService;

  const _SummaryDialog({required this.offerId, required this.apiService});

  @override
  State<_SummaryDialog> createState() => _SummaryDialogState();
}

class _SummaryDialogState extends State<_SummaryDialog> {
  Map<String, dynamic>? summary;
  String? error;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      final data = await widget.apiService.getOfferSummary(widget.offerId);
      if (mounted) {
        setState(() {
          summary = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (error != null) {
      return AlertDialog(
        title: const Text('Błąd'),
        content: Text(error!),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zamknij'),
          ),
        ],
      );
    }

    final ingredients = List<Map<String, dynamic>>.from(summary!['ingredients'] ?? []);

    return AlertDialog(
      title: Text('Podsumowanie: ${summary!['offer_title']}'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                        Column(
                          children: [
                            Text('${summary!['total_orders']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            const Text('Zamówień'),
                          ],
                        ),
                        Column(
                          children: [
                            Text('${formatNum(summary!['total_revenue'], 2)} PLN', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            const Text('Przychód'),
                          ],
                        ),
                        Column(
                          children: [
                            Text('${formatNum(summary!['profit'], 2)} PLN', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                            const Text('Zysk'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Potrzebne składniki:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (ingredients.isEmpty)
                  const Text('Brak zamówień dla tej oferty.')
                else
                  ...ingredients.map((ing) => Card(
                    child: ListTile(
                      title: Text(ing['ingredient_name'] ?? ''),
                      subtitle: Text('Koszt: ${formatNum(ing['total_cost'], 2)} PLN'),
                      trailing: Text(
                        '${formatNum(ing['total_quantity'])} ${ing['unit_abbreviation']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )),
                const SizedBox(height: 8),
                Text(
                  'Łączny koszt składników: ${formatNum(summary!['total_ingredient_cost'], 2)} PLN',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zamknij'),
          ),
        ],
      );
  }
}

void _completeOffer(BuildContext context, WidgetRef ref, String id) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Zakończ ofertę'),
      content: const Text('Czy na pewno chcesz oznaczyć tę ofertę jako zakończoną?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await ref.read(apiServiceProvider).completeOffer(id);
              ref.invalidate(offersProvider);
            } catch (e) {
              debugPrint('Błąd podczas zamykania oferty: $e');
            }
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Zakończ'),
        ),
      ],
    ),
  );
}

void _deleteOffer(BuildContext context, WidgetRef ref, String id) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Usuń ofertę'),
      content: const Text('Czy na pewno chcesz usunąć tę ofertę?'),
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
              await ref.read(apiServiceProvider).deleteOffer(id);
              ref.invalidate(offersProvider);
            } catch (e) {
              // Extract error message from DioException
              String errorMessage = 'Nie udało się usunąć oferty';
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

void _generateRecurring(BuildContext context, WidgetRef ref) async {
  try {
    final result = await ref.read(apiServiceProvider).generateRecurringOffers();
    ref.invalidate(offersProvider);
    if (context.mounted) {
      final created = result['created'] as List? ?? [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wygenerowano ${created.length} ofert cyklicznych'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Błąd: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

String _formatRecurrenceRule(String rule) {
  const dayNamesPl = {
    'MON': 'Pon', 'TUE': 'Wt', 'WED': 'Śr', 'THU': 'Czw',
    'FRI': 'Pt', 'SAT': 'Sob', 'SUN': 'Niedz'
  };

  if (rule.startsWith('WEEKLY:')) {
    final days = rule.substring(7).split(',');
    final dayNames = days.map((d) => dayNamesPl[d.trim()] ?? d).join(', ');
    return 'Co tydzień: $dayNames';
  }
  return rule;
}

Widget _buildDayChip(String dayCode, String dayName, Set<String> selectedDays, StateSetter setState) {
  final isSelected = selectedDays.contains(dayCode);
  return FilterChip(
    label: Text(dayName),
    selected: isSelected,
    onSelected: (selected) {
      setState(() {
        if (selected) {
          selectedDays.add(dayCode);
        } else {
          selectedDays.remove(dayCode);
        }
      });
    },
    selectedColor: Colors.purple.shade200,
    checkmarkColor: Colors.purple.shade900,
  );
}
