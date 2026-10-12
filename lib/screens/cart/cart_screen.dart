import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../utils/config.dart';
import '../../widgets/product_card.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  void _safe(BuildContext context, Future<void> f) => f.catchError((e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: Text('Keranjang (${cart.count})')),
      body: cart.loading && cart.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : cart.error != null && cart.items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cart.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _safe(context, cart.fetch()),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
          : cart.items.isEmpty
              ? const Center(child: Text('Keranjang masih kosong'))
              : ListView(padding: const EdgeInsets.all(12), children: [
                  if (cart.error != null)
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(cart.error!),
                      ),
                    ),
                  for (final i in cart.items)
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(children: [
                          SizedBox(width: 70, height: 70, child: ProductImage(i.product.image)),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(i.product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(rp(i.product.price)),
                            Row(children: [
                              IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => _safe(context, cart.update(i, i.quantity - 1))),
                              Text('${i.quantity}'),
                              IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => _safe(context, cart.update(i, i.quantity + 1))),
                              const Spacer(),
                              Text(rp(i.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ]),
                          ])),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _safe(context, cart.remove(i))),
                        ]),
                      ),
                    ),
                ]),
      bottomNavigationBar: cart.items.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    const Text('Total Belanja'),
                    Text(rp(cart.total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                  ])),
                  FilledButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                      child: const Text('Lanjut ke Checkout')),
                ]),
              ),
            ),
    );
  }
}
