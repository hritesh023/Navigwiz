import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, defaultTargetPlatform, kDebugMode;
import 'package:intl/intl.dart';
import '../config/app_config.dart';

enum LogLevel {
  debug(0),
  info(1),
  warning(2),
  error(3),
  critical(4);

  const LogLevel(this.value);
  final int value;
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'error': error,
      'stackTrace': stackTrace?.toString(),
    };
  }

  @override
  String toString() {
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(timestamp);
    final levelStr = level.name.toUpperCase().padRight(8);
    return '[$timeStr] $levelStr $message${error != null ? ' - Error: $error' : ''}';
  }
}

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  final List<LogEntry> _memoryBuffer = [];
  final List<LogEntry> _criticalErrors = [];
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await info('Logging service initialized', {
      'app_version': AppConfig.appVersion,
      'is_production': !kDebugMode,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    });
  }

  Future<void> debug(String message, [Map<String, dynamic>? context]) async {
    if (AppConfig.enableVerboseLogging) {
      await _log(LogLevel.debug, message, context: context);
    }
  }

  Future<void> info(String message, [Map<String, dynamic>? context]) async {
    await _log(LogLevel.info, message, context: context);
  }

  Future<void> warning(String message, [Map<String, dynamic>? context]) async {
    await _log(LogLevel.warning, message, context: context);
  }

  Future<void> error(String message,
      [Object? error,
      StackTrace? stackTrace,
      Map<String, dynamic>? context]) async {
    await _log(LogLevel.error, message,
        error: error, stackTrace: stackTrace, context: context);
  }

  Future<void> critical(String message,
      [Object? error,
      StackTrace? stackTrace,
      Map<String, dynamic>? context]) async {
    await _log(LogLevel.critical, message,
        error: error, stackTrace: stackTrace, context: context);
  }

  Future<void> _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace,
    );

    _memoryBuffer.add(entry);
    if (_memoryBuffer.length > 1000) {
      _memoryBuffer.removeAt(0);
    }
    if (level == LogLevel.critical) {
      _criticalErrors.add(entry);
    }

    if (kDebugMode) {
      debugPrint(entry.toString());
      if (context != null) {
        debugPrint('Context: $context');
      }
    }
  }

  Future<List<LogEntry>> getRecentLogs({int count = 100}) async {
    return List.from(_memoryBuffer.reversed.take(count));
  }

  Future<List<LogEntry>> getCriticalErrors() async {
    return List.from(_criticalErrors.reversed);
  }

  Future<void> clearLogs() async {
    _memoryBuffer.clear();
    _criticalErrors.clear();
    await info('Logs cleared');
  }

  Future<Map<String, dynamic>> getLogStatistics() async {
    return {
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'memory_buffer_size': _memoryBuffer.length,
      'critical_errors_count': _criticalErrors.length,
    };
  }

  Future<void> exportLogs(String filePath) async {
    await warning('File export is unavailable in this build', {
      'requested_path': filePath,
    });
  }
}

final logger = LoggingService();
