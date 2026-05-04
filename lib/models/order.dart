import 'package:hive/hive.dart';
import 'package:focus_swiftbill/services/database_service.dart';
import 'package:focus_swiftbill/models/cart_item.dart';
import 'package:focus_swiftbill/utils/constants.dart';
import 'package:intl/intl.dart';

part 'order.g.dart';

@HiveType(typeId: 3)
class Order extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String orderNumber;

  @HiveField(2)
  String userId;

  @HiveField(3)
  String userName;

  @HiveField(4)
  String userRole;

  @HiveField(5)
  List<CartItem> items;

  @HiveField(6)
  double subtotal;

  @HiveField(7)
  double tax;

  @HiveField(8)
  double total;

  @HiveField(9)
  String paymentMethod;

  @HiveField(10)
  String status;

  @HiveField(11)
  DateTime createdAt;

  @HiveField(12)
  bool synced;
  

  Order({
    required this.id,
    required this.orderNumber,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.synced = false,
  });

  String get orderDate => DateFormat('yyyy-MM-dd').format(createdAt);

  static Future<String> generateOrderNumber() async {
    try {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyyMMdd').format(now);
      final settings = DatabaseService.getSettings();
      final counterKey = 'order_counter_$dateKey';
      final result = settings.get(counterKey) as Map?;
      final value = result?["value"] as int?;
      int counter = (value ?? 0) + 1;  // Increment counter
      await settings.put(counterKey, {"value": counter});
      return 'ORD-$dateKey-${counter.toString().padLeft(6, '0')}';
    } catch (e) {
      // Fallback if Hive operation fails
      final now = DateTime.now();
      final dateKey = DateFormat('yyyyMMdd').format(now);
      final timestamp = now.millisecondsSinceEpoch % 100000;
      return 'ORD-$dateKey-FALLBACK-${timestamp.toString().padLeft(5, '0')}';
    }
  }

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'],
        orderNumber: json['orderNumber'],
        userId: json['userId'],
        userName: json['userName'],
        userRole: json['userRole'],
        items: (json['items'] as List)
            .map((i) => CartItem.fromJson(i))
            .toList(),
        subtotal: json['subtotal'].toDouble(),
        tax: json['tax'].toDouble(),
        total: json['total'].toDouble(),
        paymentMethod: json['paymentMethod'],
        status: json['status'],
        createdAt: DateTime.parse(json['createdAt']),
        synced: json['synced'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
        'items': items.map((i) => i.toJson()).toList(),
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'paymentMethod': paymentMethod,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'synced': synced,
      };
}














