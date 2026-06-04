import 'dart:async';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, kDebugMode;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';
import 'logging_service.dart';

enum AnalyticsEventType {
  appStart('app_start'),
  appBackground('app_background'),
  appForeground('app_foreground'),
  browserTabCreated('browser_tab_created'),
  browserTabClosed('browser_tab_closed'),
  navigation('navigation'),
  search('search'),
  aiInteraction('ai_interaction'),
  bookmarkAdded('bookmark_added'),
  bookmarkRemoved('bookmark_removed'),
  themeChanged('theme_changed'),
  error('error'),
  performance('performance');

  const AnalyticsEventType(this.value);
  final String value;
}

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> parameters;
  final DateTime timestamp;

  AnalyticsEvent({
    required this.name,
    required this.parameters,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'parameters': parameters,
      'timestamp': timestamp.toIso8601String(),
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'app_version': AppConfig.appVersion,
    };
  }
}

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final LoggingService _logger = LoggingService();
  final List<AnalyticsEvent> _eventQueue = [];
  Timer? _flushTimer;
  bool _isInitialized = false;
  String? _userId;
  String? _sessionId;

  Future<void> initialize() async {
    if (!AppConfig.enableAnalytics || _isInitialized) return;

    try {
      await _generateSessionId();
      await _loadUserId();
      _startFlushTimer();
      _isInitialized = true;

      await _logger.info('Analytics service initialized');
      await trackEvent(AnalyticsEventType.appStart.value, {
        'session_id': _sessionId,
        'user_id': _userId,
      });
    } catch (e, stackTrace) {
      await _logger.error('Failed to initialize analytics', e, stackTrace);
    }
  }

  Future<void> trackEvent(String eventName,
      [Map<String, dynamic>? parameters]) async {
    if (!_isInitialized || !AppConfig.enableAnalytics) return;

    try {
      final event = AnalyticsEvent(
        name: eventName,
        parameters: {
          ...?parameters,
          'session_id': _sessionId,
          'user_id': _userId,
        },
      );

      _eventQueue.add(event);

      // Flush immediately for critical events
      if (_isCriticalEvent(eventName)) {
        await _flushEvents();
      }
    } catch (e, stackTrace) {
      await _logger.error('Failed to track event', e, stackTrace);
    }
  }

  Future<void> trackScreenView(String screenName,
      [Map<String, dynamic>? parameters]) async {
    await trackEvent('screen_view', {
      'screen_name': screenName,
      ...?parameters,
    });
  }

  Future<void> trackUserAction(String action,
      [Map<String, dynamic>? parameters]) async {
    await trackEvent('user_action', {
      'action': action,
      ...?parameters,
    });
  }

  Future<void> trackPerformance(String operation, Duration duration,
      [Map<String, dynamic>? parameters]) async {
    await trackEvent('performance', {
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      ...?parameters,
    });
  }

  Future<void> trackError(String error, [String? stackTrace]) async {
    await trackEvent('error', {
      'error_message': error,
      'stack_trace': stackTrace,
      'is_fatal': false,
    });
  }

  Future<void> trackFatalError(String error, [String? stackTrace]) async {
    await trackEvent('error', {
      'error_message': error,
      'stack_trace': stackTrace,
      'is_fatal': true,
    });
  }

  Future<void> setUserId(String userId) async {
    _userId = userId;
    await _saveUserId();
  }

  Future<void> setUserProperty(String name, String value) async {
    await trackEvent('user_property_set', {
      'property_name': name,
      'property_value': value,
    });
  }

  Future<void> _generateSessionId() async {
    _sessionId =
        '${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    return String.fromCharCodes(Iterable.generate(
      length,
      (_) => chars.codeUnitAt((random + _) % chars.length),
    ));
  }

  Future<void> _loadUserId() async {
    // In a real implementation, this would load from secure storage
    // For now, generate a unique ID
    _userId = 'user_${_generateRandomString(16)}';
  }

  Future<void> _saveUserId() async {
    // In a real implementation, this would save to secure storage
  }

  void _startFlushTimer() {
    _flushTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _flushEvents();
    });
  }

  bool _isCriticalEvent(String eventName) {
    const criticalEvents = [
      'error',
      'app_start',
      'fatal_error',
    ];
    return criticalEvents.contains(eventName);
  }

  Future<void> _flushEvents() async {
    if (_eventQueue.isEmpty) return;

    final events = List<AnalyticsEvent>.from(_eventQueue);
    _eventQueue.clear();

    try {
      await _sendEvents(events);
    } catch (e, stackTrace) {
      // Re-add events to queue if send failed
      _eventQueue.insertAll(0, events);
      await _logger.error('Failed to send analytics events', e, stackTrace);
    }
  }

  Future<void> _sendEvents(List<AnalyticsEvent> events) async {
    if (kDebugMode) {
      await _logger.debug('Sending analytics events', {
        'event_count': events.length,
        'events': events.map((e) => e.toJson()).toList(),
      });
      return;
    }

    final payload = {
      'events': events.map((e) => e.toJson()).toList(),
      'app_id': 'navigwiz',
      'app_version': AppConfig.appVersion,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final response = await http
        .post(
          Uri.parse('https://api.navigwiz.app/v1/analytics'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Navigwiz/${AppConfig.appVersion}',
          },
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to send events: ${response.statusCode}');
    }

    await _logger.debug('Analytics events sent successfully', {
      'event_count': events.length,
    });
  }

  Future<void> dispose() async {
    _flushTimer?.cancel();
    await _flushEvents();
    _isInitialized = false;
  }

  // Privacy methods
  Future<void> optOut() async {
    await trackEvent('analytics_opt_out');
    await _flushEvents();
    _eventQueue.clear();
    _flushTimer?.cancel();
    _isInitialized = false;
  }

  Future<void> optIn() async {
    await initialize();
    await trackEvent('analytics_opt_in');
  }

  Future<void> deleteUserData() async {
    await trackEvent('user_data_delete_request');
    await _flushEvents();
    _userId = null;
    _sessionId = null;
    _eventQueue.clear();
  }

  // Analytics data retrieval (for admin purposes)
  Future<Map<String, dynamic>> getAnalyticsSummary() async {
    return {
      'is_initialized': _isInitialized,
      'session_id': _sessionId,
      'user_id': _userId,
      'queued_events': _eventQueue.length,
      'analytics_enabled': AppConfig.enableAnalytics,
      'last_flush': _flushTimer?.tick,
    };
  }
}

// Global analytics instance for easy access
final analytics = AnalyticsService();
