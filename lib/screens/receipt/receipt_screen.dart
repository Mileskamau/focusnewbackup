import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:focus_swiftbill/models/order.dart';
import 'package:focus_swiftbill/theme/app_theme.dart';
import 'package:focus_swiftbill/utils/constants.dart';
import 'package:focus_swiftbill/providers/navigation_provider.dart';
import 'package:focus_swiftbill/providers/data_refresh_provider.dart';
import 'package:focus_swiftbill/screens/receipt/receipt_print_screen.dart';

class ReceiptScreen extends StatelessWidget {
  final Order order;
  final double change;

  const ReceiptScreen({super.key, required this.order, required this.change});

  String get _currencyLabel {
    for (final item in order.items) {
      final code = item.product.currencyCode.trim();
      if (code.isNotEmpty) {
        return code;
      }
    }
    return AppConstants.currencySymbol;
  }

  void _goToDashboard(BuildContext context) {
    Provider.of<DataRefreshProvider>(context, listen: false).refresh();
    Provider.of<NavigationProvider>(context, listen: false).setIndex(0);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    const double receiptWidth = 280; // ~80mm POS roll
    const double baseFont = 9;
    const double smallFont = 8;
    const double largeFont = 11;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          _goToDashboard(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Receipt'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _goToDashboard(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ReceiptPrintScreen(
                      order: order,
                      change: change,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: receiptWidth,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Center(
                    child: Text(
                      'FOCUS SwiftBill',
                      style: TextStyle(
                        fontSize: largeFont,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      '123 Main Street, City',
                      style: TextStyle(fontSize: smallFont),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'GSTIN: 12ABCDE1234F',
                      style: TextStyle(fontSize: smallFont),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const _Dashed(),
                  const SizedBox(height: 4),
                  _row('Order #', order.orderNumber),
                  _row(
                    'Date',
                    '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                  ),
                  _row(
                    'Time',
                    '${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                  ),
                  _row('Cashier', order.userName),
                  const SizedBox(height: 4),
                  const _Dashed(),
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Expanded(
                        flex: 5,
                        child: Text(
                          'Item',
                          style: TextStyle(
                            fontSize: smallFont,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Qty',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: smallFont,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Amt',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: smallFont,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  ...order.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              item.product.name,
                              style: const TextStyle(fontSize: smallFont),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              '${item.quantity}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: smallFont),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '$_currencyLabel${item.total.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: smallFont),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const _Dashed(),
                  const SizedBox(height: 4),
                  _amountRow('Subtotal', order.subtotal),
                  _amountRow('Tax (18%)', order.tax),
                  const _Dashed(),
                  const SizedBox(height: 2),
                  _amountRow('TOTAL', order.total, isBold: true, isLarge: true),
                  const SizedBox(height: 4),
                  _row('Paid via', order.paymentMethod.toUpperCase()),
                  if (order.paymentMethod == AppConstants.paymentCash &&
                      change > 0)
                    _amountRow('Change', change, isBold: true),
                  const SizedBox(height: 6),
                  const _Dashed(),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Thank you for shopping with us!',
                      style: TextStyle(
                        fontSize: smallFont,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Provider.of<NavigationProvider>(context,
                                    listen: false)
                                .setIndex(1);
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text(
                            'New',
                            style: TextStyle(fontSize: baseFont),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _goToDashboard(context),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text(
                            'Home',
                            style: TextStyle(fontSize: baseFont),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 8)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(String label, double amount,
      {bool isBold = false, bool isLarge = false}) {
    final size = isLarge ? 11.0 : 9.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: size,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '$_currencyLabel${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: size,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isLarge ? AppTheme.primaryOrange : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dashed extends StatelessWidget {
  const _Dashed();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 3.0;
        const dashSpace = 2.0;
        final dashCount =
            (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dashCount,
            (_) => const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black54),
              ),
            ),
          ),
        );
      },
    );
  }
}
