num _n(dynamic v) => num.tryParse(v.toString()) ?? 0;

class Category {
  final int id;
  final String name;
  Category(this.id, this.name);
  factory Category.fromJson(Map j) => Category(j['id'], j['name']);
}

class Product {
  final int id, stock;
  final String name, brand, description;
  final num price, weight;
  final String? image, category;
  Product.fromJson(Map j)
      : id = j['id'],
        stock = _n(j['stock']).toInt(),
        name = j['name'],
        brand = j['brand'] ?? '-',
        description = j['description'] ?? '',
        price = _n(j['price']),
        weight = _n(j['weight']),
        image = j['image_url'],
        category = j['category'] is Map ? j['category']['name'] : j['category'];
}

class CartItem {
  final int id;
  int quantity;
  final Product product;
  CartItem.fromJson(Map j)
      : id = j['id'],
        quantity = j['quantity'],
        product = Product.fromJson(j['product']);
  num get subtotal => product.price * quantity;
}
