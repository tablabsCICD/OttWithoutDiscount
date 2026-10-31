import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/core/constant/prefrense_constant.dart';
import 'package:ott/app/core/services/gift_deep_link_service.dart';
import 'package:ott/app/provider/language_provider.dart';
import 'package:ott/app/provider/localeLanguageProvider.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/provider/userProvider.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('GiftDeepLinkService Flow and State Management', () {
    testWidgets('unauthenticated user preserves code and redirects to login', (
      tester,
    ) async {
      final service = GiftDeepLinkService.instance;
      final prefs = await SharedPreferences.getInstance();

      // Ensure user is marked logged out
      await prefs.setBool(SharedPreferencesConstant.isUserLoggedIn, false);

      await tester.pumpWidget(
        MultiProvider(
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
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      await service.showGiftDialogForCode(
                        context,
                        'GF000843A767720E',
                      );
                    },
                    child: const Text('Open Gift'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Tap to trigger gift dialog while unauthenticated
      await tester.tap(find.text('Open Gift'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));

      // Pending gift code must be preserved in SharedPreferences
      expect(
        prefs.getString(SharedPreferencesConstant.pendingGiftCode),
        'GF000843A767720E',
      );
      expect(await service.getPendingGiftCode(), 'GF000843A767720E');

      // Verify that LoginCard with gift code badge is displayed
      expect(find.text('Gift Code: GF000843A767720E'), findsOneWidget);
    });

    testWidgets('authenticated user with pending gift can process pending code',
        (
      tester,
    ) async {
      final service = GiftDeepLinkService.instance;
      final prefs = await SharedPreferences.getInstance();

      // User logged in and has pending code
      await prefs.setBool(SharedPreferencesConstant.isUserLoggedIn, true);
      await service.savePendingGiftCode('GF000843A767720E');

      expect(await service.getPendingGiftCode(), 'GF000843A767720E');

      // Clear code simulates successful redemption
      await service.clearPendingGiftCode();
      expect(await service.getPendingGiftCode(), isNull);
    });

    test('duplicate presentation check prevents rapid duplicate triggers',
        () async {
      final uri = Uri.parse('https://filmytell.com/gift/GF000843A767720E');
      final code1 = GiftDeepLinkService.extractGiftCodeFromUri(uri);
      expect(code1, 'GF000843A767720E');

      final code2 = GiftDeepLinkService.extractGiftCodeFromUri(uri);
      expect(code2, 'GF000843A767720E');
    });

    test('invalid or corrupted codes are safely rejected', () async {
      final service = GiftDeepLinkService.instance;

      final invalidUri1 = Uri.parse('https://filmytell.com/gift/{giftCode}');
      expect(GiftDeepLinkService.extractGiftCodeFromUri(invalidUri1), isNull);

      final invalidUri2 = Uri.parse('https://filmytell.com/gift/null');
      expect(GiftDeepLinkService.extractGiftCodeFromUri(invalidUri2), isNull);

      final invalidUri3 = Uri.parse('https://filmytell.com/gift/undefined');
      expect(GiftDeepLinkService.extractGiftCodeFromUri(invalidUri3), isNull);

      final invalidUri4 = Uri.parse('https://filmytell.com/gift/invalid');
      expect(GiftDeepLinkService.extractGiftCodeFromUri(invalidUri4), isNull);

      final emptyUri = Uri.parse('https://filmytell.com/gift/');
      expect(GiftDeepLinkService.extractGiftCodeFromUri(emptyUri), isNull);

      await service.savePendingGiftCode('invalid');
      // Should not save corrupt codes
      expect(await service.getPendingGiftCode(), isNull);
    });

    test('deferred referrer string parses complex UTM payloads', () {
      final payload =
          'utm_source=google-play&utm_medium=organic&utm_campaign=diwali&gift_code=GF000843A767720E';
      final extracted = GiftDeepLinkService.extractGiftCodeFromString(payload);
      expect(extracted, 'GF000843A767720E');
    });
  });
}
