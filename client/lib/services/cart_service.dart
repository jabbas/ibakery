import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartItem {
  final String offerItemId;
  final String productName;
  final double price;
  int quantity;

  CartItem({
    required this.offerItemId,
    required this.productName,
    required this.price,
    this.quantity = 1,
  });

  double get total => price * quantity;
}

class CartState {
  final String? offerId;
  final String? offerTitle;
  final List<CartItem> items;

  CartState({this.offerId, this.offerTitle, this.items = const []});

  double get total => items.fold(0, (sum, item) => sum + item.total);

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  CartState copyWith({
    String? offerId,
    String? offerTitle,
    List<CartItem>? items,
  }) {
    return CartState(
      offerId: offerId ?? this.offerId,
      offerTitle: offerTitle ?? this.offerTitle,
      items: items ?? this.items,
    );
  }
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => CartState();

  void setOffer(String offerId, String offerTitle) {
    if (state.offerId != offerId) {
      state = CartState(offerId: offerId, offerTitle: offerTitle, items: []);
    }
  }

  void addItem(CartItem item) {
    final existingIndex = state.items.indexWhere(
      (i) => i.offerItemId == item.offerItemId,
    );

    if (existingIndex >= 0) {
      final updatedItems = List<CartItem>.from(state.items);
      updatedItems[existingIndex].quantity += item.quantity;
      state = state.copyWith(items: updatedItems);
    } else {
      state = state.copyWith(items: [...state.items, item]);
    }
  }

  void updateQuantity(String offerItemId, int quantity) {
    if (quantity <= 0) {
      removeItem(offerItemId);
      return;
    }

    final updatedItems = state.items.map((item) {
      if (item.offerItemId == offerItemId) {
        item.quantity = quantity;
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  void removeItem(String offerItemId) {
    final updatedItems = state.items.where(
      (item) => item.offerItemId != offerItemId,
    ).toList();
    state = state.copyWith(items: updatedItems);
  }

  void clear() {
    state = CartState();
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(() {
  return CartNotifier();
});
