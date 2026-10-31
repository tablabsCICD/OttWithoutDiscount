import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ott/app/core/constant/prefrense_constant.dart';
import 'package:ott/app/core/utils/sharepreferences.dart';
import 'package:ott/app/pages/sign%20in%20page/LoginCard.dart';
import 'package:ott/app/widgets/gift_claim_dialog.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized service handling gift deep links, deferred installation deep linking,
/// temporary gift persistence, authentication readiness, and gift claim popup display.
class GiftDeepLinkService {
  GiftDeepLinkService._();

  static final GiftDeepLinkService instance = GiftDeepLinkService._();

  static const String domain = 'filmytell.com';
  static const String altDomain = 'filmytell.in';
  static const String giftPath = 'gift';
  static const String scheme = 'myapp';

  /// Builds a gift deep link. Canonical domain is filmytell.com.
  static String buildGiftUrl(String couponCode, {bool useCanonical = true}) {
    final host = useCanonical ? domain : altDomain;
    return 'https://$host/gift/${couponCode.trim().toUpperCase()}';
  }

  static const MethodChannel _installReferrerChannel =
      MethodChannel('com.filmytell.ott/install_referrer');

  bool _isDialogShowing = false;
  String? _lastShownCode;
  DateTime? _lastShownTime;

  /// Validates whether [rawCode] adheres to the gift/coupon code format.
  /// Typically 16 uppercase alphanumeric characters (e.g., GF000843A767720E)
  /// or alphanumeric between 6 and 32 characters, excluding placeholders.
  static bool isValidGiftCode(String? rawCode) {
    if (rawCode == null) return false;
    final trimmed = rawCode.trim().replaceAll(' ', '');
    if (trimmed.isEmpty) return false;

    final lower = trimmed.toLowerCase();
    if (lower == '{giftcode}' ||
        lower == '{gift_code}' ||
        lower == '{couponcode}' ||
        lower == '{code}' ||
        lower == 'undefined' ||
        lower == 'null' ||
        lower == 'none' ||
        lower == 'invalid' ||
        lower == 'error') {
      return false;
    }

    // Must be alphanumeric with optional hyphen/underscore, length between 6 and 32
    final isAlphanumeric = RegExp(r'^[A-Za-z0-9_-]{6,32}$').hasMatch(trimmed);
    return isAlphanumeric;
  }

  /// Normalizes a gift coupon code (removes spaces, trims, and converts to uppercase).
  static String? normalizeGiftCode(String? rawCode) {
    if (rawCode == null) return null;
    final normalized = rawCode.trim().replaceAll(' ', '').toUpperCase();
    return isValidGiftCode(normalized) ? normalized : null;
  }

