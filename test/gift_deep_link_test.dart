import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/core/services/DeepLinkService.dart';
import 'package:ott/app/core/services/gift_deep_link_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('GiftDeepLinkService Code Validation', () {
    test('isValidGiftCode tests', () {
      expect(GiftDeepLinkService.isValidGiftCode('GF000843A767720E'), isTrue);
      expect(GiftDeepLinkService.isValidGiftCode('GF12345678'), isTrue);
      expect(GiftDeepLinkService.isValidGiftCode('GIFT-123456'), isTrue);
      expect(GiftDeepLinkService.isValidGiftCode(''), isFalse);
      expect(GiftDeepLinkService.isValidGiftCode('   '), isFalse);
      expect(GiftDeepLinkService.isValidGiftCode(null), isFalse);
      expect(GiftDeepLinkService.isValidGiftCode('{giftCode}'), isFalse);
      expect(GiftDeepLinkService.isValidGiftCode('{gift_code}'), isFalse);
      expect(GiftDeepLinkService.isValidGiftCode('{couponCode}'), isFalse);
      expect(GiftDeepLinkService.isValidGiftCode('null'), isFalse);
      expect(GiftDeepLinkService.isValidGiftCode('undefined'), isFalse);
      expect(GiftDeepLinkService.isValidGiftCode('none'), isFalse);
      expect(
          GiftDeepLinkService.isValidGiftCode('short'), isFalse); // < 6 chars
    });

    test('normalizeGiftCode trims, removes spaces, and converts to uppercase',
        () {
      expect(
        GiftDeepLinkService.normalizeGiftCode('  gf000843a767720e  '),
        'GF000843A767720E',
      );
      expect(
        GiftDeepLinkService.normalizeGiftCode('GF 0008 43A7 6772 0E'),
        'GF000843A767720E',
      );
    });
  });

  group('GiftDeepLinkService Extraction from URIs and Strings', () {
    test('extracts gift code from filmytell.com /gift/{giftCode} URL', () {
      final uri = Uri.parse('https://filmytell.com/gift/GF000843A767720E');
      expect(
        GiftDeepLinkService.extractGiftCodeFromUri(uri),
        'GF000843A767720E',
      );
    });

    test('extracts gift code from www.filmytell.com URL', () {
      final uri = Uri.parse('https://www.filmytell.com/gift/GF000843A767720E');
      expect(
        GiftDeepLinkService.extractGiftCodeFromUri(uri),
        'GF000843A767720E',
      );
    });

    test('extracts gift code from legacy filmytell.in URL', () {
      final uri = Uri.parse('https://filmytell.in/gift/GF000843A767720E');
      expect(
        GiftDeepLinkService.extractGiftCodeFromUri(uri),
        'GF000843A767720E',
      );
    });

    test('extracts gift code with ott or share prefixes', () {
      final uri1 = Uri.parse('https://filmytell.com/ott/gift/GF000843A767720E');
      expect(
        GiftDeepLinkService.extractGiftCodeFromUri(uri1),
        'GF000843A767720E',
      );

      final uri2 =
          Uri.parse('https://filmytell.com/share/gift/GF000843A767720E');
      expect(
        GiftDeepLinkService.extractGiftCodeFromUri(uri2),
        'GF000843A767720E',
      );
    });

    test('extracts gift code from myapp scheme', () {
      final uri = Uri.parse('myapp://gift/GF000843A767720E');
      expect(
        GiftDeepLinkService.extractGiftCodeFromUri(uri),
        'GF000843A767720E',
      );
    });

    test('extracts gift code from various query parameters', () {
      final uri1 =
          Uri.parse('https://filmytell.com/gift?gift_code=GF000843A767720E');
      expect(
        GiftDeepLinkService.extractGiftCodeFromUri(uri1),
        'GF000843A767720E',
      );

      final uri2 =
          Uri.parse('https://filmytell.com/gift?couponCode=GF000843A767720E');
      expect(
        GiftDeepLinkService.extractGiftCodeFromUri(uri2),
        'GF000843A767720E',
      );

      final uri3 =
          Uri.parse('https://filmytell.com/gift?gift=GF000843A767720E');
      expect(
        GiftDeepLinkService.extractGiftCodeFromUri(uri3),
        'GF000843A767720E',
      );
    });

    test('extracts gift code from Google Play install referrer string', () {
      expect(
        GiftDeepLinkService.extractGiftCodeFromString(
            'gift_code=GF000843A767720E'),
        'GF000843A767720E',
      );
      expect(
        GiftDeepLinkService.extractGiftCodeFromString(
          'utm_source=play&gift_code=GF000843A767720E&utm_medium=banner',
        ),
        'GF000843A767720E',
      );
      expect(
        GiftDeepLinkService.extractGiftCodeFromString('GF000843A767720E'),
        'GF000843A767720E',
      );
      expect(
        GiftDeepLinkService.extractGiftCodeFromString(
          'https://filmytell.com/gift/GF000843A767720E',
        ),
        'GF000843A767720E',
      );
    });
  });

  group('GiftDeepLinkService Pending State Persistence', () {
    test('save, get, and clear pending gift code', () async {
      final service = GiftDeepLinkService.instance;

      // Initially null
      expect(await service.getPendingGiftCode(), isNull);

      // Save
      await service.savePendingGiftCode('GF000843A767720E');
      expect(await service.getPendingGiftCode(), 'GF000843A767720E');

      // Clear
      await service.clearPendingGiftCode();
      expect(await service.getPendingGiftCode(), isNull);
    });

    test('captureFromUri saves and returns pending code', () async {
      final service = GiftDeepLinkService.instance;
      final uri = Uri.parse('https://filmytell.com/gift/GF000843A767720E');

      final captured = await service.captureFromUri(uri);
      expect(captured, 'GF000843A767720E');
      expect(await service.getPendingGiftCode(), 'GF000843A767720E');
    });
  });

  group('DeepLinkService Integration for filmytell.com and Gift Links', () {
    final service = DeepLinkService.instance;

    test('parses https://filmytell.com/gift/GF000843A767720E correctly', () {
      final uri = Uri.parse('https://filmytell.com/gift/GF000843A767720E');
      final target = service.parseTarget(uri);

      expect(target, isNotNull);
      expect(target!.type, DeepLinkContentType.gift);
      expect(target.couponCode, 'GF000843A767720E');
    });

    test('parses https://www.filmytell.com/gift/GF000843A767720E correctly',
        () {
      final uri = Uri.parse('https://www.filmytell.com/gift/GF000843A767720E');
      final target = service.parseTarget(uri);

      expect(target, isNotNull);
      expect(target!.type, DeepLinkContentType.gift);
      expect(target.couponCode, 'GF000843A767720E');
    });

    test('parses https://filmytell.in/gift/GF000843A767720E correctly', () {
      final uri = Uri.parse('https://filmytell.in/gift/GF000843A767720E');
      final target = service.parseTarget(uri);

      expect(target, isNotNull);
      expect(target!.type, DeepLinkContentType.gift);
      expect(target.couponCode, 'GF000843A767720E');
    });

    test('parses myapp://gift/GF000843A767720E correctly', () {
      final uri = Uri.parse('myapp://gift/GF000843A767720E');
      final target = service.parseTarget(uri);

      expect(target, isNotNull);
      expect(target!.type, DeepLinkContentType.gift);
      expect(target.couponCode, 'GF000843A767720E');
    });

    test('buildGiftAppLink generates https://filmytell.com/gift/{CODE}', () {
      final link = service.buildGiftAppLink('GF000843A767720E');
      expect(link.scheme, 'https');
      expect(link.host, 'filmytell.com');
      expect(link.path, '/gift/GF000843A767720E');
      expect(link.toString(), 'https://filmytell.com/gift/GF000843A767720E');
    });

    test('preserves existing deep links without regression', () {
      // Movie
      final movieUri = Uri.parse('https://filmytell.com/movie/101');
      final movieTarget = service.parseTarget(movieUri);
      expect(movieTarget, isNotNull);
      expect(movieTarget!.type, DeepLinkContentType.movie);
      expect(movieTarget.id, 101);

      // Series
      final seriesUri = Uri.parse('https://filmytell.com/series/202');
      final seriesTarget = service.parseTarget(seriesUri);
      expect(seriesTarget, isNotNull);
      expect(seriesTarget!.type, DeepLinkContentType.series);
      expect(seriesTarget.id, 202);

      // Register with referral
      final regUri = Uri.parse(
          'https://filmytell.com/register?referralCode=FILMY-REF-1234');
      final regTarget = service.parseTarget(regUri);
      expect(regTarget, isNotNull);
      expect(regTarget!.type, DeepLinkContentType.register);
      expect(regTarget.referralCode, 'FILMY-REF-1234');
    });
  });
}
