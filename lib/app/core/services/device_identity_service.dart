import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ott/app/core/constant/prefrense_constant.dart';
import 'package:ott/app/core/services/device_runtime.dart';
import 'package:ott/app/core/utils/security_debug_log.dart';
import 'package:ott/data/models/anti_piracy_models.dart';

abstract class DeviceIdStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureDeviceIdStore implements DeviceIdStore {
  SecureDeviceIdStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(resetOnError: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  static const _key = 'anti_piracy_installation_device_id';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      final val = await _storage
          .read(key: _key)
          .timeout(const Duration(milliseconds: 1000));
      if (val != null && val.isNotEmpty) return val;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String value) async {
    try {
      await _storage
          .write(key: _key, value: value)
          .timeout(const Duration(milliseconds: 1000));
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value);
    } catch (_) {}
  }
}

class DeviceIdentityService {
  DeviceIdentityService({
    DeviceIdStore? store,
    Future<Map<String, dynamic>?> Function()? platformInfoLoader,
    String Function()? idGenerator,
  })  : _store = store ?? SecureDeviceIdStore(),
        _platformInfoLoader = platformInfoLoader ?? _loadPlatformInfo,
        _idGenerator = idGenerator ?? _generateUuidV4;

  static final DeviceIdentityService instance = DeviceIdentityService();
  static const MethodChannel _channel =
      MethodChannel('com.filmytell.ott/anti_piracy');

  final DeviceIdStore _store;
  final Future<Map<String, dynamic>?> Function() _platformInfoLoader;
  final String Function() _idGenerator;
  Future<DeviceIdentity>? _identityRequest;

  Future<DeviceIdentity> getIdentity() {
    return _identityRequest ??= _createIdentity().whenComplete(() {
      _identityRequest = null;
    });
  }

  Future<DeviceIdentity> _createIdentity() async {
    final storedDeviceId = _normalizeDeviceId(await _store.read());
    final sessionDeviceId = _normalizeDeviceId(await _readLegacyDeviceId());
    final signedInUserDeviceId =
        _normalizeDeviceId(await _readSignedInUserDeviceId());
    final activeSessionDeviceId = signedInUserDeviceId ?? sessionDeviceId;

    late final String deviceId;
    if (activeSessionDeviceId != null) {
      // The JWT/login session is already bound to this installation ID.
      // Preserve it during migration so device registration and signed
      // playback send the same value that authenticated the user.
      deviceId = activeSessionDeviceId;
      if (storedDeviceId != deviceId) {
        await _store.write(deviceId);
      }
      if (sessionDeviceId != deviceId) {
        await _writeLegacyDeviceId(deviceId);
      }
      SecurityDebugLog.event(
        'DEVICE',
        'Using the canonical device ID from the authenticated installation session.',
      );
    } else if (storedDeviceId != null) {
      deviceId = storedDeviceId;
      await _writeLegacyDeviceId(deviceId);
      SecurityDebugLog.event(
        'DEVICE',
        'Using the canonical device ID from secure storage.',
      );
    } else {
      deviceId = _idGenerator();
      await _store.write(deviceId);
      await _writeLegacyDeviceId(deviceId);
      SecurityDebugLog.event(
        'DEVICE',
        'Created one canonical installation UUID for login and secure playback.',
      );
    }
    final selectedSource = signedInUserDeviceId != null
        ? 'loggedUser.deviceId'
        : sessionDeviceId != null
            ? 'sessionDeviceId'
            : storedDeviceId != null
                ? 'secureStorage'
                : 'newInstallationUuid';
    SecurityDebugLog.diagnostic(
      'DEVICE_ID_CHECK selectedSource=$selectedSource '
      'loggedUserPresent=${signedInUserDeviceId != null} '
      'loggedUserMatches=${signedInUserDeviceId == null || signedInUserDeviceId == deviceId} '
      'initialSessionMatched=${sessionDeviceId == null || sessionDeviceId == deviceId} '
      'initialSecureStorageMatched=${storedDeviceId == null || storedDeviceId == deviceId} '
      'synchronized=true',
    );

    final platformInfo = await _platformInfoLoader();
    final runtime = readDeviceRuntimeInfo();
    final type = _deviceType();
    return DeviceIdentity(
      deviceId: deviceId,
      deviceType: type,
      deviceName: _stringValue(
        platformInfo?['deviceName'],
        fallback: runtime.model,
      ),
      osVersion: _stringValue(
        platformInfo?['osVersion'],
        fallback: runtime.os,
      ),
    );
  }

  Future<String?> _readLegacyDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPreferencesConstant.sessionDeviceId)?.trim();
  }

  Future<void> _writeLegacyDeviceId(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPreferencesConstant.sessionDeviceId, value);
  }

  Future<String?> _readSignedInUserDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString(SharedPreferencesConstant.currentUser);
    if (rawUser == null || rawUser.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is! Map) return null;
      return decoded['deviceId']?.toString();
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _loadPlatformInfo() async {
    if (kIsWeb) return null;
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('deviceIdentity')
          .timeout(const Duration(milliseconds: 1000));
      return result == null ? null : Map<String, dynamic>.from(result);
    } catch (_) {
      return null;
    }
  }

  static String _deviceType() {
    if (kIsWeb) return 'WEB';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) return 'IOS';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'ANDROID';
    }
    return 'UNSUPPORTED';
  }

  static String _stringValue(dynamic value, {required String fallback}) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) return fallback;
    return normalized;
  }

  static String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  static bool _isUuid(String? value) {
    if (value == null) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  static String? _normalizeDeviceId(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    if (_isUuid(normalized)) return normalized;
    if (normalized.length < 8 || normalized.length > 256) return null;
    return RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(normalized)
        ? normalized
        : null;
  }
}
