#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

/// Production build script for Navigwiz Browser
/// This script automates the production build process for all platforms

class ProductionBuilder {
  static const String appName = 'Navigwiz Browser';
  static const String version = '1.0.0';
  
  final Map<String, String> environment = Platform.environment;
  
  Future<void> buildAll() async {
    print('🚀 Starting production build for $appName v$version');
    
    // Validate environment
    await _validateEnvironment();
    
    // Clean previous builds
    await _cleanBuild();
    
    // Build for each platform
    await _buildAndroid();
    await _buildWindows();
    await _buildWeb();
    
    // Generate build report
    await _generateBuildReport();
    
    print('✅ Production build completed successfully!');
  }
  
  Future<void> _validateEnvironment() async {
    print('🔍 Validating environment...');
    
    // Check required environment variables
    final requiredVars = ['OPENAI_API_KEY'];
    for (final varName in requiredVars) {
      if (environment[varName]?.isEmpty ?? true) {
        throw Exception('Missing required environment variable: $varName');
      }
    }
    
    // Check Flutter installation
    final result = await Process.run('flutter', ['--version']);
    if (result.exitCode != 0) {
      throw Exception('Flutter is not installed or not in PATH');
    }
    
    print('✅ Environment validation passed');
  }
  
  Future<void> _cleanBuild() async {
    print('🧹 Cleaning previous builds...');
    
    await Process.run('flutter', ['clean']);
    await Process.run('flutter', ['pub', 'get']);
    
    print('✅ Build cleaned');
  }
  
  Future<void> _buildAndroid() async {
    print('🤖 Building Android release...');
    
    // Build APK
    final apkResult = await Process.run('flutter', [
      'build', 'apk',
      '--release',
      '--obfuscate',
      '--split-debug-info=build/debug-info/',
      '--tree-shake-icons',
      '--dart-define=OPENAI_API_KEY=${environment['OPENAI_API_KEY']}',
      '--dart-define=WEATHER_API_KEY=${environment['WEATHER_API_KEY'] ?? ''}',
    ]);
    
    if (apkResult.exitCode != 0) {
      throw Exception('Android APK build failed: ${apkResult.stderr}');
    }
    
    // Build App Bundle
    final bundleResult = await Process.run('flutter', [
      'build', 'appbundle',
      '--release',
      '--obfuscate',
      '--split-debug-info=build/debug-info/',
      '--tree-shake-icons',
      '--dart-define=OPENAI_API_KEY=${environment['OPENAI_API_KEY']}',
      '--dart-define=WEATHER_API_KEY=${environment['WEATHER_API_KEY'] ?? ''}',
    ]);
    
    if (bundleResult.exitCode != 0) {
      throw Exception('Android App Bundle build failed: ${bundleResult.stderr}');
    }
    
    print('✅ Android build completed');
  }
  
  Future<void> _buildWindows() async {
    print('🪟 Building Windows release...');
    
    final result = await Process.run('flutter', [
      'build', 'windows',
      '--release',
      '--obfuscate',
      '--split-debug-info=build/debug-info/',
      '--tree-shake-icons',
      '--dart-define=OPENAI_API_KEY=${environment['OPENAI_API_KEY']}',
      '--dart-define=WEATHER_API_KEY=${environment['WEATHER_API_KEY'] ?? ''}',
    ]);
    
    if (result.exitCode != 0) {
      throw Exception('Windows build failed: ${result.stderr}');
    }
    
    print('✅ Windows build completed');
  }
  
  Future<void> _buildWeb() async {
    print('🌐 Building web release...');
    
    final result = await Process.run('flutter', [
      'build', 'web',
      '--release',
      '--web-renderer=html',
      '--dart-define=OPENAI_API_KEY=${environment['OPENAI_API_KEY']}',
      '--dart-define=WEATHER_API_KEY=${environment['WEATHER_API_KEY'] ?? ''}',
    ]);
    
    if (result.exitCode != 0) {
      throw Exception('Web build failed: ${result.stderr}');
    }
    
    print('✅ Web build completed');
  }
  
  Future<void> _generateBuildReport() async {
    print('📊 Generating build report...');
    
    final report = {
      'app_name': appName,
      'version': version,
      'build_time': DateTime.now().toIso8601String(),
      'flutter_version': await _getFlutterVersion(),
      'builds': {
        'android': await _getBuildInfo('build/app/outputs/flutter-apk/'),
        'windows': await _getBuildInfo('build/windows/runner/Release/'),
        'web': await _getBuildInfo('build/web/'),
      },
      'environment': {
        'platform': Platform.operatingSystem,
        'dart_version': Platform.version,
      },
    };
    
    final reportFile = File('build_report_${DateTime.now().millisecondsSinceEpoch}.json');
    await reportFile.writeAsString(json.encode(report));
    
    print('✅ Build report generated: ${reportFile.path}');
  }
  
  Future<String> _getFlutterVersion() async {
    final result = await Process.run('flutter', ['--version']);
    return result.stdout.toString().trim();
  }
  
  Future<Map<String, dynamic>> _getBuildInfo(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      return {'exists': false};
    }
    
    final files = await dir.list().toList();
    final totalSize = files.fold<int>(0, (sum, file) => sum + (file is File ? file.lengthSync() : 0));
    
    return {
      'exists': true,
      'file_count': files.length,
      'total_size_bytes': totalSize,
      'total_size_mb': (totalSize / (1024 * 1024)).toStringAsFixed(2),
    };
  }
}

Future<void> main(List<String> args) async {
  try {
    final builder = ProductionBuilder();
    
    if (args.contains('--android')) {
      await builder._buildAndroid();
    } else if (args.contains('--windows')) {
      await builder._buildWindows();
    } else if (args.contains('--web')) {
      await builder._buildWeb();
    } else {
      await builder.buildAll();
    }
  } catch (e, stackTrace) {
    print('❌ Build failed: $e');
    print(stackTrace);
    exit(1);
  }
}
