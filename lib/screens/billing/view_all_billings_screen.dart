import 'package:flutter/material.dart';
import 'package:focus_swiftbill/services/database_service.dart';
import 'package:focus_swiftbill/models/order.dart';
import 'package:focus_swiftbill/theme/app_theme.dart';
import 'package:focus_swiftbill/utils/constants.dart';

class ViewAllBillingsScreen extends StatefulWidget {
  const ViewAllBillingsScreen({super.key});

  @override
  State<ViewAllBillingsScreen> createState() => _ViewAllBillingsScreenState();
}

class _ViewAllBillingsScreenState extends State<ViewAllBillingsScreen> {
  List<Order> _allBillings = [];
  List<Order> _filteredBillings = [];
  String _filterStatus = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBillings();
  }

  Future<void> _loadBillings() async {
    final ordersBox = DatabaseService.getOrders();
    final allOrders = ordersBox.values.toList();
    // Filter for completed status (actual billings)
    final completedOrders = allOrders
        .where((o) => o.status == AppConstants.statusCompleted)
        .toList();
    completedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    setState(() {
      _allBillings = completedOrders;
      _applyFilters();
    });
  }

  void _applyFilters() {
    var filtered = _allBillings;

    if (_filterStatus != 'All') {
      filtered = filtered.where((o) => o.status == _filterStatus).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((o) {
        return o.orderNumber.toLowerCase().contains(query) ||
            o.userName.toLowerCase().contains(query) ||
            o.paymentMethod.toLowerCase().contains(query) ||
            o.orderDate.contains(query);
      }).toList();
    }

    setState(() {
      _filteredBillings = filtered;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Billings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter by Status',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        children: ['All', AppConstants.statusCompleted]
                            .map((status) => FilterChip(
                                  label: Text(status),
                                  selected: _filterStatus == status,
                                  onSelected: (selected) {
                                    setState(() => _filterStatus = status);
                                    _applyFilters();
                                    Navigator.pop(context);
                                  },
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search billings...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredBillings.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No billings found'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredBillings.length,
                    itemBuilder: (context, index) {
                      final billing = _filteredBillings[index];
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
                            child: const Icon(
                              Icons.receipt_long,
                              color: AppTheme.primaryOrange,
                              size: 24,
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  billing.orderNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Text(
                                '${AppConstants.currencySymbol}${billing.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryOrange,
                                ),
                              ),
                            ],
                          ),
                        
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                'Customer: ${billing.userName}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                'Paid via ${billing.paymentMethod}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '${billing.createdAt.day}/${billing.createdAt.month}/${billing.createdAt.year} ${billing.createdAt.hour}:${billing.createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
