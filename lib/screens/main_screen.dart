import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:focus_swiftbill/providers/navigation_provider.dart';
import 'dashboard/dashboard_screen.dart';
import 'billing/billing_hub_screen.dart';
import 'orders/orders_screen.dart';
import 'receipt/receipts_list_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const List<Widget> _screens = <Widget>[
    DashboardScreen(),
    BillingHubScreen(),
    OrdersScreen(),
    ReceiptsListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final currentIndex = navigationProvider.currentIndex;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          final navProvider = context.read<NavigationProvider>();

          if (navProvider.currentIndex != 0) {
            // Switch to Dashboard tab (index 0)
            navProvider.setIndex(0);
          } else {
            // Already on Dashboard - show exit confirmation dialog
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
                      Navigator.of(context).pop(); // Close dialog
                      exit(0);                     // Exit the app
                    },
                    child: const Text('Exit'),
                  ),
                ],
              ),
            );
          }
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            navigationProvider.setIndex(index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.point_of_sale),
              label: 'Billing',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment),
              label: 'Sales Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long),
              label: 'Receipts',
            ),
          ],
        ),
      ),
    );
  }
}