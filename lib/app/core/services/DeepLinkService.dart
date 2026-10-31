import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ott/app/core/constant/prefrense_constant.dart';
import 'package:ott/app/core/services/gift_deep_link_service.dart';
import 'package:ott/app/core/services/referral_service.dart';
import 'package:ott/app/pages/movie%20details%20page/MovieDetailsPage.dart';
import 'package:ott/app/pages/series%20details%20page/seriesdetailspage.dart';
import 'package:ott/app/pages/shorts%20page/component/ShortsPlayerPage.dart';
import 'package:ott/app/pages/sign%20in%20page/LoginCard.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/provider/shorts_provider.dart';
import 'package:ott/app/route/navigation_service.dart';
import 'package:ott/app/route/routes/app_routes.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:ott/data/models/shorts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_links/uni_links.dart';

class MovieDetailsRouteArgs {
  const MovieDetailsRouteArgs({
    required this.movieId,
    this.source = 'internal',
    this.contentType = 'MOVIE',
  });

  final int movieId;
  final String source;
  final String contentType;
}

enum DeepLinkContentType {
  movie,
  shortFilm,
  series,
  miniSeries,
  short,
  gift,
  register,
}

class DeepLinkTarget {
  const DeepLinkTarget({
    required this.type,
    this.id,
    this.couponCode,
    this.referralCode,
  });

  final DeepLinkContentType type;
  final int? id;
  final String? couponCode;
  final String? referralCode;

