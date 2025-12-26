import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/cart_service.dart';

final activeOffersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(apiServiceProvider).getActiveOffers();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(activeOffersProvider);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.bakery_dining, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('iBakery'),
          ],
        ),
        actions: [
          if (cart.itemCount > 0)
            Badge(
              label: Text('${cart.itemCount}'),
              child: IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => context.push('/cart'),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () => context.push('/cart'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: offersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Nie można załadować ofert: $err'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(activeOffersProvider),
                child: const Text('Spróbuj ponownie'),
              ),
            ],
          ),
        ),
        data: (offers) => offers.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Brak aktywnych ofert'),
                    Text('Sprawdź później!'),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(activeOffersProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: offers.length,
                  itemBuilder: (context, index) {
                    final offer = offers[index];
                    final pickupDate = DateTime.tryParse(offer['pickup_date'] ?? '');
                    final deadline = DateTime.tryParse(offer['order_deadline'] ?? '');
                    final items = List<Map<String, dynamic>>.from(offer['items'] ?? []);

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.push('/offer/${offer['id']}'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      offer['title'] ?? '',
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                  ),
                                  Chip(
                                    label: Text('${items.length} produktów'),
                                    backgroundColor: Colors.brown.shade50,
                                  ),
                                ],
                              ),
                              if (offer['description'] != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  offer['description'],
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16),
                                  const SizedBox(width: 4),
                                  if (pickupDate != null)
                                    Text(
                                      'Odbiór: ${DateFormat('dd.MM.yyyy').format(pickupDate)} '
                                      '${offer['pickup_time_from']?.substring(0, 5)} - ${offer['pickup_time_to']?.substring(0, 5)}',
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.timer, size: 16, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  if (deadline != null)
                                    Text(
                                      'Zamów do: ${DateFormat('dd.MM.yyyy HH:mm').format(deadline)}',
                                      style: const TextStyle(color: Colors.orange),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () => context.push('/offer/${offer['id']}'),
                                  child: const Text('Zobacz ofertę'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
