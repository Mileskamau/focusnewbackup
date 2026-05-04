import 'package:flutter/material.dart';
import 'package:focus_swiftbill/services/database_service.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  void _exportData(BuildContext context) {
    try {
      final products = DatabaseService.getProducts().values.toList();
      final customers = DatabaseService.getCustomers().values.toList();
      final orders = DatabaseService.getOrders().values.toList();

      // In real app, use file_picker or share_plus to save
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup created (demo mode)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Export Backup'),
              subtitle: const Text('Save data to device storage'),
              onTap: () => _exportData(context),
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Import Backup'),
              subtitle: const Text('Restore from backup file'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Import coming soon'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
