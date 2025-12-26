import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/units_screen.dart';
import 'screens/ingredients_screen.dart';
import 'screens/products_screen.dart';
import 'screens/offers_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/pickup_points_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const ProviderScope(child: BakerApp()));
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => DashboardShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/units',
            builder: (context, state) => const UnitsScreen(),
          ),
          GoRoute(
            path: '/ingredients',
            builder: (context, state) => const IngredientsScreen(),
          ),
          GoRoute(
            path: '/products',
            builder: (context, state) => const ProductsScreen(),
          ),
          GoRoute(
            path: '/offers',
            builder: (context, state) => const OffersScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/pickup-points',
            builder: (context, state) => const PickupPointsScreen(),
          ),
        ],
      ),
    ],
  );
});

class BakerApp extends ConsumerWidget {
  const BakerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'iBakery - Panel Piekarza',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

class DashboardShell extends ConsumerWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _getSelectedIndex(context),
            onDestinationSelected: (index) => _onDestinationSelected(context, index),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(Icons.bakery_dining, size: 40, color: Theme.of(context).primaryColor),
                  const SizedBox(height: 8),
                  const Text('iBakery', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () {
                      ref.read(authStateProvider.notifier).logout();
                      context.go('/login');
                    },
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Panel'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.straighten_outlined),
                selectedIcon: Icon(Icons.straighten),
                label: Text('Jednostki'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.egg_outlined),
                selectedIcon: Icon(Icons.egg),
                label: Text('Składniki'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bakery_dining_outlined),
                selectedIcon: Icon(Icons.bakery_dining),
                label: Text('Produkty'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_offer_outlined),
                selectedIcon: Icon(Icons.local_offer),
                label: Text('Oferty'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Zamówienia'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.location_on_outlined),
                selectedIcon: Icon(Icons.location_on),
                label: Text('Punkty odbioru'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/units')) return 1;
    if (location.startsWith('/ingredients')) return 2;
    if (location.startsWith('/products')) return 3;
    if (location.startsWith('/offers')) return 4;
    if (location.startsWith('/orders')) return 5;
    if (location.startsWith('/pickup-points')) return 6;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/units');
        break;
      case 2:
        context.go('/ingredients');
        break;
      case 3:
        context.go('/products');
        break;
      case 4:
        context.go('/offers');
        break;
      case 5:
        context.go('/orders');
        break;
      case 6:
        context.go('/pickup-points');
        break;
    }
  }
}
