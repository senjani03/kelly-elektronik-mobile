import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/api.dart';
import '../../utils/config.dart';

const _adminBlue = Color(0xFF1D4ED8);
const _adminInk = Color(0xFF172033);
const _adminSections = [
  ('Ringkasan', Icons.grid_view_rounded),
  ('Produk', Icons.inventory_2_outlined),
  ('Kategori', Icons.category_outlined),
  ('Pesanan', Icons.receipt_long_outlined),
  ('Pembayaran', Icons.payments_outlined),
  ('Pengguna', Icons.people_outline),
  ('Pengaturan', Icons.settings_outlined),
];

class AdminRoute extends StatefulWidget {
  const AdminRoute({super.key});

  @override
  State<AdminRoute> createState() => _AdminRouteState();
}

class _AdminRouteState extends State<AdminRoute> {
  bool checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authorize());
  }

  Future<void> _authorize() async {
    final auth = context.read<AuthProvider>();
    if (!auth.loggedIn) await auth.load();
    if (!mounted) return;
    if (!auth.loggedIn || !auth.isAdmin) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        auth.loggedIn ? '/home' : '/login',
        (_) => false,
      );
      return;
    }
    setState(() => checking = false);
  }

  @override
  Widget build(BuildContext context) => checking
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : const AdminConsole();
}

class AdminConsole extends StatefulWidget {
  const AdminConsole({super.key});

  @override
  State<AdminConsole> createState() => _AdminConsoleState();
}

class _AdminConsoleState extends State<AdminConsole> {
  int section = 0;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  String get title => _adminSections[section].$1;

  Widget _content() => switch (section) {
        0 => const DashboardPage(),
        1 => const CatalogPage(products: true),
        2 => const CatalogPage(products: false),
        3 => const OrdersPage(),
        4 => const PaymentsPage(),
        5 => const UsersPage(),
        _ => const SettingsPage(),
      };

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    context.read<CartProvider>().clear();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Widget _nav({bool drawer = false}) => SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 16, 18),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _adminBlue,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.storefront, color: Colors.white),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kelly Elektronik',
                            style: TextStyle(
                                color: _adminInk,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                        Text('ADMIN CONSOLE',
                            style: TextStyle(
                                color: Colors.blueGrey,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w700,
                                fontSize: 10)),
                      ]),
                ),
              ]),
            ),
            for (var i = 0; i < _adminSections.length; i++)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: ListTile(
                  selected: section == i,
                  selectedTileColor: const Color(0xFFEAF0FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: Icon(_adminSections[i].$2,
                      color: section == i ? _adminBlue : Colors.blueGrey),
                  title: Text(_adminSections[i].$1,
                      style: TextStyle(
                        color: section == i ? _adminBlue : _adminInk,
                        fontWeight:
                            section == i ? FontWeight.w700 : FontWeight.w500,
                      )),
                  onTap: () {
                    setState(() => section = i);
                    if (drawer) Navigator.pop(context);
                  },
                ),
              ),
            const Spacer(),
            const Divider(indent: 20, endIndent: 20),
            ListTile(
              leading: const Icon(Icons.open_in_new, color: Colors.blueGrey),
              title: const Text('Lihat toko'),
              onTap: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil('/home', (_) => false),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Keluar', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
            const SizedBox(height: 12),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 920;
    final user = context.watch<AuthProvider>().user ?? {};
    return Scaffold(
      key: scaffoldKey,
      drawer: wide
          ? null
          : Drawer(
              width: 280,
              backgroundColor: Colors.white,
              child: _nav(drawer: true),
            ),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        titleSpacing: wide ? 28 : 0,
        leading: wide
            ? null
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => scaffoldKey.currentState?.openDrawer(),
              ),
        title: Text(title,
            style: const TextStyle(
                color: _adminInk, fontWeight: FontWeight.w800, fontSize: 19)),
        actions: [
          if (width >= 600)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text('${user['name'] ?? 'Administrator'}',
                    style: const TextStyle(
                        color: _adminInk, fontWeight: FontWeight.w600)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 22),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFE0E8FF),
              child: Text(
                ('${user['name'] ?? 'A'}').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    color: _adminBlue, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Row(children: [
        if (wide)
          Container(
            width: 250,
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Color(0xFFE7EBF2)))),
            child: _nav(),
          ),
        Expanded(child: _content()),
      ]),
    );
  }
}

class _PageBody extends StatelessWidget {
  final Widget child;
  const _PageBody({required this.child});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1380),
          child: child,
        ),
      );
}

class _PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  const _PageHeader(this.title, this.subtitle, {this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: LayoutBuilder(builder: (context, constraints) {
          final heading =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: _adminInk)),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(color: Colors.blueGrey)),
          ]);
          if (action == null) return heading;
          if (constraints.maxWidth < 560) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading,
                  const SizedBox(height: 12),
                  action!,
                ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: heading),
            action!,
          ]);
        }),
      );
}

Widget _panel(
        {required Widget child,
        EdgeInsets padding = const EdgeInsets.all(18)}) =>
    Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EDF4)),
      ),
      child: child,
    );

Widget _loadingState() =>
    const Center(child: CircularProgressIndicator(color: _adminBlue));

Widget _errorState(Object error, VoidCallback retry) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined,
              size: 42, color: Colors.blueGrey),
          const SizedBox(height: 10),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi')),
        ]),
      ),
    );

Widget _emptyState(String title, String detail) => Padding(
      padding: const EdgeInsets.all(30),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.inbox_outlined, size: 44, color: Colors.blueGrey),
          const SizedBox(height: 10),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 5),
          Text(detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.blueGrey)),
        ]),
      ),
    );

Widget _pagination(Map? meta, int page, ValueChanged<int> onPage) {
  final lastPage = _number(meta?['last_page'] ?? 1).toInt().clamp(1, 100000);
  final total = _number(meta?['total'] ?? 0).toInt();
  if (lastPage <= 1 && total == 0) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(
        tooltip: 'Halaman sebelumnya',
        onPressed: page > 1 ? () => onPage(page - 1) : null,
        icon: const Icon(Icons.chevron_left),
      ),
      Text('Halaman $page dari $lastPage · $total data',
          style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
      IconButton(
        tooltip: 'Halaman berikutnya',
        onPressed: page < lastPage ? () => onPage(page + 1) : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ]),
  );
}

String _date(dynamic value) {
  if (value == null) return '-';
  final text = '$value';
  return text.length > 10 ? text.substring(0, 10) : text;
}

String _dateInput(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

Future<String?> _selectDate(BuildContext context, String? current) async {
  final today = DateTime.now();
  final initial = current == null ? today : DateTime.tryParse(current) ?? today;
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(today.year + 5),
  );
  return picked == null ? current : _dateInput(picked);
}

