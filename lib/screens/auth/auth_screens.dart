import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  final String? paymentReturnOrderId;

  const SplashScreen({super.key, this.paymentReturnOrderId});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      await auth.load();
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        final route = auth.loggedIn
            ? widget.paymentReturnOrderId == null
                ? '/home'
                : '/payment-return'
            : '/login';
        Navigator.pushReplacementNamed(
          context,
          route,
          arguments: widget.paymentReturnOrderId,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Color(0xFF1D4ED8),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.shopping_cart, size: 80, color: Colors.white),
            SizedBox(height: 12),
            Text('Kelly Elektronik',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
            Text('Solusi Elektronik Rumah Anda',
                style: TextStyle(color: Colors.white70)),
          ]),
        ),
      );
}

class _AuthForm extends StatefulWidget {
  final bool register;
  final String? paymentReturnOrderId;

  const _AuthForm(this.register, {this.paymentReturnOrderId});
  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  final _key = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController(),
      pass = TextEditingController();
  bool loading = false, hide = true;

  Future<void> submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => loading = true);
    final auth = context.read<AuthProvider>();
    try {
      widget.register
          ? await auth.register(
              name.text.trim(), email.text.trim(), phone.text.trim(), pass.text)
          : await auth.login(email.text.trim(), pass.text);
      if (mounted) {
        final returnOrderId = widget.paymentReturnOrderId;
        Navigator.pushNamedAndRemoveUntil(
          context,
          returnOrderId == null ? '/home' : '/payment-return',
          (_) => false,
          arguments: returnOrderId,
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.register;
    return Scaffold(
      appBar: r ? AppBar(title: const Text('Daftar')) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _key,
              child: Column(children: [
                if (!r) ...[
                  const Icon(Icons.shopping_cart,
                      size: 64, color: Color(0xFF1D4ED8)),
                  const Text('Kelly Elektronik',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                ],
                if (r) ...[
                  TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                          labelText: 'Nama lengkap',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          v!.trim().isEmpty ? 'Wajib diisi' : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: 'No. telepon',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          v!.trim().length < 9 ? 'Nomor tidak valid' : null),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Email', border: OutlineInputBorder()),
                    validator: (v) =>
                        !v!.contains('@') ? 'Email tidak valid' : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: pass,
                    obscureText: hide,
                    decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                            icon: Icon(
                                hide ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => hide = !hide))),
                    validator: (v) =>
                        v!.length < 8 ? 'Minimal 8 karakter' : null),
                const SizedBox(height: 20),
                SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                        onPressed: loading ? null : submit,
                        child: loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(r ? 'Daftar' : 'Masuk'))),
                TextButton(
                    onPressed: () => r
                        ? Navigator.pop(context)
                        : Navigator.pushNamed(context, '/register'),
                    child: Text(r
                        ? 'Sudah punya akun? Masuk'
                        : 'Belum punya akun? Daftar')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  final String? paymentReturnOrderId;

  const LoginScreen({super.key, this.paymentReturnOrderId});
  @override
  Widget build(BuildContext context) =>
      _AuthForm(false, paymentReturnOrderId: paymentReturnOrderId);
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});
  @override
  Widget build(BuildContext context) => const _AuthForm(true);
}