  String get typeName => type.name;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.name,
        if (id != null) 'id': id,
        if (couponCode != null) 'couponCode': couponCode,
        if (referralCode != null) 'referralCode': referralCode,
      };

  factory DeepLinkTarget.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'movie';
    final type = DeepLinkContentType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => DeepLinkContentType.movie,
    );
    return DeepLinkTarget(
      type: type,
      id: json['id'] as int?,
      couponCode: json['couponCode'] as String?,
      referralCode: json['referralCode'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeepLinkTarget &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          id == other.id &&
          couponCode == other.couponCode &&
          referralCode == other.referralCode;

  @override
  int get hashCode => Object.hash(type, id, couponCode, referralCode);

  @override
  String toString() =>
      'DeepLinkTarget(type: $typeName, id: $id, couponCode: $couponCode, referralCode: $referralCode)';
}

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  static const String scheme = 'myapp';
  static const String movieHost = 'movie';
  static const String shortFilmHost = 'short-film';
  static const String seriesHost = 'series';
  static const String miniseriesHost = 'miniseries';
  static const String shortHost = 'short';
  static const String giftHost = 'gift';
  static const String registerHost = 'register';
  static const String loginHost = 'login';
  static const String httpsHost = 'filmytell.com'; // Canonical host
  static const String httpsWwwHost = 'www.filmytell.com';
  static const String httpsLegacyHost = 'filmytell.in'; // Legacy host
  static const String httpsInHost = 'filmytell.in'; // Kept for backward compatibility
  static const String httpsWwwInHost = 'www.filmytell.in';
  static const String ottPathPrefix = 'ott';
  static const String androidPackageName = 'com.filmytell.ott';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$androidPackageName';
  static const String appStoreUrl =
      'https://apps.apple.com/fr/app/filmytell/id6783863260';

  static const MethodChannel _installReferrerChannel =
      MethodChannel('com.filmytell.ott/install_referrer');

  StreamSubscription<Uri?>? _linkSubscription;
  DeepLinkTarget? _pendingTarget;
  bool _isInitialized = false;
  Uri? _lastProcessedUri;
  DateTime? _lastProcessedTime;
  DeepLinkTarget? _lastProcessedTarget;
  DateTime? _lastTargetTime;

  bool get hasPendingNavigation => _pendingTarget != null;

  DeepLinkTarget? get pendingTarget => _pendingTarget;

  DeepLinkTarget? get lastProcessedTarget => _lastProcessedTarget;

  bool get supportsUniversalLinks => true;

  Future<void> init() async {
    if (_isInitialized) {
      developer.log(
        'Deep link service already initialized',
        name: 'DeepLinkService',
      );
      return;
    }

    developer.log(
      'Initializing deep link service. platform=${kIsWeb ? 'web' : defaultTargetPlatform.name}',
      name: 'DeepLinkService',
    );

    if (kIsWeb) {
      await _handleIncomingUri(Uri.base, source: 'initial_uri');
      _isInitialized = true;
      return;
    }

    try {
      final initialUri = await getInitialUri();
      developer.log(
        'Initial deep link uri=${initialUri?.toString() ?? 'none'}',
        name: 'DeepLinkService',
      );
      await _handleIncomingUri(initialUri, source: 'initial_uri');
    } on FormatException catch (error, stackTrace) {
      _log('Invalid initial deep link received', error, stackTrace);
    } catch (error, stackTrace) {
      _log('Unable to read initial deep link', error, stackTrace);
    }

    if (_pendingTarget == null) {
      final persisted = await getPendingDeepLinkTarget();
      if (persisted != null) {
        if (persisted.type == DeepLinkContentType.gift &&
            persisted.couponCode != null &&
            await GiftDeepLinkService.instance
                .isGiftCodeClaimed(persisted.couponCode!)) {
          developer.log(
            'Persisted pending gift deep link ${persisted.couponCode} is already claimed. Clearing.',
            name: 'DeepLinkService',
          );
          await clearPendingDeepLinkTarget();
        } else {
          _pendingTarget = persisted;
          developer.log(
            'Restored persisted pending target on init: $persisted',
            name: 'DeepLinkService',
          );
        }
      }
    }

    _linkSubscription = uriLinkStream.listen(
      (uri) {
        developer.log(
          'Deep link stream uri=${uri?.toString() ?? 'none'}',
          name: 'DeepLinkService',
        );
        unawaited(_handleIncomingUri(uri, source: 'uri_stream'));
      },
      onError: (Object error, StackTrace stackTrace) {
        _log('Deep link stream failed', error, stackTrace);
      },
    );

    _isInitialized = true;
  }

  Uri buildMovieDeepLink(int movieId) {
    return Uri(
      scheme: scheme,
      host: movieHost,
      pathSegments: <String>['$movieId'],
    );
  }

  Uri buildGiftDeepLink(String couponCode) {
    return Uri(
      scheme: scheme,
      host: giftHost,
      pathSegments: <String>[couponCode.trim().toUpperCase()],
    );
  }

  Uri buildDeepLink({
    required DeepLinkContentType type,
    required int id,
  }) {
    return Uri(
      scheme: scheme,
      host: _hostForType(type),
      pathSegments: <String>['$id'],
    );
  }

  Uri buildMovieAppLink(int movieId, {String? customHost}) {
    return Uri.https(customHost ?? httpsHost, 'movie/$movieId');
  }

  Uri buildGiftAppLink(String couponCode, {String? customHost}) {
    return Uri.https(
      customHost ?? httpsHost,
      '$giftHost/${couponCode.trim().toUpperCase()}',
    );
  }

  Uri buildReferralAppLink(String referralCode, {String? customHost}) {
    return Uri.https(
      customHost ?? httpsHost,
      registerHost,
      <String, String>{'referralCode': referralCode.trim()},
    );
  }

  /// Builds a clean universal URL without '/share/'.
  /// Examples:
  /// - https://filmytell.com/movie/123
  /// - https://filmytell.com/series/456
  /// - https://filmytell.com/miniseries/789
  /// - https://filmytell.com/short-film/101
  Uri buildAppLink({
    required DeepLinkContentType type,
    required int id,
    String? customHost,
  }) {
    return Uri.https(
      customHost ?? httpsHost,
      '${_hostForType(type)}/$id',
    );
  }

  Uri buildPreferredQrLink({
    required DeepLinkContentType type,
    required int id,
  }) {
    return buildAppLink(type: type, id: id);
  }

  DeepLinkTarget? parseTarget(Uri uri) {
    if (_isExpiredLink(uri)) return null;

    if (uri.scheme == scheme) {
      final type = _typeFromString(uri.host);
      final firstSegment =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;

      if (type == DeepLinkContentType.register) {
        final referralCode = ReferralService.extractCodeFromUri(uri);
        return DeepLinkTarget(
          type: DeepLinkContentType.register,
          referralCode: referralCode,
        );
      } else if (type == DeepLinkContentType.gift) {
        final couponCode = GiftDeepLinkService.extractGiftCodeFromUri(uri) ??
            _parseCouponCode(firstSegment);
        if (couponCode != null) {
          return DeepLinkTarget(
            type: DeepLinkContentType.gift,
            couponCode: couponCode,
          );
        }
      } else {
        final id = _parsePositiveInt(firstSegment);
        if (type != null && id != null) {
          return DeepLinkTarget(type: type, id: id);
        }
      }
    }

    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        _isSupportedHttpHost(uri.host)) {
      final pathSegments = _httpPathSegments(uri);
      final normalizedPathSegments = _normalizePathSegments(pathSegments);
      developer.log(
        'HTTP deep link path=${normalizedPathSegments.join('/')} query=${uri.queryParameters}',
        name: 'DeepLinkService',
      );
      final pathType = normalizedPathSegments.isNotEmpty
          ? _typeFromString(normalizedPathSegments.first)
          : null;

      if (pathType == DeepLinkContentType.register) {
        final referralCode = ReferralService.extractCodeFromUri(uri);
        return DeepLinkTarget(
          type: DeepLinkContentType.register,
          referralCode: referralCode,
        );
      } else if (pathType == DeepLinkContentType.gift) {
        final couponCode = GiftDeepLinkService.extractGiftCodeFromUri(uri) ??
            (normalizedPathSegments.length >= 2
                ? _parseCouponCode(normalizedPathSegments[1])
                : _parseCouponCode(
                    uri.queryParameters['giftCode'] ??
                        uri.queryParameters['gift_code'] ??
                        uri.queryParameters['couponCode'] ??
                        uri.queryParameters['coupon_code'] ??
                        uri.queryParameters['gift'] ??
                        uri.queryParameters['code'],
                  ));
        if (couponCode != null) {
          return DeepLinkTarget(
            type: DeepLinkContentType.gift,
            couponCode: couponCode,
          );
        }
      } else {
        final pathId = normalizedPathSegments.length >= 2
            ? _parsePositiveInt(normalizedPathSegments[1])
            : null;
        if (pathType != null && pathId != null) {
          return DeepLinkTarget(type: pathType, id: pathId);
        }
      }

      final queryType = _typeFromString(uri.queryParameters['type']);
      final queryId = _parsePositiveInt(uri.queryParameters['id']);

      if (queryType == DeepLinkContentType.register) {
        final referralCode = ReferralService.extractCodeFromUri(uri);
        return DeepLinkTarget(
          type: DeepLinkContentType.register,
          referralCode: referralCode,
        );
      } else if (queryType == DeepLinkContentType.gift) {
        final couponCode = GiftDeepLinkService.extractGiftCodeFromUri(uri) ??
            _parseCouponCode(
              uri.queryParameters['giftCode'] ??
                  uri.queryParameters['gift_code'] ??
                  uri.queryParameters['couponCode'] ??
                  uri.queryParameters['coupon_code'] ??
                  uri.queryParameters['gift'] ??
                  uri.queryParameters['code'],
            );
        if (couponCode != null) {
          return DeepLinkTarget(
            type: DeepLinkContentType.gift,
            couponCode: couponCode,
          );
        }
      } else if (queryType != null && queryId != null) {
        return DeepLinkTarget(type: queryType, id: queryId);
      }
    }

    return null;
  }

  Future<bool> handleUri(
    Uri? uri, {
    String source = 'external',
  }) {
    return _handleIncomingUri(uri, source: source);
  }

  Future<bool> handleUriString(
    String? rawValue, {
    String source = 'external',
  }) async {
    final uri = _uriFromText(rawValue);
    if (uri == null) return false;
    return _handleIncomingUri(uri, source: source);
  }

  bool _isSupportedHttpHost(String rawHost) {
    final host = rawHost.trim().toLowerCase();
    return host == 'filmytell.com' ||
        host == 'www.filmytell.com' ||
        host == 'filmytell.in' ||
        host == 'www.filmytell.in' ||
        host.endsWith('.filmytell.com') ||
        host.endsWith('.filmytell.in');
  }

  List<String> _normalizePathSegments(List<String> pathSegments) {
    var segments = pathSegments;
    if (segments.isNotEmpty && segments.first.toLowerCase() == ottPathPrefix) {
      segments = segments.sublist(1);
    }
    // Backward compatibility: strip 'share' prefix if present (e.g. /share/movie/123 -> /movie/123)
    if (segments.isNotEmpty && segments.first.toLowerCase() == 'share') {
      segments = segments.sublist(1);
    }
    return segments;
  }

  List<String> _httpPathSegments(Uri uri) {
    final pathSegments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    if (pathSegments.isNotEmpty) return pathSegments;

    final fragment = uri.fragment.trim();
    if (fragment.isEmpty) return const <String>[];

    final effectiveHost = uri.host.isNotEmpty ? uri.host : httpsHost;
    final fragmentUri = Uri.tryParse(fragment.startsWith('/')
        ? 'https://$effectiveHost$fragment'
        : 'https://$effectiveHost/$fragment');
    return fragmentUri?.pathSegments
            .where((segment) => segment.trim().isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
  }

  Future<void> savePendingDeepLinkTarget(DeepLinkTarget target) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        SharedPreferencesConstant.pendingDeepLinkUri,
        jsonEncode(target.toJson()),
      );
      developer.log(
        'Persisted pending deep link target: $target',
        name: 'DeepLinkService',
      );
    } catch (e) {
      developer.log(
        'Failed to persist deep link target: $e',
        name: 'DeepLinkService',
      );
    }
  }

  Future<DeepLinkTarget?> getPendingDeepLinkTarget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(SharedPreferencesConstant.pendingDeepLinkUri);
      if (raw == null || raw.trim().isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return DeepLinkTarget.fromJson(map);
    } catch (e) {
      developer.log(
        'Failed to read persisted deep link target: $e',
        name: 'DeepLinkService',
      );
      return null;
    }
  }

  Future<void> clearPendingDeepLinkTarget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(SharedPreferencesConstant.pendingDeepLinkUri);
      developer.log(
        'Cleared persisted pending deep link target',
        name: 'DeepLinkService',
      );
    } catch (e) {
      developer.log(
        'Failed to clear persisted deep link target: $e',
        name: 'DeepLinkService',
      );
    }
  }

  /// Extracts a deep link target from arbitrary strings (e.g. Android Install Referrer
  /// query strings, iOS clipboard, or full universal URLs).
  DeepLinkTarget? extractTargetFromString(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // 1. Try parsing direct URI
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.hasScheme || uri.pathSegments.isNotEmpty)) {
      final target = parseTarget(uri);
      if (target != null) return target;
    }

    // 2. Parse query parameters or referrer payload
    String toParse = trimmed;
    if (toParse.startsWith('?') || toParse.startsWith('#')) {
      toParse = toParse.substring(1);
    }

    try {
      final decodedQuery = Uri.decodeQueryComponent(toParse);
      final queryParams = Uri.splitQueryString(decodedQuery);

      if (queryParams.containsKey('url')) {
        final nestedUrl = queryParams['url'];
        if (nestedUrl != null && nestedUrl.isNotEmpty) {
          final parsedNested = Uri.tryParse(nestedUrl.trim());
          if (parsedNested != null) {
            final target = parseTarget(parsedNested);
            if (target != null) return target;
          }
        }
      }

      final rawType = queryParams['content_type'] ?? queryParams['type'];
      final rawId = queryParams['content_id'] ?? queryParams['id'];
      final type = _typeFromString(rawType);
      final id = _parsePositiveInt(rawId);
      if (type != null && id != null) {
        return DeepLinkTarget(type: type, id: id);
      }

      final giftCode = queryParams['gift_code'] ??
          queryParams['giftCode'] ??
          queryParams['couponCode'] ??
          queryParams['coupon_code'];
      if (giftCode != null && GiftDeepLinkService.isValidGiftCode(giftCode)) {
        return DeepLinkTarget(
          type: DeepLinkContentType.gift,
          couponCode: giftCode.trim().toUpperCase(),
        );
      }

      final referralCode = queryParams['referralCode'] ??
          queryParams['referral_code'] ??
          queryParams['ref'];
      if (referralCode != null && ReferralService.isValidCode(referralCode)) {
        return DeepLinkTarget(
          type: DeepLinkContentType.register,
          referralCode: referralCode.trim(),
        );
      }
    } catch (_) {}

    return null;
  }

  /// Checks for deferred content install deep links on first launch after installation.
  /// On Android: Queries the Google Play Install Referrer API.
  /// On iOS: Checks clipboard for universal URL or deep link scheme.
  Future<DeepLinkTarget?> checkDeferredContentInstall() async {
    if (kIsWeb) {
      return getPendingDeepLinkTarget();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasChecked = prefs.getBool(
            SharedPreferencesConstant.hasCheckedDeferredContentInstall,
          ) ??
          false;

      final existingTarget = await getPendingDeepLinkTarget();
      if (existingTarget != null) {
        _pendingTarget = existingTarget;
        return existingTarget;
      }

      if (hasChecked) {
        return null;
      }

      await prefs.setBool(
        SharedPreferencesConstant.hasCheckedDeferredContentInstall,
        true,
      );

      // Android: query Google Play Install Referrer API
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          final String? rawReferrer = await _installReferrerChannel
              .invokeMethod<String>('getInstallReferrer');
          developer.log(
            'Raw Android Install Referrer for Content: ${rawReferrer ?? 'none'}',
            name: 'DeepLinkService',
          );
          if (rawReferrer != null && rawReferrer.trim().isNotEmpty) {
            final target = extractTargetFromString(rawReferrer);
            if (target != null) {
              await savePendingDeepLinkTarget(target);
              _pendingTarget = target;
              developer.log(
                'Recovered deferred deep link target from Play Store: $target',
                name: 'DeepLinkService',
              );
              return target;
            }
          }
        } catch (e) {
          developer.log(
            'Failed to read Android install referrer for content: $e',
            name: 'DeepLinkService',
          );
        }
      }

      // iOS: check clipboard for deferred content link on first launch
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
          final text = clipboardData?.text?.trim();
          if (text != null && text.isNotEmpty) {
            final target = extractTargetFromString(text);
            if (target != null) {
              await savePendingDeepLinkTarget(target);
              _pendingTarget = target;
              developer.log(
                'Recovered deferred deep link target on iOS first launch: $target',
                name: 'DeepLinkService',
              );
              return target;
            }
          }
        } catch (e) {
          developer.log(
            'Failed to check iOS clipboard for deferred content link: $e',
            name: 'DeepLinkService',
          );
        }
      }
    } catch (error) {
      developer.log(
        'Error during deferred content install check: $error',
        name: 'DeepLinkService',
      );
    }

    return getPendingDeepLinkTarget();
  }

  Future<void> consumePendingNavigation() async {
    var target = _pendingTarget;
    target ??= await getPendingDeepLinkTarget();
    if (target == null) {
      return;
    }

    _pendingTarget = null;
    await _navigateToTarget(target, source: 'pending_navigation');
  }

  Future<void> dispose() async {
    await _linkSubscription?.cancel();
    _linkSubscription = null;
    _isInitialized = false;
  }

  Future<bool> _handleIncomingUri(Uri? uri, {required String source}) async {
    if (uri == null) {
      return false;
    }

    final now = DateTime.now();
    if (_lastProcessedUri == uri &&
        _lastProcessedTime != null &&
        now.difference(_lastProcessedTime!).inMilliseconds < 1500) {
      developer.log(
        'Duplicate URI event detected within 1500ms, skipping duplicate processing: $uri',
        name: 'DeepLinkService',
      );
      return true;
    }
    _lastProcessedUri = uri;
    _lastProcessedTime = now;

    final capturedReferralCode =
        await ReferralService.instance.captureFromUri(uri);
    final capturedGiftCode =
        await GiftDeepLinkService.instance.captureFromUri(uri);
    final target = parseTarget(uri);
    developer.log(
      'Deep Link Received: $uri source=$source referralCode=${capturedReferralCode ?? 'none'} giftCode=${capturedGiftCode ?? 'none'}',
      name: 'DeepLinkService',
    );
    developer.log(
      'Route Matched: ${target?.typeName ?? 'unknown'}',
      name: 'DeepLinkService',
    );
    developer.log(
      'Extracted id: ${target?.id ?? 'invalid'}',
      name: 'DeepLinkService',
    );
    developer.log(
      'Gift Code Extracted: ${target?.couponCode ?? 'none'}',
      name: 'DeepLinkService',
    );

    if (target?.type == DeepLinkContentType.gift && target?.couponCode != null) {
      final coupon = target!.couponCode!;
      if (await GiftDeepLinkService.instance.isGiftCodeClaimed(coupon)) {
        developer.log(
          'Gift deep link code $coupon is already claimed. Skipping duplicate presentation.',
          name: 'DeepLinkService',
        );
        await GiftDeepLinkService.instance.clearPendingGiftCode();
        return false;
      }

      if (source == 'initial_uri' &&
          await GiftDeepLinkService.instance.isGiftUriProcessed(uri)) {
        developer.log(
          'Gift deep link URI $uri was already processed on a previous launch. Skipping duplicate launch trigger.',
          name: 'DeepLinkService',
        );
        return false;
      }

      await GiftDeepLinkService.instance.markGiftUriProcessed(uri);
    }

    if (target == null) {
      if (capturedReferralCode != null) {
        developer.log(
          'Captured referral code $capturedReferralCode from non-target deep link',
          name: 'DeepLinkService',
        );
        return true;
      }
      developer.log(
        'Ignoring unsupported deep link',
        name: 'DeepLinkService',
        level: 900,
      );
      return false;
    }

    await savePendingDeepLinkTarget(target);

    if (source == 'initial_uri') {
      _pendingTarget = target;
      developer.log(
        'Navigation Triggered: queued ${target.typeName} from initial launch',
        name: 'DeepLinkService',
      );
      return true;
    }

    await _navigateToTarget(target, source: source);
    return true;
  }

  Future<void> _navigateToTarget(
    DeepLinkTarget target, {
    required String source,
  }) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _pendingTarget = target;
      await savePendingDeepLinkTarget(target);
      developer.log(
        'Navigator unavailable. Queued ${target.typeName} deep link',
        name: 'DeepLinkService',
      );
      return;
    }

    final now = DateTime.now();
    if (_lastProcessedTarget == target &&
        _lastTargetTime != null &&
        now.difference(_lastTargetTime!).inMilliseconds < 1500) {
      developer.log(
        'Duplicate target navigation suppressed within 1500ms: $target',
        name: 'DeepLinkService',
      );
      return;
    }
    _lastProcessedTarget = target;
    _lastTargetTime = now;

    developer.log(
      'Navigation Triggered: ${target.typeName} id=${target.id} source=$source',
      name: 'DeepLinkService',
    );

    switch (target.type) {
      case DeepLinkContentType.movie:
        await _openMovieDetails(
          navigator,
          target.id!,
          source: source,
          contentType: 'MOVIE',
        );
        await clearPendingDeepLinkTarget();
        return;
      case DeepLinkContentType.shortFilm:
        await _openMovieDetails(
          navigator,
          target.id!,
          source: source,
          contentType: 'SHORT_FILM',
        );
        await clearPendingDeepLinkTarget();
        return;
      case DeepLinkContentType.series:
        await _openSeriesDetails(navigator, target.id!);
        await clearPendingDeepLinkTarget();
        return;
      case DeepLinkContentType.miniSeries:
      case DeepLinkContentType.short:
        await _openShortDetails(navigator, target.id!);
        await clearPendingDeepLinkTarget();
        return;
      case DeepLinkContentType.gift:
        await _openGiftClaimDialog(navigator, target.couponCode!);
        await clearPendingDeepLinkTarget();
        return;
      case DeepLinkContentType.register:
        await _openRegistration(
          navigator,
          target.referralCode,
          source: source,
        );
        await clearPendingDeepLinkTarget();
        return;
    }
  }

  Future<void> _openRegistration(
    NavigatorState navigator,
    String? referralCode, {
    required String source,
  }) async {
    developer.log(
      'Navigation Triggered: opening registration for referralCode=$referralCode source=$source',
      name: 'DeepLinkService',
    );
    if (referralCode != null && ReferralService.isValidCode(referralCode)) {
      await ReferralService.instance.saveReferralCode(referralCode);
    }
    navigator.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.login),
        builder: (_) => LoginCard(
          initialReferralCode: referralCode,
          isReferralFlow: true,
        ),
      ),
    );
  }

  Future<void> _openGiftClaimDialog(
    NavigatorState navigator,
    String couponCode,
  ) async {
    developer.log(
      'Navigation Triggered: opening gift claim for code=$couponCode',
      name: 'DeepLinkService',
    );
    if (await GiftDeepLinkService.instance.isGiftCodeClaimed(couponCode)) {
      developer.log(
        'Gift code $couponCode is already claimed. Skipping dialog presentation.',
        name: 'DeepLinkService',
      );
      await GiftDeepLinkService.instance.clearPendingGiftCode();
      return;
    }
    if (!navigator.mounted) return;
    await GiftDeepLinkService.instance.showGiftDialogForCode(
      navigator.context,
      couponCode,
    );
  }

  Future<void> _openMovieDetails(
    NavigatorState navigator,
    int movieId, {
    required String source,
    required String contentType,
  }) async {
    final dashboardProvider =
        Provider.of<DashboardProvider>(navigator.context, listen: false);
    await dashboardProvider.getContentById(movieId);
    final content = dashboardProvider.content;

    if (content.id == null || content.id! <= 0) {
      developer.log(
        'Movie content could not be loaded for id=$movieId',
        name: 'DeepLinkService',
        level: 900,
      );
      if (navigator.mounted) {
        CustomToast.show(
          navigator.context,
          'Movie details are not available or have been removed',
          isSuccess: false,
        );
      }
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: AppRoutes.movieDetails,
          arguments: MovieDetailsRouteArgs(
            movieId: movieId,
            source: source,
            contentType: contentType,
          ),
        ),
        builder: (_) => MovieDetailsPage(
          movieId: movieId,
          contentType: contentType,
        ),
      ),
    );
  }

  Future<void> _openSeriesDetails(
    NavigatorState navigator,
    int seriesId,
  ) async {
    final dashboardProvider =
        Provider.of<DashboardProvider>(navigator.context, listen: false);
    await dashboardProvider.getContentById(seriesId);
    final content = dashboardProvider.content;

    if (content.id == null || content.id! <= 0) {
      developer.log(
        'Series content could not be loaded for id=$seriesId',
        name: 'DeepLinkService',
        level: 900,
      );
      if (navigator.mounted) {
        CustomToast.show(
          navigator.context,
          'Series details are not available or have been removed',
          isSuccess: false,
        );
      }
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: AppRoutes.seriesDetails,
          arguments: <String, dynamic>{'id': seriesId},
        ),
        builder: (_) => SeriesDetailsPage(
          seriesId: seriesId,
          content: content,
        ),
      ),
    );
  }

  Future<void> _openShortDetails(
    NavigatorState navigator,
    int shortId,
  ) async {
    final shortProvider =
        Provider.of<ShortProvider>(navigator.context, listen: false);
    await shortProvider.fetchShortDetail(shortId, 1);
    final ShortDetailModel? detail = shortProvider.shortDetail;

    if (detail == null || detail.id <= 0) {
      developer.log(
        'Short content could not be loaded for id=$shortId',
        name: 'DeepLinkService',
        level: 900,
      );
      if (navigator.mounted) {
        CustomToast.show(
          navigator.context,
          'Content details are not available or have been removed',
          isSuccess: false,
        );
      }
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: AppRoutes.shortDetails,
          arguments: <String, dynamic>{'id': shortId},
        ),
        builder: (_) => ShortsPlayerPage(short: detail),
      ),
    );
  }

  DeepLinkContentType? _typeFromString(String? rawType) {
    switch ((rawType ?? '').trim().toLowerCase()) {
      case movieHost:
      case 'movies':
        return DeepLinkContentType.movie;
      case shortFilmHost:
      case 'short_film':
      case 'shortfilm':
      case 'shortfilms':
      case 'short-films':
        return DeepLinkContentType.shortFilm;
      case seriesHost:
        return DeepLinkContentType.series;
      case miniseriesHost:
      case 'mini-series':
      case 'mini_series':
        return DeepLinkContentType.miniSeries;
      case shortHost:
      case 'shorts':
        return DeepLinkContentType.short;
      case giftHost:
      case 'gifts':
        return DeepLinkContentType.gift;
      case registerHost:
      case loginHost:
      case 'signup':
      case 'sign-up':
      case 'signin':
      case 'sign-in':
        return DeepLinkContentType.register;
      default:
        return null;
    }
  }

  String _hostForType(DeepLinkContentType type) {
    switch (type) {
      case DeepLinkContentType.movie:
        return movieHost;
      case DeepLinkContentType.shortFilm:
        return shortFilmHost;
      case DeepLinkContentType.series:
        return seriesHost;
      case DeepLinkContentType.miniSeries:
        return miniseriesHost;
      case DeepLinkContentType.short:
        return shortHost;
      case DeepLinkContentType.gift:
        return giftHost;
      case DeepLinkContentType.register:
        return registerHost;
    }
  }

  int? _parsePositiveInt(String? rawValue) {
    final value = int.tryParse((rawValue ?? '').trim());
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  String? _parseCouponCode(String? rawValue) {
    final value = (rawValue ?? '').trim().replaceAll(' ', '').toUpperCase();
    if (value.isEmpty) {
      return null;
    }
    return value;
  }

  Uri? _uriFromText(String? rawValue) {
    final value = (rawValue ?? '').trim();
    if (value.isEmpty) return null;

    final directUri = Uri.tryParse(value);
    if (directUri != null &&
        (directUri.hasScheme || directUri.pathSegments.isNotEmpty)) {
      if (directUri.hasScheme) return directUri;
      if (directUri.path.startsWith('/')) {
        return Uri.https(httpsHost, directUri.path, directUri.queryParameters);
      }
    }

    final urlMatch = RegExp(
      r"""(https?:\/\/[^\s<>"']+|myapp:\/\/[^\s<>"']+)""",
      caseSensitive: false,
    ).firstMatch(value);
    if (urlMatch != null) {
      final url = _trimTrailingPunctuation(urlMatch.group(0)!);
      return Uri.tryParse(url);
    }

    final couponMatch = RegExp(
      r'\bGF[A-Z0-9]{8,}\b',
      caseSensitive: false,
    ).firstMatch(value);
    if (couponMatch != null) {
      return buildGiftAppLink(couponMatch.group(0)!);
    }

    return null;
  }

  String _trimTrailingPunctuation(String value) {
    return value.replaceFirst(RegExp(r'[),.;:!?]+$'), '');
  }

  bool _isExpiredLink(Uri uri) {
    final raw = uri.queryParameters['expires'] ??
        uri.queryParameters['expiry'] ??
        uri.queryParameters['expiresAt'] ??
        uri.queryParameters['exp'];
    if (raw == null || raw.trim().isEmpty) return false;

    final numeric = int.tryParse(raw);
    DateTime? expiry;
    if (numeric != null) {
      expiry = numeric > 100000000000
          ? DateTime.fromMillisecondsSinceEpoch(numeric, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(numeric * 1000, isUtc: true);
    } else {
      expiry = DateTime.tryParse(raw)?.toUtc();
    }

    return expiry != null && DateTime.now().toUtc().isAfter(expiry);
  }

  void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'DeepLinkService',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}
