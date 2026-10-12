import 'package:flutter_test/flutter_test.dart';
import 'package:kelly_elektronik/utils/config.dart';

void main() {
  group('resolveProductImageUrl', () {
    test('replaces localhost with the configured API host', () {
      expect(
        resolveProductImageUrl(
          'http://localhost:8000/api/product-images/speaker.png',
        ),
        'http://172.20.10.8:8000/api/product-images/speaker.png',
      );
    });

    test('replaces 127.0.0.1 with the configured API host', () {
      expect(
        resolveProductImageUrl(
          'http://127.0.0.1:8000/api/product-images/speaker.png',
        ),
        'http://172.20.10.8:8000/api/product-images/speaker.png',
      );
    });

    test('preserves URLs that are not loopback URLs', () {
      const imageUrl = 'https://images.example.com/speaker.png';

      expect(resolveProductImageUrl(imageUrl), imageUrl);
    });
  });
}
