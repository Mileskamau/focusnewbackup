import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:focus_swiftbill/models/order.dart';
import 'package:focus_swiftbill/theme/app_theme.dart';
import 'package:focus_swiftbill/utils/constants.dart';
import 'package:focus_swiftbill/providers/navigation_provider.dart';
import 'package:focus_swiftbill/providers/data_refresh_provider.dart';

class ReceiptScreen extends StatelessWidget {
  final Order order;
  final double change;

  const ReceiptScreen({super.key, required this.order, required this.change});

  void _goToDashboard(BuildContext context) {
    Provider.of<DataRefreshProvider>(context, listen: false).refresh();
    Provider.of<NavigationProvider>(context, listen: false).setIndex(0);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final horizontalPadding = isSmallScreen ? 12.0 : 24.0;
    final cardPadding = isSmallScreen ? 12.0 : 20.0;
    final headerIconSize = screenSize.width * 0.1; // ~40 on phone
    final fontSizeBase = isSmallScreen ? 11.0 : 13.0;
    final smallFont = fontSizeBase - 1;
    final largeFont = fontSizeBase + 2;

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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Print feature coming soon'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Share feature coming soon'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              height: constraints.maxHeight,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 12.0,
              ),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(cardPadding),
                  child: Column(
                    children: [
                      // ----- Header (Payment Success) -----
                      Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(cardPadding * 0.5),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_circle,
                              size: headerIconSize,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Payment Successful',
                            style: TextStyle(
                              fontSize: fontSizeBase + 4,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ----- Store Info -----
                      Column(
                        children: [
                          Text(
                            'FOCUS SwiftBill',
                            style: TextStyle(
                              fontSize: fontSizeBase + 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '123 Main Street, City',
                            style: TextStyle(
                              fontSize: smallFont,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'GSTIN: 12ABCDE1234F',
                            style: TextStyle(
                              fontSize: smallFont,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ----- Order Details -----
                      _buildInfoRow('Order #', order.orderNumber, fontSizeBase),
                      const SizedBox(height: 2),
                      _buildInfoRow(
                        'Date',
                        '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                        fontSizeBase,
                      ),
                      const SizedBox(height: 2),
                      _buildInfoRow(
                        'Time',
                        '${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                        fontSizeBase,
                      ),
                      const SizedBox(height: 2),
                      _buildInfoRow('Cashier', order.userName, fontSizeBase),
                      const Divider(height: 16),

                      // ----- Items (Scrollable if needed) -----
                      Expanded(
                        child: ListView.builder(
                          itemCount: order.items.length,
                          shrinkWrap: true,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final item = order.items[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.product.name} x${item.quantity}',
                                      style: TextStyle(fontSize: smallFont),
                                    ),
                                  ),
                                  Text(
                                    '${AppConstants.currencySymbol}${item.total.toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: smallFont),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // ----- Totals -----
                      Column(
                        children: [
                          const Divider(height: 16),
                          _buildTotalRow('Subtotal', order.subtotal, fontSizeBase),
                          const SizedBox(height: 2),
                          _buildTotalRow('Tax (18%)', order.tax, fontSizeBase),
                          const Divider(),
                          _buildTotalRow(
                            'TOTAL',
                            order.total,
                            fontSizeBase,
                            isBold: true,
                            isLarge: true,
                          ),
                          const SizedBox(height: 12),

                          // ----- Payment Method & Change -----
                          Row(
                            children: [
                              Text(
                                'Paid via: ',
                                style: TextStyle(fontSize: smallFont),
                              ),
                              Chip(
                                label: Text(
                                  order.paymentMethod.toUpperCase(),
                                  style: TextStyle(fontSize: smallFont - 1),
                                ),
                                backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          if (order.paymentMethod == AppConstants.paymentCash && change > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Change',
                                  style: TextStyle(fontSize: smallFont),
                                ),
                                Text(
                                  '${AppConstants.currencySymbol}${change.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: fontSizeBase,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),

                          // ----- Thank You -----
                          Center(
                            child: Text(
                              'Thank you for shopping with us!',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                                fontSize: smallFont,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ----- Action Buttons -----
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Provider.of<NavigationProvider>(context, listen: false)
                                        .setIndex(1);
                                    Navigator.of(context).popUntil((route) => route.isFirst);
                                  },
                                  icon: const Icon(Icons.add_shopping_cart),
                                  label: Text(
                                    'New Receipt',
                                    style: TextStyle(fontSize: fontSizeBase),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _goToDashboard(context),
                                  icon: const Icon(Icons.home),
                                  label: Text(
                                    'Dashboard',
                                    style: TextStyle(fontSize: fontSizeBase),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: fontSize - 1, color: Colors.grey[700])),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: fontSize - 1),
        ),
      ],
    );
  }

  Widget _buildTotalRow(String label, double amount, double fontSize,
      {bool isBold = false, bool isLarge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isLarge ? fontSize + 2 : fontSize,
          ),
        ),
        Text(
          '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isLarge ? fontSize + 2 : fontSize,
            color: isLarge ? AppTheme.primaryOrange : null,
          ),
        ),
      ],
    );
  }
}