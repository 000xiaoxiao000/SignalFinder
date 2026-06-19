import 'package:flutter/foundation.dart';

enum AppLogLevel { info, warning, error }

class AppLogEntry {
  final DateTime time;
  final AppLogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const AppLogEntry({
    required this.time,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });
}

class AppLogService extends ChangeNotifier {
  AppLogService._();

  static final AppLogService instance = AppLogService._();

  final List<AppLogEntry> _entries = [];

  List<AppLogEntry> get entries => List.unmodifiable(_entries);

  void info(String message) => _add(AppLogLevel.info, message);

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _add(AppLogLevel.warning, message, error, stackTrace);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _add(AppLogLevel.error, message, error, stackTrace);
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  void _add(
    AppLogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _entries.insert(
      0,
      AppLogEntry(
        time: DateTime.now(),
        level: level,
        message: message,
        error: error,
        stackTrace: stackTrace,
      ),
    );
    if (_entries.length > 300) {
      _entries.removeRange(300, _entries.length);
    }
    notifyListeners();
  }
}
