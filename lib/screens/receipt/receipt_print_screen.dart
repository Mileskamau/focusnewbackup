import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:focus_swiftbill/models/order.dart';
import 'package:focus_swiftbill/utils/constants.dart';

class ReceiptPrintScreen extends StatelessWidget {
  const ReceiptPrintScreen({
    super.key,
    required this.order,
    required this.change,
  });

  final Order order;
  final double change;

  String get _currencyLabel {
    for (final item in order.items) {
      final code = item.product.currencyCode.trim();
      if (code.isNotEmpty) {
        return code;
      }
    }
    return AppConstants.currencySymbol;
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    final dateLabel = DateFormat('dd/MM/yyyy').format(order.createdAt);
    final timeLabel = DateFormat('HH:mm').format(order.createdAt);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(18),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'Focus SwiftBill',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text('Sales Receipt')),
          pw.SizedBox(height: 14),
          _infoRow('Order #', order.orderNumber),
          _infoRow('Date', dateLabel),
          _infoRow('Time', timeLabel),
          _infoRow('Cashier', order.userName),
          _infoRow('Payment', order.paymentMethod.toUpperCase()),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(
                flex: 5,
                child: pw.Text(
                  'Item',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Qty',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Amount',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          ...order.items.map(
            (item) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text(item.product.name),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(item.quantity.toString()),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        '$_currencyLabel${item.total.toStringAsFixed(2)}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.SizedBox(height: 6),
          _amountRow('Subtotal', order.subtotal),
          _amountRow('Tax', order.tax),
          _amountRow('Total', order.total, isBold: true),
          if (order.paymentMethod.toLowerCase() == 'cash' && change > 0)
            _amountRow('Change', change),
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Text(
              'Thank you for shopping with us!',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(value),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _amountRow(String label, double amount, {bool isBold = false}) {
    final style = pw.TextStyle(
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text('$_currencyLabel${amount.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Receipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              await Printing.layoutPdf(onLayout: _buildPdf);
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: _buildPdf,
        allowSharing: false,
        canDebug: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: '${order.orderNumber}.pdf',
      ),
    );
  }
}