  /// Extracts a gift code from a [Uri], inspecting path segments, query parameters,
  /// nested referrer payloads, and fragments.
  static String? extractGiftCodeFromUri(Uri? uri) {
    if (uri == null) return null;

    final queryParams = uri.queryParameters;
    String? rawValue;

    final segments = uri.pathSegments
        .where((s) => s.trim().isNotEmpty)
        .toList(growable: false);

    // 1. Check custom scheme host: myapp://gift/{code}
    if ((uri.scheme == scheme || uri.scheme.isEmpty) &&
        (uri.host.toLowerCase() == giftPath ||
            uri.host.toLowerCase() == 'gifts')) {
      if (segments.isNotEmpty) {
        rawValue = segments.first;
      }
    }

    // 2. Check path segments: /gift/{giftCode}, /ott/gift/{giftCode}, /share/gift/{giftCode}
    if (rawValue == null || !isValidGiftCode(rawValue)) {
      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i].toLowerCase();
        if (segment == giftPath || segment == 'gifts') {
          if (i + 1 < segments.length) {
            rawValue = segments[i + 1];
            break;
          }
        }
      }
    }

    // 2. Check direct query parameters
    if (rawValue == null || !isValidGiftCode(rawValue)) {
      for (final entry in queryParams.entries) {
        final keyLower = entry.key.trim().toLowerCase();
        if (keyLower == 'giftcode' ||
            keyLower == 'gift_code' ||
            keyLower == 'couponcode' ||
            keyLower == 'coupon_code' ||
            keyLower == 'gift' ||
            keyLower == 'code') {
          rawValue = entry.value;
          break;
        }
      }
    }

    // 3. Check nested referrer parameter e.g. ?referrer=gift_code%3DGF000843A767720E
    if ((rawValue == null || !isValidGiftCode(rawValue)) &&
        queryParams.containsKey('referrer')) {
      final referrerValue = queryParams['referrer'];
      final extracted = extractGiftCodeFromString(referrerValue);
      if (extracted != null) return extracted;
    }

    // 4. Check fragment if present (e.g. /#/gift/GF000843A767720E)
    if ((rawValue == null || !isValidGiftCode(rawValue)) &&
        uri.fragment.isNotEmpty) {
      final fragmentUri = Uri.tryParse(
        uri.fragment.startsWith('/')
            ? 'https://$domain${uri.fragment}'
            : 'https://$domain/${uri.fragment}',
      );
      if (fragmentUri != null) {
        final fromFragment = extractGiftCodeFromUri(fragmentUri);
        if (fromFragment != null) return fromFragment;
      }
    }

    return normalizeGiftCode(rawValue);
  }

  /// Extracts a gift code from arbitrary text or referrer strings.
  static String? extractGiftCodeFromString(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Check direct code match first
    if (!trimmed.contains('=') &&
        !trimmed.contains('/') &&
        !trimmed.contains('&') &&
        !trimmed.contains('?')) {
      return normalizeGiftCode(trimmed);
    }

    // Try parsing as URI
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.hasScheme || uri.pathSegments.isNotEmpty)) {
      final code = extractGiftCodeFromUri(uri);
      if (code != null) return code;
    }

    // Try query string split (e.g. gift_code=GF000843A767720E&utm_source=play)
    String toParse = trimmed;
    if (toParse.startsWith('?') || toParse.startsWith('#')) {
      toParse = toParse.substring(1);
    }

    try {
      final decodedQuery = Uri.decodeQueryComponent(toParse);
      final queryParams = Uri.splitQueryString(decodedQuery);
      for (final entry in queryParams.entries) {
        final keyLower = entry.key.trim().toLowerCase();
        if (keyLower == 'gift_code' ||
            keyLower == 'giftcode' ||
            keyLower == 'couponcode' ||
            keyLower == 'coupon_code' ||
            keyLower == 'gift' ||
            keyLower == 'code') {
          final val = normalizeGiftCode(entry.value);
          if (val != null) return val;
        }
      }
    } catch (_) {}

    // Regex fallback for gift_code=XXXX or GF000843A767720E pattern
    final keyMatch = RegExp(
      r'(?:gift_code|giftCode|couponCode|coupon_code|gift|code)=([A-Za-z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (keyMatch != null) {
      final captured = Uri.decodeComponent(keyMatch.group(1) ?? '').trim();
      final normalized = normalizeGiftCode(captured);
      if (normalized != null) return normalized;
    }

    final codePatternMatch = RegExp(
      r'\bGF[A-Z0-9]{8,24}\b',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (codePatternMatch != null) {
      return normalizeGiftCode(codePatternMatch.group(0));
    }

    return null;
  }

  /// Captures a gift code from an incoming URI, persists it, and returns the code.
  Future<String?> captureFromUri(Uri? uri) async {
    final code = extractGiftCodeFromUri(uri);
    if (code != null) {
      await savePendingGiftCode(code);
      developer.log(
        'Captured valid gift code from URI: $code',
        name: 'GiftDeepLinkService',
      );
      return code;
    }
    return getPendingGiftCode();
  }

  /// Persists a pending gift code to [SharedPreferences].
  Future<void> savePendingGiftCode(String code) async {
    final normalized = normalizeGiftCode(code);
    if (normalized == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        SharedPreferencesConstant.pendingGiftCode,
        normalized,
      );
      developer.log(
        'Persisted pending gift code: $normalized',
        name: 'GiftDeepLinkService',
      );
    } catch (e) {
      developer.log(
        'Failed to save pending gift code: $e',
        name: 'GiftDeepLinkService',
      );
    }
  }

  /// Retrieves the currently pending gift code from [SharedPreferences], if any.
  Future<String?> getPendingGiftCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(SharedPreferencesConstant.pendingGiftCode);
      return normalizeGiftCode(raw);
    } catch (e) {
      developer.log(
        'Failed to get pending gift code: $e',
        name: 'GiftDeepLinkService',
      );
      return null;
    }
  }

  /// Clears the pending gift code from [SharedPreferences].
  Future<void> clearPendingGiftCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(SharedPreferencesConstant.pendingGiftCode);
      developer.log(
        'Cleared pending gift code',
        name: 'GiftDeepLinkService',
      );
    } catch (e) {
      developer.log(
        'Failed to clear pending gift code: $e',
        name: 'GiftDeepLinkService',
      );
    }
  }

  /// Checks for deferred install deep links on cold start / first launch.
  /// On Android: Queries Google Play Install Referrer API.
  /// On iOS: Checks clipboard for gift URL or code (copied via web fallback flow).
  Future<String?> checkDeferredGiftInstall() async {
    if (kIsWeb) {
      return getPendingGiftCode();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasChecked = prefs.getBool(
            SharedPreferencesConstant.hasCheckedDeferredGiftInstall,
          ) ??
          false;

      // Existing pending code takes precedence if already set
      final existingCode = await getPendingGiftCode();
      if (existingCode != null) {
        return existingCode;
      }

      if (hasChecked) {
        return null;
      }

      await prefs.setBool(
        SharedPreferencesConstant.hasCheckedDeferredGiftInstall,
        true,
      );

      // Android: query Google Play Install Referrer API
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          final String? rawReferrer = await _installReferrerChannel
              .invokeMethod<String>('getInstallReferrer');
          developer.log(
            'Raw Android Install Referrer for Gift: ${rawReferrer ?? 'none'}',
            name: 'GiftDeepLinkService',
          );
          if (rawReferrer != null && rawReferrer.trim().isNotEmpty) {
            final code = extractGiftCodeFromString(rawReferrer);
            if (code != null) {
              await savePendingGiftCode(code);
              developer.log(
                'Recovered deferred gift code from Play Store: $code',
                name: 'GiftDeepLinkService',
              );
              return code;
            }
          }
        } catch (e) {
          developer.log(
            'Failed to read Android install referrer for gift: $e',
            name: 'GiftDeepLinkService',
          );
        }
      }

      // iOS: check clipboard for deferred gift code/link on first install launch
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
          final text = clipboardData?.text?.trim();
          if (text != null && text.isNotEmpty) {
            final code = extractGiftCodeFromString(text);
            if (code != null) {
              await savePendingGiftCode(code);
              developer.log(
                'Recovered deferred gift code on iOS first launch: $code',
                name: 'GiftDeepLinkService',
              );
              return code;
            }
          }
        } catch (e) {
          developer.log(
            'Failed to check iOS clipboard for gift code: $e',
            name: 'GiftDeepLinkService',
          );
        }
      }
    } catch (error) {
      developer.log(
        'Error during deferred gift install check: $error',
        name: 'GiftDeepLinkService',
      );
    }

    return getPendingGiftCode();
  }

  /// Checks if there is a pending gift code and navigation/auth is ready,
  /// then displays the existing gift popup.
  Future<bool> checkAndProcessPendingGift(BuildContext context) async {
    final pendingCode = await getPendingGiftCode();
    if (pendingCode == null) return false;
    if (!context.mounted) return false;

    return showGiftDialogForCode(context, pendingCode);
  }

  /// Displays the existing gift claim popup for [couponCode].
  /// Ensures:
  /// 1. Dialog is not duplicated if already showing or recently shown.
  /// 2. User authentication status is checked:
  ///    - If authenticated: opens [showGiftClaimDialog].
  ///    - If unauthenticated: preserves code and navigates to [LoginCard].
  /// 3. Upon successful redemption, clears [pendingGiftCode].
  Future<bool> showGiftDialogForCode(
    BuildContext context,
    String couponCode,
  ) async {
    final normalized = normalizeGiftCode(couponCode);
    if (normalized == null) return false;

    // Prevent duplicate display
    if (_isDialogShowing) {
      developer.log(
        'Gift dialog already visible, skipping duplicate request',
        name: 'GiftDeepLinkService',
      );
      return false;
    }

    final now = DateTime.now();
    if (_lastShownCode == normalized &&
        _lastShownTime != null &&
        now.difference(_lastShownTime!).inSeconds < 4) {
      developer.log(
        'Gift dialog recently presented for code=$normalized, skipping duplicate',
        name: 'GiftDeepLinkService',
      );
      return false;
    }

    // Check user authentication
    final isLoggedIn =
        await LocalSharePreferences.localSharePreferences.getBool(
      SharedPreferencesConstant.isUserLoggedIn,
    );

    if (!isLoggedIn) {
      developer.log(
        'User not logged in. Preserving pending gift code $normalized and directing to login.',
        name: 'GiftDeepLinkService',
      );
      await savePendingGiftCode(normalized);

      if (context.mounted) {
        CustomToast.show(
          context,
          'Please sign in to claim your gift ($normalized)',
          isSuccess: true,
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginCard()),
        );
      }
      return false;
    }

    if (!context.mounted) return false;

    _isDialogShowing = true;
    _lastShownCode = normalized;
    _lastShownTime = DateTime.now();

    try {
      developer.log(
        'Opening gift claim dialog for code: $normalized',
        name: 'GiftDeepLinkService',
      );

      final result = await showGiftClaimDialog(
        context,
        initialCouponCode: normalized,
      );

      // If user successfully claimed the gift, clear the pending code
      if (result == true) {
        developer.log(
          'Gift claimed successfully for code $normalized. Clearing pending state.',
          name: 'GiftDeepLinkService',
        );
        await clearPendingGiftCode();
        return true;
      }

      return false;
    } finally {
      _isDialogShowing = false;
    }
  }
}
