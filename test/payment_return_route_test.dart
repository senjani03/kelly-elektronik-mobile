import 'package:flutter_test/flutter_test.dart';
import 'package:kelly_elektronik/screens/order/payment_return_screen.dart';

void main() {
  test('reads the Midtrans order ID from the Flutter hash route', () {
    final uri = Uri.parse(
      'http://localhost:3000/#/payment-return?order_id=KEL-8-attempt'
      '&status_code=200&transaction_status=settlement',
    );

    expect(midtransOrderIdFromUri(uri), 'KEL-8-attempt');
  });

  test('reads an order ID from a path-based return URL', () {
    final uri = Uri.parse(
      'https://shop.example.test/payment-return?order_id=KEL-8-attempt'
      '&transaction_status=settlement',
    );

    expect(midtransOrderIdFromUri(uri), 'KEL-8-attempt');
  });

  test('does not treat transaction status on another route as a return', () {
    final uri = Uri.parse(
      'http://localhost:3000/#/home?transaction_status=settlement',
    );

    expect(midtransOrderIdFromUri(uri), isNull);
  });
}
