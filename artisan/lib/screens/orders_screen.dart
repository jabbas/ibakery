import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../utils/number_utils.dart';

final ordersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(apiServiceProvider).getOrders();
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zamówienia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(ordersProvider),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Błąd: $err')),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('Brak zamówień.'));
          }

          // Grupuj zamówienia po ofercie
          final Map<String, List<Map<String, dynamic>>> ordersByOffer = {};
          final Map<String, Map<String, dynamic>> offerInfoMap = {};

          for (var order in orders) {
            final offer = order['offer'] as Map<String, dynamic>?;
            final offerId = order['offer_id'] as String? ?? 'unknown';

            if (!ordersByOffer.containsKey(offerId)) {
              ordersByOffer[offerId] = [];
              if (offer != null) {
                offerInfoMap[offerId] = offer;
              }
            }
            ordersByOffer[offerId]!.add(order);
          }

          // Sortuj oferty po dacie odbioru (najnowsze pierwsze)
          final sortedOfferIds = ordersByOffer.keys.toList()
            ..sort((a, b) {
              final offerA = offerInfoMap[a];
              final offerB = offerInfoMap[b];
              if (offerA == null || offerB == null) return 0;
              final dateA = DateTime.tryParse(offerA['pickup_date'] ?? '') ?? DateTime(2000);
              final dateB = DateTime.tryParse(offerB['pickup_date'] ?? '') ?? DateTime(2000);
              return dateB.compareTo(dateA);
            });

          // Oblicz statystyki
          double totalRevenue = 0;
          double paidRevenue = 0;
          double pendingRevenue = 0;
          int paidCount = 0;
          int pendingCount = 0;
          int cancelledCount = 0;

          for (var order in orders) {
            final price = double.tryParse(order['total_price']?.toString() ?? '0') ?? 0;
            final status = order['payment_status'] ?? 'PENDING';

            if (status == 'PAID') {
              paidRevenue += price;
              paidCount++;
            } else if (status == 'PENDING') {
              pendingRevenue += price;
              pendingCount++;
            } else {
              cancelledCount++;
            }

            if (status != 'CANCELLED') {
              totalRevenue += price;
            }
          }

          return Column(
            children: [
              // Podsumowanie
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Podsumowanie zamówień',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Łącznie', orders.length.toString(), Colors.white),
                        _buildStatItem('Opłacone', paidCount.toString(), Colors.greenAccent),
                        _buildStatItem('Oczekujące', pendingCount.toString(), Colors.orangeAccent),
                        _buildStatItem('Anulowane', cancelledCount.toString(), Colors.redAccent),
                      ],
                    ),
                    const Divider(color: Colors.white30, height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMoneyItem('Przychód (opłacone)', paidRevenue, Colors.greenAccent),
                        _buildMoneyItem('Oczekuje na płatność', pendingRevenue, Colors.orangeAccent),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Razem: ${totalRevenue.toStringAsFixed(2)} PLN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Lista zamówień pogrupowana po ofercie
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sortedOfferIds.length,
                  itemBuilder: (context, index) {
                    final offerId = sortedOfferIds[index];
                    final offerOrders = ordersByOffer[offerId]!;
                    final offerInfo = offerInfoMap[offerId];

                    return _OfferOrdersGroup(
                      offerInfo: offerInfo,
                      orders: offerOrders,
                      onUpdateStatus: (orderId, status) => _updateStatus(context, ref, orderId, status),
                      onShowDetails: (order) => _showOrderDetails(context, order),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildMoneyItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          '${value.toStringAsFixed(2)} PLN',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  void _updateStatus(BuildContext context, WidgetRef ref, String orderId, String status) async {
    try {
      await ref.read(apiServiceProvider).updateOrder(orderId, {'payment_status': status});
      ref.invalidate(ordersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status zaktualizowany na: $status')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e')),
        );
      }
    }
  }

  void _showOrderDetails(BuildContext context, Map<String, dynamic> order) {
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Zamówienie od ${order['customer_name']}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Telefon: ${order['customer_phone']}'),
              Text('Email: ${order['customer_email']}'),
              if (order['notes'] != null && order['notes'].isNotEmpty)
                Text('Uwagi: ${order['notes']}'),
              const Divider(),
              const Text('Pozycje:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...items.map((item) => ListTile(
                dense: true,
                title: Text('Produkt'),
                subtitle: Text('Ilość: ${item['quantity']} x ${formatNum(item['unit_price'], 2)} PLN'),
              )),
              const Divider(),
              Text(
                'Suma: ${formatNum(order['total_price'], 2)} PLN',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }
}