num _number(dynamic value) => num.tryParse('$value') ?? 0;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<dynamic> future;
  String salesPeriod = 'daily';
  @override
  void initState() {
    super.initState();
    future = Api.req('GET', '/admin/dashboard');
  }

  void refresh() => setState(() => future = Api.req('GET', '/admin/dashboard'));

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _errorState(snapshot.error!, refresh);
          if (!snapshot.hasData) return _loadingState();
          final data = (snapshot.data as Map)['data'] as Map? ?? {};
          final stats = data['stats'] as Map? ?? {};
          final cards = [
            (
              'Total penjualan',
              rp(_number(stats['sales_total'])),
              Icons.trending_up,
              const Color(0xFFE6F7EF)
            ),
            (
              'Pesanan',
              '${stats['orders_count'] ?? 0}',
              Icons.receipt_long,
              const Color(0xFFEAF0FF)
            ),
            (
              'Menunggu pembayaran',
              '${stats['pending_payments_count'] ?? 0}',
              Icons.hourglass_top,
              const Color(0xFFFFF3DE)
            ),
            (
              'Pengguna',
              '${stats['users_count'] ?? 0}',
              Icons.people_alt,
              const Color(0xFFF2EAFE)
            ),
            (
              'Stok menipis',
              '${stats['low_stock_count'] ?? 0}',
              Icons.inventory_2,
              const Color(0xFFFFE8E8)
            ),
          ];
          final sales = salesPeriod == 'monthly'
              ? (data['monthly_sales'] as List? ?? const [])
                  .map((row) => {
                        'label': row['month'],
                        'total': row['sales'],
                      })
                  .toList()
              : (data['sales'] as List? ?? const []);
          final recent = (data['recent_orders'] as List? ?? const []);
          return _PageBody(
            child: ListView(padding: const EdgeInsets.all(24), children: [
              _PageHeader('Selamat datang 👋',
                  'Pantau aktivitas toko dan tindak lanjuti operasional hari ini.',
                  action: IconButton(
                      tooltip: 'Muat ulang',
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh))),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth > 900
                    ? 5
                    : constraints.maxWidth > 590
                        ? 3
                        : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: constraints.maxWidth < 500 ? 1.45 : 1.7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final card in cards)
                      _panel(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CircleAvatar(
                                  radius: 17,
                                  backgroundColor: card.$4,
                                  child: Icon(card.$3,
                                      size: 18, color: _adminBlue)),
                              Text(card.$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: _adminInk)),
                              Text(card.$1,
                                  maxLines: 2,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.blueGrey)),
                            ]),
                      ),
                  ],
                );
              }),
              const SizedBox(height: 20),
              LayoutBuilder(builder: (context, constraints) {
                final stacked = constraints.maxWidth < 750;
                final chart = _panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Expanded(
                            child: Text('Penjualan',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'daily', label: Text('Harian')),
                              ButtonSegment(
                                  value: 'monthly', label: Text('Bulanan')),
                            ],
                            selected: {salesPeriod},
                            showSelectedIcon: false,
                            onSelectionChanged: (value) =>
                                setState(() => salesPeriod = value.first),
                          ),
                        ]),
                        Text(
                            salesPeriod == 'daily'
                                ? 'Penjualan 7 hari terakhir'
                                : 'Penjualan 12 bulan terakhir',
                            style: const TextStyle(color: Colors.blueGrey)),
                        const SizedBox(height: 20),
                        if (sales.isEmpty)
                          _emptyState('Belum ada data penjualan',
                              'Data akan tampil setelah pesanan tercatat.')
                        else
                          ...sales.map((entry) {
                            final maxValue = sales.fold<num>(
                                0,
                                (previous, item) =>
                                    _number((item as Map)['total']) > previous
                                        ? _number(item['total'])
                                        : previous);
                            final value = _number((entry as Map)['total']);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(children: [
                                SizedBox(
                                    width: 85,
                                    child: Text('${entry['label'] ?? ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11))),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: LinearProgressIndicator(
                                      minHeight: 11,
                                      value:
                                          maxValue == 0 ? 0 : value / maxValue,
                                      backgroundColor: const Color(0xFFEAF0FF),
                                      color: _adminBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(rp(value),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ]),
                            );
                          }),
                      ]),
                );
                final recentOrders = _panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pesanan terbaru',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        if (recent.isEmpty)
                          _emptyState('Belum ada pesanan',
                              'Pesanan terbaru akan ditampilkan di sini.')
                        else
                          for (final order in recent)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  '${order['code'] ?? '#${order['id']}'}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  '${order['customer_name'] ?? order['recipient_name'] ?? 'Pelanggan'} · ${_date(order['created_at'])}'),
                              trailing: Text(
                                statusLabel['${order['status']}'] ??
                                    '${order['status'] ?? '-'}',
                                style: const TextStyle(
                                    fontSize: 11, color: _adminBlue),
                              ),
                            ),
                      ]),
                );
                return stacked
                    ? Column(children: [
                        chart,
                        const SizedBox(height: 14),
                        recentOrders
                      ])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Expanded(flex: 3, child: chart),
                            const SizedBox(width: 14),
                            Expanded(flex: 2, child: recentOrders),
                          ]);
              }),
            ]),
          );
        },
      );
}

class CatalogPage extends StatefulWidget {
  final bool products;
  const CatalogPage({super.key, required this.products});
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late Future<dynamic> future;
  final search = TextEditingController();
  String searchQuery = '';
  String? categoryFilter;
  String statusFilter = '';
  String sort = 'latest';
  List categories = [];
  int page = 1;
  @override
  void initState() {
    super.initState();
    future = _load();
    if (widget.products) _loadCategories();
  }

  Future<dynamic> _load() {
    final query = <String, String>{'page': '$page'};
    if (widget.products) {
      if (searchQuery.isNotEmpty) query['search'] = searchQuery;
      if (categoryFilter != null) query['category_id'] = categoryFilter!;
      if (statusFilter.isNotEmpty) query['status'] = statusFilter;
      query['sort'] = sort;
    }
    return Api.req(
      'GET',
      widget.products ? '/admin/products' : '/admin/categories',
      query: query,
    );
  }

  Future<void> _loadCategories() async {
    try {
      final response = await Api.req('GET', '/admin/categories');
      if (mounted) setState(() => categories = response['data'] as List? ?? []);
    } catch (_) {}
  }

  void refresh() => setState(() {
        page = 1;
        future = _load();
      });

  void _changePage(int value) => setState(() {
        page = value;
        future = _load();
      });

