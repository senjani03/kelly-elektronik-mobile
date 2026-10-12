import 'package:flutter/foundation.dart';

// Default to this computer's Wi-Fi address for a physical Android device.
// Android emulators can override this with API_BASE_URL=http://10.0.2.2:8000/api.
const String _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
final String baseUrl = _configuredApiBaseUrl.isNotEmpty
    ? _configuredApiBaseUrl
    : kIsWeb && Uri.base.host.isNotEmpty
        ? '${Uri.base.scheme}://${Uri.base.host}:8000/api'
        : 'http://172.20.10.8:8000/api';

String resolveProductImageUrl(String imageUrl) {
  final uri = Uri.tryParse(imageUrl);
  final apiUri = Uri.tryParse(baseUrl);
  if (uri == null ||
      apiUri == null ||
      (uri.host != 'localhost' && uri.host != '127.0.0.1')) {
    return imageUrl;
  }

  return uri
      .replace(
        scheme: apiUri.scheme,
        host: apiUri.host,
        port: apiUri.hasPort ? apiUri.port : null,
      )
      .toString();
}

String rp(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return 'Rp $b';
}

const statusLabel = {
  'pending_payment': 'Menunggu Pembayaran',
  'processing': 'Diproses',
  'packed': 'Dikemas',
  'shipped': 'Dikirim',
  'delivered': 'Terkirim',
  'completed': 'Selesai',
  'cancelled': 'Dibatalkan',
};
const paymentLabel = {
  'midtrans': 'Midtrans (QRIS, VA, e-wallet, kartu)',
  'bank_transfer': 'Transfer Bank',
  'cod': 'COD (Bayar di Tempat)',
  'ewallet': 'E-Wallet (Simulasi)',
};
