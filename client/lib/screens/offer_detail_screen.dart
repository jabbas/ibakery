import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/cart_service.dart';

class OfferDetailScreen extends ConsumerStatefulWidget {
  final String offerId;

  const OfferDetailScreen({super.key, required this.offerId});

  @override
  ConsumerState<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends ConsumerState<OfferDetailScreen> {
  Map<String, dynamic>? _offer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOffer();
  }

  Future<void> _loadOffer() async {
    try {
      final offer = await ref.read(apiServiceProvider).getOffer(widget.offerId);
      setState(() {
        _offer = offer;
        _loading = false;
      });
      ref.read(cartProvider.notifier).setOffer(widget.offerId, offer['title'] ?? '');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ładowanie...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _offer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Błąd')),
        body: Center(child: Text('Błąd: $_error')),
      );
    }

    final offer = _offer!;
    final items = List<Map<String, dynamic>>.from(offer['items'] ?? []);
    final pickupDate = DateTime.tryParse(offer['pickup_date'] ?? '');

    return Scaffold(
      appBar: AppBar(
        title: Text(offer['title'] ?? ''),
        actions: [
          if (cart.itemCount > 0)
            Badge(
              label: Text('${cart.itemCount}'),
              child: IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => context.push('/cart'),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (offer['description'] != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.brown.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(offer['description']),
                  const SizedBox(height: 8),
                  if (pickupDate != null)
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Odbiór: ${DateFormat('dd.MM.yyyy').format(pickupDate)} '
                          '${offer['pickup_time_from']?.substring(0, 5)} - ${offer['pickup_time_to']?.substring(0, 5)}',
                        ),
                      ],
                    ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final product = item['product'] as Map<String, dynamic>?;
                final productSize = item['product_size'] as Map<String, dynamic>?;
                final sizeName = productSize?['name'];
                final displayName = sizeName != null
                    ? '${product?['name'] ?? 'Produkt'} ($sizeName)'
                    : product?['name'] ?? 'Produkt';
                final cartItem = cart.items.where(
                  (i) => i.offerItemId == item['id'],
                ).firstOrNull;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.brown.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.bakery_dining, size: 40, color: Colors.brown),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (product?['description'] != null)
                                Text(
                                  product!['description'],
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 8),
                              Text(
                                '${item['price']} PLN',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              if (item['available_quantity'] != null)
                                Text(
                                  'Dostępne: ${item['available_quantity']}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (cartItem != null)
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () {
                                  ref.read(cartProvider.notifier).updateQuantity(
                                    item['id'],
                                    cartItem.quantity - 1,
                                  );
                                },
                              ),
                              Text(
                                '${cartItem.quantity}',
                                style: const TextStyle(fontSize: 18),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  ref.read(cartProvider.notifier).updateQuantity(
                                    item['id'],
                                    cartItem.quantity + 1,
                                  );
                                },
                              ),
                            ],
                          )
                        else
                          FilledButton(
                            onPressed: () {
                              ref.read(cartProvider.notifier).addItem(CartItem(
                                offerItemId: item['id'],
                                productName: displayName,
                                price: double.tryParse(item['price'].toString()) ?? 0,
                              ));
                            },
                            child: const Text('Dodaj'),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: cart.itemCount > 0
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${cart.itemCount} produktów'),
                          Text(
                            '${cart.total.toStringAsFixed(2)} PLN',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => context.push('/cart'),
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Koszyk'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
