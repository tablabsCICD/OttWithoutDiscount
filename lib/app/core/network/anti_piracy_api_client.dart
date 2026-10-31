import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:ott/app/core/constant/api_constant.dart';
import 'package:ott/app/core/utils/security_debug_log.dart';
import 'package:ott/app/core/utils/sharepreferences.dart';
import 'package:ott/data/models/anti_piracy_models.dart';

enum SecurePlaybackFailure {
  unauthenticated,
  accessDenied,
  notFound,
  rateLimited,
  server,
  network,
  invalidResponse,
  unsupportedPlatform,
  integrityUnavailable,
}

class SecurePlaybackException implements Exception {
  const SecurePlaybackException(this.failure, this.userMessage);

  final SecurePlaybackFailure failure;
  final String userMessage;

  bool get isTransient =>
      failure == SecurePlaybackFailure.network ||
      failure == SecurePlaybackFailure.server ||
      failure == SecurePlaybackFailure.rateLimited;

  @override
  String toString() => 'SecurePlaybackException($failure)';
}

typedef AccessTokenProvider = Future<String?> Function();

class AntiPiracyApiClient {
  AntiPiracyApiClient({
    http.Client? client,
    AccessTokenProvider? tokenProvider,
  })  : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider ??
            (() => LocalSharePreferences.localSharePreferences.getAuthToken());

  final http.Client _client;
  final AccessTokenProvider _tokenProvider;

  Future<void> registerDevice(DeviceIdentity identity) async {
    await _request(
      'POST',
      Uri.parse(ApiConstant.antiPiracyDevices),
      body: identity.toRegistrationJson(),
    );
  }

  Future<List<DeviceBinding>> getDevices(
      {required String currentDeviceId}) async {
    final response = await _request(
      'GET',
      Uri.parse(ApiConstant.antiPiracyDevices),
    );
    final decoded = _decode(response.body);
    dynamic raw;
    if (decoded is List) {
      raw = decoded;
    } else if (decoded is Map) {
      final data = decoded['data'];
      raw = data is Map ? data['devices'] : data ?? decoded['devices'];
    }
    if (raw is! List) {
      throw const SecurePlaybackException(
        SecurePlaybackFailure.invalidResponse,
        'The registered device list could not be read.',
      );
    }
    return raw
        .whereType<Map>()
        .map((item) => DeviceBinding.fromJson(
              item.cast<String, dynamic>(),
              currentDeviceId: currentDeviceId,
            ))
        .where((item) => item.deviceId.isNotEmpty)
        .toList();
  }

  Future<void> removeDevice(String deviceId) async {
    await _request(
      'DELETE',
      Uri.parse(ApiConstant.antiPiracyDevice(deviceId)),
    );
  }

  Future<SignedPlaybackResponse> createSignedPlayback(
    SignedPlaybackRequest request,
  ) async {
    SecurityDebugLog.event(
      'API',
      'Requesting a signed playback URL from the security middleware.',
    );
    final response = await _request(
      'POST',
      Uri.parse(ApiConstant.signedPlaybackUrl),
      body: request.toJson(),
    );
    SecurityDebugLog.event(
      'API',
      'Signed playback response received; validating URL, session, and expiry.',
    );
    final decoded = _unwrapMap(_decode(response.body));
    try {
      final parsed = SignedPlaybackResponse.fromJson(
        decoded,
        platform: request.platform,
      );
      SecurityDebugLog.event(
        'API',
        'Signed playback response parsed successfully; playback access authorized.',
      );
      return parsed;
    } on FormatException {
      SecurityDebugLog.event(
        'API',
        'Signed playback response parsing failed; invalid format.',
      );
      throw const SecurePlaybackException(
        SecurePlaybackFailure.invalidResponse,
        'Secure playback could not be prepared.',
      );
    }
  }

  Future<void> sendAnalytics(PlaybackAnalyticsRequest request) async {
    await _request(
      'POST',
      Uri.parse(ApiConstant.playbackAnalytics),
      body: request.toJson(),
      timeout: const Duration(seconds: 4),
    );
  }

