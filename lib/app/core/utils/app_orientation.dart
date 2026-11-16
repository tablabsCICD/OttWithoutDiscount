import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native side: MainActivity (`releasePortraitWhenUpright`).
const MethodChannel _androidOrientationChannel =
    MethodChannel('com.filmytell.ott/orientation');

/// App-wide orientation policy.
///
/// iOS: the app opens in portrait and otherwise follows the device, so users
/// can rotate an iPhone to landscape and back (Info.plist allows Portrait,
/// Landscape Left and Landscape Right). Only the full-screen player locks
/// landscape, and it hands back to this policy when it closes.
///
/// iOS only rotates the interface when the current orientation stops being
/// allowed. Simply unlocking after a landscape-only lock therefore leaves the
/// UI sideways inside a portrait device. [restoreDefault] first requests
/// portrait, waits until the view is actually portrait, and only then
/// unlocks.
///
/// Android phones: the activity opens in portrait (MainActivity) and is
/// released to the system rotation setting once the phone is held upright,
/// so it never launches sideways but can still be rotated by hand. Leaving
/// the full-screen player requests portrait and asks the activity to release
/// it again the same way. Android TV / tablets are released immediately
/// (their natural landscape is kept). Other platforms: portrait lock after
/// the player, no change at startup.
class AppOrientation {
  AppOrientation._();

  static int _generation = 0;

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// iPhones use a portrait default; iPads keep free rotation.
  static bool get _isPhone {
    final views = ServicesBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return true;
    final view = views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    if (size.isEmpty) return true;
    return math.min(size.width, size.height) < 600;
  }

  static bool get _viewIsPortrait {
    final views = ServicesBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return true;
    final size = views.first.physicalSize;
    return size.isEmpty || size.height >= size.width;
  }

  /// Call once at startup, before [runApp]. (Android's launch portrait is
  /// applied natively in MainActivity, so this is a no-op there.)
  ///
  /// Also clears a landscape lock that survived a Dart restart (e.g. a hot
  /// restart while the player was open) — that lock is native state.
  static Future<void> applyLaunchDefault() async {
    if (!_isIOS) return;
    if (_isPhone) {
      await restoreDefault();
    } else {
      _generation++;
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
    }
  }

  /// Full-screen playback: landscape only.
  static Future<void> lockLandscape() {
    _generation++;
    return SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Leave full-screen playback: back to portrait. On iOS the device may then
  /// be rotated freely again; the unlock happens in the background once the
  /// rotation has landed, so callers (e.g. a pop) are not delayed.
  static Future<void> restoreDefault() async {
    final generation = ++_generation;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    if (_isAndroid) {
      await _releaseAndroidPortraitWhenUpright();
      return;
    }
    if (!_isIOS) return; // Other platforms: unchanged portrait lock.
    unawaited(_unlockWhenPortrait(generation));
  }

  /// Best-effort: without the native handler (tests, older builds) Android
  /// simply keeps the previous portrait lock.
  static Future<void> _releaseAndroidPortraitWhenUpright() async {
    try {
      await _androidOrientationChannel
          .invokeMethod<void>('releasePortraitWhenUpright');
    } on MissingPluginException {
      // Keep portrait.
    } on PlatformException {
      // Keep portrait.
    }
  }

  static Future<void> _unlockWhenPortrait(int generation) async {
    // Wait (bounded) for iOS to finish rotating to portrait.
    for (var i = 0; i < 20 && !_viewIsPortrait; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (generation != _generation) return;
    }
    // One more beat so the rotation animation is committed.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (generation != _generation) return; // player re-locked meanwhile
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
  }
}
