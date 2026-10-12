import 'package:flutter/material.dart';
import '../../services/api.dart';
import '../home/main_shell.dart';

String? midtransOrderIdFromUri(Uri uri) {
  final fragment = uri.fragment.isEmpty ? null : Uri.tryParse(uri.fragment);
  final isReturnRoute = uri.path == '/payment-return' ||
      fragment?.path == '/payment-return';
  if (!isReturnRoute) return null;

  final orderId = fragment?.queryParameters['order_id'] ??
      uri.queryParameters['order_id'];
  return orderId == null || orderId.isEmpty ? null : orderId;
}

class PaymentReturnScreen extends StatefulWidget {
  final String midtransOrderId;

  const PaymentReturnScreen({super.key, required this.midtransOrderId});

  @override
  State<PaymentReturnScreen> createState() => _PaymentReturnScreenState();
}

class _PaymentReturnScreenState extends State<PaymentReturnScreen> {
  late Future<dynamic> _statusFuture;
  bool _openingOrder = false;

  @override
  void initState() {
    super.initState();
    _statusFuture = _loadStatus();
  }

  Future<dynamic> _loadStatus() {
    return Api.req(
      'GET',
      '/payments/midtrans/return-status',
      query: {'order_id': widget.midtransOrderId},
    );
  }

  void _refreshStatus() {
    setState(() {
      _statusFuture = _loadStatus();
    });
  }

  void _openOrder(int orderId, {String? message}) {
    if (_openingOrder) return;
    _openingOrder = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => MainShell(
          initialTab: 3,
          initialOrderId: orderId,
          initialMessage: message,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Status Pembayaran')),
        body: FutureBuilder<dynamic>(
          future: _statusFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _messageView(
                'Status pembayaran belum dapat diperiksa.',
                actions: [
                  FilledButton(
                    onPressed: _refreshStatus,
                    child: const Text('Periksa lagi'),
                  ),
                ],
              );
            }

            final data = (snapshot.data as Map)['data'] as Map;
            final status = data['payment_status'] as String? ?? 'pending';
            final orderId = (data['order_id'] as num).toInt();

            if (status == 'paid') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _openOrder(orderId, message: 'Pembayaran berhasil');
                }
              });
              return _messageView(
                'Pembayaran berhasil. Membuka detail pesanan…',
                loading: true,
              );
            }

            if (status == 'failed' || status == 'expired') {
              return _messageView(
                status == 'expired'
                    ? 'Pembayaran kedaluwarsa. Anda dapat mencoba bayar ulang selama stok tersedia.'
                    : 'Pembayaran gagal. Silakan coba bayar ulang.',
                actions: [
                  FilledButton(
                    onPressed: () => _openOrder(orderId),
                    child: const Text('Bayar ulang'),
                  ),
                  OutlinedButton(
                    onPressed: _refreshStatus,
                    child: const Text('Periksa status lagi'),
                  ),
                ],
              );
            }

            return _messageView(
              'Pembayaran masih menunggu konfirmasi Midtrans.',
              actions: [
                FilledButton(
                  onPressed: _refreshStatus,
                  child: const Text('Periksa status lagi'),
                ),
                OutlinedButton(
                  onPressed: () => _openOrder(orderId),
                  child: const Text('Lihat detail pesanan'),
                ),
              ],
            );
          },
        ),
      );

  Widget _messageView(
    String message, {
    List<Widget> actions = const [],
    bool loading = false,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
              ],
              Text(message, textAlign: TextAlign.center),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      );
}