  void _updateFilters(
      {String? query, String? category, String? status, String? order}) {
    setState(() {
      if (query != null) searchQuery = query.trim();
      if (category != null) categoryFilter = category.isEmpty ? null : category;
      if (status != null) statusFilter = status;
      if (order != null) sort = order;
      page = 1;
      future = _load();
    });
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _edit([Map? item]) async {
    final result = await showDialog<bool>(
        context: context,
        builder: (_) => _CatalogDialog(products: widget.products, item: item));
    if (result == true) refresh();
  }

  Future<void> _delete(Map item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus data?'),
        content: Text(
            'Apakah Anda yakin ingin menghapus ${widget.products ? 'produk' : 'kategori'} “${item['name']}”?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Api.req('DELETE',
          '/admin/${widget.products ? 'products' : 'categories'}/${item['id']}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data berhasil dihapus.')));
        refresh();
      }
    } catch (error) {
      if (mounted) _snack(context, '$error');
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _errorState(snapshot.error!, refresh);
          if (!snapshot.hasData) return _loadingState();
          final items = List<Map>.from(
              ((snapshot.data as Map)['data'] as List? ?? const [])
                  .whereType<Map>());
          final meta = (snapshot.data as Map)['meta'] as Map?;
          final filtered = widget.products
              ? items
              : items.where((item) {
                  final query = searchQuery.toLowerCase();
                  return query.isEmpty ||
                      '${item['name']}'.toLowerCase().contains(query);
                }).toList();
          return _PageBody(
            child: ListView(padding: const EdgeInsets.all(24), children: [
              _PageHeader(
                widget.products ? 'Produk' : 'Kategori',
                widget.products
                    ? 'Kelola katalog, harga, stok, dan gambar produk.'
                    : 'Atur kategori yang tersedia di toko.',
                action: FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add),
                  label: Text(widget.products ? 'Tambah produk' : 'Tambah'),
                ),
              ),
              TextField(
                controller: search,
                onChanged: (value) {
                  if (widget.products) {
                    _updateFilters(query: value);
                  } else {
                    setState(() {
                      searchQuery = value.trim();
                      page = 1;
                      future = _load();
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText: widget.products
                      ? 'Cari nama atau merek produk'
                      : 'Cari kategori',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE9EDF4))),
                ),
              ),
              if (widget.products) ...[
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 620;
                  final filters = [
                    DropdownButtonFormField<String>(
                      initialValue: categoryFilter ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: '', child: Text('Semua kategori')),
                        for (final category in categories)
                          DropdownMenuItem(
                            value: '${category['id']}',
                            child: Text('${category['name']}',
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (value) =>
                          _updateFilters(category: value ?? ''),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: statusFilter,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: '', child: Text('Semua status')),
                        DropdownMenuItem(value: 'active', child: Text('Aktif')),
                        DropdownMenuItem(
                            value: 'inactive', child: Text('Nonaktif')),
                      ],
                      onChanged: (value) => _updateFilters(status: value ?? ''),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: sort,
                      decoration: const InputDecoration(
                        labelText: 'Urutkan',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'latest', child: Text('Terbaru')),
                        DropdownMenuItem(
                            value: 'oldest', child: Text('Terlama')),
                        DropdownMenuItem(
                            value: 'name_asc', child: Text('Nama A–Z')),
                        DropdownMenuItem(
                            value: 'name_desc', child: Text('Nama Z–A')),
                        DropdownMenuItem(
                            value: 'price_asc', child: Text('Harga terendah')),
                        DropdownMenuItem(
                            value: 'price_desc',
                            child: Text('Harga tertinggi')),
                        DropdownMenuItem(
                            value: 'stock_asc', child: Text('Stok terendah')),
                        DropdownMenuItem(
                            value: 'stock_desc', child: Text('Stok tertinggi')),
                      ],
                      onChanged: (value) =>
                          _updateFilters(order: value ?? 'latest'),
                    ),
                  ];
                  return narrow
                      ? Column(
                          children: filters
                              .map((filter) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: filter,
                                  ))
                              .toList(),
                        )
                      : Row(
                          children: [
                            for (var i = 0; i < filters.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              Expanded(child: filters[i]),
                            ],
                          ],
                        );
                }),
              ],
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                _panel(
                    child: _emptyState(
                        'Tidak ada data ditemukan',
                        widget.products
                            ? 'Tambahkan produk atau ubah kata pencarian.'
                            : 'Tambahkan kategori atau ubah kata pencarian.'))
              else
                ...filtered.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _catalogCard(item),
                    )),
              _pagination(meta, page, _changePage),
            ]),
          );
        },
      );

  Widget _catalogCard(Map item) {
    final image = '${item['image_url'] ?? item['image'] ?? ''}';
    return _panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        if (widget.products)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: image.isEmpty
                ? Container(
                    width: 62,
                    height: 62,
                    color: const Color(0xFFEAF0FF),
                    child: const Icon(Icons.image_outlined, color: _adminBlue))
                : Image.network(resolveProductImageUrl(image),
                    width: 62,
                    height: 62,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 62,
                        height: 62,
                        color: const Color(0xFFEAF0FF),
                        child: const Icon(Icons.broken_image_outlined))),
          ),
        if (widget.products) const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${item['name'] ?? '-'}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: _adminInk)),
            if (widget.products) ...[
              Text(
                  '${item['brand'] ?? 'Tanpa merek'} · ${item['category'] is Map ? item['category']['name'] : item['category'] ?? 'Tanpa kategori'}',
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
              const SizedBox(height: 3),
              Text('${rp(_number(item['price']))} · Stok ${item['stock'] ?? 0}',
                  style: const TextStyle(
                      color: _adminBlue, fontWeight: FontWeight.w700)),
              Text(
                  item['is_active'] == false || item['is_active'] == 0
                      ? 'Nonaktif'
                      : 'Aktif',
                  style: TextStyle(
                      fontSize: 11,
                      color:
                          item['is_active'] == false || item['is_active'] == 0
                              ? Colors.red
                              : Colors.green)),
            ] else
              Text(
                  '${item['products_count'] ?? item['product_count'] ?? 0} produk',
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
          ]),
        ),
        IconButton(
            tooltip: 'Ubah',
            onPressed: () => _edit(item),
            icon: const Icon(Icons.edit_outlined)),
        IconButton(
            tooltip: 'Hapus',
            onPressed: () => _delete(item),
            icon: const Icon(Icons.delete_outline, color: Colors.red)),
      ]),
    );
  }
}

class _CatalogDialog extends StatefulWidget {
  final bool products;
  final Map? item;
  const _CatalogDialog({required this.products, this.item});
  @override
  State<_CatalogDialog> createState() => _CatalogDialogState();
}