  Future<WatermarkData> getWatermark({required String deviceId}) async {
    final response = await _request(
      'GET',
      Uri.parse(ApiConstant.currentWatermark),
      extraHeaders: {'X-Device-Id': deviceId},
    );
    return WatermarkData.fromJson(_unwrapMap(_decode(response.body)));
  }

  Future<http.Response> _request(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw const SecurePlaybackException(
        SecurePlaybackFailure.invalidResponse,
        'A secure connection is required for playback.',
      );
    }
    final token = (await _tokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      SecurityDebugLog.event(
        'AUTH',
        'JWT is missing; secure API request was not sent.',
      );
      throw const SecurePlaybackException(
        SecurePlaybackFailure.unauthenticated,
        'Your session has expired. Please sign in again.',
      );
    }

    try {
      SecurityDebugLog.event(
        'AUTH',
        'JWT is present and will be sent in the Authorization header.',
      );
      SecurityDebugLog.event(
        'API',
        '$method ${_safeEndpointName(uri)} started.',
      );
      final stopwatch = Stopwatch()..start();
      late http.Response response;
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        ...?extraHeaders,
      };
      _logDiagnosticRequest(method, uri, body, extraHeaders);
      if (method == 'GET') {
        response = await _client.get(uri, headers: headers).timeout(timeout);
      } else if (method == 'POST') {
        response = await _client
            .post(uri, headers: headers, body: jsonEncode(body ?? const {}))
            .timeout(timeout);
      } else if (method == 'DELETE') {
        response = await _client.delete(uri, headers: headers).timeout(timeout);
      } else {
        throw UnsupportedError(method);
      }
      stopwatch.stop();
      _logDiagnosticResponse(method, uri, response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        SecurityDebugLog.event(
          'API',
          '$method ${_safeEndpointName(uri)} completed in ${stopwatch.elapsedMilliseconds}ms with HTTP ${response.statusCode}.',
        );
        return response;
      }
      SecurityDebugLog.event(
        'API',
        '$method ${_safeEndpointName(uri)} rejected in ${stopwatch.elapsedMilliseconds}ms with HTTP ${response.statusCode}.',
      );
      throw _mapStatus(response.statusCode, response.body);
    } on SecurePlaybackException {
      rethrow;
    } on TimeoutException {
      SecurityDebugLog.event('API', 'Secure API request timed out.');
      throw const SecurePlaybackException(
        SecurePlaybackFailure.network,
        'The secure playback service did not respond. Please retry.',
      );
    } on http.ClientException {
      SecurityDebugLog.event(
        'API',
        'Secure API request failed because of a network or CORS error.',
      );
      throw const SecurePlaybackException(
        SecurePlaybackFailure.network,
        'Check your internet connection and retry.',
      );
    } catch (_) {
      SecurityDebugLog.event(
        'API',
        'Secure API request failed before a valid response was available.',
      );
      throw const SecurePlaybackException(
        SecurePlaybackFailure.network,
        'Check your internet connection and retry.',
      );
    }
  }

  String _safeEndpointName(Uri uri) {
    final path = uri.path;
    if (path.endsWith('/anti-piracy/devices')) return 'device registration';
    if (path.contains('/anti-piracy/devices/')) return 'device removal';
    if (path.endsWith('/anti-piracy/playback/signed-url')) {
      return 'signed playback';
    }
    if (path.endsWith('/anti-piracy/playback/analytics')) {
      return 'playback analytics';
    }
    if (path.endsWith('/watermark/current')) return 'watermark';
    return 'secure endpoint';
  }

  void _logDiagnosticRequest(
    String method,
    Uri uri,
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  ) {
    final printableHeaders = <String, String>{
      'Authorization': 'Bearer <redacted>',
      'Content-Type': 'application/json',
      ...?extraHeaders,
    };
    final printableBody = body == null
        ? '<none>'
        : jsonEncode(_redactSensitiveFields(body));
    SecurityDebugLog.diagnostic(
      'REQUEST $method ${_diagnosticEndpoint(uri)} '
      'headers=${jsonEncode(printableHeaders)} body=$printableBody',
    );
  }

  void _logDiagnosticResponse(
    String method,
    Uri uri,
    http.Response response,
  ) {
    final rawBody = response.body.trim();
    var printableBody = rawBody.isEmpty ? '<empty>' : rawBody;
    if (rawBody.isNotEmpty) {
      try {
        printableBody = jsonEncode(
          _redactSensitiveFields(jsonDecode(rawBody)),
        );
      } catch (_) {
        // Non-JSON backend error text is useful for diagnosing 5xx responses.
      }
    }
    SecurityDebugLog.diagnostic(
      'RESPONSE $method ${_diagnosticEndpoint(uri)} '
      'status=${response.statusCode} body=$printableBody',
    );
  }

  String _diagnosticEndpoint(Uri uri) =>
      '${uri.scheme}://${uri.authority}${uri.path}';

  dynamic _redactSensitiveFields(dynamic value) {
    if (value is List) {
      return value.map(_redactSensitiveFields).toList(growable: false);
    }
    if (value is Map) {
      return value.map((rawKey, rawValue) {
        final key = rawKey.toString();
        final normalizedKey = key.toLowerCase().replaceAll(RegExp(r'[-_]'), '');
        final sensitive = normalizedKey == 'authorization' ||
            normalizedKey.contains('token') ||
            normalizedKey == 'playbackurl' ||
            normalizedKey == 'signedurl' ||
            normalizedKey == 'signature' ||
            normalizedKey == 'sessionid' ||
            normalizedKey == 'cloudfrontpolicy' ||
            normalizedKey == 'cloudfrontsignature' ||
            normalizedKey == 'cloudfrontkeypairid';
        return MapEntry(
          key,
          sensitive ? '<redacted>' : _redactSensitiveFields(rawValue),
        );
      });
    }
    return value;
  }

  SecurePlaybackException _mapStatus(int statusCode, String responseBody) {
    switch (statusCode) {
      case 401:
        return const SecurePlaybackException(
          SecurePlaybackFailure.unauthenticated,
          'Your session has expired. Please sign in again.',
        );
      case 403:
      case 409:
        if (_isDeviceLimitResponse(responseBody)) {
          return const SecurePlaybackException(
            SecurePlaybackFailure.accessDenied,
            'The maximum registered-device limit has been reached. Remove an old device and retry.',
          );
        }
        return const SecurePlaybackException(
          SecurePlaybackFailure.accessDenied,
          'Playback is not allowed for this account or device.',
        );
      case 404:
        return const SecurePlaybackException(
          SecurePlaybackFailure.notFound,
          'The requested content or playback session was not found.',
        );
      case 429:
        return const SecurePlaybackException(
          SecurePlaybackFailure.rateLimited,
          'Too many playback requests. Please wait and retry.',
        );
      default:
        return const SecurePlaybackException(
          SecurePlaybackFailure.server,
          'Secure playback could not be prepared.',
        );
    }
  }

  bool _isDeviceLimitResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return false;
      final code = (decoded['code'] ?? decoded['errorCode'] ?? '')
          .toString()
          .toUpperCase();
      final message = (decoded['message'] ?? '').toString().toLowerCase();
      return code.contains('DEVICE_LIMIT') ||
          message.contains('device limit') ||
          message.contains('maximum device');
    } catch (_) {
      return false;
    }
  }

  dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      throw const SecurePlaybackException(
        SecurePlaybackFailure.invalidResponse,
        'Secure playback could not be prepared.',
      );
    }
  }

  Map<String, dynamic> _unwrapMap(dynamic decoded) {
    if (decoded is Map) {
      final map = decoded.cast<String, dynamic>();
      final data = map['data'];
      return data is Map ? data.cast<String, dynamic>() : map;
    }
    throw const SecurePlaybackException(
      SecurePlaybackFailure.invalidResponse,
      'Secure playback could not be prepared.',
    );
  }
}
