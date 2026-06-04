# Production Deployment Guide

## Overview

This guide covers the complete production deployment process for Navigwiz, including security, build configuration, testing, and deployment procedures.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Build Configuration](#build-configuration)
4. [Security Configuration](#security-configuration)
5. [Testing](#testing)
6. [Build Process](#build-process)
7. [Deployment](#deployment)
8. [Monitoring](#monitoring)
9. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

- **Flutter SDK**: 3.16.0 or higher
- **Dart SDK**: 3.0.0 or higher
- **Git**: Latest version
- **Code Signing Certificates**: Platform-specific
- **Build Environment**: Windows/Linux/macOS

### Platform Requirements

#### Windows
- Windows 10/11
- Visual Studio 2022 or newer
- Windows SDK 10.0.22000.0 or higher

#### macOS
- macOS 10.15 or higher
- Xcode 14.0 or higher
- Apple Developer Account

#### Linux
- Ubuntu 18.04 or higher
- GCC 9.0 or higher
- GTK 3.0 or higher

#### Android
- Android API level 21 or higher
- Java 8 or higher
- Android Studio

## Environment Setup

### 1. Clone Repository

```bash
git clone https://github.com/your-org/navigwiz.git
cd navigwiz
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Environment Variables

Create a `.env` file in the project root:

```env
# API Keys (required for production)
OPENAI_API_KEY=your_openai_api_key_here
WEATHER_API_KEY=your_weather_api_key_here

# Optional Configuration
SEARXNG_URL=https://search.brave.com/search
UPDATE_CHECK_URL=https://api.navigwiz.app/v1/updates
ANALYTICS_ENDPOINT=https://analytics.navigwiz.app/v1/events
```

### 4. Code Signing Setup

#### Android

1. Generate signing key:
```bash
keytool -genkey -v -keystore navigwiz-release.keystore -alias navigwiz -keyalg RSA -keysize 2048 -validity 10000
```

2. Configure `android/key.properties`:
```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=navigwiz
storeFile=../navigwiz-release.keystore
```

#### Windows

1. Create certificate:
```bash
# Use OpenSSL or purchase from certificate authority
openssl req -x509 -newkey rsa:4096 -keyout navigwiz.key -out navigwiz.crt -days 365
```

#### macOS

1. Create developer certificate in Apple Developer Portal
2. Download and install certificate
3. Configure signing in Xcode

## Build Configuration

### Production Build Settings

The production build configuration is defined in `build_production.yaml`:

```yaml
environment:
  OPENAI_API_KEY: "${OPENAI_API_KEY}"
  WEATHER_API_KEY: "${WEATHER_API_KEY}"
  SEARXNG_URL: "https://search.brave.com/search"

flutter:
  release:
    obfuscate: true
    split-debug-info: "build/debug-info/"
    tree-shake-icons: true
    deferred-components: true

platforms:
  android:
    signing:
      keystore: "android/app/keystore.jks"
      key_alias: "navigwiz"
    
  windows:
    signing:
      certificate: "windows/certificate.pfx"
    
  macos:
    signing:
      identity: "Developer ID Application: Your Name"
```

## Security Configuration

### API Key Management

1. **Never hardcode API keys** in source code
2. **Use environment variables** for all sensitive data
3. **Implement key rotation** policies
4. **Use secure storage** for runtime key management

### Network Security

- HTTPS-only connections enforced
- Certificate pinning enabled
- Content Security Policy configured
- API rate limiting implemented

### Code Obfuscation

```bash
# Enable obfuscation for production builds
flutter build apk --obfuscate --split-debug-info=build/debug-info/
```

## Testing

### 1. Unit Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage
```

### 2. Integration Tests

```bash
# Run integration tests
flutter test integration_test/
```

### 3. Performance Tests

```bash
# Run performance profiling
flutter run --profile
```

### 4. Security Tests

```bash
# Run security analysis
flutter analyze
dart analyze --fatal-infos
```

## Build Process

### Automated Build Script

Use the provided build script:

```bash
# Make executable
chmod +x scripts/build_production.dart

# Run production build
dart scripts/build_production.dart
```

### Manual Build Commands

#### Android
```bash
# Build APK
flutter build apk --release --obfuscate --split-debug-info=build/debug-info/ --dart-define=OPENAI_API_KEY=$OPENAI_API_KEY

# Build App Bundle
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info/ --dart-define=OPENAI_API_KEY=$OPENAI_API_KEY
```

#### Windows
```bash
flutter build windows --release --obfuscate --split-debug-info=build/debug-info/ --dart-define=OPENAI_API_KEY=$OPENAI_API_KEY
```

#### Web
```bash
flutter build web --release --web-renderer=html --dart-define=OPENAI_API_KEY=$OPENAI_API_KEY
```

## Deployment

### Android Deployment

#### Google Play Store

1. **Prepare Release Bundle**:
   ```bash
   # Upload to Google Play Console
   # Target: production
   # Track: production
   ```

2. **Store Listing Requirements**:
   - App icon: 512x512 PNG
   - Screenshots: All device sizes
   - Privacy policy URL
   - Content rating

#### Alternative Distribution

```bash
# Generate signed APK
flutter build apk --release --obfuscate --split-per-abi

# Distribute via direct download or third-party stores
```

### Windows Deployment

#### Microsoft Store

1. **Package Application**:
   ```bash
   # Create installer
   flutter build windows --release
   ```

2. **Store Requirements**:
   - Windows 10/11 compatibility
   - Code signing certificate
   - Store policies compliance

#### Direct Distribution

```bash
# Create portable installer
flutter build windows --release
# Use Inno Setup or WiX Toolset for installer
```

### macOS Deployment

#### Mac App Store

1. **Prepare for App Store**:
   ```bash
   # Build for distribution
   flutter build macos --release
   ```

2. **Notarization**:
   ```bash
   # Required for macOS 10.15+
    xcrun altool --notarize-app --primary-bundle-id "com.navigwiz.browser" --username "your@email.com" --password "app-specific-password" --file "build/macos/Build/Products/Release/Navigwiz.app"
   ```

#### Direct Distribution

```bash
# Create DMG installer
flutter build macos --release
# Use create-dmg for disk image
```

### Web Deployment

#### Static Hosting

1. **Build for Production**:
   ```bash
   flutter build web --release --web-renderer=html --no-sound-null-safety
   ```

2. **Configure CDN**:
   - Enable gzip compression
   - Set cache headers
   - Configure SSL certificates

#### Progressive Web App (PWA)

1. **Service Worker Registration**
2. **Offline Support**
3. **App Manifest Configuration**

## Monitoring

### Analytics Integration

The app includes comprehensive analytics:

```dart
// Analytics automatically track:
// - App starts/stops
// - User interactions
// - Performance metrics
// - Error events
// - Feature usage
```

### Crash Reporting

```dart
// Automatic crash report collection:
// - Stack traces
// - Device information
// - App state
// - User context
```

### Performance Monitoring

```dart
// Built-in performance tracking:
// - Startup time
// - Memory usage
// - CPU usage
// - Network latency
```

## Troubleshooting

### Common Issues

#### Build Failures

1. **Missing Dependencies**:
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Signing Issues**:
   - Verify certificate validity
   - Check key store permissions
   - Ensure correct aliases

3. **Platform-Specific Issues**:
   - Android: Check Gradle configuration
   - Windows: Verify Visual Studio setup
   - macOS: Check Xcode provisioning

#### Runtime Issues

1. **API Key Errors**:
   - Verify environment variables
   - Check API key validity
   - Review rate limits

2. **Network Issues**:
   - Check HTTPS certificates
   - Verify firewall settings
   - Test API endpoints

3. **Performance Issues**:
   - Profile with Flutter tools
   - Check memory leaks
   - Optimize image sizes

### Debug Mode

Enable debug logging for troubleshooting:

```dart
// In AppConfig
static const bool enableVerboseLogging = true;
```

### Support Information

For production issues:

- **Documentation**: [GitHub Wiki](https://github.com/your-org/navigwiz/wiki)
- **Issues**: [GitHub Issues](https://github.com/your-org/navigwiz/issues)
- **Community**: [Discord](https://discord.gg/navigwiz)
- **Email**: support@navigwiz.app

## Security Best Practices

### Code Security

1. **Regular Security Audits**:
   - Quarterly penetration testing
   - Dependency vulnerability scanning
   - Code review processes

2. **Data Protection**:
   - End-to-end encryption
   - Secure API key storage
   - User data anonymization

3. **Compliance**:
   - GDPR compliance
   - CCPA compliance
   - Accessibility standards

### Release Checklist

Before deploying to production, ensure:

- [ ] All tests passing
- [ ] Code obfuscation enabled
- [ ] API keys secured
- [ ] Code signing configured
- [ ] Performance benchmarks met
- [ ] Security audit completed
- [ ] Documentation updated
- [ ] Backup procedures tested
- [ ] Rollback plan ready

## Version Management

### Semantic Versioning

Use semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes
- **MINOR**: New features
- **PATCH**: Bug fixes

### Release Process

1. **Development**: Feature development on `develop` branch
2. **Testing**: Comprehensive testing on `staging` branch
3. **Release**: Merge to `main` and tag with version
4. **Deployment**: Deploy tagged version to production

### Hotfixes

For critical fixes:

1. Create hotfix branch from `main`
2. Implement fix
3. Test thoroughly
4. Merge back to `main`
5. Create patch release

## Conclusion

Following this guide ensures a secure, performant, and maintainable production deployment of Navigwiz. Regular updates to this document should accompany each release to reflect new requirements and best practices.
