import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../services/api.dart';
import '../../utils/config.dart';
import '../../widgets/product_card.dart';
import '../checkout/checkout_screen.dart';

class ProductListScreen extends StatefulWidget {
  final String title;
  final int? categoryId;
  final String? search;
  const ProductListScreen({super.key, required this.title, this.categoryId, this.search});
  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<dynamic> future;
  late final TextEditingController searchController;
  late final TextEditingController minPriceController;
  late final TextEditingController maxPriceController;
  String? search, minP, maxP;

  @override
  void initState() {
    super.initState();
    search = widget.search;
    searchController = TextEditingController(text: search);
    minPriceController = TextEditingController();
    maxPriceController = TextEditingController();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    super.dispose();
  }

  void load() => future = Api.req('GET', '/products', query: {
        if (widget.categoryId != null) 'category_id': '${widget.categoryId}',
        if (search != null && search!.isNotEmpty) 'search': search!,
        if (minP != null && minP!.isNotEmpty) 'min_price': minP!,
        if (maxP != null && maxP!.isNotEmpty) 'max_price': maxP!,
      });

  Future<void> filter() async {
    minPriceController.text = minP ?? '';
    maxPriceController.text = maxP ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Filter Harga'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: minPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga minimum')),
          TextField(controller: maxPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga maksimum')),
        ]),
        actions: [
          TextButton(onPressed: () { minPriceController.clear(); maxPriceController.clear(); Navigator.pop(context, true); }, child: const Text('Reset')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Terapkan')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        minP = minPriceController.text.trim();
        maxP = maxPriceController.text.trim();
        load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: [IconButton(icon: const Icon(Icons.filter_list), onPressed: filter)]),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(hintText: 'Cari produk...', prefixIcon: const Icon(Icons.search), filled: true,
                  fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              onSubmitted: (q) => setState(() { search = q.trim(); load(); }),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: future,
              builder: (c, s) {
                if (s.hasError) return Center(child: Text('${s.error}'));
                if (!s.hasData) return const Center(child: CircularProgressIndicator());
                final list = ((s.data as Map)['data'] as List).map((e) => Product.fromJson(e)).toList();
                if (list.isEmpty) return const Center(child: Text('Produk tidak ditemukan'));
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: list.length,
                  itemBuilder: (_, i) => ProductCard(list[i]),
                );
              },
            ),
          ),
        ]),
      );
}

class ProductDetailScreen extends StatefulWidget {
  final int id;
  const ProductDetailScreen(this.id, {super.key});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<dynamic> future = Api.req('GET', '/products/${widget.id}');
  int qty = 1;

  Future<bool> addToCart(Product p) async {
    try {
      await context.read<CartProvider>().add(p.id, qty);
      return true;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Detail Produk')),
        body: FutureBuilder(
          future: future,
          builder: (c, s) {
            if (s.hasError) return Center(child: Text('${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final p = Product.fromJson((s.data as Map)['data']);
            final ready = p.stock > 0;
            return Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Container(color: Colors.white, padding: const EdgeInsets.all(12), child: ProductImage(p.image, height: 240)),
                  const SizedBox(height: 12),
                  Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(rp(p.price), style: const TextStyle(fontSize: 22, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(ready ? 'Stok tersedia: ${p.stock}' : 'Stok habis',
                      style: TextStyle(color: ready ? Colors.green : Colors.red, fontWeight: FontWeight.w600)),
                  const Divider(height: 24),
                  Text('Merek: ${p.brand}'),
                  Text('Kategori: ${p.category ?? '-'}'),
                  Text('Berat: ${p.weight} gram'),
                  const SizedBox(height: 12),
                  const Text('Deskripsi', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(p.description),
                ]),
              ),
              if (ready)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      IconButton(onPressed: qty > 1 ? () => setState(() => qty--) : null, icon: const Icon(Icons.remove_circle_outline)),
                      Text('$qty', style: const TextStyle(fontSize: 16)),
                      IconButton(onPressed: qty < p.stock ? () => setState(() => qty++) : null, icon: const Icon(Icons.add_circle_outline)),
                      const SizedBox(width: 4),
                      Expanded(child: OutlinedButton(
                          onPressed: () async {
                            if (await addToCart(p) && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ditambahkan ke keranjang')));
                            }
                          },
                          child: const Text('Keranjang'))),
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton(
                          onPressed: () async {
                            if (await addToCart(p) && mounted) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                            }
                          },
                          child: const Text('Beli Sekarang'))),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      );
}
