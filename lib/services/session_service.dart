import 'dart:async';
import 'package:flutter/material.dart';

class SessionService {
  static const _timeoutDuration = Duration(minutes: 15);
  Timer? _timer;
  VoidCallback? _onTimeout;

  SessionService({VoidCallback? onTimeout}) : _onTimeout = onTimeout;

  void start() {
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(_timeoutDuration, () {
      if (_onTimeout != null) {
        _onTimeout!();
      }
    });
  }

  void resetTimer() {
    _resetTimer();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _timer?.cancel();
  }
}
