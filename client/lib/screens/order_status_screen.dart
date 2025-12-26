import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';

class OrderStatusScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderStatusScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends ConsumerState<OrderStatusScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final order = await ref.read(apiServiceProvider).getOrder(widget.orderId);
      setState(() {
        _order = order;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Zamówienie')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Błąd')),
        body: Center(child: Text('Nie znaleziono zamówienia')),
      );
    }

    final order = _order!;
    final paymentStatus = order['payment_status'] ?? 'PENDING';
    final paymentMethod = order['payment_method'] ?? 'CASH';
    final createdAt = DateTime.tryParse(order['created_at'] ?? '');

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (paymentStatus) {
      case 'PAID':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Opłacone';
        break;
      case 'CANCELLED':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Anulowane';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Oczekuje na płatność';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Potwierdzenie zamówienia'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              'Zamówienie złożone!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Numer zamówienia: ${widget.orderId.substring(0, 8)}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 32),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Status płatności'),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow('Imię i nazwisko', order['customer_name']),
                    _buildInfoRow('Telefon', order['customer_phone']),
                    _buildInfoRow('Email', order['customer_email']),
                    _buildInfoRow('Metoda płatności', paymentMethod == 'BLIK' ? 'BLIK' : 'Przy odbiorze'),
                    _buildInfoRow('Suma', '${order['total_price']} PLN'),
                    if (createdAt != null)
                      _buildInfoRow('Data zamówienia', DateFormat('dd.MM.yyyy HH:mm').format(createdAt)),
                  ],
                ),
              ),
            ),
            if (paymentMethod == 'BLIK' && paymentStatus == 'PENDING') ...[
              const SizedBox(height: 24),
              Card(
                color: Colors.purple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.payment, size: 40, color: Colors.purple),
                      const SizedBox(height: 8),
                      const Text(
                        'Płatność BLIK',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Prześlij płatność BLIK na numer telefonu piekarza. '
                        'Po zaksięgowaniu płatności status zamówienia zostanie zaktualizowany.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.info, size: 32, color: Colors.blue),
                    SizedBox(height: 8),
                    Text(
                      'Potwierdzenie zostało wysłane na podany email i SMS. '
                      'Pamiętaj o odbiorze zamówienia w wyznaczonym terminie!',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Powrót do strony głównej'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value ?? '-', style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
