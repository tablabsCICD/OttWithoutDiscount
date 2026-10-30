import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:ott/app/core/services/DeepLinkService.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/data/themes/custom_theme.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';
import 'package:ott/app/core/services/notification_service.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/provider/giftProvider.dart';
import 'package:ott/app/provider/language_provider.dart';
import 'package:ott/app/provider/localeLanguageProvider.dart';
import 'package:ott/app/provider/offline_download_provider.dart';
import 'package:ott/app/provider/onboarding_tour_provider.dart';
import 'package:ott/app/provider/playMediaProvider.dart';
import 'package:ott/app/provider/purchaseContentProvider.dart';
import 'package:ott/app/provider/series_provider.dart';
import 'package:ott/app/provider/session_device_provider.dart';
import 'package:ott/app/provider/shorts_provider.dart';
import 'package:ott/app/provider/ticketProvider.dart';
import 'package:ott/app/provider/videoProvider.dart';
import 'package:ott/app/provider/wallet_provider.dart';
import 'package:ott/app/widgets/feature_tour.dart';
import 'package:ott/app/widgets/ott_tv_app_shell.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/core/constant/prefrense_constant.dart';
import 'app/core/utils/sharepreferences.dart';
import 'app/provider/userProvider.dart';
import 'app/route/navigation_service.dart';
import 'app/route/route_observer.dart';
import 'app/route/routes/routes.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await DeepLinkService.instance.init();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Check theme preference
  final themeBool = prefs.getBool("isDark") ?? true;

  LocalSharePreferences localSharePreferences = LocalSharePreferences();
  // Check if user is logged in
  final isLoggedIn = await localSharePreferences
      .getBool(SharedPreferencesConstant.isUserLoggedIn);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => ThemeProvider(isDark: themeBool),
        ),
        ChangeNotifierProvider(
          create: (context) => LanguageProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => UserProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => WalletProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => TicketProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => VideoProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => DashboardProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => PurchaseContentProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => LocaleLanguageProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => GiftProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => ShortProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => SeriesProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => PlayMediaProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => OfflineDownloadProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => BookmarkProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => SessionDeviceProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => OnboardingTourProvider(),
        ),
      ],
      child: MyApp(
        isLoggedIn: isLoggedIn,
      ),
    ),
  );

  if (!kIsWeb) {
    unawaited(_initializeNotificationsSafely());
  }
}

Future<void> _initializeNotificationsSafely() async {
  try {
    await NotificationService.instance.init();
  } catch (_) {
    // Notification initialization failures are intentionally non-fatal.

  }
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;

  const MyApp({
    super.key,
    required this.isLoggedIn,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    sendNotification();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NotificationService.instance.consumePendingNavigation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleLanguageProvider>(context);
    if (kDebugMode) {

    }
    return MaterialApp(
      title: 'Filmytell',
      locale: localeProvider.locale,

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('hi'), // Hindi (हिंदी)
        Locale('ur'), // Urdu (اُردُو)
        Locale('mr'), // Marathi (मराठी)
        Locale('ml'), // Malayalam (മലയാളം)
        Locale('ta'), // Tamil (தமிழ்)
        Locale('kn'), // Kannada (ಕನ್ನಡ)
        Locale('te'), // Telugu (తెలుగు)
        Locale('or'), // Odia (ଓଡ଼ିଆ)
        Locale('gu'), // Gujarati (ગુજરાતી)
        Locale('pa'), // Punjabi (ਪੰਜਾਬੀ)
        Locale('as'), // Assamese (অসমীয়া)
        Locale('bn'), // Bengali (বাংলা)
        Locale('ne'), // Nepali (नेपाली)
      ],
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      // Navigate based on login state
      initialRoute: "/",
      onGenerateRoute: RouteGenerator.generateRoute,
      builder: (context, child) {
        final routeChild = child ?? const SizedBox.shrink();
        return Stack(
          fit: StackFit.expand,
          children: [
            kIsWeb ? routeChild : OttTvAppShell(child: routeChild),
            const Positioned.fill(child: FeatureTourOverlay()),
          ],
        );
      },
    );
  }

  sendNotification() async {
    await FirebaseMessaging.instance.subscribeToTopic('all');
  }
}
