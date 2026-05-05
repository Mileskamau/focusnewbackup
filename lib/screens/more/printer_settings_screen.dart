import 'package:flutter/material.dart';

class PrinterSettingsScreen extends StatelessWidget {
  const PrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _PrinterInfoCard(
            icon: Icons.print_outlined,
            title: 'Receipt Printing',
            subtitle:
                'Receipts can now be printed from the receipt screen using the device print dialog.',
          ),
          SizedBox(height: 12),
          _PrinterInfoCard(
            icon: Icons.bluetooth,
            title: 'Bluetooth / Wi-Fi Printers',
            subtitle:
                'Use your device print sheet to choose a supported printer. Direct printer pairing can be added later if needed.',
          ),
          SizedBox(height: 12),
          _PrinterInfoCard(
            icon: Icons.receipt_long,
            title: 'How To Print',
            subtitle:
                'Open any receipt, tap the print icon, preview the receipt, then choose Print.',
          ),
        ],
      ),
    );
  }
}

class _PrinterInfoCard extends StatelessWidget {
  const _PrinterInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
