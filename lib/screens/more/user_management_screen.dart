import 'package:flutter/material.dart';
import 'package:focus_swiftbill/services/auth_service.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: const Center(
        child: Text('User management coming soon'),
      ),
    );
  }
}
