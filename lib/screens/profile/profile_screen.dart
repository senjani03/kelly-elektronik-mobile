import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../order/payment_admin_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final u = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('Akun Saya')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: CircleAvatar(radius: 36, backgroundColor: const Color(0xFF1D4ED8),
            child: Text('${u?['name'] ?? '?'}'[0].toUpperCase(), style: const TextStyle(fontSize: 28, color: Colors.white)))),
        const SizedBox(height: 12),
        Center(child: Text('${u?['name'] ?? ''}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        const SizedBox(height: 16),
        Card(color: Colors.white, child: Column(children: [
          ListTile(leading: const Icon(Icons.email_outlined), title: Text('${u?['email'] ?? '-'}')),
          ListTile(leading: const Icon(Icons.phone_outlined), title: Text('${u?['phone'] ?? '-'}')),
          ListTile(leading: const Icon(Icons.badge_outlined), title: Text('Role: ${u?['role'] ?? '-'}')),
        ])),
        if (context.watch<AuthProvider>().isAdmin) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Admin console'),
              subtitle: const Text('Kelola toko, pesanan, pembayaran, dan pengguna'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/admin'),
            ),
          ),
          Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Konfirmasi pembayaran'),
              subtitle: const Text('Periksa bukti transfer pelanggan'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PaymentAdminScreen(),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Keluar', style: TextStyle(color: Colors.red)),
          onPressed: () async {
            await context.read<AuthProvider>().logout();
            if (context.mounted) {
              context.read<CartProvider>().clear();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            }
          },
        ),
      ]),
    );
  }
}
