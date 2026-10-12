import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api.dart';

class CartProvider extends ChangeNotifier {
  List<CartItem> items = [];
  bool loading = false;
  String? error;
  num get total => items.fold(0, (s, i) => s + i.subtotal);
  int get count => items.fold(0, (s, i) => s + i.quantity);

  Future<void> fetch() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final r = await Api.req('GET', '/cart');
      items = (r['data'] as List).map((e) => CartItem.fromJson(e)).toList();
    } catch (e) {
      error = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> add(int productId, [int qty = 1]) async {
    await Api.req('POST', '/cart', body: {'product_id': productId, 'quantity': qty});
    await fetch();
  }

  Future<void> update(CartItem i, int qty) async {
    if (qty < 1) return;
    await Api.req('PUT', '/cart/${i.id}', body: {'quantity': qty});
    await fetch();
  }

  Future<void> remove(CartItem i) async {
    await Api.req('DELETE', '/cart/${i.id}');
    await fetch();
  }

  void clear() {
    items = [];
    error = null;
    notifyListeners();
  }
}
