import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/config.dart';
import '../screens/product/product_screens.dart';

class ProductImage extends StatelessWidget {
  final String? url;
  final double? height;
  const ProductImage(this.url, {super.key, this.height});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: url == null
            ? const Icon(Icons.devices_other, size: 48, color: Colors.grey)
            : Image.network(resolveProductImageUrl(url!), fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 48, color: Colors.grey)),
      );
}

class ProductCard extends StatelessWidget {
  final Product p;
  const ProductCard(this.p, {super.key});
  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ProductDetailScreen(p.id))),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: ProductImage(p.image)),
              const SizedBox(height: 8),
              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(rp(p.price), style: const TextStyle(
                  color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
              Text(p.stock > 0 ? 'Stok: ${p.stock}' : 'Stok habis',
                  style: TextStyle(fontSize: 12,
                      color: p.stock > 0 ? Colors.green : Colors.red)),
            ]),
          ),
        ),
      );
}
