import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:focus_swiftbill/models/cart_item.dart';
import 'package:focus_swiftbill/models/order.dart';
import 'package:focus_swiftbill/providers/data_refresh_provider.dart';
import 'package:focus_swiftbill/providers/navigation_provider.dart';
import 'package:focus_swiftbill/theme/app_theme.dart';
import 'package:focus_swiftbill/utils/constants.dart';

class ReceiptScreen extends StatelessWidget {
  static const double _screenReceiptWidth = 280;
  static const double _baseFontSize = 9;
  static const double _smallFontSize = 8;
  static const String _storeAddress = '123 Main Street, City';
  static const String _storePhone = 'Phone: (555) 123-4567';
  static const String _storeTaxId = 'GSTIN: 12ABCDE1234F';

  final Order order;
  final double change;

  const ReceiptScreen({
    super.key,
    required this.order,
    required this.change,
  });

  String get _currencyLabel {
    for (final item in order.items) {
      final code = item.product.currencyCode.trim();
      if (code.isNotEmpty) {
        return code;
      }
    }
    return AppConstants.currencySymbol;
  }

  String get _formattedDateTime {
    return '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} '
        '${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}';
  }

  bool get _showChange {
    return order.paymentMethod == AppConstants.paymentCash && change > 0;
  }

  void _goToDashboard(BuildContext context) {
    Provider.of<DataRefreshProvider>(context, listen: false).refresh();
    Provider.of<NavigationProvider>(context, listen: false).setIndex(0);
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/main',
      (route) => false,
      arguments: 0,
    );
  }

  Future<void> _printReceipt() async {
    await Printing.layoutPdf(onLayout: _buildPdf);
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    final orange = PdfColor.fromInt(0xFFFFA500);
    final green = PdfColor.fromInt(0xFF4CAF50);
    final greenDark = PdfColor.fromInt(0xFF2E7D32);
    final greenLight = PdfColor.fromInt(0xFFE8F5E9);
    final grey300 = PdfColor.fromInt(0xFFE0E0E0);
    final grey400 = PdfColor.fromInt(0xFFBDBDBD);
    final grey500 = PdfColor.fromInt(0xFF9E9E9E);
    final grey700 = PdfColor.fromInt(0xFF616161);
    final receiptWidth = 80 * PdfPageFormat.mm;
    final longNameBuffer =
        order.items.where((item) => item.product.name.length > 18).length * 10;
    final pageHeight = 430 +
        (order.items.length * 24) +
        longNameBuffer +
        (_showChange ? 24 : 0);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(receiptWidth + 16, pageHeight.toDouble()),
        margin: const pw.EdgeInsets.all(8),
        build: (context) => pw.Center(
          child: pw.Container(
            width: receiptWidth,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 12,
            ),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildPdfHeader(
                  green: green,
                  greenDark: greenDark,
                  greenLight: greenLight,
                ),
                pw.SizedBox(height: 8),
                _buildPdfStoreInfo(grey700: grey700, grey500: grey500),
                pw.SizedBox(height: 10),
                _buildPdfDashedLine(grey400),
                pw.SizedBox(height: 8),
                _buildPdfTransactionInfo(grey500: grey500),
                pw.SizedBox(height: 8),
                _buildPdfDashedLine(grey400),
                pw.SizedBox(height: 8),
                _buildPdfItemsHeader(grey500: grey500),
                pw.SizedBox(height: 4),
                ...order.items.map(_buildPdfItemRow),
                pw.SizedBox(height: 8),
                _buildPdfDashedLine(grey400),
                pw.SizedBox(height: 8),
                _buildPdfAmountRow(
                  'Subtotal',
                  order.subtotal,
                  fontSize: _smallFontSize,
                ),
                _buildPdfAmountRow(
                  'Tax (18%)',
                  order.tax,
                  fontSize: _smallFontSize,
                ),
                pw.SizedBox(height: 4),
                _buildPdfDashedLine(grey400),
                pw.SizedBox(height: 6),
                _buildPdfAmountRow(
                  'TOTAL',
                  order.total,
                  fontSize: 13,
                  isBold: true,
                  labelColor: grey700,
                  amountColor: orange,
                ),
                pw.SizedBox(height: 10),
                _buildPdfDashedLine(grey400),
                pw.SizedBox(height: 8),
                _buildPdfPaymentInfo(grey700: grey700, green: green),
                pw.SizedBox(height: 8),
                _buildPdfDashedLine(grey400),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    'Thank you for shopping with us!',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontStyle: pw.FontStyle.italic,
                      color: grey500,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Visit us again',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: orange,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfHeader({
    required PdfColor green,
    required PdfColor greenDark,
    required PdfColor greenLight,
  }) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Container(
            width: 28,
            height: 28,
            decoration: pw.BoxDecoration(
              color: greenLight,
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: green),
            ),
            child: pw.Center(
              child: pw.Text(
                'OK',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: green,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'FOCUS SwiftBill',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: pw.BoxDecoration(
              color: greenLight,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Text(
              'PAID',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: greenDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfStoreInfo({
    required PdfColor grey700,
    required PdfColor grey500,
  }) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
            _storeAddress,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 8, color: grey700),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            _storePhone,
            style: pw.TextStyle(fontSize: 7, color: grey500),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            _storeTaxId,
            style: pw.TextStyle(fontSize: 7, color: grey500),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTransactionInfo({required PdfColor grey500}) {
    return pw.Column(
      children: [
        _buildPdfInfoRow('Order #', order.orderNumber, grey500: grey500),
        pw.SizedBox(height: 2),
        _buildPdfInfoRow(
          'Date & Time',
          _formattedDateTime,
          grey500: grey500,
        ),
        pw.SizedBox(height: 2),
        _buildPdfInfoRow('Cashier', order.userName, grey500: grey500),
      ],
    );
  }

  pw.Widget _buildPdfInfoRow(
    String label,
    String value, {
    required PdfColor grey500,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 50,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 8, color: grey500),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfItemsHeader({required PdfColor grey500}) {
    return pw.Row(
      children: [
        pw.Expanded(
          flex: 4,
          child: pw.Text(
            'Item',
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: grey500,
            ),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.SizedBox(
          width: 32,
          child: pw.Text(
            'Quantity',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: grey500,
            ),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.SizedBox(
          width: 55,
          child: pw.Text(
            'Amt',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: grey500,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfItemRow(CartItem item) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              item.product.name,
              style: const pw.TextStyle(fontSize: 8),
              maxLines: 2,
            ),
          ),
          pw.SizedBox(width: 4),
          pw.SizedBox(
            width: 28,
            child: pw.Text(
              '${item.quantity}',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 4),
          pw.SizedBox(
            width: 55,
            child: pw.Text(
              '$_currencyLabel${item.total.toStringAsFixed(2)}',
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfAmountRow(
    String label,
    double amount, {
    required double fontSize,
    bool isBold = false,
    PdfColor? labelColor,
    PdfColor? amountColor,
  }) {
    final labelStyle = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: labelColor,
    );
    final amountStyle = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: amountColor ?? labelColor,
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: labelStyle),
          pw.Text(
            '$_currencyLabel${amount.toStringAsFixed(2)}',
            style: amountStyle,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfPaymentInfo({
    required PdfColor grey700,
    required PdfColor green,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'PAID',
              style: pw.TextStyle(fontSize: 8, color: grey700),
            ),
            pw.Text(
              '$_currencyLabel${order.total.toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        if (_showChange)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'CHANGE',
                  style: pw.TextStyle(fontSize: 8, color: grey700),
                ),
                pw.Text(
                  '$_currencyLabel${change.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: green,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _buildPdfDashedLine(PdfColor color) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: List.generate(
        24,
        (_) => pw.Container(
          width: 4,
          height: 1,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          _goToDashboard(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2A2A2A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2A2A2A),
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Receipt', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _goToDashboard(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              color: Colors.white,
              onPressed: _printReceipt,
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Container(
              width: _screenReceiptWidth,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 8),
                  const _StoreInfo(),
                  const SizedBox(height: 10),
                  const _Dashed(),
                  const SizedBox(height: 8),
                  _buildTransactionInfo(),
                  const SizedBox(height: 8),
                  const _Dashed(),
                  const SizedBox(height: 8),
                  const _ItemsHeader(),
                  const SizedBox(height: 4),
                  ...order.items.map(_buildItemRow),
                  const SizedBox(height: 8),
                  const _Dashed(),
                  const SizedBox(height: 8),
                  _amountRow(
                    'Subtotal',
                    order.subtotal,
                    fontSize: _smallFontSize,
                  ),
                  _amountRow(
                    'Tax (18%)',
                    order.tax,
                    fontSize: _smallFontSize,
                  ),
                  const SizedBox(height: 4),
                  const _Dashed(),
                  const SizedBox(height: 6),
                  _amountRow(
                    'TOTAL',
                    order.total,
                    isBold: true,
                    isLarge: true,
                    fontSize: 13,
                  ),
                  const SizedBox(height: 10),
                  const _Dashed(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PAID',
                        style: TextStyle(
                          fontSize: _smallFontSize,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '$_currencyLabel${order.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (_showChange)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CHANGE',
                            style: TextStyle(
                              fontSize: _smallFontSize,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            '$_currencyLabel${change.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  const _Dashed(),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Thank you for shopping with us!',
                      style: TextStyle(
                        fontSize: 8,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Visit us again',
                      style: const TextStyle(
                        fontSize: 8,
                        color: AppTheme.primaryOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _Dashed(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _goToDashboard(context),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AppTheme.primaryOrange,
                          ),
                          child: const Text(
                            'Home',
                            style: TextStyle(
                              fontSize: _baseFontSize,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Icon(Icons.check_circle, size: 36, color: Color(0xFF4CAF50)),
        const SizedBox(height: 4),
        const Text(
          'FOCUS SwiftBill',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'PAID',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionInfo() {
    return Column(
      children: [
        _row('Order #', order.orderNumber, labelWidth: 50),
        const SizedBox(height: 2),
        _row('Date & Time', _formattedDateTime, labelWidth: 50),
        const SizedBox(height: 2),
        _row('Cashier', order.userName, labelWidth: 50),
      ],
    );
  }

  Widget _buildItemRow(CartItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              item.product.name,
              style: const TextStyle(fontSize: 8),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 28,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 55,
            child: Text(
              '$_currencyLabel${item.total.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {double labelWidth = 40}) {
    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: const TextStyle(fontSize: 8, color: Colors.grey),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _amountRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isLarge = false,
    required double fontSize,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isLarge ? Colors.grey.shade800 : null,
          ),
        ),
        Text(
          '$_currencyLabel${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isLarge ? AppTheme.primaryOrange : null,
          ),
        ),
      ],
    );
  }
}

class _StoreInfo extends StatelessWidget {
  const _StoreInfo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            ReceiptScreen._storeAddress,
            style: TextStyle(fontSize: 8, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            ReceiptScreen._storePhone,
            style: TextStyle(fontSize: 7, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            ReceiptScreen._storeTaxId,
            style: TextStyle(fontSize: 7, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _ItemsHeader extends StatelessWidget {
  const _ItemsHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            'Item',
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        SizedBox(width: 4),
        SizedBox(
          width: 32,
          child: Text(
            'Qty',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        SizedBox(width: 4),
        SizedBox(
          width: 55,
          child: Text(
            'Amt',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

class _Dashed extends StatelessWidget {
  const _Dashed();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 4.0;
        const dashSpace = 3.0;
        final dashCount =
            (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dashCount,
            (_) => SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.shade400,
                      Colors.grey.shade300,
                      Colors.grey.shade400,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
