import 'package:flutter/material.dart';
import '../../services/api.dart';
import '../../utils/config.dart';

class PaymentAdminScreen extends StatefulWidget {
  const PaymentAdminScreen({super.key});

  @override
  State<PaymentAdminScreen> createState() => _PaymentAdminScreenState();
}

class _PaymentAdminScreenState extends State<PaymentAdminScreen> {
  late Future<dynamic> _orders;
  int? _workingOrderId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(
        () => _orders = Api.req('GET', '/admin/orders/pending-confirmation'));
  }

  Future<void> _confirm(int id) async {
    await _update(id, '/admin/orders/$id/confirm-payment');
  }

  Future<void> _reject(int id) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak bukti transfer'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Alasan penolakan',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length < 3) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    await _update(
      id,
      '/admin/orders/$id/reject-payment',
      body: {'reason': reason},
    );
  }

  Future<void> _update(int id, String path, {Map? body}) async {
    setState(() => _workingOrderId = id);
    try {
      final response = await Api.req('POST', path, body: body ?? {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(response['message'] ?? 'Status pembayaran diperbarui.')),
      );
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _workingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Konfirmasi Pembayaran'),
          actions: [
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder(
          future: _orders,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = (snapshot.data as Map)['data'] as List;
            if (orders.isEmpty) {
              return const Center(
                child:
                    Text('Tidak ada bukti transfer yang menunggu konfirmasi.'),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final order in orders) _orderCard(order),
              ],
            );
          },
        ),
      );

  Widget _orderCard(Map order) {
    final user = order['user'] as Map? ?? {};
    final id = order['id'] as int;
    final busy = _workingOrderId == id;
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${order['code']}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
                '${user['name'] ?? order['recipient_name']} • ${user['email'] ?? ''}'),
            Text(
                '${order['phone']}\n${order['address']}\n${order['destination_label'] ?? ''}'),
            const SizedBox(height: 4),
            Text('Total: ${rp(num.parse('${order['total']}'))}'),
            Text('Bukti dikirim: ${order['payment_proof_uploaded_at'] ?? '-'}'),
            const SizedBox(height: 8),
            Image.network(
              '$baseUrl/orders/$id/payment-proof',
              headers: {
                if (Api.token != null) 'Authorization': 'Bearer ${Api.token}',
              },
              height: 280,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Text('Bukti transfer tidak dapat dimuat.'),
            ),
            const SizedBox(height: 8),
            if (busy) const LinearProgressIndicator(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _reject(id),
                    icon: const Icon(Icons.close),
                    label: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => _confirm(id),
                    icon: const Icon(Icons.check),
                    label: const Text('Konfirmasi'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
