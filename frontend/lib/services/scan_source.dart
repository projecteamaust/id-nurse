import 'dart:async';

import 'package:flutter/services.dart';

/// Something that reads a nurse card / QR code and gives back the employee ID.
///
/// The login screen only listens to [scans], so the way of scanning can change
/// without touching the screen:
/// - [KeyboardScanSource] (now): a USB card or QR reader that "types" the digits.
/// - CameraScanSource (later, tablet): reads a barcode/QR with the camera.
abstract class ScanSource {
  /// Emits one employee ID (digits only) for every successful scan.
  Stream<String> get scans;

  /// Start listening (called when the Scan tab is shown).
  void start();

  /// Stop listening (called when the Scan tab is hidden).
  void stop();

  void dispose();
}

/// A keyboard-style card reader: it sends the digits on the card followed by Enter.
/// We collect digit key presses and emit them when Enter arrives.
/// Any other key resets the buffer, so random typing doesn't turn into a scan.
class KeyboardScanSource implements ScanSource {
  final _controller = StreamController<String>.broadcast();
  final _buffer = StringBuffer();
  bool _listening = false;

  @override
  Stream<String> get scans => _controller.stream;

  @override
  void start() {
    if (_listening) return;
    _listening = true;
    _buffer.clear();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void stop() {
    if (!_listening) return;
    _listening = false;
    HardwareKeyboard.instance.removeHandler(_onKey);
  }

  @override
  void dispose() {
    stop();
    _controller.close();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_buffer.isNotEmpty) _controller.add(_buffer.toString());
      _buffer.clear();
      return true;
    }
    final char = event.character;
    if (char != null && char.length == 1 && RegExp(r'[0-9]').hasMatch(char)) {
      _buffer.write(char);
      return true;
    }
    _buffer.clear();
    return false;
  }
}