class _CatalogDialogState extends State<_CatalogDialog> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final brand = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final stock = TextEditingController();
  final weight = TextEditingController();
  final imageUrl = TextEditingController();
  dynamic categoryId;
  List categories = [];
  bool active = true, saving = false;
  bool loadingCategories = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item ?? {};
    name.text = '${item['name'] ?? ''}';
    brand.text = '${item['brand'] ?? ''}';
    description.text = '${item['description'] ?? ''}';
    price.text = '${item['price'] ?? ''}';
    stock.text = '${item['stock'] ?? ''}';
    weight.text = '${item['weight'] ?? ''}';
    imageUrl.text = '${item['image_url'] ?? ''}';
    active = item['is_active'] != false && item['is_active'] != 0;
    categoryId = item['category_id'] ??
        (item['category'] is Map ? item['category']['id'] : null);
    if (widget.products) _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => loadingCategories = true);
    try {
      final result = await Api.req('GET', '/admin/categories');
      if (mounted) {
        setState(() {
          categories = result['data'] as List? ?? [];
          loadingCategories = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loadingCategories = false);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Wajib diisi' : null;

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    if (widget.products && categoryId == null) {
      _snack(context, 'Pilih kategori produk terlebih dahulu.');
      return;
    }
    setState(() => saving = true);
    try {
      final id = widget.item?['id'];
      final path =
          '/admin/${widget.products ? 'products' : 'categories'}${id == null ? '' : '/$id'}';
      final body = widget.products
          ? {
              'name': name.text.trim(),
              'brand': brand.text.trim(),
              'description': description.text.trim(),
              'price': num.parse(price.text.trim()),
              'stock': int.parse(stock.text.trim()),
              'weight': num.tryParse(weight.text.trim()) ?? 0,
              'image_url':
                  imageUrl.text.trim().isEmpty ? null : imageUrl.text.trim(),
              'is_active': active,
              if (categoryId != null) 'category_id': categoryId,
            }
          : {'name': name.text.trim()};
      await Api.req(id == null ? 'POST' : 'PUT', path, body: body);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _snack(context, '$error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    brand.dispose();
    description.dispose();
    price.dispose();
    stock.dispose();
    weight.dispose();
    imageUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item == null ? 'Tambah' : 'Ubah';
    return AlertDialog(
      title: Text('$title ${widget.products ? 'produk' : 'kategori'}'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _field(name, 'Nama', validator: _required),
              if (widget.products) ...[
                _field(brand, 'Merek', validator: _required),
                _field(description, 'Deskripsi', maxLines: 3),
                _field(price, 'Harga (Rp)',
                    validator: (v) => num.tryParse(v ?? '') == null
                        ? 'Masukkan harga yang valid'
                        : null,
                    keyboard: TextInputType.number),
                _field(stock, 'Stok',
                    validator: (v) => int.tryParse(v ?? '') == null
                        ? 'Masukkan jumlah stok yang valid'
                        : null,
                    keyboard: TextInputType.number),
                _field(weight, 'Berat (gram)',
                    validator: (v) => (num.tryParse(v ?? '') ?? -1) < 0
                        ? 'Berat harus berupa angka positif'
                        : null,
                    keyboard: TextInputType.number),
                _field(imageUrl, 'URL gambar', validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final uri = Uri.tryParse(value.trim());
                  return uri != null &&
                          (uri.scheme == 'http' || uri.scheme == 'https') &&
                          uri.host.isNotEmpty
                      ? null
                      : 'Masukkan URL gambar yang valid';
                }, keyboard: TextInputType.url),
                const SizedBox(height: 12),
                DropdownButtonFormField<dynamic>(
                  initialValue:
                      categories.any((c) => '${c['id']}' == '$categoryId')
                          ? categoryId
                          : null,
                  decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_outlined)),
                  items: [
                    for (final category in categories)
                      DropdownMenuItem(
                          value: category['id'],
                          child: Text('${category['name']}')),
                  ],
                  validator: (value) =>
                      value == null ? 'Pilih kategori produk' : null,
                  onChanged: loadingCategories
                      ? null
                      : (value) => setState(() => categoryId = value),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Produk aktif'),
                  subtitle:
                      const Text('Produk nonaktif tidak ditampilkan di toko.'),
                  value: active,
                  onChanged: (value) => setState(() => active = value),
                ),
                if (loadingCategories)
                  const LinearProgressIndicator(minHeight: 2),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('Batal')),
        FilledButton(
            onPressed: saving ? null : _save,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Simpan')),
      ],
    );
  }
}

Widget _field(TextEditingController controller, String label,
        {String? Function(String?)? validator,
        TextInputType? keyboard,
        int maxLines = 1}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
      ),
    );

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late Future<dynamic> future;
  final search = TextEditingController();
  String searchQuery = '';
  String statusFilter = '';
  int page = 1;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<dynamic> _load() => Api.req(
        'GET',
        '/admin/orders',
        query: {
          'page': '$page',
          if (searchQuery.isNotEmpty) 'search': searchQuery,
          if (statusFilter.isNotEmpty) 'status': statusFilter,
        },
      );
  void refresh() => setState(() {
        page = 1;
        future = _load();
      });
  void _changePage(int value) => setState(() {
        page = value;
        future = _load();
      });
  void _setFilters({String? searchValue, String? status}) => setState(() {
        if (searchValue != null) searchQuery = searchValue.trim();
        if (status != null) statusFilter = status;
        page = 1;
        future = _load();
      });

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final changed = await showDialog<bool>(
        context: context, builder: (_) => const _CreateOrderDialog());
    if (changed == true) refresh();
  }

  Future<void> _detail(Map order) async {
    final changed = await showDialog<bool>(
        context: context, builder: (_) => _OrderDetailDialog(id: order['id']));
    if (changed == true) refresh();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _errorState(snapshot.error!, refresh);
          if (!snapshot.hasData) return _loadingState();
          final orders = List<Map>.from(
              ((snapshot.data as Map)['data'] as List? ?? const [])
                  .whereType<Map>());
          final meta = (snapshot.data as Map)['meta'] as Map?;
          final filtered = orders;
          return _PageBody(
            child: ListView(padding: const EdgeInsets.all(24), children: [
              _PageHeader('Pesanan',
                  'Tinjau detail, perbarui status, dan kelola pengiriman.',
                  action: FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Buat pesanan'))),
              TextField(
                controller: search,
                onChanged: (value) => _setFilters(searchValue: value),
                decoration: const InputDecoration(
                    hintText: 'Cari kode atau nama pelanggan',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: statusFilter,
                decoration: const InputDecoration(
                  labelText: 'Status pesanan',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Semua status')),
                  DropdownMenuItem(
                      value: 'pending_payment',
                      child: Text('Menunggu pembayaran')),
                  DropdownMenuItem(
                      value: 'processing', child: Text('Diproses')),
                  DropdownMenuItem(value: 'shipped', child: Text('Dikirim')),
                  DropdownMenuItem(value: 'delivered', child: Text('Terkirim')),
                  DropdownMenuItem(
                      value: 'cancelled', child: Text('Dibatalkan')),
                ],
                onChanged: (value) => _setFilters(status: value ?? ''),
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                _panel(
                    child: _emptyState('Belum ada pesanan',
                        'Pesanan toko akan muncul di daftar ini.'))
              else
                ...filtered.map((order) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _orderCard(order),
                    )),
              _pagination(meta, page, _changePage),
            ]),
          );
        },
      );

  Widget _orderCard(Map order) => _panel(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(children: [
          const CircleAvatar(
              backgroundColor: Color(0xFFEAF0FF),
              child: Icon(Icons.receipt_long, color: _adminBlue)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${order['code'] ?? '#${order['id']}'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: _adminInk)),
              Text(
                  '${order['user']?['name'] ?? order['recipient_name'] ?? 'Pelanggan'} · ${_date(order['created_at'])}',
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
              const SizedBox(height: 3),
              Text(rp(_number(order['total'])),
                  style: const TextStyle(
                      color: _adminBlue, fontWeight: FontWeight.w700)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _StatusPill('${order['status'] ?? 'pending_payment'}'),
            IconButton(
                tooltip: 'Detail pesanan',
                onPressed: () => _detail(order),
                icon: const Icon(Icons.chevron_right)),
          ]),
        ]),
      );
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill(this.status);
  @override
  Widget build(BuildContext context) {
    final label = statusLabel[status] ??
        switch (status) {
          'pending' => 'Menunggu',
          'proof_submitted' => 'Bukti diterima',
          'rejected' => 'Ditolak',
          'paid' => 'Dibayar',
          'expired' => 'Kedaluwarsa',
          _ => status,
        };
    final color = switch (status) {
      'completed' || 'delivered' || 'paid' => Colors.green,
      'cancelled' => Colors.red,
      'shipped' => Colors.blue,
      'pending_payment' => Colors.orange,
      _ => _adminBlue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _OrderDetailDialog extends StatefulWidget {
  final dynamic id;
  const _OrderDetailDialog({required this.id});
  @override
  State<_OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends State<_OrderDetailDialog> {
  late Future<dynamic> future;
  final tracking = TextEditingController();
  final note = TextEditingController();
  String? status;
  bool initialized = false, saving = false;

  @override
  void initState() {
    super.initState();
    future = Api.req('GET', '/admin/orders/${widget.id}');
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await Api.req('PUT', '/admin/orders/${widget.id}', body: {
        if (status != null) 'status': status,
        'tracking_number': tracking.text.trim(),
        'admin_notes': note.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _snack(context, '$error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _cancelOrder() async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Batalkan pesanan?'),
              content:
                  const Text('Status pesanan akan diubah menjadi dibatalkan.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Kembali')),
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Batalkan')),
              ],
            ));
    if (yes != true) return;
    setState(() => saving = true);
    try {
      await Api.req('PUT', '/admin/orders/${widget.id}',
          body: {'status': 'cancelled'});
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _snack(context, '$error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _deleteOrder() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus pesanan?'),
        content: const Text(
            'Pesanan akan dihapus permanen. Stok akan dipulihkan bila pesanan belum dikirim.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus pesanan'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    setState(() => saving = true);
    try {
      await Api.req('DELETE', '/admin/orders/${widget.id}');
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _snack(context, '$error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    tracking.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Detail pesanan'),
        content: SizedBox(
          width: 560,
          child: FutureBuilder(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Text('Gagal memuat pesanan: ${snapshot.error}');
              if (!snapshot.hasData)
                return const SizedBox(
                    height: 150,
                    child: Center(child: CircularProgressIndicator()));
              final order = (snapshot.data as Map)['data'] as Map? ??
                  snapshot.data as Map;
              if (!initialized) {
                status = '${order['status'] ?? 'pending_payment'}';
                tracking.text = '${order['tracking_number'] ?? ''}';
                note.text = '${order['admin_notes'] ?? ''}';
                initialized = true;
              }
              final items = (order['items'] as List? ??
                  order['order_items'] as List? ??
                  []);
              return SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${order['code'] ?? '#${order['id']}'}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                          '${order['user']?['name'] ?? order['recipient_name'] ?? 'Pelanggan'} · ${order['phone'] ?? ''}'),
                      Text('${order['address'] ?? '-'}'),
                      Text('Dibuat ${_date(order['created_at'])}'),
                      const Divider(height: 24),
                      for (final line in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              '${line['product']?['name'] ?? line['product_name'] ?? 'Produk'}'),
                          subtitle: Text(
                              '${line['quantity'] ?? 1} × ${rp(_number(line['price'] ?? line['unit_price']))}'),
                          trailing: Text(
                              rp(_number(line['subtotal'] ?? line['price']))),
                        ),
                      const Divider(height: 24),
                      Text('Total: ${rp(_number(order['total']))}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(
                            labelText: 'Status pesanan',
                            border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(
                              value: 'pending_payment',
                              child: Text('Menunggu pembayaran')),
                          DropdownMenuItem(
                              value: 'processing', child: Text('Diproses')),
                          DropdownMenuItem(
                              value: 'shipped', child: Text('Dikirim')),
                          DropdownMenuItem(
                              value: 'delivered', child: Text('Terkirim')),
                          DropdownMenuItem(
                              value: 'cancelled', child: Text('Dibatalkan')),
                        ],
                        onChanged: (value) => setState(() => status = value),
                      ),
                      const SizedBox(height: 12),
                      _field(tracking, 'Nomor resi'),
                      _field(note, 'Catatan admin', maxLines: 3),
                    ]),
              );
            },
          ),
        ),
        actions: [
          if (status != 'cancelled' &&
              status != 'shipped' &&
              status != 'delivered')
            TextButton(
                onPressed: saving ? null : _cancelOrder,
                child: const Text('Batalkan pesanan',
                    style: TextStyle(color: Colors.red))),
          TextButton(
              onPressed: saving ? null : _deleteOrder,
              child: const Text('Hapus', style: TextStyle(color: Colors.red))),
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Tutup')),
          FilledButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan')),
        ],
      );
}

