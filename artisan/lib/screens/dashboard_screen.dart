import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Główny'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Witaj w panelu piekarza!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Zarządzaj swoją piekarnią z jednego miejsca.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 500;
                  final cardWidth = isMobile
                      ? constraints.maxWidth
                      : constraints.maxWidth > 900
                          ? (constraints.maxWidth - 32) / 3
                          : (constraints.maxWidth - 16) / 2;

                  final cards = [
                    _DashboardCard(
                      icon: Icons.straighten,
                      title: 'Jednostki',
                      subtitle: 'Zarządzaj jednostkami miary',
                      color: Colors.blue,
                      onTap: () => context.go('/units'),
                      compact: isMobile,
                    ),
                    _DashboardCard(
                      icon: Icons.egg,
                      title: 'Składniki',
                      subtitle: 'Zarządzaj składnikami',
                      color: Colors.orange,
                      onTap: () => context.go('/ingredients'),
                      compact: isMobile,
                    ),
                    _DashboardCard(
                      icon: Icons.bakery_dining,
                      title: 'Produkty',
                      subtitle: 'Zarządzaj produktami',
                      color: Colors.brown,
                      onTap: () => context.go('/products'),
                      compact: isMobile,
                    ),
                    _DashboardCard(
                      icon: Icons.local_offer,
                      title: 'Oferty',
                      subtitle: 'Twórz i zarządzaj ofertami',
                      color: Colors.green,
                      onTap: () => context.go('/offers'),
                      compact: isMobile,
                    ),
                    _DashboardCard(
                      icon: Icons.receipt_long,
                      title: 'Zamówienia',
                      subtitle: 'Przeglądaj zamówienia',
                      color: Colors.purple,
                      onTap: () => context.go('/orders'),
                      compact: isMobile,
                    ),
                  ];

                  return SingleChildScrollView(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: cards
                          .map((card) => SizedBox(
                                width: cardWidth,
                                child: card,
                              ))
                          .toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 32, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 48, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
