import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:focus_swiftbill/providers/navigation_provider.dart';
import 'package:focus_swiftbill/services/auth_service.dart';
import 'package:focus_swiftbill/services/database_service.dart';
import 'package:focus_swiftbill/models/order.dart';
import 'package:focus_swiftbill/theme/app_theme.dart';
import 'package:focus_swiftbill/utils/constants.dart';

class ReceiptsListScreen extends StatefulWidget {
  const ReceiptsListScreen({super.key});

  @override
  State<ReceiptsListScreen> createState() => _ReceiptsListScreenState();
}

class _ReceiptsListScreenState extends State<ReceiptsListScreen> {
  final AuthService _auth = AuthService();

  List<Order> _orders = [];
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _loadOrders(); // now only clears orders and does not fetch from DB
  }

  // Modified: Never loads any actual receipt data.
  Future<void> _loadOrders() async {
    setState(() {
      _orders = []; // ensure list remains empty
    });
  }

  List<Order> get _filteredOrders {
    // Always empty because _orders is always empty
    if (_filterStatus == 'All') return _orders;
    return _orders.where((o) => o.status == _filterStatus).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.statusCompleted:
        return Colors.green;
      case AppConstants.statusCancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = _auth.getUserRole();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts'),
        
      ),
      body: _orders.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No receipts yet'),
                ],
              ),
            )
          : ListView.builder(
              // This branch will never be reached because _orders is always empty.
              padding: const EdgeInsets.all(16),
              itemCount: _filteredOrders.length,
              itemBuilder: (context, index) {
                final order = _filteredOrders[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.receipt_long,
                        color: AppTheme.primaryOrange,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      order.orderNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.userName),
                        Text(
                          '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} ${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${AppConstants.currencySymbol}${order.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            order.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(order.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showOrderDetails(order, userRole ?? AppConstants.roleCashier),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // No functionality: does nothing.
        },
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('New Receipt'),
      ),
    );
  }

  

  void _showOrderDetails(Order order, String userRole) {
    // This method will never be called because no receipt tile exists,
    // but we keep it to avoid any build error.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderNumber,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(order.status),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ...order.items.map((item) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.inventory_2),
                          title: Text(item.product.name),
                          subtitle: Text(
                              '${AppConstants.currencySymbol}${item.product.price} × ${item.quantity}'),
                          trailing: Text('${AppConstants.currencySymbol}${item.total.toStringAsFixed(2)}'),
                        )),
                    const Divider(),
                    _buildSummaryRow('Subtotal', order.subtotal),
                    _buildSummaryRow('Tax (10%)', order.tax),
                    _buildSummaryRow('Total', order.total, isBold: true),
                    const Divider(height: 24),
                    Text(
                      'Cashier: ${order.userName} (${order.userRole})',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.payment, size: 16),
                        const SizedBox(width: 4),
                        Text('Paid via ${order.paymentMethod}'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Print feature coming soon'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.print),
                            label: const Text('Print'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (order.status == AppConstants.statusCompleted &&
                            userRole == AppConstants.roleManager)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showReturnDialog(order);
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Return'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${AppConstants.currencySymbol}${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? AppTheme.primaryOrange : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showReturnDialog(Order order) {
    final Map<String, int> returnQuantities = {};
    for (var item in order.items) {
      returnQuantities[item.product.id] = 0;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return Items'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: order.items.map((item) {
              return ListTile(
                title: Text(item.product.name),
                subtitle: Text('Max: ${item.quantity}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        if ((returnQuantities[item.product.id] ?? 0) > 0) {
                          setState(() {
                            returnQuantities[item.product.id] =
                                returnQuantities[item.product.id]! - 1;
                          });
                        }
                      },
                    ),
                    Text('${returnQuantities[item.product.id] ?? 0}'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if ((returnQuantities[item.product.id] ?? 0) <
                            item.quantity) {
                          setState(() {
                            returnQuantities[item.product.id] =
                                returnQuantities[item.product.id]! + 1;
                          });
                        }
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Return processed'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              // No reload of orders needed – screen stays empty.
            },
            child: const Text('Process Return'),
          ),
        ],
      ),
    );
  }
}