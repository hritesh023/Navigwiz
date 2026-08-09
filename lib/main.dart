import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'screens/browser_screen.dart';
import 'screens/login_screen.dart';

import 'services/browser_service.dart';
import 'services/ai_service.dart';
import 'services/theme_service.dart';
import 'services/logging_service.dart';
import 'services/analytics_service.dart';
import 'services/update_service.dart';
import 'services/service_worker_updater.dart';
import 'services/window_control_service.dart';
import 'services/central_auth_service.dart';
import 'providers/chat_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/workspace_provider.dart';
import 'providers/research_provider.dart';
import 'providers/memory_provider.dart';
import 'providers/extraction_provider.dart';
import 'providers/project_provider.dart';
import 'providers/settings_provider.dart';
import 'config/app_config.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _redirected = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isSignedIn) {
      return const BrowserScreen();
    }
    if (!_redirected) {
      _redirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        auth.redirectToLogin();
      });
    }
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFf59e0b)),
      ),
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final authService = CentralAuthService();
  final themeService = ThemeService();
  final browserService = BrowserService();
  final aiService = AIService();
  final chatProvider = ChatProvider();
  final authProvider = AuthProvider(auth: authService);
  final workspaceProvider = WorkspaceProvider();
  final researchProvider = ResearchProvider(aiService: aiService);
  final memoryProvider = MemoryProvider();
  final extractionProvider = ExtractionProvider();
  final projectProvider = ProjectProvider();
  final settingsProvider = SettingsProvider();

  await logger.initialize();
  await themeService.initialize();
  await authProvider.initialize();
  await workspaceProvider.initialize();
  await researchProvider.initialize();
  await memoryProvider.initialize();
  await extractionProvider.initialize();
  await projectProvider.initialize();
  await settingsProvider.initialize();
  browserService.setSearchEngine(settingsProvider.searchEngine);
  browserService.setHomepageUrl(settingsProvider.homepageUrl);

  if (!kIsWeb) {
    await WindowControlService.initialize();
    await browserService.initialize(initialUrl: _initialUrlFromArgs(args));
  }

  runApp(
    NavigwizApp(
      themeService: themeService,
      browserService: browserService,
      aiService: aiService,
      chatProvider: chatProvider,
      authProvider: authProvider,
      workspaceProvider: workspaceProvider,
      researchProvider: researchProvider,
      memoryProvider: memoryProvider,
      extractionProvider: extractionProvider,
      projectProvider: projectProvider,
      settingsProvider: settingsProvider,
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await logger.info('Starting Navigwiz v${AppConfig.appVersion}');
      await analytics.initialize();
      await aiService.initialize();
      if (kIsWeb) {
        watchForServiceWorkerUpdates();
      } else {
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
  final AuthProvider authProvider;
  final WorkspaceProvider workspaceProvider;
  final ResearchProvider researchProvider;
  final MemoryProvider memoryProvider;
  final ExtractionProvider extractionProvider;
  final ProjectProvider projectProvider;
  final SettingsProvider settingsProvider;

  const NavigwizApp({
    super.key,
    required this.themeService,
    required this.browserService,
    required this.aiService,
    required this.chatProvider,
    required this.authProvider,
    required this.workspaceProvider,
    required this.researchProvider,
    required this.memoryProvider,
    required this.extractionProvider,
    required this.projectProvider,
    required this.settingsProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeService),
        ChangeNotifierProvider.value(value: browserService),
        ChangeNotifierProvider.value(value: aiService),
        ChangeNotifierProvider.value(value: chatProvider),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: workspaceProvider),
        ChangeNotifierProvider.value(value: researchProvider),
        ChangeNotifierProvider.value(value: memoryProvider),
        ChangeNotifierProvider.value(value: extractionProvider),
        ChangeNotifierProvider.value(value: projectProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
      ],
      child: Consumer2<ThemeService, SettingsProvider>(
        builder: (context, themeService, settingsProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: AppConfig.appName,
            theme: themeService.lightTheme,
            darkTheme: themeService.darkTheme,
            themeMode: themeService.themeMode,
            debugShowCheckedModeBanner: false,
            initialRoute: '/',
            routes: {
              '/': (context) => const AuthGate(),
              '/home': (context) => const BrowserScreen(),
              '/login': (context) => const LoginScreen(),
            },
          );
        },
      ),
    );
  }
}
