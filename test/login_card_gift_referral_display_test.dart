import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/core/constant/prefrense_constant.dart';
import 'package:ott/app/core/services/DeepLinkService.dart';
import 'package:ott/app/core/services/gift_deep_link_service.dart';
import 'package:ott/app/core/services/referral_service.dart';
import 'package:ott/app/pages/sign%20in%20page/LoginCard.dart';
import 'package:ott/app/provider/language_provider.dart';
import 'package:ott/app/provider/localeLanguageProvider.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/provider/userProvider.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestableLoginCard({
  LoginCard card = const LoginCard(),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider(isDark: true)),
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ChangeNotifierProvider(create: (_) => UserProvider()),
      ChangeNotifierProvider(create: (_) => LocaleLanguageProvider()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: card,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('LoginCard Gift and Referral Code Display Tests', () {
    testWidgets(
      'Scenario 1: Deferred install from Gift Link displays only Gift Code, not Referral Code',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        const giftCode = 'GF000843A767720E';

        // Simulate Play Store deferred install where both services captured the install referrer
        // and DeepLinkService saved the deferred gift target.
        await prefs.setString(
          SharedPreferencesConstant.pendingReferralCode,
          giftCode,
        );
        await prefs.setString(
          SharedPreferencesConstant.pendingGiftCode,
          giftCode,
        );
        final giftTarget = DeepLinkTarget(
          type: DeepLinkContentType.gift,
          couponCode: giftCode,
        );
        await DeepLinkService.instance.savePendingDeepLinkTarget(giftTarget);

        await tester.pumpWidget(_buildTestableLoginCard());
        await tester.pumpAndSettle();

        // Must display ONLY the Gift Code badge
        expect(find.text('Gift Code: $giftCode'), findsOneWidget);
        expect(find.textContaining('Referral Code:'), findsNothing);

        // Erroneously populated pending referral code must be cleared
        expect(
          await ReferralService.instance.getPendingReferralCode(),
          isNull,
        );
        // Pending gift code must be preserved
        expect(
          await GiftDeepLinkService.instance.getPendingGiftCode(),
          giftCode,
        );
      },
    );

    testWidgets(
      'Scenario 2: Deferred install from Referral Link displays only Referral Code, not Gift Code',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        const refCode = 'FILMY-XX-60E7';

        // Simulate Play Store deferred install where both services captured the install referrer
        // and DeepLinkService saved the deferred register target.
        await prefs.setString(
          SharedPreferencesConstant.pendingReferralCode,
          refCode,
        );
        await prefs.setString(
          SharedPreferencesConstant.pendingGiftCode,
          refCode,
        );
        final refTarget = DeepLinkTarget(
          type: DeepLinkContentType.register,
          referralCode: refCode,
        );
        await DeepLinkService.instance.savePendingDeepLinkTarget(refTarget);

        await tester.pumpWidget(_buildTestableLoginCard());
        await tester.pumpAndSettle();

        // Must display ONLY the Referral Code badge
        expect(find.text('Referral Code: $refCode'), findsOneWidget);
        expect(find.textContaining('Gift Code:'), findsNothing);

        // Erroneously populated pending gift code must be cleared
        expect(
          await GiftDeepLinkService.instance.getPendingGiftCode(),
          isNull,
        );
        // Pending referral code must be preserved
        expect(
          await ReferralService.instance.getPendingReferralCode(),
          refCode,
        );
      },
    );

    testWidgets(
      'Scenario 3: Open application using Gift Link when installed displays only Gift Code',
      (tester) async {
        const giftCode = 'GF000843A767720E';

        await tester.pumpWidget(
          _buildTestableLoginCard(
            card: const LoginCard(
              initialGiftCode: giftCode,
              isGiftFlow: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Gift Code: $giftCode'), findsOneWidget);
        expect(find.textContaining('Referral Code:'), findsNothing);
      },
    );

    testWidgets(
      'Scenario 4: Open application using Referral Link when installed displays only Referral Code',
      (tester) async {
        const refCode = 'FILMY-XX-60E7';

        await tester.pumpWidget(
          _buildTestableLoginCard(
            card: const LoginCard(
              initialReferralCode: refCode,
              isReferralFlow: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Referral Code: $refCode'), findsOneWidget);
        expect(find.textContaining('Gift Code:'), findsNothing);
      },
    );

    testWidgets(
      'Scenario 5: Open application normally without a link displays neither code',
      (tester) async {
        await tester.pumpWidget(_buildTestableLoginCard());
        await tester.pumpAndSettle();

        expect(find.textContaining('Gift Code:'), findsNothing);
        expect(find.textContaining('Referral Code:'), findsNothing);
      },
    );

    testWidgets(
      'Scenario 6A: Switching from Referral Link to Gift Link clears stale Referral Code',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        const oldRefCode = 'FILMY-OLD-9999';
        const newGiftCode = 'GF000843A767720E';

        // Old referral code was in preferences
        await prefs.setString(
          SharedPreferencesConstant.pendingReferralCode,
          oldRefCode,
        );
        // New gift code is received
        await prefs.setString(
          SharedPreferencesConstant.pendingGiftCode,
          newGiftCode,
        );
        await prefs.setString(
          SharedPreferencesConstant.lastProcessedGiftUri,
          'https://filmytell.com/gift/$newGiftCode',
        );

        await tester.pumpWidget(_buildTestableLoginCard());
        await tester.pumpAndSettle();

        // Must display ONLY the new Gift Code, not the stale Referral Code
        expect(find.text('Gift Code: $newGiftCode'), findsOneWidget);
        expect(find.textContaining('Referral Code:'), findsNothing);
      },
    );

    testWidgets(
      'Scenario 6B: Switching from Gift Link to Referral Link clears stale Gift Code',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        const oldGiftCode = 'GF000843A767720E';
        const newRefCode = 'FILMY-NEW-1111';

        // Old gift code was in preferences
        await prefs.setString(
          SharedPreferencesConstant.pendingGiftCode,
          oldGiftCode,
        );
        // New referral link target received
        final refTarget = DeepLinkTarget(
          type: DeepLinkContentType.register,
          referralCode: newRefCode,
        );
        await DeepLinkService.instance.savePendingDeepLinkTarget(refTarget);

        await tester.pumpWidget(_buildTestableLoginCard());
        await tester.pumpAndSettle();

        // Must display ONLY the new Referral Code, not the stale Gift Code
        expect(find.text('Referral Code: $newRefCode'), findsOneWidget);
        expect(find.textContaining('Gift Code:'), findsNothing);
      },
    );

    testWidgets(
      'Scenario 7: Identical codes in storage (without target) classified by format',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        const giftFormatCode = 'GF000843A767720E';

        // Both keys set to gift format code
        await prefs.setString(
          SharedPreferencesConstant.pendingReferralCode,
          giftFormatCode,
        );
        await prefs.setString(
          SharedPreferencesConstant.pendingGiftCode,
          giftFormatCode,
        );

        await tester.pumpWidget(_buildTestableLoginCard());
        await tester.pumpAndSettle();

        expect(find.text('Gift Code: $giftFormatCode'), findsOneWidget);
        expect(find.textContaining('Referral Code:'), findsNothing);
      },
    );

    testWidgets(
      'Scenario 8: Identical codes with referral format classified as referral',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        const refFormatCode = 'FILMY-XX-60E7';

        // Both keys set to referral format code
        await prefs.setString(
          SharedPreferencesConstant.pendingReferralCode,
          refFormatCode,
        );
        await prefs.setString(
          SharedPreferencesConstant.pendingGiftCode,
          refFormatCode,
        );

        await tester.pumpWidget(_buildTestableLoginCard());
        await tester.pumpAndSettle();

        expect(find.text('Referral Code: $refFormatCode'), findsOneWidget);
        expect(find.textContaining('Gift Code:'), findsNothing);
      },
    );

    testWidgets(
      'Scenario 9: Claimed gift code is not displayed on LoginCard',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        const giftCode = 'GF000843A767720E';

        await prefs.setString(
          SharedPreferencesConstant.pendingGiftCode,
          giftCode,
        );
        await prefs.setStringList(
          SharedPreferencesConstant.claimedGiftCodes,
          [giftCode],
        );

        await tester.pumpWidget(_buildTestableLoginCard());
        await tester.pumpAndSettle();

        expect(find.textContaining('Gift Code:'), findsNothing);
        expect(find.textContaining('Referral Code:'), findsNothing);
      },
    );
  });
}
