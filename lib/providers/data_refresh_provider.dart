import 'package:flutter/material.dart';

class DataRefreshProvider extends ChangeNotifier {
  int _refreshTrigger = 0;

  int get refreshTrigger => _refreshTrigger;

  void refresh() {
    _refreshTrigger++;
    notifyListeners();
  }
}