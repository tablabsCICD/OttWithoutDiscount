import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constant/prefrense_constant.dart';

class ReferralService {
  ReferralService._();

  static final ReferralService instance = ReferralService._();

  static const MethodChannel _installReferrerChannel =
      MethodChannel('com.filmytell.ott/install_referrer');

  /// Builds a referral URL. Canonical domain is filmytell.com.
  static String buildReferralUrl(String referralCode, {bool useCanonical = true}) {
    final host = useCanonical ? 'filmytell.com' : 'filmytell.in';
    return 'https://$host/register?referralCode=${Uri.encodeComponent(referralCode.trim())}';
  }

  static bool isValidCode(String? rawCode) {
    if (rawCode == null) return false;
    final trimmed = rawCode.trim();
    if (trimmed.isEmpty) return false;

    final lower = trimmed.toLowerCase();
    if (lower == '{referralcode}' ||
        lower == '{referral_code}' ||
        lower == '{code}' ||
        lower == 'undefined' ||
        lower == 'null' ||
        lower == 'none') {
      return false;
    }

    return trimmed.length >= 2 && trimmed.length <= 64;
  }

  static String? extractCodeFromString(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Check direct code match
    if (!trimmed.contains('=') &&
        !trimmed.contains('/') &&
        !trimmed.contains('&') &&
        !trimmed.contains('?')) {
      return isValidCode(trimmed) ? trimmed : null;
    }

    // Try parsing as URI
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      final code = extractCodeFromUri(uri);
      if (code != null) return code;
    }

    // Parse query/referrer string like "referralCode=FILMY-XX-60E7&utm_source=google"
    String toParse = trimmed;
    if (toParse.startsWith('?') || toParse.startsWith('#')) {
      toParse = toParse.substring(1);
    }

    try {
      final decodedQuery = Uri.decodeQueryComponent(toParse);
      final queryParams = Uri.splitQueryString(decodedQuery);
      for (final entry in queryParams.entries) {
        final keyLower = entry.key.trim().toLowerCase();
        if (keyLower == 'referralcode' ||
            keyLower == 'referral_code' ||
            keyLower == 'ref' ||
            keyLower == 'code') {
          final val = entry.value.trim();
          if (isValidCode(val)) return val;
        }
      }
    } catch (_) {}

    // Fallback regex match for referralCode=XXXX
    final match = RegExp(
      r'(?:referralCode|referral_code|ref|code)=([^&;\s]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (match != null) {
      final captured = Uri.decodeComponent(match.group(1) ?? '').trim();
      if (isValidCode(captured)) return captured;
    }

    return null;
  }

  static String? extractCodeFromUri(Uri? uri) {
    if (uri == null) return null;

    final queryParams = uri.queryParameters;
    String? rawValue;

    for (final entry in queryParams.entries) {
      final keyLower = entry.key.trim().toLowerCase();
      if (keyLower == 'referralcode' ||
          keyLower == 'referral_code' ||
          keyLower == 'ref') {
        rawValue = entry.value;
        break;
      }
    }

    // Check nested referrer parameter e.g. ?referrer=referralCode%3DFILMY-XX-60E7
    if (rawValue == null && queryParams.containsKey('referrer')) {
      final referrerValue = queryParams['referrer'];
      final extracted = extractCodeFromString(referrerValue);
      if (extracted != null) return extracted;
    }

    if (rawValue == null &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments.last.toLowerCase() == 'register') {
      rawValue = queryParams['code'];
    }

    // Check fragment query if present
    if (rawValue == null && uri.fragment.isNotEmpty) {
      final fragmentUri = Uri.tryParse(
        uri.fragment.startsWith('/')
            ? 'https://filmytell.com${uri.fragment}'
            : 'https://filmytell.com/${uri.fragment}',
      );
      if (fragmentUri != null) {
        final fromFragment = extractCodeFromUri(fragmentUri);
        if (fromFragment != null) return fromFragment;
      }
    }

    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = Uri.decodeComponent(rawValue).trim();
      return isValidCode(decoded) ? decoded : null;
    } catch (_) {
      final trimmed = rawValue.trim();
      return isValidCode(trimmed) ? trimmed : null;
    }
  }

  Future<String?> captureFromUri(Uri? uri) async {
    final code = extractCodeFromUri(uri);
    if (code != null) {
      await saveReferralCode(code);
      developer.log(
        'Captured valid referral code from URL: $code',
        name: 'ReferralService',
      );
      return code;
    }
    return getPendingReferralCode();
  }

  Future<String?> checkDeferredInstallReferrer() async {
    if (kIsWeb) {
      return getPendingReferralCode();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasChecked = prefs.getBool(
            SharedPreferencesConstant.hasCheckedDeferredInstallReferrer,
          ) ??
          false;

      // Existing pending code takes precedence if already set
      final existingCode = await getPendingReferralCode();
      if (existingCode != null) {
        return existingCode;
      }

      if (hasChecked) {
        return null;
      }

      await prefs.setBool(
        SharedPreferencesConstant.hasCheckedDeferredInstallReferrer,
        true,
      );

      // Android: query Google Play Install Referrer API
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          final String? rawReferrer = await _installReferrerChannel
              .invokeMethod<String>('getInstallReferrer');
          developer.log(
            'Raw Android Install Referrer: ${rawReferrer ?? 'none'}',
            name: 'ReferralService',
          );
          if (rawReferrer != null && rawReferrer.trim().isNotEmpty) {
            final code = extractCodeFromString(rawReferrer);
            if (code != null) {
              await saveReferralCode(code);
              developer.log(
                'Recovered deferred referral code from Play Store: $code',
                name: 'ReferralService',
              );
              return code;
            }
          }
        } catch (e) {
          developer.log(
            'Failed to read Android install referrer: $e',
            name: 'ReferralService',
          );
        }
      }

      // iOS: check clipboard for deferred referral code on first install launch
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
          final text = clipboardData?.text?.trim();
          if (text != null && text.isNotEmpty) {
            final code = extractCodeFromString(text);
            if (code != null) {
              await saveReferralCode(code);
              developer.log(
                'Recovered deferred referral code on iOS first launch: $code',
                name: 'ReferralService',
              );
              return code;
            }
          }
        } catch (e) {
          developer.log(
            'Failed to check iOS clipboard for referral code: $e',
            name: 'ReferralService',
          );
        }
      }
    } catch (error) {
      developer.log(
        'Error during deferred install referrer check: $error',
        name: 'ReferralService',
      );
    }

    return getPendingReferralCode();
  }

  Future<void> saveReferralCode(String code) async {
    if (!isValidCode(code)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SharedPreferencesConstant.pendingReferralCode,
      code.trim(),
    );
    developer.log(
      'Saved pending referral code: ${code.trim()}',
      name: 'ReferralService',
    );
  }

  Future<String?> getPendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(SharedPreferencesConstant.pendingReferralCode);
    if (isValidCode(raw)) {
      return raw!.trim();
    }
    return null;
  }

  Future<void> clearReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPreferencesConstant.pendingReferralCode);
    developer.log(
      'Cleared pending referral code',
      name: 'ReferralService',
    );
  }
}
