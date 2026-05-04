import 'package:flutter/material.dart';

class PrinterSettingsScreen extends StatelessWidget {
  const PrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer Settings')),
      body: const Center(
        child: Text('Printer configuration coming soon'),
      ),
    );
  }
}
