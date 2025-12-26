import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../services/cart_service.dart';

final pickupPointsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(apiServiceProvider).getPickupPoints();
});

class OrderConfirmScreen extends ConsumerStatefulWidget {
  const OrderConfirmScreen({super.key});

  @override
  ConsumerState<OrderConfirmScreen> createState() => _OrderConfirmScreenState();
}

class _OrderConfirmScreenState extends ConsumerState<OrderConfirmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'CASH';
  String? _selectedPickupPointId;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty || cart.offerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koszyk jest pusty')),
      );
      return;
    }

    if (_selectedPickupPointId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wybierz punkt odbioru')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final order = await ref.read(apiServiceProvider).createOrder({
        'offer_id': cart.offerId,
        'pickup_point_id': _selectedPickupPointId,
        'customer_name': _nameController.text,
        'customer_phone': _phoneController.text,
        'customer_email': _emailController.text,
        'payment_method': _paymentMethod,
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
        'items': cart.items.map((item) => {
          'offer_item_id': item.offerItemId,
          'quantity': item.quantity,
        }).toList(),
      });

      ref.read(cartProvider.notifier).clear();

      if (mounted) {
        context.go('/order/${order['id']}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Złóż zamówienie'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Podsumowanie zamówienia',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(),
                      ...cart.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${item.productName} x${item.quantity}'),
                            Text('${item.total.toStringAsFixed(2)} PLN'),
                          ],
                        ),
                      )),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Suma:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '${cart.total.toStringAsFixed(2)} PLN',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Dane kontaktowe',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Imię i nazwisko',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Podaj imię i nazwisko';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Numer telefonu',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  hintText: '+48 123 456 789',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Podaj numer telefonu';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Podaj email';
                  }
                  if (!value.contains('@')) {
                    return 'Podaj prawidłowy email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Uwagi do zamówienia (opcjonalnie)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Text(
                'Metoda płatności',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Płatność przy odbiorze'),
                      subtitle: const Text('Gotówka lub karta'),
                      value: 'CASH',
                      groupValue: _paymentMethod,
                      onChanged: (value) => setState(() => _paymentMethod = value!),
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      title: const Text('BLIK'),
                      subtitle: const Text('Prześlij na numer piekarza'),
                      value: 'BLIK',
                      groupValue: _paymentMethod,
                      onChanged: (value) => setState(() => _paymentMethod = value!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Punkt odbioru',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ref.watch(pickupPointsProvider).when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (err, _) => Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Blad ladowania punktow odbioru: $err'),
                  ),
                ),
                data: (points) => points.isEmpty
                    ? const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Brak dostepnych punktow odbioru'),
                        ),
                      )
                    : Card(
                        child: Column(
                          children: points.asMap().entries.map((entry) {
                            final index = entry.key;
                            final point = entry.value;
                            return Column(
                              children: [
                                if (index > 0) const Divider(height: 1),
                                RadioListTile<String>(
                                  title: Text(point['name'] ?? ''),
                                  subtitle: Text(point['address'] ?? ''),
                                  value: point['id'],
                                  groupValue: _selectedPickupPointId,
                                  onChanged: (value) => setState(() => _selectedPickupPointId = value),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submitOrder,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Złóż zamówienie'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
