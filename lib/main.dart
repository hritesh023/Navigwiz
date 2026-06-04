import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'screens/browser_screen.dart';

import 'services/browser_service.dart';
import 'services/ai_service.dart';
import 'services/theme_service.dart';
import 'services/logging_service.dart';
import 'services/analytics_service.dart';
import 'services/update_service.dart';
import 'providers/chat_provider.dart';
import 'config/app_config.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final themeService = ThemeService();
  final browserService = BrowserService();
  final aiService = AIService();
  final chatProvider = ChatProvider();

  await logger.initialize();
  await themeService.initialize();

  if (!kIsWeb) {
    await browserService.initialize(initialUrl: _initialUrlFromArgs(args));
  }

  runApp(
    NavigwizApp(
      themeService: themeService,
      browserService: browserService,
      aiService: aiService,
      chatProvider: chatProvider,
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await logger.info('Starting Navigwiz v${AppConfig.appVersion}');
      await analytics.initialize();
      await aiService.initialize();
      if (!kIsWeb) {
        await updateService.initialize();
      }
      await logger.info('All services initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('Background initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  });
}

String? _initialUrlFromArgs(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('http://') || arg.startsWith('https://')) {
      return arg;
    }
  }
  return null;
}

class NavigwizApp extends StatelessWidget {
  final ThemeService themeService;
  final BrowserService browserService;
  final AIService aiService;
  final ChatProvider chatProvider;

  const NavigwizApp({
    super.key,
    required this.themeService,
    required this.browserService,
    required this.aiService,
    required this.chatProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeService),
        ChangeNotifierProvider.value(value: browserService),
        ChangeNotifierProvider.value(value: aiService),
        ChangeNotifierProvider.value(value: chatProvider),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: AppConfig.appName,
            theme: themeService.lightTheme,
            darkTheme: themeService.darkTheme,
            themeMode: themeService.themeMode,
            home: const BrowserScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
