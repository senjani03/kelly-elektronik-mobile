import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api.dart';
import '../../utils/config.dart';

Color _statusColor(String status) => switch (status) {
      'completed' || 'processing' => Colors.green,
      'cancelled' => Colors.red,
      'pending_payment' => Colors.orange,
      _ => const Color(0xFF1D4ED8),
    };

String _paymentStatusLabel(String? status) => switch (status) {
      'paid' => 'Terverifikasi',
      'proof_submitted' => 'Menunggu konfirmasi admin',
      'rejected' => 'Bukti ditolak',
      'expired' => 'Kedaluwarsa',
      'failed' => 'Pembayaran gagal — silakan coba lagi',
      _ => 'Menunggu pembayaran',
    };

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  late Future<dynamic> future;

  @override
  void initState() {
    super.initState();
    future = Api.req('GET', '/orders');
  }

  void refresh() {
    setState(() {
      future = Api.req('GET', '/orders');
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pesanan Saya'), actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: refresh,
          ),
        ]),
        body: FutureBuilder(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = (snapshot.data as Map)['data'] as List;
            if (orders.isEmpty) {
              return const Center(child: Text('Belum ada pesanan'));
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final order in orders)
                  Card(
                    color: Colors.white,
                    child: ListTile(
                      title: Text(
                        '${order['code']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${rp(num.parse('${order['total']}'))}\n'
                        '${order['created_at'].toString().substring(0, 10)}',
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        statusLabel[order['status']] ?? '${order['status']}',
                        style: TextStyle(
                          color: _statusColor(order['status']),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailScreen(order['id']),
                        ),
                      ).then((_) => refresh()),
                    ),
                  ),
              ],
            );
          },
        ),
      );
}

class OrderDetailScreen extends StatefulWidget {
  final int id;

  const OrderDetailScreen(this.id, {super.key});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<dynamic> _orderFuture;
  Future<dynamic>? _bankFuture;
  bool _uploading = false;
  bool _payingMidtrans = false;
  String? _statusRefreshError;

  @override
  void initState() {
    super.initState();
    _orderFuture = _loadOrder();
  }

  Future<dynamic> _loadOrder() async {
    final result = await Api.req('GET', '/orders/${widget.id}');
    final order = (result as Map)['data'] as Map;
    _bankFuture = order['payment_method'] == 'bank_transfer'
        ? Api.req('GET', '/payment-details')
        : null;
    if (order['payment_method'] == 'midtrans' &&
        order['midtrans_redirect_url'] != null &&
        order['payment_status'] != 'paid') {
      try {
        await Api.req('GET', '/orders/${widget.id}/midtrans-status');
        _statusRefreshError = null;
        return await Api.req('GET', '/orders/${widget.id}');
      } catch (error) {
        _statusRefreshError = '$error';
      }
    }
    return result;
  }

  void _refresh() {
    setState(() {
      _bankFuture = null;
      _orderFuture = _loadOrder();
    });
  }

