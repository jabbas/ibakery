import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/home_screen.dart';
import 'screens/offer_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/order_confirm_screen.dart';
import 'screens/order_status_screen.dart';

void main() {
  runApp(const ProviderScope(child: ClientApp()));
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/offer/:id',
        builder: (context, state) => OfferDetailScreen(
          offerId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/order/confirm',
        builder: (context, state) => const OrderConfirmScreen(),
      ),
      GoRoute(
        path: '/order/:id',
        builder: (context, state) => OrderStatusScreen(
          orderId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});

class ClientApp extends ConsumerWidget {
  const ClientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'iBakery',
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
