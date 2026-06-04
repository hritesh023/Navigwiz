import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import '../config/app_config.dart';
import 'logging_service.dart';
import 'analytics_service.dart';

enum UpdateStatus {
  upToDate,
  updateAvailable,
  updateRequired,
  error,
  checking;

  String get displayName {
    switch (this) {
      case UpdateStatus.upToDate:
        return 'Up to date';
      case UpdateStatus.updateAvailable:
        return 'Update available';
      case UpdateStatus.updateRequired:
        return 'Update required';
      case UpdateStatus.error:
        return 'Error checking for updates';
      case UpdateStatus.checking:
        return 'Checking for updates...';
    }
  }
}

class UpdateInfo {
  final String version;
  final String buildNumber;
  final String releaseNotes;
  final DateTime releaseDate;
  final bool isRequired;
  final String downloadUrl;
  final int sizeBytes;
  final Map<String, String> platformUrls;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseNotes,
    required this.releaseDate,
    required this.isRequired,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.platformUrls,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String,
      buildNumber: json['build_number'] as String,
      releaseNotes: json['release_notes'] as String,
      releaseDate: DateTime.parse(json['release_date'] as String),
      isRequired: json['is_required'] as bool,
      downloadUrl: json['download_url'] as String,
      sizeBytes: json['size_bytes'] as int,
      platformUrls: Map<String, String>.from(json['platform_urls'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'build_number': buildNumber,
      'release_notes': releaseNotes,
      'release_date': releaseDate.toIso8601String(),
      'is_required': isRequired,
      'download_url': downloadUrl,
      'size_bytes': sizeBytes,
      'platform_urls': platformUrls,
    };
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final LoggingService _logger = LoggingService();
  final AnalyticsService _analytics = AnalyticsService();

  UpdateStatus _status = UpdateStatus.upToDate;
  UpdateInfo? _availableUpdate;
  Timer? _checkTimer;
  bool _isInitialized = false;
  PackageInfo? _packageInfo;

  UpdateStatus get status => _status;
  UpdateInfo? get availableUpdate => _availableUpdate;

  Future<void> initialize() async {
    if (!AppConfig.enableAutoUpdate || _isInitialized) return;

    try {
      _packageInfo = await PackageInfo.fromPlatform();
      _startPeriodicChecks();
      _isInitialized = true;

      await _logger.info('Update service initialized');
      await _analytics.trackEvent('update_service_initialized');

      // Check for updates on startup
      await checkForUpdates();
    } catch (e, stackTrace) {
      await _logger.error('Failed to initialize update service', e, stackTrace);
      _status = UpdateStatus.error;
    }
  }

  Future<void> checkForUpdates() async {
    if (!_isInitialized || _packageInfo == null) return;

    _status = UpdateStatus.checking;
    await _notifyStatusChanged();

    try {
      await _analytics.trackEvent('update_check_started');

      final response = await http.get(
        Uri.parse(
            'https://api.navigwiz.app/v1/updates?current_version=${_packageInfo!.version}&platform=${_platformName()}'),
        headers: {
          'User-Agent': 'Navigwiz/${AppConfig.appVersion}',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        await _processUpdateResponse(data);
      } else if (response.statusCode == 304) {
        _status = UpdateStatus.upToDate;
        await _analytics.trackEvent('update_check_not_modified');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      await _logger.error('Failed to check for updates', e, stackTrace);
      _status = UpdateStatus.error;
      await _analytics.trackError('Update check failed: $e');
    }

    await _notifyStatusChanged();
  }

  Future<void> _processUpdateResponse(Map<String, dynamic> data) async {
    if (data['update_available'] == true) {
      _availableUpdate =
          UpdateInfo.fromJson(data['update_info'] as Map<String, dynamic>);

      if (_isNewerVersion(_availableUpdate!.version)) {
        _status = _availableUpdate!.isRequired
            ? UpdateStatus.updateRequired
            : UpdateStatus.updateAvailable;

        await _analytics.trackEvent('update_available', {
          'new_version': _availableUpdate!.version,
          'is_required': _availableUpdate!.isRequired,
          'size_mb':
              (_availableUpdate!.sizeBytes / (1024 * 1024)).toStringAsFixed(1),
        });
      } else {
        _status = UpdateStatus.upToDate;
      }
    } else {
      _status = UpdateStatus.upToDate;
      await _analytics.trackEvent('update_up_to_date');
    }
  }

  bool _isNewerVersion(String newVersion) {
    if (_packageInfo == null) return false;

    final currentVersion = _packageInfo!.version;
    final currentParts = currentVersion.split('.').map(int.parse).toList();
    final newParts = newVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < currentParts.length && i < newParts.length; i++) {
      if (newParts[i] > currentParts[i]) return true;
      if (newParts[i] < currentParts[i]) return false;
    }

    return newParts.length > currentParts.length;
  }

  Future<void> downloadUpdate() async {
    if (_availableUpdate == null) {
      throw Exception('No update available');
    }

    try {
      await _analytics.trackEvent('update_download_started', {
        'version': _availableUpdate!.version,
        'size_bytes': _availableUpdate!.sizeBytes,
      });

      final platform = _platformName();
      String downloadUrl;

      switch (platform) {
        case 'android':
          downloadUrl = _availableUpdate!.platformUrls['android'] ??
              _availableUpdate!.downloadUrl;
          break;
        case 'windows':
          downloadUrl = _availableUpdate!.platformUrls['windows'] ??
              _availableUpdate!.downloadUrl;
          break;
        case 'macos':
          downloadUrl = _availableUpdate!.platformUrls['macos'] ??
              _availableUpdate!.downloadUrl;
          break;
        case 'linux':
          downloadUrl = _availableUpdate!.platformUrls['linux'] ??
              _availableUpdate!.downloadUrl;
          break;
        default:
          downloadUrl = _availableUpdate!.downloadUrl;
      }

      await _launchDownload(downloadUrl);

      await _analytics.trackEvent('update_download_completed');
    } catch (e, stackTrace) {
      await _logger.error('Failed to download update', e, stackTrace);
      await _analytics.trackError('Update download failed: $e');
      rethrow;
    }
  }

  Future<void> _launchDownload(String url) async {
    if (kIsWeb) {
      // For web, open the download URL in a new tab
      // In a real implementation, you would use url_launcher
      await _logger.info('Web update download: $url');
    } else {
      // For desktop/mobile, you might want to show a download progress dialog
      // and handle the download process more gracefully
      await _logger.info('Desktop/mobile update download: $url');
    }
  }

  String _platformName() => kIsWeb ? 'web' : defaultTargetPlatform.name;

  void _startPeriodicChecks() {
    _checkTimer = Timer.periodic(const Duration(hours: 24), (_) {
      checkForUpdates();
    });
  }

  Future<void> _notifyStatusChanged() async {
    // In a real implementation, this would notify UI listeners
    await _logger.debug('Update status changed', {
      'status': _status.displayName,
      'has_update': _availableUpdate != null,
    });
  }

  Future<void> skipUpdate() async {
    if (_availableUpdate == null) return;

    await _analytics.trackEvent('update_skipped', {
      'version': _availableUpdate!.version,
      'is_required': _availableUpdate!.isRequired,
    });

    _availableUpdate = null;
    _status = UpdateStatus.upToDate;
    await _notifyStatusChanged();
  }

  Future<void> remindLater() async {
    if (_availableUpdate == null) return;

    await _analytics.trackEvent('update_remind_later', {
      'version': _availableUpdate!.version,
    });

    // Schedule a reminder for later
    Timer(const Duration(hours: 4), () {
      checkForUpdates();
    });
  }

  Future<void> installUpdate() async {
    if (_availableUpdate == null) return;

    await _analytics.trackEvent('update_install_started', {
      'version': _availableUpdate!.version,
    });

    try {
      await downloadUpdate();

      // In a real implementation, you would handle the installation process
      // This might involve closing the app and running the installer
      if (!kIsWeb) {
        await _logger.info('Update installation initiated');
        // exit(0); // Uncomment in production to close app for update
      }
    } catch (e, stackTrace) {
      await _logger.error('Failed to install update', e, stackTrace);
      await _analytics.trackError('Update install failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUpdateStatus() async {
    return {
      'status': _status.name,
      'status_display': _status.displayName,
      'has_update': _availableUpdate != null,
      'update_info': _availableUpdate?.toJson(),
      'current_version': _packageInfo?.version,
      'auto_update_enabled': AppConfig.enableAutoUpdate,
      'last_check': DateTime.now().toIso8601String(),
    };
  }

  Future<void> dispose() async {
    _checkTimer?.cancel();
    _isInitialized = false;
  }
}

// Global update service instance for easy access
final updateService = UpdateService();
