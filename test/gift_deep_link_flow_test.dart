import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/core/constant/prefrense_constant.dart';
import 'package:ott/app/core/services/DeepLinkService.dart';
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

  group('Gift Deep Link Repeated Pop-up Fix - Scenarios 1 to 7', () {
    test('Scenario 1: Open gifting link for an unclaimed gift', () async {
      final service = GiftDeepLinkService.instance;
      final uri = Uri.parse('https://filmytell.com/gift/GF000843A767720E');

      expect(await service.isGiftCodeClaimed('GF000843A767720E'), isFalse);
      final captured = await service.captureFromUri(uri);
      expect(captured, 'GF000843A767720E');
      expect(await service.getPendingGiftCode(), 'GF000843A767720E');
    });

    test('Scenario 2: Claim the gift, close app, and reopen it (must not reopen)', () async {
      final service = GiftDeepLinkService.instance;
      final deepLinkService = DeepLinkService.instance;
      final giftUri = Uri.parse('https://filmytell.com/gift/GF000843A767720E');

      // User claims gift
      await service.markGiftCodeClaimed('GF000843A767720E');
      await service.clearPendingGiftCode();

      expect(await service.isGiftCodeClaimed('GF000843A767720E'), isTrue);
      expect(await service.getPendingGiftCode(), isNull);

      // Reopening app: intent replay or captureFromUri should return null
      final capturedOnRelaunch = await service.captureFromUri(giftUri);
      expect(capturedOnRelaunch, isNull);
      expect(await service.getPendingGiftCode(), isNull);

      // DeepLinkService rejects claimed gift deep link
      final handled = await deepLinkService.handleUri(giftUri, source: 'initial_uri');
      expect(handled, isFalse);
      expect(deepLinkService.hasPendingNavigation, isFalse);
    });

    test('Scenario 3: Open application again with same gifting link already processed', () async {
      final service = GiftDeepLinkService.instance;
      final deepLinkService = DeepLinkService.instance;
      final giftUri = Uri.parse('https://filmytell.com/gift/GF33334444555566');

      // Mark URI as already processed on initial launch
      await service.markGiftUriProcessed(giftUri);
      expect(await service.isGiftUriProcessed(giftUri), isTrue);

      // Opening again on initial_uri (cold start) must not re-process
      final handled = await deepLinkService.handleUri(giftUri, source: 'initial_uri');
      expect(handled, isFalse);
      expect(deepLinkService.hasPendingNavigation, isFalse);
    });

    test('Scenario 4: Open application with genuinely new gifting link', () async {
      final service = GiftDeepLinkService.instance;
      final deepLinkService = DeepLinkService.instance;

      // Existing gift processed
      final oldUri = Uri.parse('https://filmytell.com/gift/GF000843A767720E');
      await service.markGiftUriProcessed(oldUri);
      await service.markGiftCodeClaimed('GF000843A767720E');

      // Genuinely new gifting link arrives
      final newUri = Uri.parse('https://filmytell.com/gift/GF99998888777766');
      expect(await service.isGiftCodeClaimed('GF99998888777766'), isFalse);
      expect(await service.isGiftUriProcessed(newUri), isFalse);

      final handled = await deepLinkService.handleUri(newUri, source: 'initial_uri');
      expect(handled, isTrue);
      expect(deepLinkService.hasPendingNavigation, isTrue);
      expect(await service.getPendingGiftCode(), 'GF99998888777766');
    });

    testWidgets('Scenario 5: Dismiss pop-up without claiming gift leaves it unclaimed and prevents launch popups', (tester) async {
      final service = GiftDeepLinkService.instance;
      final prefs = await SharedPreferences.getInstance();

      // Ensure user is logged in
      await prefs.setBool(SharedPreferencesConstant.isUserLoggedIn, true);

      // Set pending code as if user opened link
      await service.savePendingGiftCode('GF000843A767720E');
      expect(await service.getPendingGiftCode(), 'GF000843A767720E');

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
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      // Show dialog and simulate cancel/dismiss
                      await service.showGiftDialogForCode(context, 'GF000843A767720E');
                    },
                    child: const Text('Launch Gift Dialog'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch Gift Dialog'));
      await tester.pumpAndSettle();

      // Find Cancel button and tap it
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Gift remains unclaimed!
      expect(await service.isGiftCodeClaimed('GF000843A767720E'), isFalse);

      // BUT pending gift code is cleared so regular app launches do not pop up!
      expect(await service.getPendingGiftCode(), isNull);
    });

    test('Scenario 6: Cold-start and warm-start deep-link handling', () async {
      final deepLinkService = DeepLinkService.instance;

      // Cold start with new gift
      final coldUri = Uri.parse('https://filmytell.com/gift/GF11112222333344');
      final coldHandled = await deepLinkService.handleUri(coldUri, source: 'initial_uri');
      expect(coldHandled, isTrue);
      expect(deepLinkService.hasPendingNavigation, isTrue);

      // Consume pending navigation
      await deepLinkService.clearPendingDeepLinkTarget();

      // Warm start (uri_stream) with another valid link
      final warmUri = Uri.parse('https://filmytell.com/gift/GF55556666777788');
      final warmHandled = await deepLinkService.handleUri(warmUri, source: 'uri_stream');
      expect(warmHandled, isTrue);
    });

    test('Scenario 7: Fix preserves non-gift deep links (movie, series, registration)', () async {
      final deepLinkService = DeepLinkService.instance;

      // Movie link
      final movieUri = Uri.parse('https://filmytell.com/movie/55');
      final movieTarget = deepLinkService.parseTarget(movieUri);
      expect(movieTarget, isNotNull);
      expect(movieTarget!.type, DeepLinkContentType.movie);
      expect(movieTarget.id, 55);

      // Series link
      final seriesUri = Uri.parse('https://filmytell.com/series/88');
      final seriesTarget = deepLinkService.parseTarget(seriesUri);
      expect(seriesTarget, isNotNull);
      expect(seriesTarget!.type, DeepLinkContentType.series);
      expect(seriesTarget.id, 88);

      // Referral link
      final refUri = Uri.parse('https://filmytell.com/register?referralCode=REF1234');
      final refTarget = deepLinkService.parseTarget(refUri);
      expect(refTarget, isNotNull);
      expect(refTarget!.type, DeepLinkContentType.register);
      expect(refTarget.referralCode, 'REF1234');
    });
  });
}

