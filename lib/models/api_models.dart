import 'package:hive/hive.dart';

part 'api_models.g.dart';

@HiveType(typeId: 4)
class DashboardData extends HiveObject {
  @HiveField(0)
  String fSessionId;

  @HiveField(1)
  String username;

  @HiveField(2)
  String role;

  @HiveField(3)
  String name;

  @HiveField(4)
  int pendingApprovals;

  @HiveField(5)
  int lowStockItems;

  @HiveField(6)
  int pendingOrders;

  DashboardData({
    required this.fSessionId,
    required this.username,
    required this.role,
    required this.name,
    required this.pendingApprovals,
    required this.lowStockItems,
    required this.pendingOrders,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
        fSessionId: json['fSessionId'],
        username: json['username'],
        role: json['role'],
        name: json['name'],
        pendingApprovals: json['pendingApprovals'],
        lowStockItems: json['lowStockItems'],
        pendingOrders: json['pendingOrders'],
      );

  Map<String, dynamic> toJson() => {
        'fSessionId': fSessionId,
        'username': username,
        'role': role,
        'name': name,
        'pendingApprovals': pendingApprovals,
        'lowStockItems': lowStockItems,
        'pendingOrders': pendingOrders,
      };
}

@HiveType(typeId: 5)
class SalesData extends HiveObject {
  @HiveField(0)
  String voucherNo;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String customerCode;

  @HiveField(3)
  String customerName;

  @HiveField(4)
  String cashierCode;

  @HiveField(5)
  String cashierName;

  @HiveField(6)
  double totalAmount;

  @HiveField(7)
  double taxAmount;

  @HiveField(8)
  double netAmount;

  @HiveField(9)
  String paymentMethod;

  @HiveField(10)
  String status;

  @HiveField(11)
  List<SalesItem> items;

  SalesData({
    required this.voucherNo,
    required this.date,
    required this.customerCode,
    required this.customerName,
    required this.cashierCode,
    required this.cashierName,
    required this.totalAmount,
    required this.taxAmount,
    required this.netAmount,
    required this.paymentMethod,
    required this.status,
    required this.items,
  });

  factory SalesData.fromJson(Map<String, dynamic> json) => SalesData(
        voucherNo: json['voucherNo'],
        date: DateTime.parse(json['date']),
        customerCode: json['customerCode'],
        customerName: json['customerName'],
        cashierCode: json['cashierCode'],
        cashierName: json['cashierName'],
        totalAmount: json['totalAmount'].toDouble(),
        taxAmount: json['taxAmount'].toDouble(),
        netAmount: json['netAmount'].toDouble(),
        paymentMethod: json['paymentMethod'],
        status: json['status'],
        items: (json['items'] as List)
            .map((i) => SalesItem.fromJson(i))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'voucherNo': voucherNo,
        'date': date.toIso8601String(),
        'customerCode': customerCode,
        'customerName': customerName,
        'cashierCode': cashierCode,
        'cashierName': cashierName,
        'totalAmount': totalAmount,
        'taxAmount': taxAmount,
        'netAmount': netAmount,
        'paymentMethod': paymentMethod,
        'status': status,
        'items': items.map((i) => i.toJson()).toList(),
      };
}

@HiveType(typeId: 6)
class SalesItem extends HiveObject {
  @HiveField(0)
  String itemCode;

  @HiveField(1)
  String itemName;

  @HiveField(2)
  double qty;

  @HiveField(3)
  double rate;

  @HiveField(4)
  double amount;

  @HiveField(5)
  double taxAmount;

  SalesItem({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.rate,
    required this.amount,
    required this.taxAmount,
  });

  factory SalesItem.fromJson(Map<String, dynamic> json) => SalesItem(
        itemCode: json['itemCode'],
        itemName: json['itemName'],
        qty: json['qty'].toDouble(),
        rate: json['rate'].toDouble(),
        amount: json['amount'].toDouble(),
        taxAmount: json['taxAmount'].toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'itemCode': itemCode,
        'itemName': itemName,
        'qty': qty,
        'rate': rate,
        'amount': amount,
        'taxAmount': taxAmount,
      };
}

@HiveType(typeId: 7)
class Supplier extends HiveObject {
  @HiveField(0)
  String code;

  @HiveField(1)
  String name;

  @HiveField(2)
  String address;

  @HiveField(3)
  String phone;

  @HiveField(4)
  String email;

  @HiveField(5)
  String gstin;

  Supplier({
    required this.code,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.gstin,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        code: json['code'],
        name: json['name'],
        address: json['address'],
        phone: json['phone'],
        email: json['email'],
        gstin: json['gstin'],
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'address': address,
        'phone': phone,
        'email': email,
        'gstin': gstin,
      };
}

@HiveType(typeId: 8)
class Account extends HiveObject {
  @HiveField(0)
  String code;

  @HiveField(1)
  String name;

  @HiveField(2)
  String accountType;

  @HiveField(3)
  String phone;

  @HiveField(4)
  String email;

  @HiveField(5)
  String address;

  Account({
    required this.code,
    required this.name,
    required this.accountType,
    required this.phone,
    required this.email,
    required this.address,
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        code: json['code'],
        name: json['name'],
        accountType: json['accountType'],
        phone: json['phone'],
        email: json['email'],
        address: json['address'],
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'accountType': accountType,
        'phone': phone,
        'email': email,
        'address': address,
      };
}
