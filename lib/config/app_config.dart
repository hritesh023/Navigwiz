import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // API Configuration - only via environment, no hardcoded keys
  static const String _workerUrl = String.fromEnvironment(
    'WORKER_URL',
    defaultValue: '',
  );

  // App Configuration
  static const String appName = 'Navigwiz';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // API Endpoints - only Worker proxy (backend) or public DuckDuckGo
  static String get workerUrl => _workerUrl;
  static bool get hasWorker => _workerUrl.isNotEmpty;

  // Fetching
  static const int maxConcurrentRequests = 4;
  static const Duration searchTimeout = Duration(seconds: 10);
  static const Duration aiResponseTimeout = Duration(seconds: 30);

  // UI Settings
  static const bool enableAnimations = true;
  static const bool enableDarkModeByDefault = false;
  static const double defaultFontSize = 14.0;

  // Feature Flags
  static const bool enableAnalytics = false;
  static const bool enableAutoUpdate = false;

  // Logging
  static const bool enableVerboseLogging = false;

  // Environment Detection
  static bool get isWeb => kIsWeb;

  // Application Tags
  static const String applicationTagKey = 'awsApplication';
  static const String applicationTagValue = 'arn:aws:resource-groups:eu-north-1:365528424228:group/Navigwiz/0dt1ixunjvtfz4wt3f1boy399o';
}
