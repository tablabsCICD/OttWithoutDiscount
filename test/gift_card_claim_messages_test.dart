import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/core/constant/prefrense_constant.dart';
import 'package:ott/app/provider/giftProvider.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/widgets/gift_claim_dialog.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockGiftProvider extends GiftProvider {
  Map<String, dynamic> Function(String code)? mockUseGiftByCoupon;
  int callCount = 0;
  Completer<void>? inFlightCompleter;

  @override
  Future<Map<String, dynamic>> useGiftByCoupon(String couponCode) async {
    callCount++;
    if (inFlightCompleter != null) {
      await inFlightCompleter!.future;
    }
    if (mockUseGiftByCoupon != null) {
      return mockUseGiftByCoupon!(couponCode);
    }
    return {
      "success": true,
      "message": "Gift card claimed successfully!",
    };
  }
}

Widget _buildTestApp({
  required _MockGiftProvider giftProvider,
  String? initialCouponCode,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<GiftProvider>.value(value: giftProvider),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: TextButton(
                onPressed: () {
                  showGiftClaimDialog(
                    context,
                    initialCouponCode: initialCouponCode,
                  );
                },
                child: const Text('Open Claim Dialog'),
              ),
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('resolveClaimErrorMessage Unit Tests', () {
    test('resolves already claimed errors to standard message', () {
      expect(
        resolveClaimErrorMessage(rawMessage: 'Gift card already claimed'),
        'This gift card has already been claimed.',
      );
      expect(
        resolveClaimErrorMessage(rawMessage: 'Coupon already redeemed by another user'),
        'This gift card has already been claimed.',
      );
      expect(
        resolveClaimErrorMessage(rawMessage: 'This gift has already been used'),
        'This gift card has already been claimed.',
      );
    });

    test('resolves expired errors to standard message', () {
      expect(
        resolveClaimErrorMessage(rawMessage: 'This coupon has expired'),
        'This gift card has expired.',
      );
      expect(
        resolveClaimErrorMessage(rawMessage: 'Gift card validity expired'),
        'This gift card has expired.',
      );
    });

    test('resolves invalid code errors to standard message', () {
      expect(
        resolveClaimErrorMessage(rawMessage: 'Invalid coupon code'),
        'Invalid gift card code. Please check and try again.',
      );
      expect(
        resolveClaimErrorMessage(rawMessage: 'Gift card code not found'),
        'Invalid gift card code. Please check and try again.',
      );
      expect(
        resolveClaimErrorMessage(rawMessage: 'Code does not exist'),
        'Invalid gift card code. Please check and try again.',
      );
    });

    test('resolves network errors to standard connection message', () {
      expect(
        resolveClaimErrorMessage(error: 'SocketException: Failed host lookup'),
        'Unable to claim the gift card. Please check your internet connection and try again.',
      );
      expect(
        resolveClaimErrorMessage(rawMessage: 'ClientException with SocketException'),
        'Unable to claim the gift card. Please check your internet connection and try again.',
      );
      expect(
        resolveClaimErrorMessage(rawMessage: 'Connection timed out'),
        'Unable to claim the gift card. Please check your internet connection and try again.',
      );
    });

    test('resolves server errors and 5xx status codes to standard server error message', () {
      expect(
        resolveClaimErrorMessage(statusCode: 500),
        'Something went wrong while claiming the gift card. Please try again later.',
      );
      expect(
        resolveClaimErrorMessage(statusCode: 502),
        'Something went wrong while claiming the gift card. Please try again later.',
      );
      expect(
        resolveClaimErrorMessage(rawMessage: 'Internal Server Error'),
        'Something went wrong while claiming the gift card. Please try again later.',
      );
    });

    test('preserves meaningful backend messages that are not generic', () {
      expect(
        resolveClaimErrorMessage(rawMessage: 'You cannot claim your own gift card.'),
        'You cannot claim your own gift card.',
      );
      expect(
        resolveClaimErrorMessage(rawMessage: 'Claim limit exceeded for this account.'),
        'Claim limit exceeded for this account.',
      );
    });

    test('falls back to standard message for empty or generic errors', () {
      expect(
        resolveClaimErrorMessage(rawMessage: 'Failed to save gift'),
        'Something went wrong while claiming the gift card. Please try again later.',
      );
      expect(
        resolveClaimErrorMessage(rawMessage: ''),
        'Something went wrong while claiming the gift card. Please try again later.',
      );
    });
  });

  group('Gift Card Claim Flow - Widget Tests', () {
    testWidgets('Valid gift card displays success message and closes dialog', (tester) async {
      final mockProvider = _MockGiftProvider();
      mockProvider.mockUseGiftByCoupon = (code) => {
        "success": true,
        "message": "Gift card claimed successfully!",
      };

      await tester.pumpWidget(_buildTestApp(
        giftProvider: mockProvider,
        initialCouponCode: 'GF000843A767720E',
      ));
      await tester.pumpAndSettle();

      // Open claim dialog
      await tester.tap(find.text('Open Claim Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Enter Gift Card Number'), findsOneWidget);
      expect(find.text('Redeem'), findsOneWidget);

      // Tap Redeem button
      await tester.tap(find.text('Redeem'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog closed
      expect(find.text('Enter Gift Card Number'), findsNothing);

      // Verify success toast displayed
      expect(find.text('Gift card claimed successfully!'), findsOneWidget);

      // Verify marked claimed in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final claimedList = prefs.getStringList(SharedPreferencesConstant.claimedGiftCodes) ?? [];
      expect(claimedList.contains('GF000843A767720E'), isTrue);

      // Let toast timer complete
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Empty or short code displays invalid gift card error without calling API', (tester) async {
      final mockProvider = _MockGiftProvider();

      await tester.pumpWidget(_buildTestApp(
        giftProvider: mockProvider,
        initialCouponCode: '',
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Claim Dialog'));
      await tester.pumpAndSettle();

      // Tap Redeem with empty code
      await tester.tap(find.text('Redeem'));
      await tester.pump();

      expect(mockProvider.callCount, 0);
      expect(find.text('Invalid gift card code. Please check and try again.'), findsOneWidget);
      expect(find.text('Gift card claimed successfully!'), findsNothing);
      expect(find.text('Enter Gift Card Number'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Invalid gift card response from backend displays invalid error message', (tester) async {
      final mockProvider = _MockGiftProvider();
      mockProvider.mockUseGiftByCoupon = (code) => {
        "success": false,
        "message": "Invalid coupon code",
        "statusCode": 200,
      };

      await tester.pumpWidget(_buildTestApp(
        giftProvider: mockProvider,
        initialCouponCode: 'INVALIDCODE12345',
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Claim Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Redeem'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockProvider.callCount, 1);
      expect(find.text('Invalid gift card code. Please check and try again.'), findsOneWidget);
      expect(find.text('Gift card claimed successfully!'), findsNothing);
      expect(find.text('Enter Gift Card Number'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Already claimed gift card displays already claimed error message', (tester) async {
      final mockProvider = _MockGiftProvider();
      mockProvider.mockUseGiftByCoupon = (code) => {
        "success": false,
        "message": "Gift card has already been claimed",
        "statusCode": 200,
      };

      await tester.pumpWidget(_buildTestApp(
        giftProvider: mockProvider,
        initialCouponCode: 'GF000843A767720E',
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Claim Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Redeem'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockProvider.callCount, 1);
      expect(find.text('This gift card has already been claimed.'), findsOneWidget);
      expect(find.text('Gift card claimed successfully!'), findsNothing);
      expect(find.text('Enter Gift Card Number'), findsOneWidget);

      // Verify marked claimed locally
      final prefs = await SharedPreferences.getInstance();
      final claimedList = prefs.getStringList(SharedPreferencesConstant.claimedGiftCodes) ?? [];
      expect(claimedList.contains('GF000843A767720E'), isTrue);

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Expired gift card displays expired error message', (tester) async {
      final mockProvider = _MockGiftProvider();
      mockProvider.mockUseGiftByCoupon = (code) => {
        "success": false,
        "message": "Gift card has expired",
        "statusCode": 200,
      };

      await tester.pumpWidget(_buildTestApp(
        giftProvider: mockProvider,
        initialCouponCode: 'GF000843A767720E',
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Claim Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Redeem'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockProvider.callCount, 1);
      expect(find.text('This gift card has expired.'), findsOneWidget);
      expect(find.text('Gift card claimed successfully!'), findsNothing);
      expect(find.text('Enter Gift Card Number'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Network failure displays connection error message', (tester) async {
      final mockProvider = _MockGiftProvider();
      mockProvider.mockUseGiftByCoupon = (code) => {
        "success": false,
        "message": "Unable to claim the gift card. Please check your internet connection and try again.",
        "error": "SocketException: OS Error: Network is unreachable",
      };

      await tester.pumpWidget(_buildTestApp(
        giftProvider: mockProvider,
        initialCouponCode: 'GF000843A767720E',
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Claim Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Redeem'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockProvider.callCount, 1);
      expect(find.text('Unable to claim the gift card. Please check your internet connection and try again.'), findsOneWidget);
      expect(find.text('Gift card claimed successfully!'), findsNothing);
      expect(find.text('Enter Gift Card Number'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Server error displays server error message', (tester) async {
      final mockProvider = _MockGiftProvider();
      mockProvider.mockUseGiftByCoupon = (code) => {
        "success": false,
        "message": "Something went wrong while claiming the gift card. Please try again later.",
        "statusCode": 500,
      };

      await tester.pumpWidget(_buildTestApp(
        giftProvider: mockProvider,
        initialCouponCode: 'GF000843A767720E',
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Claim Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Redeem'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockProvider.callCount, 1);
      expect(find.text('Something went wrong while claiming the gift card. Please try again later.'), findsOneWidget);
      expect(find.text('Gift card claimed successfully!'), findsNothing);
      expect(find.text('Enter Gift Card Number'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Loading indicator shows during claim and repeated taps do not produce duplicate requests', (tester) async {
      final mockProvider = _MockGiftProvider();
      final completer = Completer<void>();
      mockProvider.inFlightCompleter = completer;
      mockProvider.mockUseGiftByCoupon = (code) => {
        "success": true,
        "message": "Gift card claimed successfully!",
      };

      await tester.pumpWidget(_buildTestApp(
        giftProvider: mockProvider,
        initialCouponCode: 'GF000843A767720E',
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Claim Dialog'));
      await tester.pumpAndSettle();

      // First tap begins operation
      await tester.tap(find.text('Redeem'));
      await tester.pump();

      // Loading indicator must be visible on the button
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(mockProvider.callCount, 1);

      // Attempt repeated taps while in-flight
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();

      // Request must NOT be duplicated
      expect(mockProvider.callCount, 1);

      // Complete in-flight operation
      completer.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Success message shown once, dialog dismissed
      expect(find.text('Gift card claimed successfully!'), findsOneWidget);
      expect(find.text('Enter Gift Card Number'), findsNothing);

      await tester.pump(const Duration(seconds: 4));
    });
  });
}
