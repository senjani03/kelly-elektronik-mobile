import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/api.dart';
import '../../utils/config.dart';
import '../order/order_screens.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _key = GlobalKey<FormState>();
  late final name =
      TextEditingController(text: context.read<AuthProvider>().user?['name']);
  late final phone =
      TextEditingController(text: context.read<AuthProvider>().user?['phone']);
  final address = TextEditingController();
  final destinationSearch = TextEditingController();
  Timer? _searchTimer;
  List<Map<String, dynamic>> destinations = [];
  List<Map<String, dynamic>> couriers = [];
  List<Map<String, dynamic>> shippingServices = [];
  Map<String, dynamic>? destination;
  Map<String, dynamic>? selectedService;
  String? courier;
  bool searchingDestinations = false;
  bool quotingShipping = false;
  bool _settingDestination = false;
  int _destinationRequestId = 0;
  int _quoteRequestId = 0;
  String payment = 'midtrans';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    loadCouriers();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    name.dispose();
    phone.dispose();
    address.dispose();
    destinationSearch.dispose();
    super.dispose();
  }

  Future<void> loadCouriers() async {
    try {
      final result = await Api.req('GET', '/shipping/couriers');
      if (!mounted) return;
      setState(() {
        couriers = (result['data'] as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        courier = couriers.isEmpty ? null : couriers.first['code'] as String;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    }
  }

  void searchDestination(String value) {
    if (_settingDestination) return;
    final requestId = ++_destinationRequestId;
    _quoteRequestId++;
    _searchTimer?.cancel();
    setState(() {
      destination = null;
      destinations = [];
      searchingDestinations = false;
      quotingShipping = false;
      shippingServices = [];
      selectedService = null;
    });
    if (value.trim().length < 2) return;
    _searchTimer = Timer(const Duration(milliseconds: 450), () async {
      setState(() => searchingDestinations = true);
      try {
        final result = await Api.req(
          'GET',
          '/shipping/destinations',
          query: {'search': value.trim()},
        );
        if (!mounted ||
            requestId != _destinationRequestId ||
            destinationSearch.text.trim() != value.trim()) {
          return;
        }
        setState(() {
          destinations = (result['data'] as List)
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        });
      } catch (error) {
        if (mounted && requestId == _destinationRequestId) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$error')),
          );
        }
      } finally {
        if (mounted && requestId == _destinationRequestId) {
          setState(() => searchingDestinations = false);
        }
      }
    });
  }

  void selectDestination(Map<String, dynamic> value) {
    _destinationRequestId++;
    _settingDestination = true;
    destinationSearch.text = value['label']?.toString() ?? '';
    _settingDestination = false;
    setState(() {
      destination = value;
      destinations = [];
      shippingServices = [];
      selectedService = null;
    });
    calculateShipping();
  }

  Future<void> calculateShipping() async {
    if (destination == null || courier == null) return;
    final requestId = ++_quoteRequestId;
    setState(() {
      quotingShipping = true;
      shippingServices = [];
      selectedService = null;
    });
    try {
      final result = await Api.req('POST', '/shipping/quotes', body: {
        'destination_id': destination!['id'],
        'courier': courier,
      });
      if (!mounted || requestId != _quoteRequestId) return;
      setState(() {
        shippingServices = (result['data']['services'] as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        selectedService =
            shippingServices.isEmpty ? null : shippingServices.first;
      });
      if (shippingServices.isEmpty && mounted && requestId == _quoteRequestId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada layanan untuk tujuan ini.')),
        );
      }
    } catch (error) {
      if (mounted && requestId == _quoteRequestId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted && requestId == _quoteRequestId) {
        setState(() => quotingShipping = false);
      }
    }
  }

  Future<void> submit() async {
    if (!_key.currentState!.validate()) return;
    if (destination == null || selectedService == null || courier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tujuan dan hitung ongkos kirim.')),
      );
      return;
    }
    setState(() => loading = true);
    try {
      final r = await Api.req('POST', '/orders', body: {
        'recipient_name': name.text.trim(),
        'phone': phone.text.trim(),
        'address': address.text.trim(),
        'destination_id': destination!['id'],
        'destination_label': destination!['label'],
        'courier': courier,
        'courier_service': selectedService!['service'],
        'payment_method': payment,
      });
      if (!mounted) return;
      context.read<CartProvider>().clear();
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => OrderDetailScreen(r['data']['id'])));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Data Penerima',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextFormField(
              controller: name,
              decoration: const InputDecoration(
                  labelText: 'Nama penerima', border: OutlineInputBorder()),
              validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null),
          const SizedBox(height: 10),
          TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'No. telepon', border: OutlineInputBorder()),
              validator: (v) =>
                  v!.trim().length < 9 ? 'Nomor tidak valid' : null),
          const SizedBox(height: 10),
          TextField(
            controller: destinationSearch,
            onChanged: searchDestination,
            decoration: InputDecoration(
              labelText: 'Cari kota, kecamatan, atau kelurahan',
              hintText: 'Contoh: Tanjung Duren Selatan',
              border: const OutlineInputBorder(),
              suffixIcon: searchingDestinations
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search),
            ),
          ),
          if (destinations.isNotEmpty)
            Card(
              child: Column(
                children: [
                  for (final item in destinations)
                    ListTile(
                      dense: true,
                      title: Text(item['label']?.toString() ?? ''),
                      subtitle: Text([
                        item['district_name'],
                        item['city_name'],
                        item['province_name'],
                      ]
                          .whereType<String>()
                          .where((part) => part.isNotEmpty)
                          .join(', ')),
                      onTap: () => selectDestination(item),
                    ),
                ],
              ),
            ),
          if (destination != null) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: courier,
              decoration: const InputDecoration(
                labelText: 'Kurir',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final item in couriers)
                  DropdownMenuItem<String>(
                    value: item['code'] as String,
                    child: Text(item['name'] as String),
                  ),
              ],
              onChanged: quotingShipping
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => courier = value);
                      calculateShipping();
                    },
            ),
            if (quotingShipping)
              const LinearProgressIndicator()
            else if (shippingServices.isNotEmpty)
              RadioGroup<Map<String, dynamic>>(
                groupValue: selectedService,
                onChanged: (value) => setState(() => selectedService = value),
                child: Column(
                  children: shippingServices.map((service) {
                    final cost = num.parse(service['cost'].toString());
                    return RadioListTile<Map<String, dynamic>>(
                      value: service,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${service['service']} - ${rp(cost)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${service['description'] ?? ''}'
                        '${service['etd'] == null ? '' : ' • Estimasi ${service['etd']}'}',
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
          const SizedBox(height: 10),
          TextFormField(
              controller: address,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Detail alamat (jalan, nomor rumah, patokan)',
                  border: OutlineInputBorder()),
              validator: (v) =>
                  v!.trim().length < 10 ? 'Alamat terlalu pendek' : null),
          const SizedBox(height: 16),
          const Text('Ringkasan Pesanan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          for (final i in cart.items)
            ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(i.product.name),
                subtitle: Text('${i.quantity} x ${rp(i.product.price)}'),
                trailing: Text(rp(i.subtotal))),
          const Divider(),
          _row('Subtotal', rp(cart.total)),
          _row(
            'Ongkos kirim',
            selectedService == null
                ? '-'
                : rp(num.parse(selectedService!['cost'].toString())),
          ),
          _row(
            'Total pembayaran',
            rp(cart.total +
                (selectedService == null
                    ? 0
                    : num.parse(selectedService!['cost'].toString()))),
            bold: true,
          ),
          const SizedBox(height: 16),
          const Text('Metode Pembayaran',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          RadioGroup<String>(
            groupValue: payment,
            onChanged: (v) => setState(() => payment = v!),
            child: Column(children: [
              for (final e in paymentLabel.entries)
                RadioListTile<String>(
                    value: e.key,
                    title: Text(e.value),
                    contentPadding: EdgeInsets.zero),
            ]),
          ),
          Text(
            payment == 'midtrans'
                ? 'Pembayaran diproses aman melalui Midtrans Sandbox.'
                : 'Pembayaran ini dikonfirmasi secara manual oleh admin.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
              onPressed:
                  loading || cart.items.isEmpty || selectedService == null
                      ? null
                      : submit,
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Buat Pesanan')),
        ),
      ),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(a, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
          Text(b, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
        ]),
      );
}
