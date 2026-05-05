import 'package:hive/hive.dart';
import 'cart_item.dart';

part 'product.g.dart';

@HiveType(typeId: 0)
class Product extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String barcode;

  @HiveField(3)
  double price;

  @HiveField(4)
  double costPrice;

  @HiveField(5)
  int stockQty;

  @HiveField(6)
  String category;

  @HiveField(7)
  String? imageUrl;

  @HiveField(8)
  bool isActive;

  @HiveField(9)
  double taxRate;

  @HiveField(10)
  String currencyCode;

  Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.costPrice,
    required this.stockQty,
    required this.category,
    this.imageUrl,
    required this.isActive,
    this.taxRate = 0,
    this.currencyCode = '',
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: _firstString(json, const ['code', 'Code', 'id', 'Id']),
        name: _firstString(json, const ['name', 'Name']),
        barcode: _firstString(
          json,
          const ['barcode', 'Barcode', 'BarCode', 'barCode'],
          fallback: '',
        ),
        price: _firstDouble(json, const ['price', 'Price']),
        costPrice: _firstDouble(
          json,
          const ['cost', 'Cost', 'costPrice', 'CostPrice'],
        ),
        stockQty: _firstInt(
          json,
          const ['stockQty', 'StockQty', 'stockqty'],
        ),
        category: _firstString(
          json,
          const ['category', 'Category'],
          fallback: 'General',
        ),
        imageUrl: _firstNullableString(
          json,
          const ['imageUrl', 'ImageUrl', 'image', 'Image'],
        ),
        isActive: _firstBool(
          json,
          const ['isActive', 'IsActive', 'active', 'Active'],
          fallback: true,
        ),
        taxRate: _firstDouble(
          json,
          const ['taxRate', 'TaxRate', 'tax', 'Tax', 'Val1'],
        ),
        currencyCode: _firstString(
          json,
          const ['currencyCode', 'CurrencyCode', 'currency', 'Currency', 'Currency__Code'],
        ),
      );

  factory Product.fromApiMap(Map<String, dynamic> json) => Product(
        id: _firstString(
          json,
          const [
            'code',
            'Code',
            'ProductCode',
            'productCode',
            'ItemCode',
            'itemCode',
            'ProductId',
            'productId',
            'ProductId__Id',
            'ProductId__Code',
            'MasterId',
            'masterId',
            'iMasterId',
            'Id',
            'id',
          ],
          fallback: _firstString(
            json,
            const ['barcode', 'Barcode', 'BarCode', 'barCode', 'name', 'Name'],
          ),
        ),
        name: _firstString(
          json,
          const [
            'name',
            'Name',
            'ProductName',
            'productName',
            'ItemName',
            'itemName',
            'sName',
            'DisplayName',
            'ProductId__Name',
          ],
        ),
        barcode: _firstString(
          json,
          const [
            'barcode',
            'Barcode',
            'BarCode',
            'barCode',
            'EANCode',
            'EanCode',
            'UPC',
            'upc',
            'ProductId__Code',
          ],
          fallback: '',
        ),
        price: _firstDouble(
          json,
          const [
            'price',
            'Price',
            'Rate',
            'rate',
            'MRP',
            'mrp',
            'SellingPrice',
            'sellingPrice',
            'SalesRate',
            'salesRate',
            'RetailPrice',
            'retailPrice',
            'Val0',
          ],
        ),
        costPrice: _firstDouble(
          json,
          const [
            'cost',
            'Cost',
            'costPrice',
            'CostPrice',
            'PurchaseRate',
            'purchaseRate',
            'BuyingPrice',
            'buyingPrice',
          ],
          fallback: _firstDouble(
            json,
            const [
              'price',
              'Price',
              'Rate',
              'rate',
              'MRP',
              'mrp',
              'SellingPrice',
              'sellingPrice',
              'Val0',
            ],
          ),
        ),
        stockQty: _firstInt(
          json,
          const [
            'stockQty',
            'StockQty',
            'stockqty',
            'Stock',
            'stock',
            'Qty',
            'qty',
            'Quantity',
            'quantity',
            'BalanceQty',
            'balanceQty',
          ],
        ),
        category: _firstString(
          json,
          const [
            'category',
            'Category',
            'GroupName',
            'groupName',
            'Department',
            'department',
            'ParentName',
            'parentName',
            'PriceBookName',
            'Abbrevtion',
          ],
          fallback: 'General',
        ),
        imageUrl: _firstNullableString(
          json,
          const ['imageUrl', 'ImageUrl', 'image', 'Image'],
        ),
        isActive: _firstBool(
          json,
          const ['isActive', 'IsActive', 'Active', 'active', 'Status', 'status', 'bActive'],
          fallback: true,
        ),
        taxRate: _firstDouble(
          json,
          const ['taxRate', 'TaxRate', 'Tax', 'tax', 'Val1'],
        ),
        currencyCode: _firstString(
          json,
          const ['currencyCode', 'CurrencyCode', 'currency', 'Currency', 'Currency__Code'],
        ),
      );

  Map<String, dynamic> toJson() => {
        'code': id,
        'name': name,
        'barcode': barcode,
        'price': price,
        'cost': costPrice,
        'stockQty': stockQty,
        'category': category,
        'imageUrl': imageUrl,
        'isActive': isActive,
        'taxRate': taxRate,
        'currencyCode': currencyCode,
      };

  static String _firstString(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return fallback;
  }

  static String? _firstNullableString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    final value = _firstString(json, keys);
    return value.isEmpty ? null : value;
  }

  static double _firstDouble(
    Map<String, dynamic> json,
    List<String> keys, {
    double fallback = 0,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is num) {
        return value.toDouble();
      }
      final parsed = double.tryParse(value.toString().replaceAll(',', '').trim());
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback;
  }

  static int _firstInt(
    Map<String, dynamic> json,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      final parsed = int.tryParse(value.toString().replaceAll(',', '').trim());
      if (parsed != null) {
        return parsed;
      }
      final parsedDouble =
          double.tryParse(value.toString().replaceAll(',', '').trim());
      if (parsedDouble != null) {
        return parsedDouble.toInt();
      }
    }
    return fallback;
  }

  static bool _firstBool(
    Map<String, dynamic> json,
    List<String> keys, {
    bool fallback = false,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      final text = value.toString().trim().toLowerCase();
      if (text.isEmpty) continue;
      if (text == 'true' ||
          text == '1' ||
          text == 'yes' ||
          text == 'y' ||
          text == 'active' ||
          text == 'enabled') {
        return true;
      }
      if (text == 'false' ||
          text == '0' ||
          text == 'no' ||
          text == 'n' ||
          text == 'inactive' ||
          text == 'disabled') {
        return false;
      }
    }
    return fallback;
  }
}
