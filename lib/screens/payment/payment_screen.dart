import 'dart:async';
import 'package:flutter/material.dart';
import 'package:focus_swiftbill/services/database_service.dart';
import 'package:focus_swiftbill/services/auth_service.dart';
import 'package:focus_swiftbill/models/cart_item.dart';
import 'package:focus_swiftbill/utils/constants.dart';
import 'package:focus_swiftbill/models/order.dart';
import 'package:focus_swiftbill/theme/app_theme.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final AuthService _auth = AuthService();
  final Uuid _uuid = const Uuid();

  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _chequeNumberController = TextEditingController();
  final TextEditingController _chequeDateController = TextEditingController();
  final TextEditingController _chequeAmountController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardExpiryController = TextEditingController();
  final TextEditingController _cardCvvController = TextEditingController();
  final TextEditingController _cardAmountController = TextEditingController();

  static const String paymentCheque = 'cheque';
  String _selectedPayment = AppConstants.paymentCard;
  bool _isProcessing = false;
  double _subtotal = 0;
  double _tax = 0;
  double _total = 0;
  double _change = 0;
  List<CartItem> _cart = [];

  @override
  void initState() {
    super.initState();
    _loadCart();
    _cashController.addListener(_calculateChange);
  }

  Future<void> _loadCart() async {
    final cartBox = DatabaseService.getCart();
    setState(() {
      _cart = cartBox.values.toList();
      _subtotal = _cart.fold(0, (sum, item) => sum + item.total);
      _tax = _subtotal * AppConstants.taxRate;
      _total = _subtotal + _tax;

      // Update all controllers inside setState
      _chequeAmountController.text = _total.toStringAsFixed(2);
      _cashController.text = _total.toStringAsFixed(2);
      _cardAmountController.text = _total.toStringAsFixed(2);
    });
  }

  void _calculateChange() {
    final tendered = double.tryParse(_cashController.text) ?? 0;
    setState(() {
      _change = tendered - _total;
    });
  }

  // ======================== SINGLE PAYMENT (unchanged) ========================
  Future<void> _processPayment() async {
    const epsilon = 0.01;

    // ---------- Card validation block removed ----------

    if (_selectedPayment == paymentCheque) {
      final chequeNumber = _chequeNumberController.text.trim();
      final chequeDate = _chequeDateController.text.trim();
      final chequeAmount = double.tryParse(_chequeAmountController.text) ?? 0;

      if (chequeNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cheque number is required'), behavior: SnackBarBehavior.floating),
        );
        return;
      }

      if (chequeDate.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cheque date is required'), behavior: SnackBarBehavior.floating),
        );
        return;
      }

      final selectedDate = DateTime.tryParse(chequeDate);
      if (selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid cheque date'), behavior: SnackBarBehavior.floating),
        );
        return;
      }

      if ((chequeAmount - _total).abs() > epsilon) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cheque amount must equal total (${AppConstants.currencySymbol}${_total.toStringAsFixed(2)})'), behavior: SnackBarBehavior.floating),
        );
        return;
      }
    }

    // Cash is pre‑filled and read‑only, so no further check needed
    if (_selectedPayment == AppConstants.paymentCash) {
      // optional: you could still verify tendered >= total, but it's already total
    }

    if (mounted) {
      setState(() => _isProcessing = true);
    }

    try {
      String orderNumber;
      try {
        orderNumber = await Order.generateOrderNumber().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Order number generation timed out');
          },
        );
      } on TimeoutException {
        final now = DateTime.now();
        final dateKey = DateFormat('yyyyMMdd').format(now);
        final timestamp = now.millisecondsSinceEpoch % 100000;
        orderNumber = 'ORD-$dateKey-TIMEOUT-${timestamp.toString().padLeft(5, '0')}';
      }

      final userId = _auth.getUserId();
      final userName = _auth.getUserName();
      final userRole = _auth.getUserRole();

      final order = Order(
        id: _uuid.v4(),
        orderNumber: orderNumber,
        userId: userId ?? 'unknown',
        userName: userName ?? 'Unknown',
        userRole: userRole ?? AppConstants.roleCashier,
        items: List.from(_cart),
        subtotal: _subtotal,
        tax: _tax,
        total: _total,
        paymentMethod: _selectedPayment,
        status: AppConstants.statusCompleted,
        createdAt: DateTime.now(),
        synced: false,
        // Single payment → no payments list
      );

      final pendingBillsBox = DatabaseService.getPendingBills();
      try {
        await pendingBillsBox.put(order.id, order).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Order save timed out');
          },
        );
      } on TimeoutException {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order save timeout'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 4)),
          );
        }
        return;
      }

      // Decrement inventory stock for each item in the order
      final productsBox = DatabaseService.getProducts();
      try {
        for (var item in _cart) {
          final product = productsBox.get(item.product.id);
          if (product != null) {
            product.stockQty -= item.quantity;
            if (product.stockQty < 0) product.stockQty = 0;
            await productsBox.put(product.id, product);
          }
        }
      } catch (e) {
        // Log but don't fail payment if stock update fails
        debugPrint('Error updating stock: $e');
      }

      final cartBox = DatabaseService.getCart();
      try {
        await cartBox.clear().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('Cart clear timed out');
          },
        );
      } on TimeoutException {}

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pushNamed(
          context,
          '/receipt',
          arguments: {'order': order, 'change': _change},
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        String errorMessage = 'Payment processing error';
        if (e is TimeoutException) {
          errorMessage = 'Operation timed out. Please try again.';
        } else {
          errorMessage = e.toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4)),
        );
      }
    }
  }

  // ======================== SPLIT PAYMENT (NEW) ========================
  Future<void> _showSplitPaymentAndProcess() async {
    final splits = await _showSplitPaymentDialog();
    if (splits != null && splits.isNotEmpty && mounted) {
      _processSplitPayment(splits);
    }
  }

  Future<List<Map<String, dynamic>>?> _showSplitPaymentDialog() async {
    final cashCtrl = TextEditingController();
    final cardCtrl = TextEditingController();
    final chequeCtrl = TextEditingController();

    final cardHolderCtrl = TextEditingController();
    final cardNumberCtrl = TextEditingController();

    final chequeNumberCtrl = TextEditingController();
    final chequeDateCtrl = TextEditingController();

    bool validate({bool showErrors = false}) {
      final cash = double.tryParse(cashCtrl.text) ?? 0;
      final card = double.tryParse(cardCtrl.text) ?? 0;
      final cheque = double.tryParse(chequeCtrl.text) ?? 0;
      final totalEntered = cash + card + cheque;
      return (totalEntered - _total).abs() < 0.01;
    }

    return showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final allValid = validate();
            final cardAmt = double.tryParse(cardCtrl.text) ?? 0;
            final chequeAmt = double.tryParse(chequeCtrl.text) ?? 0;
            final totalEntered = (double.tryParse(cashCtrl.text) ?? 0) +
                (double.tryParse(cardCtrl.text) ?? 0) +
                (double.tryParse(chequeCtrl.text) ?? 0);

            return AlertDialog(
              title: const Text('Split Payment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cash
                    TextField(
                      controller: cashCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Cash Amount',
                        prefixIcon: const Icon(Icons.money),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => setLocalState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Card
                    TextField(
                      controller: cardCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Card Amount',
                        prefixIcon: const Icon(Icons.credit_card),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => setLocalState(() {}),
                    ),
                    if (cardAmt > 0) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: cardHolderCtrl,
                        decoration: InputDecoration(
                          labelText: 'Cardholder Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (_) => setLocalState(() {}),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: cardNumberCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Approval Number',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (_) => setLocalState(() {}),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Cheque
                    TextField(
                      controller: chequeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Cheque Amount',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => setLocalState(() {}),
                    ),
                    if (chequeAmt > 0) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: chequeNumberCtrl,
                        decoration: InputDecoration(
                          labelText: 'Cheque Number',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (_) => setLocalState(() {}),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: chequeDateCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Cheque Date',
                          suffixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            chequeDateCtrl.text =
                                DateFormat('yyyy-MM-dd').format(picked);
                            setLocalState(() {});
                          }
                        },
                      ),
                    ],

                    const SizedBox(height: 12),
                    Text(
                      'Total required: ${AppConstants.currencySymbol}${_total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Entered: ${AppConstants.currencySymbol}${totalEntered.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: allValid ? Colors.green : Colors.red,
                      ),
                    ),
                    if (!allValid)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'The split must exactly match the total bill.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: allValid &&
                              (cardAmt <= 0 ||
                                  (cardHolderCtrl.text.isNotEmpty &&
                                      cardNumberCtrl.text.isNotEmpty)) &&
                              (chequeAmt <= 0 ||
                                  (chequeNumberCtrl.text.isNotEmpty &&
                                      chequeDateCtrl.text.isNotEmpty))
                          ? () {
                              final payments = <Map<String, dynamic>>[];
                              final cash = double.tryParse(cashCtrl.text) ?? 0;
                              final card = double.tryParse(cardCtrl.text) ?? 0;
                              final cheque =
                                  double.tryParse(chequeCtrl.text) ?? 0;
                              if (cash > 0) {
                                payments.add({'method': 'cash', 'amount': cash});
                              }
                              if (card > 0) {
                                payments.add({
                                  'method': 'card',
                                  'amount': card,
                                  'cardHolder': cardHolderCtrl.text.trim(),
                                  'approvalNumber': cardNumberCtrl.text.trim(),
                                });
                              }
                              if (cheque > 0) {
                                payments.add({
                                  'method': 'cheque',
                                  'amount': cheque,
                                  'chequeNumber': chequeNumberCtrl.text.trim(),
                                  'chequeDate': chequeDateCtrl.text.trim(),
                                });
                              }
                              Navigator.pop(ctx, payments);
                            }
                          : null,
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _processSplitPayment(List<Map<String, dynamic>> splits) async {
    if (mounted) setState(() => _isProcessing = true);

    try {
      String orderNumber;
      try {
        orderNumber = await Order.generateOrderNumber().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Order number generation timed out');
          },
        );
      } on TimeoutException {
        final now = DateTime.now();
        final dateKey = DateFormat('yyyyMMdd').format(now);
        final timestamp = now.millisecondsSinceEpoch % 100000;
        orderNumber =
            'ORD-$dateKey-TIMEOUT-${timestamp.toString().padLeft(5, '0')}';
      }

      final userId = _auth.getUserId();
      final userName = _auth.getUserName();
      final userRole = _auth.getUserRole();

      final order = Order(
        id: _uuid.v4(),
        orderNumber: orderNumber,
        userId: userId ?? 'unknown',
        userName: userName ?? 'Unknown',
        userRole: userRole ?? AppConstants.roleCashier,
        items: List.from(_cart),
        subtotal: _subtotal,
        tax: _tax,
        total: _total,
        paymentMethod: 'split',            // keep as 'split' or 'multiple'
        status: AppConstants.statusCompleted,
        createdAt: DateTime.now(),
        synced: false,
                        // the new field
      );

      final pendingBillsBox = DatabaseService.getPendingBills();
      await pendingBillsBox.put(order.id, order).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Order save timed out'),
      );

      // Decrement stock
      final productsBox = DatabaseService.getProducts();
      for (var item in _cart) {
        final product = productsBox.get(item.product.id);
        if (product != null) {
          product.stockQty -= item.quantity;
          if (product.stockQty < 0) product.stockQty = 0;
          await productsBox.put(product.id, product);
        }
      }

      // Clear cart
      final cartBox = DatabaseService.getCart();
      await cartBox.clear().timeout(const Duration(seconds: 5));

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pushNamed(
          context,
          '/receipt',
          arguments: {'order': order, 'change': 0.0},
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Split payment error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ======================== UI BUILDERS (unchanged) ========================
  Widget _buildPaymentChip({required IconData icon, required String label, required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPayment = label.toLowerCase()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryOrange : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? Colors.white : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cash Tendered'),
        const SizedBox(height: 8),
        TextField(
          controller: _cashController,
          readOnly: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Amount from cart',
            prefixIcon: const Icon(Icons.money),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_change > 0) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Change Due', style: TextStyle(color: Colors.grey)),
                Text(
                  '${AppConstants.currencySymbol}${_change.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Amount'),
        const SizedBox(height: 8),
        TextField(
          controller: _cardAmountController,
          readOnly: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Amount from cart',
            prefixIcon: const Icon(Icons.money),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Cardholder Name'),
        const SizedBox(height: 8),
        TextField(
          controller: _cardHolderController,
          decoration: InputDecoration(
            hintText: 'Enter cardholder name',
            prefixIcon: const Icon(Icons.person),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Approval Number'),
        const SizedBox(height: 8),
        TextField(
          controller: _cardNumberController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter card number',
            prefixIcon: const Icon(Icons.credit_card),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChequeForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cheque Number'),
        const SizedBox(height: 8),
        TextField(
          controller: _chequeNumberController,
          decoration: InputDecoration(
            hintText: 'Enter cheque number',
            prefixIcon: const Icon(Icons.description),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Cheque Date'),
        const SizedBox(height: 8),
        TextField(
          controller: _chequeDateController,
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'Select date',
            prefixIcon: const Icon(Icons.calendar_today),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() {
                _chequeDateController.text = DateFormat('yyyy-MM-dd').format(picked);
              });
            }
          },
        ),
        const SizedBox(height: 16),
        const Text('Amount'),
        const SizedBox(height: 8),
        TextField(
          controller: _chequeAmountController,
          readOnly: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Amount from cart',
            prefixIcon: const Icon(Icons.money),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _onWillPop() async {
    Navigator.pop(context);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) {
          _onWillPop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Payment')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ExpansionTile(
                  title: const Text('Order Summary'),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    ..._cart.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${item.product.name} x${item.quantity}'),
                              Text('${AppConstants.currencySymbol}${item.total.toStringAsFixed(2)}'),
                            ],
                          ),
                        )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text('${AppConstants.currencySymbol}${_subtotal.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tax (18%)'),
                        Text('${AppConstants.currencySymbol}${_tax.toStringAsFixed(2)}'),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${AppConstants.currencySymbol}${_total.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryOrange),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildPaymentChip(icon: Icons.credit_card, label: 'Card', selected: _selectedPayment == AppConstants.paymentCard),
                  const SizedBox(width: 12),
                  _buildPaymentChip(icon: Icons.money, label: 'Cash', selected: _selectedPayment == AppConstants.paymentCash),
                  const SizedBox(width: 12),
                  _buildPaymentChip(icon: Icons.description, label: 'Cheque', selected: _selectedPayment == paymentCheque),
                ],
              ),
              const SizedBox(height: 24),
              if (_selectedPayment == AppConstants.paymentCash) _buildCashForm(),
              if (_selectedPayment == AppConstants.paymentCard) _buildCardForm(),
              if (_selectedPayment == paymentCheque) _buildChequeForm(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text('PAY NOW', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              // ------------------ NEW SPLIT PAYMENT BUTTON ------------------
             
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cashController.dispose();
    _chequeNumberController.dispose();
    _chequeDateController.dispose();
    _chequeAmountController.dispose();
    _cardHolderController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardAmountController.dispose();
    super.dispose();
  }
}