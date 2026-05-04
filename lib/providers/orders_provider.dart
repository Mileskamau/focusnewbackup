import 'package:flutter/material.dart';

class OrdersProvider extends ChangeNotifier {
  int _refreshCounter = 0;
  int get refreshCounter => _refreshCounter;

  void refreshOrders() {
    _refreshCounter++;
    notifyListeners();
  }
}