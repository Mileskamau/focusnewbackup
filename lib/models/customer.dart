import 'package:hive/hive.dart';

part 'customer.g.dart';

@HiveType(typeId: 2)
class Customer extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String phone;

  @HiveField(3)
  String? email;

  @HiveField(4)
  String? address;

  @HiveField(5)
  int totalOrders;

  @HiveField(6)
  double totalSpent;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.totalOrders = 0,
    this.totalSpent = 0,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'],
        name: json['name'],
        phone: json['phone'],
        email: json['email'],
        address: json['address'],
        totalOrders: json['totalOrders'] ?? 0,
        totalSpent: (json['totalSpent'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'totalOrders': totalOrders,
        'totalSpent': totalSpent,
      };
}




