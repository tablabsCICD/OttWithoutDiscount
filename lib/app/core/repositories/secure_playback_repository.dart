import 'dart:async';

import 'package:ott/app/core/network/anti_piracy_api_client.dart';
import 'package:ott/app/core/services/device_identity_service.dart';
import 'package:ott/app/core/services/device_integrity_service.dart';
import 'package:ott/app/core/utils/security_debug_log.dart';
import 'package:ott/app/core/utils/sharepreferences.dart';
import 'package:ott/data/models/anti_piracy_models.dart';

class SecurePlaybackRepository {
  SecurePlaybackRepository({
    AntiPiracyApiClient? apiClient,
    DeviceIdentityService? identityService,
    DeviceIntegrityChecker? integrityService,
  })  : _apiClient = apiClient ?? AntiPiracyApiClient(),
        _identityService = identityService ?? DeviceIdentityService.instance,
        _integrityService = integrityService ?? const DeviceIntegrityService();

  static final SecurePlaybackRepository instance = SecurePlaybackRepository();

  final AntiPiracyApiClient _apiClient;
  final DeviceIdentityService _identityService;
  final DeviceIntegrityChecker _integrityService;
  Future<void>? _registrationRequest;
  bool _registrationKnown = false;

  Future<DeviceIdentity> get identity => _identityService.getIdentity();

  Future<void> registerCurrentDevice() {
    if (_registrationKnown) {
      SecurityDebugLog.event(
        'DEVICE',
        'Registration is already known; duplicate request skipped.',
      );
      return Future.value();
    }
    if (_registrationRequest != null) {
      SecurityDebugLog.event(
        'DEVICE',
        'Registration is already running; reusing the active request.',
      );
    }
    return _registrationRequest ??= _register().whenComplete(() {
      _registrationRequest = null;
    });
  }

  Future<void> _register() async {
    SecurityDebugLog.event(
      'DEVICE',
      'Resolving the persistent installation identity.',
    );
    final current = await identity;
    SecurityDebugLog.event(
      'DEVICE',
      'Identity resolved for platform type ${current.deviceType}; device ID remains redacted.',
    );
    if (current.deviceType == 'UNSUPPORTED') {
      SecurityDebugLog.event(
        'DEVICE',
        'Platform is unsupported by the current backend device contract.',
      );
      throw const SecurePlaybackException(
        SecurePlaybackFailure.unsupportedPlatform,
        'Secure playback is not configured for this platform.',
      );
    }
    try {
      SecurityDebugLog.event('DEVICE', 'Registering device before playback.');
      await _apiClient.registerDevice(current);
      _registrationKnown = true;
      SecurityDebugLog.event('DEVICE', 'Device registration succeeded.');
    } catch (e) {
      if (current.deviceType == 'WEB' ||
          (e is SecurePlaybackException &&
              e.failure != SecurePlaybackFailure.accessDenied &&
              e.failure != SecurePlaybackFailure.unauthenticated)) {
        SecurityDebugLog.event(
          'DEVICE',
          'Device registration note: $e; proceeding to signed playback.',
        );
        _registrationKnown = true;
      } else {
        rethrow;
      }
    }
  }

  void markRegistrationUnknown() {
    _registrationKnown = false;
  }

  Future<List<DeviceBinding>> getRegisteredDevices() async {
    final current = await identity;
    return _apiClient.getDevices(currentDeviceId: current.deviceId);
  }

  Future<void> removeDevice(String deviceId) async {
    final current = await identity;
    await _apiClient.removeDevice(deviceId);
    if (deviceId == current.deviceId) _registrationKnown = false;
  }

  Future<SignedPlaybackResponse> createSignedPlaybackSession({
    required String contentId,
    required String playbackUrl,
    required String country,
    required String type,
  }) async {
    SecurityDebugLog.event(
      'FLOW',
      'Secure playback preparation started; original media URL remains redacted.',
    );
    final source = Uri.tryParse(playbackUrl.trim());
    if (source == null ||
        (source.scheme != 'https' && source.scheme != 'http') ||
        source.host.isEmpty) {
      throw const SecurePlaybackException(
        SecurePlaybackFailure.invalidResponse,
        'This content does not have a secure playback source.',
      );
    }
    if (contentId.trim().isEmpty) {
      throw const SecurePlaybackException(
        SecurePlaybackFailure.notFound,
        'The requested content was not found.',
      );
    }

    await registerCurrentDevice();
    final current = await identity;
    SecurityDebugLog.event('INTEGRITY', 'Running the device integrity check.');
    final integrity = await _integrityService.checkIntegrity();
    if (integrity.state == DeviceIntegrityState.unknown) {
      SecurityDebugLog.event(
        'INTEGRITY',
        'Integrity result is unknown; forwarding the declared flags so the backend authority can apply its configured policy.',
      );
    } else {
      SecurityDebugLog.event(
        'INTEGRITY',
        'Integrity check completed; sending its result to the backend authority.',
      );
    }
    SecurityDebugLog.event(
      'FLOW',
      'Calling POST /anti-piracy/playback/signed-url.',
    );
    return _apiClient.createSignedPlayback(
      SignedPlaybackRequest(
        contentId: contentId,
        deviceId: current.deviceId,
        playbackUrl: playbackUrl,
        type: type,
        country: country,
        platform: current.deviceType,
        deviceIntegrity: integrity,
      ),
    );
  }

  Future<WatermarkData> getCurrentWatermark() async {
    final current = await identity;
    final localUser =
        await LocalSharePreferences.localSharePreferences.getUser();
    final localEmail = localUser?.emailId?.trim() ?? '';
    try {
      final remote = await _apiClient.getWatermark(deviceId: current.deviceId);
      if (remote.email.trim().isNotEmpty) {
        return remote;
      }
      if (localEmail.isNotEmpty) {
        return remote.copyWith(email: localEmail);
      }
      return remote;
    } catch (_) {
      if (localEmail.isNotEmpty) {
        return WatermarkData(
          userId: localUser?.id?.toString() ?? '',
          userName:
              '${localUser?.firstName ?? ''} ${localUser?.lastName ?? ''}'.trim(),
          email: localEmail,
          deviceId: current.deviceId,
          timestamp: DateTime.now(),
          signature: '',
        );
      }
      rethrow;
    }
  }

  Future<void> sendAnalytics({
    required String contentId,
    required String sessionId,
    required String country,
    required PlaybackAnalyticsEvent event,
  }) async {
    final current = await identity;
    await _apiClient.sendAnalytics(
      PlaybackAnalyticsRequest(
        contentId: contentId,
        deviceId: current.deviceId,
        sessionId: sessionId,
        country: country,
        eventType: event,
      ),
    );
  }
}