class _CreateOrderDialog extends StatefulWidget {
  const _CreateOrderDialog();
  @override
  State<_CreateOrderDialog> createState() => _CreateOrderDialogState();
}

class _CreateOrderDialogState extends State<_CreateOrderDialog> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController();
  List products = [], customers = [];
  dynamic customerId;
  dynamic productId;
  int quantity = 1;
  String paymentMethod = 'bank_transfer';
  bool loading = true, saving = false;
  String? loadingError;

  @override
  void initState() {
    super.initState();
    _loadFormOptions();
  }

  Future<void> _loadFormOptions() async {
    try {
      final results = await Future.wait([
        Api.req('GET', '/admin/products', query: {'status': 'active'}),
        Api.req('GET', '/admin/users',
            query: {'role': 'customer', 'status': 'active', 'per_page': '100'}),
      ]);
      if (!mounted) return;
      setState(() {
        products = results[0]['data'] as List? ?? [];
        customers = results[1]['data'] as List? ?? [];
        loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          loading = false;
          loadingError = '$error';
        });
      }
    }
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await Api.req('POST', '/admin/orders', body: {
        'user_id': customerId,
        'recipient_name': name.text.trim(),
        'phone': phone.text.trim(),
        'address': address.text.trim(),
        'payment_method': paymentMethod,
        'items': [
          {'product_id': productId, 'quantity': quantity}
        ],
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _snack(context, '$error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Buat pesanan manual'),
        content: SizedBox(
          width: 520,
          child: loading
              ? const SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator()))
              : loadingError != null
                  ? SizedBox(
                      height: 180,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                              'Gagal memuat pelanggan dan produk:\n$loadingError',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                loading = true;
                                loadingError = null;
                              });
                              _loadFormOptions();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    )
                  : Form(
                      key: form,
                      child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          DropdownButtonFormField<dynamic>(
                            initialValue: customerId,
                            decoration: const InputDecoration(
                                labelText: 'Pelanggan aktif',
                                border: OutlineInputBorder()),
                            items: [
                              for (final customer in customers)
                                DropdownMenuItem(
                                  value: customer['id'],
                                  child: Text(
                                    '${customer['name']} · ${customer['email']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            validator: (value) =>
                                value == null ? 'Pilih pelanggan' : null,
                            onChanged: (value) {
                              final customer = customers.firstWhere(
                                  (entry) => '${entry['id']}' == '$value');
                              setState(() {
                                customerId = value;
                                name.text = '${customer['name'] ?? ''}';
                                phone.text = '${customer['phone'] ?? ''}';
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _field(name, 'Nama penerima',
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Wajib diisi'
                                  : null),
                          _field(phone, 'Nomor telepon',
                              keyboard: TextInputType.phone,
                              validator: (v) => v == null || v.trim().length < 8
                                  ? 'Nomor telepon tidak valid'
                                  : null),
                          _field(address, 'Alamat',
                              maxLines: 2,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Wajib diisi'
                                  : null),
                          DropdownButtonFormField<dynamic>(
                            initialValue: productId,
                            decoration: const InputDecoration(
                                labelText: 'Produk',
                                border: OutlineInputBorder()),
                            items: [
                              for (final product in products)
                                DropdownMenuItem(
                                    value: product['id'],
                                    child: Text(
                                        '${product['name']} · stok ${product['stock'] ?? 0}',
                                        overflow: TextOverflow.ellipsis)),
                            ],
                            validator: (value) =>
                                value == null ? 'Pilih produk' : null,
                            onChanged: (value) =>
                                setState(() => productId = value),
                          ),
                          const SizedBox(height: 12),
                          Row(children: [
                            const Expanded(child: Text('Jumlah')),
                            IconButton(
                                onPressed: quantity <= 1
                                    ? null
                                    : () => setState(() => quantity--),
                                icon: const Icon(Icons.remove_circle_outline)),
                            Text('$quantity'),
                            IconButton(
                                onPressed: () => setState(() => quantity++),
                                icon: const Icon(Icons.add_circle_outline)),
                          ]),
                          DropdownButtonFormField<String>(
                            initialValue: paymentMethod,
                            decoration: const InputDecoration(
                                labelText: 'Metode pembayaran',
                                border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(
                                  value: 'bank_transfer',
                                  child: Text('Transfer bank')),
                              DropdownMenuItem(
                                  value: 'cod', child: Text('COD')),
                              DropdownMenuItem(
                                  value: 'ewallet', child: Text('E-Wallet')),
                            ],
                            onChanged: (value) => setState(
                                () => paymentMethod = value ?? 'bank_transfer'),
                          ),
                          const SizedBox(height: 12),
                          if (customers.isEmpty)
                            const Text(
                                'Tidak ada pelanggan aktif untuk dipilih.',
                                style: TextStyle(color: Colors.red)),
                          if (products.isEmpty)
                            const Text('Belum ada produk yang bisa dipesan.',
                                style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ),
        ),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Batal')),
          FilledButton(
              onPressed: saving || products.isEmpty || customers.isEmpty
                  ? null
                  : _save,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Buat pesanan')),
        ],
      );
}

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});
  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  late Future<dynamic> future;
  int? working;
  int page = 1;
  String statusFilter = 'proof_submitted';
  String? fromDate, toDate;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<dynamic> _load() => Api.req(
        'GET',
        '/admin/payments',
        query: {
          'page': '$page',
          if (statusFilter.isNotEmpty) 'status': statusFilter,
          if (fromDate != null) 'from': fromDate!,
          if (toDate != null) 'to': toDate!,
        },
      );
  void refresh() => setState(() {
        page = 1;
        future = _load();
      });
  void _changePage(int value) => setState(() {
        page = value;
        future = _load();
      });

  void _applyFilters(
      {String? status,
      String? from,
      String? to,
      bool clearFrom = false,
      bool clearTo = false}) {
    setState(() {
      if (status != null) statusFilter = status;
      if (from != null) fromDate = from.isEmpty ? null : from;
      if (to != null) toDate = to.isEmpty ? null : to;
      if (clearFrom) fromDate = null;
      if (clearTo) toDate = null;
      page = 1;
      future = _load();
    });
  }

  Future<void> _chooseDate({required bool start}) async {
    final value = await _selectDate(context, start ? fromDate : toDate);
    if (value != null) {
      final proposed = DateTime.parse(value);
      final counterpart =
          DateTime.tryParse(start ? (toDate ?? '') : (fromDate ?? ''));
      if (counterpart != null &&
          (start
              ? proposed.isAfter(counterpart)
              : proposed.isBefore(counterpart))) {
        _snack(context, 'Rentang tanggal pembayaran tidak valid.');
        return;
      }
      start ? _applyFilters(from: value) : _applyFilters(to: value);
    }
  }

  Future<void> _update(int id, bool approve, [String? reason]) async {
    setState(() => working = id);
    try {
      await Api.req(
        'POST',
        '/admin/orders/$id/${approve ? 'confirm-payment' : 'reject-payment'}',
        body: reason == null ? {} : {'reason': reason},
      );
      if (mounted) {
        _snack(
            context,
            approve
                ? 'Pembayaran berhasil dikonfirmasi.'
                : 'Bukti pembayaran ditolak.');
        refresh();
      }
    } catch (error) {
      if (mounted) _snack(context, '$error');
    } finally {
      if (mounted) setState(() => working = null);
    }
  }

  Future<void> _reject(int id) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Tolak bukti pembayaran'),
              content: TextField(
                controller: controller,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                    labelText: 'Alasan penolakan',
                    border: OutlineInputBorder()),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal')),
                FilledButton(
                    onPressed: () {
                      if (controller.text.trim().length < 3) return;
                      Navigator.pop(context, controller.text.trim());
                    },
                    child: const Text('Tolak')),
              ],
            ));
    controller.dispose();
    if (reason != null) await _update(id, false, reason);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _errorState(snapshot.error!, refresh);
          if (!snapshot.hasData) return _loadingState();
          final payments = List<Map>.from(
              ((snapshot.data as Map)['data'] as List? ?? const [])
                  .whereType<Map>());
          final meta = (snapshot.data as Map)['meta'] as Map?;
          return _PageBody(
            child: ListView(padding: const EdgeInsets.all(24), children: [
              _PageHeader('Pembayaran',
                  'Periksa bukti transfer dan konfirmasi pembayaran pelanggan.',
                  action: IconButton(
                      tooltip: 'Muat ulang',
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh))),
              LayoutBuilder(builder: (context, constraints) {
                final statusControl = DropdownButtonFormField<String>(
                  initialValue: statusFilter,
                  decoration: const InputDecoration(
                      labelText: 'Status pembayaran',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Semua status')),
                    DropdownMenuItem(value: 'pending', child: Text('Menunggu')),
                    DropdownMenuItem(
                        value: 'proof_submitted',
                        child: Text('Bukti diterima')),
                    DropdownMenuItem(value: 'rejected', child: Text('Ditolak')),
                    DropdownMenuItem(value: 'paid', child: Text('Dibayar')),
                    DropdownMenuItem(
                        value: 'cancelled', child: Text('Dibatalkan')),
                    DropdownMenuItem(
                        value: 'expired', child: Text('Kedaluwarsa')),
                  ],
                  onChanged: (value) => _applyFilters(status: value ?? ''),
                );
                final dateControls = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _chooseDate(start: true),
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                          fromDate == null ? 'Dari tanggal' : 'Dari $fromDate'),
                    ),
                    if (fromDate != null)
                      IconButton(
                        tooltip: 'Hapus tanggal awal',
                        onPressed: () => _applyFilters(clearFrom: true),
                        icon: const Icon(Icons.close),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _chooseDate(start: false),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                          toDate == null ? 'Sampai tanggal' : 'Sampai $toDate'),
                    ),
                    if (toDate != null)
                      IconButton(
                        tooltip: 'Hapus tanggal akhir',
                        onPressed: () => _applyFilters(clearTo: true),
                        icon: const Icon(Icons.close),
                      ),
                    TextButton(
                      onPressed: statusFilter.isEmpty &&
                              fromDate == null &&
                              toDate == null
                          ? null
                          : () => setState(() {
                                statusFilter = '';
                                fromDate = null;
                                toDate = null;
                                page = 1;
                                future = _load();
                              }),
                      child: const Text('Bersihkan filter'),
                    ),
                  ],
                );
                return constraints.maxWidth < 700
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          statusControl,
                          const SizedBox(height: 10),
                          dateControls,
                        ],
                      )
                    : Row(children: [
                        SizedBox(width: 210, child: statusControl),
                        const SizedBox(width: 12),
                        Expanded(child: dateControls),
                      ]);
              }),
              const SizedBox(height: 12),
              if (payments.isEmpty)
                _panel(
                    child: _emptyState('Tidak ada pembayaran menunggu',
                        'Bukti pembayaran baru akan muncul di halaman ini.'))
              else
                ...payments.map(_paymentCard),
              _pagination(meta, page, _changePage),
            ]),
          );
        },
      );

  Widget _paymentCard(Map entry) {
    final order = entry['order'] is Map ? entry['order'] as Map : entry;
    final id = _number(entry['order_id'] ?? order['id']).toInt();
    final user = order['user'] as Map? ?? entry['user'] as Map? ?? {};
    final proofUrl = '$baseUrl/orders/$id/payment-proof';
    final busy = working == id;
    final paymentStatus = '${order['payment_status'] ?? 'pending'}';
    final canReview = paymentStatus == 'proof_submitted';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _panel(
        child: LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 620;
          final details =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${order['code'] ?? '#$id'}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _adminInk)),
            const SizedBox(height: 4),
            Text(
                '${user['name'] ?? order['recipient_name'] ?? 'Pelanggan'} · ${user['email'] ?? ''}'),
            Text(
                '${order['phone'] ?? ''} · ${_date(order['payment_proof_uploaded_at'] ?? entry['created_at'])}'),
            const SizedBox(height: 5),
            Text('Total ${rp(_number(order['total']))}',
                style: const TextStyle(
                    color: _adminBlue, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            _StatusPill(paymentStatus),
            const SizedBox(height: 14),
            if (canReview) ...[
              if (busy) const LinearProgressIndicator(),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                      onPressed: busy ? null : () => _reject(id),
                      icon: const Icon(Icons.close),
                      label: const Text('Tolak')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                      onPressed: busy ? null : () => _update(id, true),
                      icon: const Icon(Icons.check),
                      label: const Text('Konfirmasi')),
                ),
              ]),
            ],
          ]);
          final image = !canReview
              ? Container(
                  height: stacked ? 160 : 280,
                  width: stacked ? double.infinity : 250,
                  color: const Color(0xFFF4F6FA),
                  child: const Center(
                      child: Text('Tidak ada bukti yang menunggu peninjauan')),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    proofUrl,
                    headers: {
                      if (Api.token != null)
                        'Authorization': 'Bearer ${Api.token}',
                    },
                    height: stacked ? 220 : 310,
                    width: stacked ? double.infinity : 250,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      height: stacked ? 160 : 280,
                      width: stacked ? double.infinity : 250,
                      color: const Color(0xFFF4F6FA),
                      child: const Center(
                          child: Text('Bukti transfer tidak dapat dimuat')),
                    ),
                  ),
                );
          return stacked
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  image,
                  const SizedBox(height: 16),
                  details,
                ])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  image,
                  const SizedBox(width: 18),
                  Expanded(child: details),
                ]);
        }),
      ),
    );
  }
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late Future<dynamic> future;
  final search = TextEditingController();
  String searchQuery = '', roleFilter = '', statusFilter = '';
  int page = 1;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<dynamic> _load() => Api.req(
        'GET',
        '/admin/users',
        query: {
          'page': '$page',
          if (searchQuery.isNotEmpty) 'search': searchQuery,
          if (roleFilter.isNotEmpty) 'role': roleFilter,
          if (statusFilter.isNotEmpty) 'status': statusFilter,
        },
      );
  void refresh() => setState(() {
        page = 1;
        future = _load();
      });
  void _changePage(int value) => setState(() {
        page = value;
        future = _load();
      });
  void _setFilters({String? searchValue, String? role, String? status}) =>
      setState(() {
        if (searchValue != null) searchQuery = searchValue.trim();
        if (role != null) roleFilter = role;
        if (status != null) statusFilter = status;
        page = 1;
        future = _load();
      });

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _edit([Map? user]) async {
    final result = await showDialog<bool>(
        context: context, builder: (_) => _UserDialog(user: user));
    if (result == true) refresh();
  }

  Future<void> _delete(Map user) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Hapus pengguna?'),
              content: Text('Akun ${user['name']} akan dihapus dari sistem.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal')),
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Hapus')),
              ],
            ));
    if (yes != true) return;
    try {
      await Api.req('DELETE', '/admin/users/${user['id']}');
      if (mounted) {
        _snack(context, 'Pengguna berhasil dihapus.');
        refresh();
      }
    } catch (error) {
      if (mounted) _snack(context, '$error');
    }
  }

  Future<void> _history(Map user) async {
    try {
      final result = await Api.req('GET', '/admin/users/${user['id']}');
      if (!mounted) return;
      final details = result['data'] as Map? ?? {};
      final orders =
          details['orders'] as List? ?? details['order_history'] as List? ?? [];
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text('Riwayat pesanan · ${user['name']}'),
                content: SizedBox(
                  width: 480,
                  child: orders.isEmpty
                      ? _emptyState('Belum ada riwayat pesanan',
                          'Pesanan pelanggan akan muncul di sini.')
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final order in orders)
                              ListTile(
                                title: Text(
                                    '${order['code'] ?? '#${order['id']}'}'),
                                subtitle: Text(
                                    '${_date(order['created_at'])} · ${statusLabel['${order['status']}'] ?? order['status']}'),
                                trailing: Text(rp(_number(order['total']))),
                              ),
                          ],
                        ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup')),
                ],
              ));
    } catch (error) {
      if (mounted) _snack(context, '$error');
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _errorState(snapshot.error!, refresh);
          if (!snapshot.hasData) return _loadingState();
          final users = List<Map>.from(
              ((snapshot.data as Map)['data'] as List? ?? const [])
                  .whereType<Map>());
          final meta = (snapshot.data as Map)['meta'] as Map?;
          final filtered = users;
          return _PageBody(
            child: ListView(padding: const EdgeInsets.all(24), children: [
              _PageHeader(
                  'Pengguna', 'Kelola akun pelanggan dan administrator.',
                  action: FilledButton.icon(
                      onPressed: () => _edit(),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Tambah pengguna'))),
              TextField(
                controller: search,
                onChanged: (value) => _setFilters(searchValue: value),
                decoration: const InputDecoration(
                    hintText: 'Cari nama, email, atau nomor telepon',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, constraints) {
                final filters = [
                  DropdownButtonFormField<String>(
                    initialValue: roleFilter,
                    decoration: const InputDecoration(
                        labelText: 'Peran',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Semua peran')),
                      DropdownMenuItem(
                          value: 'customer', child: Text('Pelanggan')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (value) => _setFilters(role: value ?? ''),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: statusFilter,
                    decoration: const InputDecoration(
                        labelText: 'Status akun',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Semua status')),
                      DropdownMenuItem(value: 'active', child: Text('Aktif')),
                      DropdownMenuItem(
                          value: 'inactive', child: Text('Nonaktif')),
                    ],
                    onChanged: (value) => _setFilters(status: value ?? ''),
                  ),
                ];
                return constraints.maxWidth < 550
                    ? Column(
                        children: filters
                            .map((filter) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: filter,
                                ))
                            .toList(),
                      )
                    : Row(children: [
                        for (var i = 0; i < filters.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(child: filters[i]),
                        ],
                      ]);
              }),
              const SizedBox(height: 4),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                _panel(
                    child: _emptyState('Pengguna tidak ditemukan',
                        'Coba kata pencarian lain.'))
              else
                ...filtered.map(_userCard),
              _pagination(meta, page, _changePage),
            ]),
          );
        },
      );

  Widget _userCard(Map user) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _panel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            CircleAvatar(
                backgroundColor: const Color(0xFFEAF0FF),
                child: Text(
                    '${user['name'] ?? 'U'}'.substring(0, 1).toUpperCase())),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${user['name'] ?? '-'}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${user['email'] ?? '-'} · ${user['phone'] ?? '-'}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.blueGrey)),
                  ]),
            ),
            Column(children: [
              _StatusPill('${user['role'] ?? 'customer'}'),
              const SizedBox(height: 3),
              Text(
                  user['is_active'] == false || user['is_active'] == 0
                      ? 'Nonaktif'
                      : 'Aktif',
                  style: TextStyle(
                      fontSize: 11,
                      color:
                          user['is_active'] == false || user['is_active'] == 0
                              ? Colors.red
                              : Colors.green)),
            ]),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _edit(user);
                if (value == 'history') _history(user);
                if (value == 'delete') _delete(user);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Ubah profil')),
                PopupMenuItem(value: 'history', child: Text('Riwayat pesanan')),
                PopupMenuItem(value: 'delete', child: Text('Hapus pengguna')),
              ],
            ),
          ]),
        ),
      );
}

