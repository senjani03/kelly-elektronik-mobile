import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../services/api.dart';
import '../../widgets/product_card.dart';
import '../cart/cart_screen.dart';
import '../order/order_screens.dart';
import '../product/product_screens.dart';
import '../profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  final int initialTab;
  final int? initialOrderId;
  final String? initialMessage;

  const MainShell({
    super.key,
    this.initialTab = 0,
    this.initialOrderId,
    this.initialMessage,
  });
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  @override
  void initState() {
    super.initState();
    index = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().fetch();
      if (widget.initialOrderId != null) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OrderDetailScreen(widget.initialOrderId!),
          ),
        );
      }
      if (widget.initialMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.initialMessage!)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = context.watch<CartProvider>().count;
    final pages = [
      const HomeTab(),
      const CategoryTab(),
      const CartScreen(),
      const OrderListScreen(),
      const ProfileScreen()
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Beranda'),
          const NavigationDestination(
              icon: Icon(Icons.grid_view), label: 'Kategori'),
          NavigationDestination(
              icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.shopping_cart_outlined)),
              label: 'Keranjang'),
          const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'Pesanan'),
          const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Akun'),
        ],
      ),
    );
  }
}

Future<List<Category>> fetchCategories() async {
  final r = await Api.req('GET', '/categories');
  return (r['data'] as List).map((e) => Category.fromJson(e)).toList();
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final Future<List<Category>> categories = fetchCategories();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
              hintText: 'Cari produk, merek, atau kategori...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none)),
          onSubmitted: (q) => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ProductListScreen(title: 'Hasil: $q', search: q))),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF60A5FA)])),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Peralatan Elektronik\nLengkap untuk Rumah Anda',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1D4ED8)),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const ProductListScreen(title: 'Semua Produk'))),
                child: const Text('Belanja Sekarang')),
          ]),
        ),
        const SizedBox(height: 20),
        const Text('Kategori Pilihan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        FutureBuilder<List<Category>>(
          future: categories,
          builder: (c, s) {
            if (s.hasError) return Center(child: Text('${s.error}'));
            if (!s.hasData) return const LinearProgressIndicator();
            if (s.data!.isEmpty) return const Text('Belum ada kategori');
            return SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final cat in s.data!)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(cat.name),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductListScreen(
                              title: cat.name,
                              categoryId: cat.id,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const ProductStrip('Produk Terlaris', 'best_selling'),
        const ProductStrip('Produk Terbaru', 'latest'),
      ]),
    );
  }
}

class ProductStrip extends StatefulWidget {
  final String title, sort;
  const ProductStrip(this.title, this.sort, {super.key});

  @override
  State<ProductStrip> createState() => _ProductStripState();
}

class _ProductStripState extends State<ProductStrip> {
  late final Future<dynamic> products = Api.req(
    'GET',
    '/products',
    query: {'sort': widget.sort, 'per_page': '8'},
  );

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 20),
        Text(widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(
          height: 250,
          child: FutureBuilder(
            future: products,
            builder: (c, s) {
              if (s.hasError) return Center(child: Text('${s.error}'));
              if (!s.hasData)
                return const Center(child: CircularProgressIndicator());
              final list = ((s.data as Map)['data'] as List)
                  .map((e) => Product.fromJson(e))
                  .toList();
              return ListView(scrollDirection: Axis.horizontal, children: [
                for (final p in list)
                  SizedBox(width: 165, child: ProductCard(p)),
              ]);
            },
          ),
        ),
      ]);
}

class CategoryTab extends StatefulWidget {
  const CategoryTab({super.key});

  @override
  State<CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<CategoryTab> {
  late final Future<List<Category>> categories = fetchCategories();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Kategori')),
        body: FutureBuilder<List<Category>>(
          future: categories,
          builder: (c, s) {
            if (s.hasError) return Center(child: Text('${s.error}'));
            if (!s.hasData)
              return const Center(child: CircularProgressIndicator());
            return ListView(children: [
              for (final cat in s.data!)
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(cat.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ProductListScreen(
                              title: cat.name, categoryId: cat.id))),
                ),
            ]);
          },
        ),
      );
}
