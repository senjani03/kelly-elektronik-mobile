import 'package:flutter_test/flutter_test.dart';
import 'package:kelly_elektronik/main.dart';
import 'package:kelly_elektronik/providers/auth_provider.dart';
import 'package:kelly_elektronik/providers/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app opens the login screen without a saved session', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => CartProvider()),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Kelly Elektronik'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });
}
