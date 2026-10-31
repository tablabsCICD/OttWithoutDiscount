import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ott/app/core/constant/prefrense_constant.dart';
import 'package:ott/app/core/services/DeepLinkService.dart';
import 'package:ott/app/core/services/session_manager.dart';
import 'package:ott/app/core/utils/sharepreferences.dart';
import 'package:ott/app/pages/movie%20details%20page/MovieDetailsPage.dart';
import 'package:ott/app/pages/news%20page/NewsScreen.dart';
import 'package:ott/app/pages/notification%20page/NotificationPage.dart';
import 'package:ott/presentation/web_landing/designs/preview/landing_page_design_preview.dart';
import 'package:ott/presentation/web_landing/screens/content_web_fallback_screen.dart';
import 'package:ott/presentation/web_landing/screens/producer_learn_more_screen.dart';
import 'package:ott/presentation/web_landing/screens/web_landing_screen.dart';

import '../../pages/onboarding pages/SplashScreen.dart';
import '../../pages/sign in page/LoginCard.dart';
import 'package:ott/app/core/services/referral_service.dart';
import 'package:ott/app/core/services/gift_deep_link_service.dart';
import 'app_routes.dart';
import 'web_navigation_routes.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    _logRouteRequest(settings);

    if (settings.name == AppRoutes.producerLearnMore ||
        settings.name == '/producer-learn-more' ||
        settings.name == '/learn-more') {
      return buildRoute(
        const ProducerLearnMoreScreen(),
        settings: settings,
      );
    }

    if (settings.name == AppRoutes.landingPreview ||
        settings.name == '/preview' ||
        settings.name == '/landing-preview') {
      return buildRoute(
        const LandingPageDesignPreview(),
        settings: settings,
      );
    }

    if (settings.name == AppRoutes.news &&
        settings.arguments is NewsScreenArgs) {
      final args = settings.arguments as NewsScreenArgs;
      return buildRoute(NewsScreen(args: args), settings: settings);
    }

    final webNavigationRoute =
        kIsWeb ? WebNavigationRoutes.fromPath(settings.name) : null;
    if (webNavigationRoute != null) {
      return buildRoute(
        SplashScreen(initialNavigationRoute: webNavigationRoute),
        settings: settings,
      );
    }

    if (settings.name != null) {
      final uri = Uri.tryParse(settings.name!);
      if (uri != null) {
        ReferralService.instance.captureFromUri(uri);
        GiftDeepLinkService.instance.captureFromUri(uri);
        final pathLower = uri.path.trim().toLowerCase();
        if (pathLower == '/register' ||
            pathLower == 'register' ||
            pathLower == '/login' ||
            pathLower == 'login') {
          return buildRoute(const LoginCard(), settings: settings);
        }

        // Check if universal content URL (e.g. /movie/123, /series/456, /miniseries/789, /short-film/101) or gift URL
        final targetUri = uri.hasScheme
            ? uri
            : Uri.tryParse('https://${DeepLinkService.httpsHost}${uri.path.startsWith('/') ? '' : '/'}${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}');
        if (targetUri != null) {
          final target = DeepLinkService.instance.parseTarget(targetUri);
          if (target != null) {
            if (target.type == DeepLinkContentType.gift) {
              final couponCode = target.couponCode;
              if (couponCode != null) {
                GiftDeepLinkService.instance.savePendingGiftCode(couponCode);
              }
              return buildRoute(
                const SplashScreen(),
                settings: settings,
              );
            }
            if (target.id != null && target.id! > 0) {
              if (kIsWeb) {
                return buildRoute(
                  ContentWebFallbackScreen(
                    contentId: target.id!,
                    contentType: target.type,
                  ),
                  settings: settings,
                );
              }
            }
          }
        }
      }
    }

    switch (settings.name) {
      case AppRoutes.login:
      case '/register':
        return buildRoute(const LoginCard(), settings: settings);

      case AppRoutes.entry:
        return buildRoute(SplashScreen(), settings: settings);

      case AppRoutes.news:
        final args = settings.arguments is NewsScreenArgs
            ? settings.arguments as NewsScreenArgs
            : const NewsScreenArgs(
                title: 'News',
                body: 'Opened from notification',
                payload: <String, dynamic>{},
              );
        return buildRoute(NewsScreen(args: args), settings: settings);

      case AppRoutes.movieDetails:
        final movieId = _parseMovieId(settings.arguments);
        final contentType = settings.arguments is MovieDetailsRouteArgs
            ? (settings.arguments as MovieDetailsRouteArgs).contentType
            : 'MOVIE';
        if (movieId == null || movieId <= 0) {
          return _invalidMovieRoute(settings);
        }
        return buildRoute(
          MovieDetailsPage(movieId: movieId, contentType: contentType),
          settings: settings,
        );

      case AppRoutes.notificationPage:
        _logRouteDecision(
          'Protected notification route requested name=${settings.name}',
        );
        if (kIsWeb) {
          return buildRoute(
            const _WebProtectedRoute(
              routeName: AppRoutes.notificationPage,
              child: NotificationPage(),
            ),
            settings: settings,
          );
        }
        return buildRoute(const NotificationPage(), settings: settings);

      /*  case AppRoutes.home:
         return buildRoute(DashboardPage(), settings: settings);

       case AppRoutes.forgotPassword:
         return buildRoute(DashboardPage(), settings: settings);

      case AppRoutes.profile:
        return buildRoute(ProfilePage(), settings: settings);

      case AppRoutes.editProfile:
        return buildRoute(EditProfilePage(), settings: settings);

      case AppRoutes.document:
        return buildRoute(DocumentsPage(), settings: settings);

      case AppRoutes.analytics:
        return buildRoute(AnalyticsPage(), settings: settings);

      case AppRoutes.settlement:
        return buildRoute(SettlementPage(), settings: settings);

      case AppRoutes.helpSupport:
        return buildRoute(HelpDeskPage(), settings: settings);

      case AppRoutes.releaseContent:
        return buildRoute(ReleasedContentPage(), settings: settings);

      case AppRoutes.pendingContent:
        return buildRoute(PendingContentPage(), settings: settings);*/

      default:
        _logRouteDecision(
          'Unknown route ${settings.name}; falling back to SplashScreen',
        );
        return buildRoute(SplashScreen(), settings: settings);
    }
  }

  static void _logRouteRequest(RouteSettings settings) {
    if (!kIsWeb || !kDebugMode) return;
    developer.log(
      'Requested route name=${settings.name} arguments=${settings.arguments.runtimeType}',
      name: 'WebRoute',
    );
  }

  static void _logRouteDecision(String message) {
    if (!kIsWeb || !kDebugMode) return;
    developer.log(message, name: 'WebRoute');
  }

  static MaterialPageRoute buildRoute(Widget child,
      {required RouteSettings settings}) {
    return MaterialPageRoute(
        settings: settings, builder: (BuildContext context) => child);
  }

  static int? _parseMovieId(Object? arguments) {
    if (arguments is MovieDetailsRouteArgs) {
      return arguments.movieId;
    }

    if (arguments is int) {
      return arguments;
    }

    if (arguments is String) {
      return int.tryParse(arguments);
    }

    if (arguments is Map<String, dynamic>) {
      final value = arguments['movieId'] ?? arguments['id'];
      return int.tryParse('$value');
    }

    if (arguments is Map) {
      final value = arguments['movieId'] ?? arguments['id'];
      return int.tryParse('$value');
    }

    return null;
  }

  static Route<dynamic> _invalidMovieRoute(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !kIsWeb,
          title: const Text('Movie not found'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'The shared movie link is invalid or incomplete.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  static Route _createRoute(Widget root) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => root,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = const Offset(0.0, 1.0);
        var end = Offset.zero;
        const curve = Curves.ease;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !kIsWeb,
          backgroundColor: Colors.transparent,
          title: const Text(
            'Exit App',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 450.0,
                  width: 450.0,
                  //child: Lottie.asset('assets/lottie/error.json'),
                ),
                Text(
                  'Seems the route you\'ve navigated to doesn\'t exist!!',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _WebProtectedRoute extends StatefulWidget {
  const _WebProtectedRoute({
    required this.routeName,
    required this.child,
  });

  final String routeName;
  final Widget child;

  @override
  State<_WebProtectedRoute> createState() => _WebProtectedRouteState();
}

class _WebProtectedRouteState extends State<_WebProtectedRoute> {
  bool? _authenticated;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final loggedIn = await LocalSharePreferences.localSharePreferences.getBool(
      SharedPreferencesConstant.isUserLoggedIn,
    );
    final token = await SessionManager.instance.token;
    final authenticated = loggedIn && token != null;
    if (!mounted) return;
    if (kDebugMode) {
      developer.log(
        'Protected route auth check route=${widget.routeName} loggedInFlag=$loggedIn hasToken=${token != null} authenticated=$authenticated',
        name: 'WebAuthGuard',
      );
    }
    setState(() => _authenticated = authenticated);
    if (!authenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/'),
          builder: (_) => const WebLandingScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authenticated = _authenticated;
    if (authenticated == null) {
      return const SizedBox.shrink();
    }
    if (!authenticated) {
      if (kDebugMode) {
        developer.log(
          'Protected route redirecting to web landing route=${widget.routeName}',
          name: 'WebAuthGuard',
        );
      }
      return const WebLandingScreen();
    }
    return widget.child;
  }
}
