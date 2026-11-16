// Orientation policy: iPhone opens in portrait and can then be rotated
// freely; the full-screen player locks landscape and hands back to portrait.
// Android: launch portrait is native (MainActivity); leaving the player
// requests portrait and asks the activity to release it once upright.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/core/utils/app_orientation.dart';

const _portrait = ['DeviceOrientation.portraitUp'];
const _landscape = [
  'DeviceOrientation.landscapeLeft',
  'DeviceOrientation.landscapeRight',
];
const _unlocked = <String>[];

void main() {
  late List<List<String>> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        calls.add(List<String>.from(call.arguments as List));
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  void setView(WidgetTester tester, Size logical, {double dpr = 3}) {
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = logical * dpr;
    addTearDown(tester.view.reset);
  }

  testWidgets('iPhone launch: portrait first, then rotation unlocked',
      (tester) async {
    setView(tester, const Size(402, 874)); // portrait iPhone

    await AppOrientation.applyLaunchDefault();
    expect(calls, [_portrait]);

    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, [_portrait, _unlocked]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
      'iPhone stuck sideways (stale landscape lock): unlock waits until the '
      'UI has rotated back to portrait', (tester) async {
    setView(tester, const Size(874, 402)); // UI currently landscape

    await AppOrientation.applyLaunchDefault();
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, [_portrait], reason: 'must not unlock while still sideways');

    setView(tester, const Size(402, 874)); // iOS finished rotating
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, [_portrait, _unlocked]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('player exit restores portrait, then unlocks on iOS',
      (tester) async {
    setView(tester, const Size(874, 402));

    await AppOrientation.lockLandscape();
    expect(calls.last, _landscape);

    await AppOrientation.restoreDefault();
    expect(calls.last, _portrait);
    setView(tester, const Size(402, 874));
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, [_landscape, _portrait, _unlocked]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('re-entering the player cancels a pending unlock',
      (tester) async {
    setView(tester, const Size(874, 402));

    await AppOrientation.restoreDefault(); // pending unlock (still sideways)
    await AppOrientation.lockLandscape(); // user opens the next video
    setView(tester, const Size(402, 874));
    await tester.pump(const Duration(seconds: 3));

    expect(calls, [_portrait, _landscape],
        reason: 'stale unlock must not override the landscape lock');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iPad launch keeps free rotation (no portrait lock)',
      (tester) async {
    setView(tester, const Size(1366, 1024), dpr: 2);

    await AppOrientation.applyLaunchDefault();
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, [_unlocked]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('Android', () {
    const channel = MethodChannel('com.filmytell.ott/orientation');
    late List<String> nativeCalls;

    setUp(() {
      nativeCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        nativeCalls.add(call.method);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('launch: no Dart orientation change (handled natively)',
        (tester) async {
      setView(tester, const Size(412, 915));
      await AppOrientation.applyLaunchDefault();
      expect(calls, isEmpty);
      expect(nativeCalls, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets(
        'player exit: portrait, then the activity releases it once upright',
        (tester) async {
      setView(tester, const Size(915, 412));
      await AppOrientation.lockLandscape();
      await AppOrientation.restoreDefault();
      await tester.pump(const Duration(seconds: 3));
      expect(calls, [_landscape, _portrait],
          reason: 'no blanket Dart unlock on Android');
      expect(nativeCalls, ['releasePortraitWhenUpright']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('without the native handler it keeps the portrait lock',
        (tester) async {
      // What an engine without the MainActivity handler reports.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              channel, (call) async => throw MissingPluginException());
      await AppOrientation.restoreDefault();
      await tester.pump(const Duration(seconds: 3));
      expect(calls, [_portrait]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
