import 'package:hive/hive.dart';
import 'product.dart';

part 'cart_item.g.dart';

@HiveType(typeId: 1)
class CartItem extends HiveObject {
  @HiveField(0)
  Product product;

  @HiveField(1)
  int quantity;

  @HiveField(2)
  double discount;

  CartItem({
    required this.product,
    required this.quantity,
    this.discount = 0.0,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        product: Product.fromJson(json['product']),
        quantity: json['quantity'],
        discount: (json['discount'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'quantity': quantity,
        'discount': discount,
      };

   double get total => product.price * quantity * (1.0 - discount);
}