  Future<void> _payWithMidtrans() async {
    setState(() => _payingMidtrans = true);
    try {
      final response = await Api.req(
        'POST',
        '/orders/${widget.id}/midtrans-payment',
      );
      final redirectUrl = (response['data'] as Map?)?['redirect_url'];
      if (redirectUrl is String) {
        final opened = await launchUrl(
          Uri.parse(redirectUrl),
          mode: LaunchMode.externalApplication,
        );
        if (!opened && mounted) {
          throw ApiException('Halaman pembayaran Midtrans tidak dapat dibuka.');
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembayaran sudah terverifikasi.')),
        );
      }
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _payingMidtrans = false);
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label berhasil disalin')),
    );
  }

  Future<void> _uploadProof() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gambar tidak dapat dibaca.')),
        );
      }
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ukuran gambar maksimal 5 MB.')),
        );
      }
      return;
    }

    setState(() => _uploading = true);
    try {
      final response = await Api.uploadImage(
        '/orders/${widget.id}/payment-proof',
        bytes: bytes,
        filename: file.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Bukti terkirim.')),
      );
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Detail Pesanan'),
          actions: [
            IconButton(
              tooltip: 'Muat ulang',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder(
          future: _orderFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final order = (snapshot.data as Map)['data'];
            num amount(String key) => num.parse('${order[key]}');
            final canPay = order['payment_method'] == 'bank_transfer' &&
                order['status'] == 'pending_payment' &&
                ['pending', 'rejected'].contains(order['payment_status']);
            final canPayWithMidtrans = order['payment_method'] == 'midtrans' &&
                ((order['status'] == 'pending_payment' &&
                        ['pending', 'failed'].contains(order['payment_status'])) ||
                    (order['status'] == 'cancelled' &&
                        order['payment_status'] == 'expired'));

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${order['code']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(
                      statusLabel[order['status']] ?? '${order['status']}'),
                  backgroundColor:
                      _statusColor(order['status']).withValues(alpha: 0.15),
                ),
                const SizedBox(height: 8),
                const Text('Penerima',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '${order['recipient_name']} - ${order['phone']}\n'
                  '${order['address']}\n${order['destination_label'] ?? ''}',
                ),
                if (order['courier_code'] != null) ...[
                  const SizedBox(height: 12),
                  const Text('Pengiriman',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${order['courier_code']} ${order['courier_service']}'
                    '${order['shipping_etd'] == null ? '' : ' • Estimasi ${order['shipping_etd']}'}',
                  ),
                ],
                const SizedBox(height: 12),
                const Text('Pembayaran',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '${paymentLabel[order['payment_method']] ?? order['payment_method']}'
                  ' • ${_paymentStatusLabel(order['payment_status'])}',
                ),
                if (_statusRefreshError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Status Midtrans belum dapat diperbarui: $_statusRefreshError',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (canPayWithMidtrans) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _payingMidtrans ? null : _payWithMidtrans,
                    icon: const Icon(Icons.lock_outline),
                    label: Text(_payingMidtrans
                        ? 'Menyiapkan pembayaran...'
                        : order['payment_status'] == 'failed'
                            ? 'Coba bayar lagi dengan Midtrans'
                            : order['payment_status'] == 'expired'
                                ? 'Bayar ulang dengan Midtrans'
                                : 'Bayar dengan Midtrans'),
                  ),
                  const Text(
                    'Pilih QRIS, virtual account, e-wallet, atau metode lain pada halaman Midtrans.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                if (canPay) _transferDetails(order, amount),
                if (order['payment_rejection_reason'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Alasan penolakan: ${order['payment_rejection_reason']}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                if (order['payment_proof_uploaded_at'] != null &&
                    order['payment_status'] != 'rejected') ...[
                  const SizedBox(height: 12),
                  const Text('Bukti transfer',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  _proofImage(widget.id),
                ],
                if (order['payment_method'] == 'bank_transfer' &&
                    order['payment_status'] == 'proof_submitted')
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Bukti diterima. Pesanan akan diproses setelah admin memverifikasi pembayaran.',
                    ),
                  ),
                if (canPay) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _uploading ? null : _uploadProof,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_uploading
                        ? 'Mengunggah...'
                        : order['payment_status'] == 'rejected'
                            ? 'Unggah ulang bukti transfer'
                            : 'Unggah bukti transfer'),
                  ),
                  const Text('Format JPG atau PNG, maksimal 5 MB.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                const Divider(height: 24),
                const Text('Produk',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                for (final item in order['items'])
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${item['product_name']}'),
                    subtitle: Text(
                      '${item['quantity']} x ${rp(num.parse('${item['price']}'))}',
                    ),
                    trailing: Text(
                      rp(num.parse('${item['price']}') * item['quantity']),
                    ),
                  ),
                const Divider(),
                _row('Subtotal', rp(amount('subtotal'))),
                _row('Ongkos kirim', rp(amount('shipping_cost'))),
                if ((order['payment_unique_code'] as num? ?? 0) > 0)
                  _row(
                    'Kode unik transfer',
                    rp(order['payment_unique_code'] as num),
                  ),
                _row('Total transfer', rp(amount('total')), bold: true),
              ],
            );
          },
        ),
      );

  Widget _transferDetails(
    Map order,
    num Function(String) amount,
  ) =>
      FutureBuilder(
        future: _bankFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final bank = (snapshot.data as Map)['data'];
          final number = '${bank['account_number']}';
          final total = amount('total').round().toString();
          return Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transfer ke rekening toko',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${bank['name']} • ${bank['account_name']}'),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          number,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Salin nomor rekening',
                        onPressed: () => _copy(number, 'Nomor rekening'),
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                  const Divider(),
                  const Text('Jumlah yang harus ditransfer'),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          rp(amount('total')),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Salin jumlah transfer',
                        onPressed: () => _copy(total, 'Jumlah transfer'),
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                  Text(
                    'Sertakan kode unik ${order['payment_unique_code']} '
                    'pada tiga digit terakhir jumlah transfer.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Widget _proofImage(int orderId) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Image.network(
          '$baseUrl/orders/$orderId/payment-proof',
          headers: {
            if (Api.token != null) 'Authorization': 'Bearer ${Api.token}',
          },
          height: 240,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Text('Bukti transfer tidak dapat ditampilkan.'),
        ),
      );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
            Text(value,
                style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
          ],
        ),
      );
}
