import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:focus_swiftbill/providers/navigation_provider.dart';
import 'package:focus_swiftbill/services/auth_service.dart';
import 'package:focus_swiftbill/services/database_service.dart';
import 'package:focus_swiftbill/services/rbac_service.dart';
import 'package:focus_swiftbill/models/order.dart';
import 'package:focus_swiftbill/models/product.dart';
import 'package:focus_swiftbill/screens/more/more_screen.dart';
import 'package:focus_swiftbill/theme/app_theme.dart';
import 'package:focus_swiftbill/utils/constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final AuthService _auth = AuthService();
  final DatabaseService _db = DatabaseService();
  final RbacService _rbac = RbacService();

  bool _isLoading = true;
  List<Order> _orders = [];
  List<Product> _topProducts = [];
  double _todaySales = 0;
  int _todayOrdersCount = 0;
  int _lowStockCount = 0;

  // New variables for pending bills
  int _pendingBillsCount = 0;
  double _pendingBillsTotal = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData(); // Refresh when app returns to foreground
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also refresh when the screen is rebuilt (e.g., after tab switch)
    _loadData();
  }

  Future<void> _loadData() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final ordersBox = DatabaseService.getOrders();
    final productsBox = DatabaseService.getProducts();

    final allOrders = ordersBox.values.toList();
    
    final todayOrdersList = allOrders
        .where((o) => o.orderDate == today)
        .toList();

    final todaySales = todayOrdersList
        .where((o) => o.status == AppConstants.statusCompleted)
        .fold(0.0, (sum, o) => sum + o.total);

    final topProducts = DatabaseService.getTopSellingProducts(limit: 5);
    final lowStock = productsBox.values.where((p) => p.stockQty < 5).length;

    // ---- Load pending bills data ----
    final pendingBox = DatabaseService.getPendingBills();
    final pendingList = pendingBox.values.toList();
    final pendingCount = pendingList.length;
    final pendingTotal = pendingList.fold(0.0, (sum, order) => sum + order.total);

    setState(() {
      _orders = allOrders;
      _todaySales = todaySales;
      _todayOrdersCount = todayOrdersList.length;
      _topProducts = topProducts;
      _lowStockCount = lowStock;
      _pendingBillsCount = pendingCount;
      _pendingBillsTotal = pendingTotal;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userRole = _auth.getUserRole() ?? AppConstants.roleCashier;
    final userName = _auth.getUserName() ?? 'User';
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayOrders = _orders.where((o) => o.orderDate == today).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Good ${_getTimeOfDay()}, $userName'),
            Text(
              _rbac.getStoreName(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Exit App'),
                  content: const Text('Are you sure you want to exit?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        exit(0);
                      },
                      child: const Text('Exit'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context, userName, userRole),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  // KPI Cards Row (now with 4 cards)
                  SizedBox(
  child: Column(
    children: [
      // Top row
      Row(
        children: [
          Expanded(
            child: _buildKpiCard(
              title: "Today's Sales",
              value: '${_todaySales.toStringAsFixed(2)}',
              text: 'Rs',
              color: AppTheme.primaryOrange,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: _buildKpiCard(
              title: "Today's Orders",
              value: '$_todayOrdersCount',
              icon: Icons.receipt_long,
              color: Colors.blue,
            ),
          ),
        ],
      ),

      const SizedBox(height: 15),

      // Bottom row
      Row(
        children: [
          Expanded(
            child: _buildKpiCard(
              title: "Total Bills",
              value: '${_pendingBillsTotal.toStringAsFixed(2)}',
              text: 'Rs',
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: _buildKpiCard(
              title: "Total Bills count",
              value: '$_pendingBillsCount',
              icon: Icons.pending_actions,
              color: Colors.orange.shade700,
            ),
          ), 
        ],
      ),
    ],
  ),
),
                  const SizedBox(height: 24),
                  // Manager-only sections
                  if (_rbac.canViewFullDashboard(userRole)) ...[
                    const Text(
                      'Last 7 Days Sales',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildSalesChart(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Payment Method Split',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildPaymentChart(todayOrders),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Top 5 Selling Products',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _topProducts.length,
                        itemBuilder: (context, index) {
                          final product = _topProducts[index];
                          return Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    color: AppTheme.primaryOrange.withOpacity(0.1),
                                    child: Icon(
                                      Icons.inventory_2,
                                      size: 40,
                                      color: AppTheme.primaryOrange,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  product.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Qty: ${product.stockQty}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Quick Actions
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(width: 12),
                      if (userRole == AppConstants.roleManager) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionCard(
                            icon: Icons.inventory_2,
                            title: 'Stock Alert',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Coming soon'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    IconData? icon,
    String? text,
    required Color color,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryOrange, AppTheme.primaryLightOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart() {
    final days = List.generate(7, (i) {
      final date = DateTime.now().subtract(Duration(days: 6 - i));
      return DateFormat('E').format(date);
    });

    final lastSpot = _todaySales > 0 ? _todaySales : 2000.0;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(days[index], style: const TextStyle(fontSize: 10)),
                  );
                }
                return const Text('');
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: lastSpot * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: [
              const FlSpot(0, 1000),
              const FlSpot(1, 1500),
              const FlSpot(2, 1200),
              const FlSpot(3, 1800),
              const FlSpot(4, 2200),
              const FlSpot(5, 1900),
              FlSpot(6, lastSpot),
            ],
            isCurved: true,
            color: AppTheme.primaryOrange,
            barWidth: 4,
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primaryOrange.withOpacity(0.2),
            ),
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChart(List<Order> orders) {
    final cash = orders.where((o) => o.paymentMethod == AppConstants.paymentCash).length;
    final card = orders.where((o) => o.paymentMethod == AppConstants.paymentCard).length;
    final cheque = orders.where((o) => o.paymentMethod == 'cheque').length;
    final total = orders.length.toDouble();
    if (total == 0) return const Center(child: Text('No data'));

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(
            value: cash.toDouble(),
            title: '${(cash / total * 100).toStringAsFixed(0)}%',
            color: Colors.blue,
            radius: 50,
          ),
          PieChartSectionData(
            value: card.toDouble(),
            title: '${(card / total * 100).toStringAsFixed(0)}%',
            color: Colors.green,
            radius: 50,
          ),
          PieChartSectionData(
            value: cheque.toDouble(),
            title: '${(cheque / total * 100).toStringAsFixed(0)}%',
            color: Colors.orange,
            radius: 50,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, String userName, String userRole) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryOrange, AppTheme.primaryLightOrange],
              ),
            ),
            accountName: Text(userName),
            accountEmail: Text(userRole),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: AppTheme.primaryOrange),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ExpansionTile(
            leading: const Icon(Icons.point_of_sale),
            title: const Text('Billing'),
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('New Bill'),
                onTap: () {
                  Provider.of<NavigationProvider>(context, listen: false).setIndex(1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('View bill'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/pending_bills');
                },
              ),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Receipts'),
            onTap: () {
              Provider.of<NavigationProvider>(context, listen: false).setIndex(3);
              Navigator.pop(context);
            },
          ),
          ExpansionTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Sales Orders'),
            children: [
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('New Sales Orders'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/salesorders');
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('View Sales Orders'),
                onTap: () {
                  Provider.of<NavigationProvider>(context, listen: false).setIndex(2);
                  Navigator.pop(context, '/salesorders');
                },
              ),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MoreScreen()),
              );
            },
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _handleLogout(context);
            },
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Powered by Focus Softnet Pvt LTD',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    AuthService().logout();
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }
}