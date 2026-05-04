import 'package:flutter/material.dart';
import 'package:focus_swiftbill/models/order.dart';
import 'package:focus_swiftbill/services/database_service.dart';
import 'package:focus_swiftbill/theme/app_theme.dart';
import 'package:focus_swiftbill/utils/constants.dart';

class PendingBillsScreen extends StatefulWidget {
  const PendingBillsScreen({super.key});

  @override
  State<PendingBillsScreen> createState() => _PendingBillsScreenState();
}

class _PendingBillsScreenState extends State<PendingBillsScreen> {
  List<Order> _pendingBills = [];

  @override
  void initState() {
    super.initState();
    _loadPendingBills();
  }

  Future<void> _loadPendingBills() async {
    final box = DatabaseService.getPendingBills();
    setState(() {
      _pendingBills = box.values.toList();
      _pendingBills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
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

  Future<void> _confirmOrder(Order order) async {
    // Move order to completed orders
    final ordersBox = DatabaseService.getOrders();
    await ordersBox.put(order.id, order);
    // Remove from pending
    final pendingBox = DatabaseService.getPendingBills();
    await pendingBox.delete(order.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order confirmed and saved'), behavior: SnackBarBehavior.floating),
      );
      _loadPendingBills();
    }
  }

  Future<void> _cancelOrder(Order order) async {
    // Restore product stocks
    final productsBox = DatabaseService.getProducts();
    for (var item in order.items) {
      final product = productsBox.get(item.product.id);
      if (product != null) {
        product.stockQty += item.quantity;
        await productsBox.put(product.id, product);
      }
    }
    // Delete from pending
    final pendingBox = DatabaseService.getPendingBills();
    await pendingBox.delete(order.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled and stock restored'), behavior: SnackBarBehavior.floating),
      );
      _loadPendingBills();
    }
  }

  void _showOrderDetails(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(order.orderNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(order.status.toUpperCase(), style: TextStyle(color: _getStatusColor(order.status))),
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
                          subtitle: Text('${AppConstants.currencySymbol}${item.product.price} × ${item.quantity}'),
                          trailing: Text('${AppConstants.currencySymbol}${item.total.toStringAsFixed(2)}'),
                        )),
                    const Divider(),
                    _buildSummaryRow('Subtotal', order.subtotal),
                    _buildSummaryRow('Tax (18%)', order.tax),
                    _buildSummaryRow('Total', order.total, isBold: true),
                    const SizedBox(height: 24),
                    Row(children: [const Icon(Icons.payment, size: 16), const SizedBox(width: 4), Text('Paid via ${order.paymentMethod}')]),
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
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bills')),
      body: _pendingBills.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No pending bills'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pendingBills.length,
              itemBuilder: (context, index) {
                final order = _pendingBills[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.receipt_long, color: AppTheme.primaryOrange, size: 24),
                    ),
                    title: Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.userName),
                        Text(
                          '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} ${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${AppConstants.currencySymbol}${order.total.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryOrange),
                        ),
                        const SizedBox(height: 8),
                        
                      ],
                    ),
                    onTap: () => _showOrderDetails(order),
                  ),
                );
              },
            ),
    );
  }
}