class _OfferOrdersGroup extends StatelessWidget {
  final Map<String, dynamic>? offerInfo;
  final List<Map<String, dynamic>> orders;
  final Function(String orderId, String status) onUpdateStatus;
  final Function(Map<String, dynamic> order) onShowDetails;

  const _OfferOrdersGroup({
    required this.offerInfo,
    required this.orders,
    required this.onUpdateStatus,
    required this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    // Oblicz statystyki dla tej oferty
    double offerRevenue = 0;
    int pendingCount = 0;

    for (var order in orders) {
      final price = double.tryParse(order['total_price']?.toString() ?? '0') ?? 0;
      final status = order['payment_status'] ?? 'PENDING';
      if (status != 'CANCELLED') {
        offerRevenue += price;
      }
      if (status == 'PENDING') pendingCount++;
    }

    final pickupDate = offerInfo != null
        ? DateTime.tryParse(offerInfo!['pickup_date'] ?? '')
        : null;
    final isCompleted = offerInfo?['is_completed'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: !isCompleted,
        leading: CircleAvatar(
          backgroundColor: isCompleted ? Colors.blue : Colors.green,
          child: Icon(
            isCompleted ? Icons.check_circle : Icons.shopping_bag,
            color: Colors.white,
          ),
        ),
        title: Text(
          offerInfo?['title'] ?? 'Nieznana oferta',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pickupDate != null)
              Text(
                'Odbiór: ${DateFormat('dd.MM.yyyy').format(pickupDate)} '
                '${offerInfo!['pickup_time_from']} - ${offerInfo!['pickup_time_to']}',
              ),
            Row(
              children: [
                Text('${orders.length} zamówień'),
                const SizedBox(width: 8),
                Text('•', style: TextStyle(color: Colors.grey.shade400)),
                const SizedBox(width: 8),
                Text(
                  '${offerRevenue.toStringAsFixed(2)} PLN',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$pendingCount oczekuje',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        children: orders.map((order) => _OrderListItem(
          order: order,
          onUpdateStatus: onUpdateStatus,
          onShowDetails: onShowDetails,
        )).toList(),
      ),
    );
  }
}

class _OrderListItem extends StatelessWidget {
  final Map<String, dynamic> order;
  final Function(String orderId, String status) onUpdateStatus;
  final Function(Map<String, dynamic> order) onShowDetails;

  const _OrderListItem({
    required this.order,
    required this.onUpdateStatus,
    required this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(order['created_at'] ?? '');
    final paymentStatus = order['payment_status'] ?? 'PENDING';
    final paymentMethod = order['payment_method'] ?? 'CASH';

    Color statusColor;
    IconData statusIcon;
    switch (paymentStatus) {
      case 'PAID':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'CANCELLED':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return InkWell(
      onTap: () => onShowDetails(order),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: statusColor.withValues(alpha: 0.2),
              child: Icon(statusIcon, color: statusColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${order['customer_name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${order['customer_phone']}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  if (createdAt != null)
                    Text(
                      DateFormat('dd.MM.yyyy HH:mm').format(createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: paymentMethod == 'BLIK'
                              ? Colors.purple.shade100
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          paymentMethod,
                          style: TextStyle(
                            fontSize: 11,
                            color: paymentMethod == 'BLIK'
                                ? Colors.purple.shade800
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          paymentStatus,
                          style: TextStyle(fontSize: 11, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${formatNum(order['total_price'], 2)} PLN',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (paymentStatus == 'PENDING')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green, size: 20),
                        tooltip: 'Oznacz jako opłacone',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onUpdateStatus(order['id'], 'PAID'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 20),
                        tooltip: 'Anuluj',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onUpdateStatus(order['id'], 'CANCELLED'),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
