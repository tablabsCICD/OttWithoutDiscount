import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ott/app/core/services/session_manager.dart';
import 'package:ott/app/core/services/DeepLinkService.dart';
import 'package:ott/app/core/constant/image_constant.dart';
import 'package:ott/app/core/constant/app_constant.dart';
import 'package:ott/app/core/services/app_update_service.dart';
import 'package:ott/app/core/services/referral_service.dart';
import 'package:ott/app/core/services/gift_deep_link_service.dart';
import 'package:ott/app/pages/NavigationPage.dart';
import 'package:ott/app/pages/onboarding pages/selectLanguagePage.dart';
import 'package:ott/app/route/routes/web_navigation_routes.dart';
import 'package:ott/presentation/web_landing/screens/web_landing_screen.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constant/prefrense_constant.dart';
import '../../core/utils/sharepreferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.initialNavigationRoute,
  });

  final WebNavigationRoute? initialNavigationRoute;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final LocalSharePreferences _prefs = LocalSharePreferences();
  final AppUpdateService _appUpdateService = AppUpdateService();
  bool _isLoggedIn = false;
  int _flowVersion = 0;

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  Future<void> _startFlow() async {
    final flowVersion = ++_flowVersion;
    final requestedPath = widget.initialNavigationRoute?.path ?? '/';

    // Recover any deferred install referral code, gift code, or content link on cold start / first launch
    unawaited(ReferralService.instance.checkDeferredInstallReferrer());
    unawaited(GiftDeepLinkService.instance.checkDeferredGiftInstall());
    unawaited(DeepLinkService.instance.checkDeferredContentInstall());

    final loggedIn =
        await _prefs.getBool(SharedPreferencesConstant.isUserLoggedIn);
    if (!_isActiveFlow(flowVersion)) return;
    final token = await SessionManager.instance.token;
    if (!_isActiveFlow(flowVersion)) return;
    final hasToken = token != null;

    _isLoggedIn = kIsWeb ? loggedIn && hasToken : loggedIn;
    _logWebAuth(
      'Splash auth check requestedPath=$requestedPath loggedInFlag=$loggedIn hasToken=$hasToken authenticated=$_isLoggedIn',
    );

    if (widget.initialNavigationRoute == null) {
      // Splash delay
      await Future.delayed(const Duration(seconds: 2));
      if (!_isActiveFlow(flowVersion)) return;

      if (_supportsUpdateDialog) {
        final updateInfo = await _appUpdateService.getUpdateInfo();
        if (!_isActiveFlow(flowVersion)) return;

        final shouldShowUpdateDialog = updateInfo.isUpdateAvailable;

        if (shouldShowUpdateDialog) {
          await _showUpdateDialog(updateInfo);
          if (!_isActiveFlow(flowVersion)) return;
        }
      }
    }

    if (!_isActiveFlow(flowVersion)) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return;
    }

    final initialNavigationRoute = widget.initialNavigationRoute;
    final isLoggedIn = _isLoggedIn;
    final routeName = isLoggedIn
        ? initialNavigationRoute?.path
        : kIsWeb
            ? '/'
            : null;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: routeName),
        builder: (routeContext) {
          if (isLoggedIn) {
            final route = initialNavigationRoute;
            return NavigationPage(
              initialIndex: route?.index ?? 0,
              initialHomeContentType: route?.homeContentType ?? 'MOVIE',
            );
          }
          if (_shouldShowWebLandingForContext(routeContext)) {
            if (kIsWeb && kDebugMode) {
              developer.log(
                'Splash redirecting to web landing because authenticated=false',
                name: 'WebAuthGuard',
              );
            }
            return const WebLandingScreen();
          }
          return const SelectLocaleLanguagePage();
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(DeepLinkService.instance.consumePendingNavigation());
      }
    });
  }

  bool _isActiveFlow(int flowVersion) {
    return mounted && flowVersion == _flowVersion;
  }

  @override
  void dispose() {
    _flowVersion++;
    super.dispose();
  }

  static bool _shouldShowWebLandingForContext(BuildContext context) {
    return kIsWeb || ResponsiveWidget.isTablet(context);
  }

  void _logWebAuth(String message) {
    if (!kIsWeb || !kDebugMode) return;
    developer.log(message, name: 'WebAuthGuard');
  }

  bool get _supportsUpdateDialog {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _showUpdateDialog(AppUpdateInfo updateInfo) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: const Text('Update Available'),
          content: Text(
            'A newer version is available (${updateInfo.latestVersion}). Please update for the best experience.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext, rootNavigator: true).pop(),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse(AppConstant.playStoreLink);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                }
              },
              child: const Text('Update Now'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Hero(
              tag: 'logo',
              child: Image.asset(
                kIsWeb
                    ? ImageConstant.webFullScreenLogo
                    : ImageConstant.fullScreenLogo,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
