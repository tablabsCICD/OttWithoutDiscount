import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/core/services/DeepLinkService.dart';
import 'package:ott/app/core/services/gift_deep_link_service.dart';
import 'package:ott/app/core/services/referral_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Domain Migration: Canonical filmytell.com Link Generation', () {
    final deepLinkService = DeepLinkService.instance;

    test('buildMovieAppLink generates canonical https://filmytell.com/movie/{id}', () {
      final uri = deepLinkService.buildMovieAppLink(101);
      expect(uri.scheme, 'https');
      expect(uri.host, 'filmytell.com');
      expect(uri.path, '/movie/101');
      expect(uri.toString(), 'https://filmytell.com/movie/101');
    });

    test('buildGiftAppLink generates canonical https://filmytell.com/gift/{code}', () {
      final uri = deepLinkService.buildGiftAppLink('GF000843A767720E');
      expect(uri.scheme, 'https');
      expect(uri.host, 'filmytell.com');
      expect(uri.path, '/gift/GF000843A767720E');
      expect(uri.toString(), 'https://filmytell.com/gift/GF000843A767720E');
    });

    test('GiftDeepLinkService.buildGiftUrl generates canonical https://filmytell.com/gift/{code}', () {
      final url = GiftDeepLinkService.buildGiftUrl('GF000843A767720E');
      expect(url, 'https://filmytell.com/gift/GF000843A767720E');

      final legacyUrl = GiftDeepLinkService.buildGiftUrl('GF000843A767720E', useCanonical: false);
      expect(legacyUrl, 'https://filmytell.in/gift/GF000843A767720E');
    });

    test('buildReferralAppLink generates canonical https://filmytell.com/register?referralCode={code}', () {
      final uri = deepLinkService.buildReferralAppLink('FILMY-XX-60E7');
      expect(uri.scheme, 'https');
      expect(uri.host, 'filmytell.com');
      expect(uri.path, '/register');
      expect(uri.queryParameters['referralCode'], 'FILMY-XX-60E7');
      expect(uri.toString(), 'https://filmytell.com/register?referralCode=FILMY-XX-60E7');
    });

    test('ReferralService.buildReferralUrl generates canonical and legacy URLs', () {
      final url = ReferralService.buildReferralUrl('FILMY-XX-60E7');
      expect(url, 'https://filmytell.com/register?referralCode=FILMY-XX-60E7');

      final legacyUrl = ReferralService.buildReferralUrl('FILMY-XX-60E7', useCanonical: false);
      expect(legacyUrl, 'https://filmytell.in/register?referralCode=FILMY-XX-60E7');
    });

    test('buildAppLink generates clean canonical URLs for all content types', () {
      final movie = deepLinkService.buildAppLink(type: DeepLinkContentType.movie, id: 10);
      expect(movie.toString(), 'https://filmytell.com/movie/10');

      final series = deepLinkService.buildAppLink(type: DeepLinkContentType.series, id: 20);
      expect(series.toString(), 'https://filmytell.com/series/20');

      final shortFilm = deepLinkService.buildAppLink(type: DeepLinkContentType.shortFilm, id: 30);
      expect(shortFilm.toString(), 'https://filmytell.com/short-film/30');

      final miniSeries = deepLinkService.buildAppLink(type: DeepLinkContentType.miniSeries, id: 40);
      expect(miniSeries.toString(), 'https://filmytell.com/miniseries/40');
    });
  });

  group('Backward Compatibility: Parsing Legacy filmytell.in and www Domains', () {
    final deepLinkService = DeepLinkService.instance;

    test('parses legacy filmytell.in and canonical filmytell.com movie links', () {
      final canonical = deepLinkService.parseTarget(Uri.parse('https://filmytell.com/movie/123'));
      expect(canonical, isNotNull);
      expect(canonical!.type, DeepLinkContentType.movie);
      expect(canonical.id, 123);

      final legacy = deepLinkService.parseTarget(Uri.parse('https://filmytell.in/movie/123'));
      expect(legacy, isNotNull);
      expect(legacy!.type, DeepLinkContentType.movie);
      expect(legacy.id, 123);

      final wwwLegacy = deepLinkService.parseTarget(Uri.parse('https://www.filmytell.in/movie/123'));
      expect(wwwLegacy, isNotNull);
      expect(wwwLegacy!.type, DeepLinkContentType.movie);
      expect(wwwLegacy.id, 123);
    });

    test('parses legacy filmytell.in and canonical filmytell.com series links', () {
      final canonical = deepLinkService.parseTarget(Uri.parse('https://filmytell.com/series/456'));
      expect(canonical, isNotNull);
      expect(canonical!.type, DeepLinkContentType.series);
      expect(canonical.id, 456);

      final legacy = deepLinkService.parseTarget(Uri.parse('https://filmytell.in/series/456'));
      expect(legacy, isNotNull);
      expect(legacy!.type, DeepLinkContentType.series);
      expect(legacy.id, 456);
    });

    test('parses legacy filmytell.in and canonical filmytell.com short-film links', () {
      final canonical = deepLinkService.parseTarget(Uri.parse('https://filmytell.com/short-film/789'));
      expect(canonical, isNotNull);
      expect(canonical!.type, DeepLinkContentType.shortFilm);
      expect(canonical.id, 789);

      final legacy = deepLinkService.parseTarget(Uri.parse('https://filmytell.in/short-film/789'));
      expect(legacy, isNotNull);
      expect(legacy!.type, DeepLinkContentType.shortFilm);
      expect(legacy.id, 789);
    });

    test('parses legacy filmytell.in and canonical filmytell.com mini-series links', () {
      final canonical = deepLinkService.parseTarget(Uri.parse('https://filmytell.com/mini-series/555'));
      expect(canonical, isNotNull);
      expect(canonical!.type, DeepLinkContentType.miniSeries);
      expect(canonical.id, 555);

      final legacy = deepLinkService.parseTarget(Uri.parse('https://filmytell.in/miniseries/555'));
      expect(legacy, isNotNull);
      expect(legacy!.type, DeepLinkContentType.miniSeries);
      expect(legacy.id, 555);
    });

    test('parses legacy filmytell.in and canonical filmytell.com gift links', () {
      final canonical = deepLinkService.parseTarget(Uri.parse('https://filmytell.com/gift/GF000843A767720E'));
      expect(canonical, isNotNull);
      expect(canonical!.type, DeepLinkContentType.gift);
      expect(canonical.couponCode, 'GF000843A767720E');

      final legacy = deepLinkService.parseTarget(Uri.parse('https://filmytell.in/gift/GF000843A767720E'));
      expect(legacy, isNotNull);
      expect(legacy!.type, DeepLinkContentType.gift);
      expect(legacy.couponCode, 'GF000843A767720E');
    });

    test('parses legacy filmytell.in and canonical filmytell.com referral links', () {
      final canonical = deepLinkService.parseTarget(Uri.parse('https://filmytell.com/register?referralCode=FILMY-XX-60E7'));
      expect(canonical, isNotNull);
      expect(canonical!.type, DeepLinkContentType.register);
      expect(canonical.referralCode, 'FILMY-XX-60E7');

      final legacy = deepLinkService.parseTarget(Uri.parse('https://filmytell.in/register?referralCode=FILMY-XX-60E7'));
      expect(legacy, isNotNull);
      expect(legacy!.type, DeepLinkContentType.register);
      expect(legacy.referralCode, 'FILMY-XX-60E7');
    });

    test('parses legacy URLs with /ott/ and /share/ prefixes seamlessly', () {
      final uri1 = Uri.parse('https://filmytell.in/ott/movie/202');
      final target1 = deepLinkService.parseTarget(uri1);
      expect(target1!.type, DeepLinkContentType.movie);
      expect(target1.id, 202);

      final uri2 = Uri.parse('https://filmytell.com/share/series/303');
      final target2 = deepLinkService.parseTarget(uri2);
      expect(target2!.type, DeepLinkContentType.series);
      expect(target2.id, 303);

      final uri3 = Uri.parse('https://filmytell.in/ott/share/gift/GF000843A767720E');
      final target3 = deepLinkService.parseTarget(uri3);
      expect(target3!.type, DeepLinkContentType.gift);
      expect(target3.couponCode, 'GF000843A767720E');
    });
  });

  group('Deferred Deep Linking: Payload Extraction and First-Launch Recovery', () {
    final deepLinkService = DeepLinkService.instance;

    test('extractTargetFromString recovers content_type and content_id from Play Store referrer', () {
      final referrer = 'utm_source=google-play&content_type=movie&content_id=123';
      final target = deepLinkService.extractTargetFromString(referrer);
      expect(target, isNotNull);
      expect(target!.type, DeepLinkContentType.movie);
      expect(target.id, 123);
    });

    test('extractTargetFromString recovers series from nested URL in referrer payload', () {
      final referrer = 'utm_source=play&url=https%3A%2F%2Ffilmytell.com%2Fseries%2F456';
      final target = deepLinkService.extractTargetFromString(referrer);
      expect(target, isNotNull);
      expect(target!.type, DeepLinkContentType.series);
      expect(target.id, 456);
    });

    test('extractTargetFromString recovers gift code from Play Store referrer', () {
      final referrer = 'gift_code=GF000843A767720E&utm_medium=campaign';
      final target = deepLinkService.extractTargetFromString(referrer);
      expect(target, isNotNull);
      expect(target!.type, DeepLinkContentType.gift);
      expect(target.couponCode, 'GF000843A767720E');
    });

    test('extractTargetFromString recovers referralCode from Play Store referrer', () {
      final referrer = 'referralCode=FILMY-XX-60E7&utm_source=invite';
      final target = deepLinkService.extractTargetFromString(referrer);
      expect(target, isNotNull);
      expect(target!.type, DeepLinkContentType.register);
      expect(target.referralCode, 'FILMY-XX-60E7');
    });

    test('extractTargetFromString recovers direct URL pasted in clipboard on iOS', () {
      final clipboardText = 'https://filmytell.com/short-film/999';
      final target = deepLinkService.extractTargetFromString(clipboardText);
      expect(target, isNotNull);
      expect(target!.type, DeepLinkContentType.shortFilm);
      expect(target.id, 999);
    });
  });

  group('State Persistence: Pending Deep Link Targets', () {
    final deepLinkService = DeepLinkService.instance;

    test('saves, retrieves, and clears pending deep link target', () async {
      expect(await deepLinkService.getPendingDeepLinkTarget(), isNull);

      const target = DeepLinkTarget(type: DeepLinkContentType.movie, id: 888);
      await deepLinkService.savePendingDeepLinkTarget(target);

      final retrieved = await deepLinkService.getPendingDeepLinkTarget();
      expect(retrieved, isNotNull);
      expect(retrieved!.type, DeepLinkContentType.movie);
      expect(retrieved.id, 888);

      await deepLinkService.clearPendingDeepLinkTarget();
      expect(await deepLinkService.getPendingDeepLinkTarget(), isNull);
    });

    test('persists gift target with coupon code accurately', () async {
      const giftTarget = DeepLinkTarget(
        type: DeepLinkContentType.gift,
        couponCode: 'GF000843A767720E',
      );
      await deepLinkService.savePendingDeepLinkTarget(giftTarget);

      final retrieved = await deepLinkService.getPendingDeepLinkTarget();
      expect(retrieved, isNotNull);
      expect(retrieved!.type, DeepLinkContentType.gift);
      expect(retrieved.couponCode, 'GF000843A767720E');

      await deepLinkService.clearPendingDeepLinkTarget();
    });

    test('persists referral target with referral code accurately', () async {
      const refTarget = DeepLinkTarget(
        type: DeepLinkContentType.register,
        referralCode: 'FILMY-XX-60E7',
      );
      await deepLinkService.savePendingDeepLinkTarget(refTarget);

      final retrieved = await deepLinkService.getPendingDeepLinkTarget();
      expect(retrieved, isNotNull);
      expect(retrieved!.type, DeepLinkContentType.register);
      expect(retrieved.referralCode, 'FILMY-XX-60E7');

      await deepLinkService.clearPendingDeepLinkTarget();
    });
  });

  group('Reliability & Error Handling: Safe Rejection', () {
    final deepLinkService = DeepLinkService.instance;

    test('rejects malformed or unparseable URLs without crashing', () {
      expect(deepLinkService.parseTarget(Uri.parse('https://filmytell.com/')), isNull);
      expect(deepLinkService.parseTarget(Uri.parse('https://filmytell.com/unknown/123')), isNull);
      expect(deepLinkService.parseTarget(Uri.parse('https://filmytell.com/movie/abc')), isNull);
      expect(deepLinkService.parseTarget(Uri.parse('https://filmytell.com/movie/-1')), isNull);
      expect(deepLinkService.parseTarget(Uri.parse('https://filmytell.com/gift/')), isNull);
      expect(deepLinkService.parseTarget(Uri.parse('https://external.com/movie/123')), isNull);
    });

    test('rejects expired deep links based on expires parameter', () {
      final pastTimestamp = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      final expiredUri = Uri.parse('https://filmytell.com/movie/123?expires=$pastTimestamp');
      expect(deepLinkService.parseTarget(expiredUri), isNull);

      final futureTimestamp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      final validUri = Uri.parse('https://filmytell.com/movie/123?expires=$futureTimestamp');
      expect(deepLinkService.parseTarget(validUri), isNotNull);
    });
  });
}
