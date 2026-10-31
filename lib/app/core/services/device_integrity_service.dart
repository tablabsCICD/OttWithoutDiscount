import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:ott/data/models/anti_piracy_models.dart';

abstract class DeviceIntegrityChecker {
  Future<DeviceIntegrityStatus> checkIntegrity();
}

class DeviceIntegrityService implements DeviceIntegrityChecker {
  const DeviceIntegrityService();

  static const MethodChannel _channel =
      MethodChannel('com.filmytell.ott/anti_piracy');

  @override
  Future<DeviceIntegrityStatus> checkIntegrity() async {
    if (kIsWeb) return const DeviceIntegrityStatus.unknown();
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('deviceIntegrity')
          .timeout(const Duration(milliseconds: 1000));
      if (result == null) return const DeviceIntegrityStatus.unknown();
      return DeviceIntegrityStatus(
        rooted: result['rooted'] == true ||
            (defaultTargetPlatform == TargetPlatform.android &&
                result['rootedOrJailbroken'] == true),
        jailbroken: result['jailbroken'] == true ||
            (defaultTargetPlatform == TargetPlatform.iOS &&
                result['rootedOrJailbroken'] == true),
        emulator: result['emulator'] == true,
      );
    } catch (_) {
      return const DeviceIntegrityStatus.unknown();
    }
  }
}
