import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:focus_swiftbill/providers/navigation_provider.dart';
import 'package:focus_swiftbill/screens/sales orders/salesorders.dart';

class BillingHubScreen extends StatefulWidget {
  const BillingHubScreen({super.key});

  @override
  State<BillingHubScreen> createState() => _BillingHubScreenState();
}

class _BillingHubScreenState extends State<BillingHubScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing'),
      ),
      body: const BillingScreen(),
    );
  }
}