class _UserDialog extends StatefulWidget {
  final Map? user;
  const _UserDialog({this.user});
  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final form = GlobalKey<FormState>();
  late final name =
      TextEditingController(text: '${widget.user?['name'] ?? ''}');
  late final email =
      TextEditingController(text: '${widget.user?['email'] ?? ''}');
  late final phone =
      TextEditingController(text: '${widget.user?['phone'] ?? ''}');
  final password = TextEditingController();
  final passwordConfirmation = TextEditingController();
  String role = 'customer';
  bool active = true, saving = false;

  @override
  void initState() {
    super.initState();
    role = '${widget.user?['role'] ?? 'customer'}';
    active =
        widget.user?['is_active'] != false && widget.user?['is_active'] != 0;
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final body = {
        'name': name.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'role': role,
        'is_active': active,
        if (password.text.isNotEmpty) ...{
          'password': password.text,
          'password_confirmation': passwordConfirmation.text,
        },
      };
      final id = widget.user?['id'];
      await Api.req(id == null ? 'POST' : 'PUT',
          '/admin/users${id == null ? '' : '/$id'}',
          body: body);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _snack(context, '$error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    passwordConfirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.user == null ? 'Tambah pengguna' : 'Ubah pengguna'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _field(name, 'Nama lengkap',
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Wajib diisi' : null),
                _field(email, 'Email',
                    keyboard: TextInputType.emailAddress,
                    validator: (v) => v == null || !v.contains('@')
                        ? 'Email tidak valid'
                        : null),
                _field(phone, 'Nomor telepon',
                    keyboard: TextInputType.phone,
                    validator: (v) => v == null || v.trim().length < 8
                        ? 'Nomor telepon tidak valid'
                        : null),
                _field(
                    password,
                    widget.user == null
                        ? 'Kata sandi'
                        : 'Kata sandi baru (opsional)',
                    validator: (v) =>
                        (widget.user == null || (v?.isNotEmpty ?? false)) &&
                                (v == null || v.length < 8)
                            ? 'Minimal 8 karakter'
                            : null),
                _field(
                  passwordConfirmation,
                  'Konfirmasi kata sandi',
                  validator: (v) {
                    if (widget.user != null && password.text.isEmpty) {
                      return null;
                    }
                    if (v == null || v.isEmpty) return 'Wajib dikonfirmasi';
                    return v != password.text
                        ? 'Konfirmasi kata sandi tidak cocok'
                        : null;
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                      labelText: 'Peran', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: 'customer', child: Text('Pelanggan')),
                    DropdownMenuItem(
                        value: 'admin', child: Text('Administrator')),
                  ],
                  onChanged: (value) =>
                      setState(() => role = value ?? 'customer'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Akun aktif'),
                  value: active,
                  onChanged: (value) => setState(() => active = value),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Batal')),
          FilledButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan')),
        ],
      );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user ?? {};
    return _PageBody(
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const _PageHeader(
            'Pengaturan', 'Informasi aplikasi dan catatan operasional.'),
        _panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Profil administrator',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _settingLine(
                Icons.person_outline, 'Nama', '${user['name'] ?? '-'}'),
            _settingLine(
                Icons.email_outlined, 'Email', '${user['email'] ?? '-'}'),
            _settingLine(
                Icons.verified_user_outlined, 'Peran', 'Administrator'),
          ]),
        ),
        const SizedBox(height: 14),
        _panel(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Operasional & pemeliharaan',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                    'Halaman admin frontend ini tidak mengubah konfigurasi server. Pengaturan rekening pembayaran, integrasi ongkir, scheduler, database, serta environment harus dikelola melalui deployment/backend dan tidak tersedia sebagai operasi di panel ini.',
                    style: TextStyle(color: Colors.blueGrey, height: 1.45)),
                SizedBox(height: 12),
                Chip(
                    avatar: Icon(Icons.info_outline, size: 17),
                    label: Text(
                        'Informasi saja · tidak menyimpan pengaturan toko')),
                SizedBox(height: 10),
                Text(
                    'Pemeliharaan rutin: pantau layanan API dan antrean scheduler pada server, verifikasi backup database, serta periksa log deployment saat terjadi gangguan.',
                    style: TextStyle(color: Colors.blueGrey, height: 1.45)),
              ]),
        ),
        const SizedBox(height: 14),
        _panel(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Tentang Kelly Elektronik',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Admin Console · Frontend Flutter',
                    style: TextStyle(
                        color: _adminBlue, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text(
                    'Panel ini mengelola produk, kategori, pesanan, pembayaran, dan pengguna melalui API admin yang terautentikasi.',
                    style: TextStyle(color: Colors.blueGrey, height: 1.45)),
              ]),
        ),
      ]),
    );
  }

  Widget _settingLine(IconData icon, String title, String value) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: _adminBlue),
        title: Text(title, style: const TextStyle(color: Colors.blueGrey)),
        subtitle: Text(value,
            style:
                const TextStyle(fontWeight: FontWeight.w600, color: _adminInk)),
        dense: true,
      );
}
