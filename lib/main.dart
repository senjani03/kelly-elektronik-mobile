import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'screens/auth/auth_screens.dart';
import 'screens/admin/admin_console.dart';
import 'screens/home/main_shell.dart';
import 'screens/order/payment_return_screen.dart';

void main() => runApp(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const App(),
    ));

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    final paymentReturnOrderId = midtransOrderIdFromUri(Uri.base);
    return MaterialApp(
        title: 'Kelly Elektronik',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1D4ED8)),
          scaffoldBackgroundColor: const Color(0xFFF5F7FB),
          appBarTheme: const AppBarTheme(centerTitle: true),
        ),
        initialRoute: '/',
        routes: {
          '/': (_) => SplashScreen(
                paymentReturnOrderId: paymentReturnOrderId,
              ),
          '/login': (context) => LoginScreen(
                paymentReturnOrderId:
                    ModalRoute.of(context)?.settings.arguments as String?,
              ),
          '/register': (_) => const RegisterScreen(),
          '/home': (_) => const MainShell(),
          '/admin': (_) => const AdminRoute(),
          '/payment-return': (context) => PaymentReturnScreen(
                midtransOrderId: ModalRoute.of(context)?.settings.arguments
                        as String? ??
                    paymentReturnOrderId ??
                    '',
              ),
        },
      );
  }
}
