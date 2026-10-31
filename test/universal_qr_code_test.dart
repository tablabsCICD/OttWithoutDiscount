import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/core/constant/app_constant.dart';
import 'package:ott/app/core/services/DeepLinkService.dart';
import 'package:ott/app/core/services/ShareService.dart';
import 'package:ott/data/models/content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );
  });

  group('Universal Clean URLs (No /share/ anywhere)', () {
    final deepLinkService = DeepLinkService.instance;

    test('buildAppLink builds clean URL without /share/ for movie', () {
      final url = deepLinkService.buildAppLink(
        type: DeepLinkContentType.movie,
        id: 123,
      );
      expect(url.toString(), 'https://filmytell.com/movie/123');
      expect(url.toString().contains('/share/'), isFalse);
    });

    test('buildAppLink builds clean URL without /share/ for series', () {
      final url = deepLinkService.buildAppLink(
        type: DeepLinkContentType.series,
        id: 456,
      );
      expect(url.toString(), 'https://filmytell.com/series/456');
      expect(url.toString().contains('/share/'), isFalse);
    });

    test('buildAppLink builds clean URL without /share/ for miniseries', () {
      final url = deepLinkService.buildAppLink(
        type: DeepLinkContentType.miniSeries,
        id: 789,
      );
      expect(url.toString(), 'https://filmytell.com/miniseries/789');
      expect(url.toString().contains('/share/'), isFalse);
    });

    test('buildAppLink builds clean URL without /share/ for short film', () {
      final url = deepLinkService.buildAppLink(
        type: DeepLinkContentType.shortFilm,
        id: 101,
      );
      expect(url.toString(), 'https://filmytell.com/short-film/101');
      expect(url.toString().contains('/share/'), isFalse);
    });

    test('buildAppLink supports filmytell.com custom domain', () {
      final url = deepLinkService.buildAppLink(
        type: DeepLinkContentType.movie,
        id: 123,
        customHost: 'filmytell.com',
      );
      expect(url.toString(), 'https://filmytell.com/movie/123');
    });
  });

  group('Universal URL Parsing across supported domains', () {
    final deepLinkService = DeepLinkService.instance;

    test('parses filmytell.com and filmytell.com clean movie links', () {
      final targetCom = deepLinkService.parseTarget(
        Uri.parse('https://filmytell.com/movie/123'),
      );
      expect(targetCom, isNotNull);
      expect(targetCom!.type, DeepLinkContentType.movie);
      expect(targetCom.id, 123);

      final targetIn = deepLinkService.parseTarget(
        Uri.parse('https://filmytell.com/movie/123'),
      );
      expect(targetIn, isNotNull);
      expect(targetIn!.type, DeepLinkContentType.movie);
      expect(targetIn.id, 123);

      final targetWwwIn = deepLinkService.parseTarget(
        Uri.parse('https://www.filmytell.com/movie/123'),
      );
      expect(targetWwwIn, isNotNull);
      expect(targetWwwIn!.type, DeepLinkContentType.movie);
      expect(targetWwwIn.id, 123);
    });

    test('parses series, miniseries, short-film, and shorts URLs', () {
      final seriesTarget = deepLinkService.parseTarget(
        Uri.parse('https://filmytell.com/series/456'),
      );
      expect(seriesTarget, isNotNull);
      expect(seriesTarget!.type, DeepLinkContentType.series);
      expect(seriesTarget.id, 456);

      final miniTarget1 = deepLinkService.parseTarget(
        Uri.parse('https://filmytell.com/miniseries/789'),
      );
      expect(miniTarget1, isNotNull);
      expect(miniTarget1!.type, DeepLinkContentType.miniSeries);
      expect(miniTarget1.id, 789);

      final miniTarget2 = deepLinkService.parseTarget(
        Uri.parse('https://filmytell.com/mini-series/789'),
      );
      expect(miniTarget2, isNotNull);
      expect(miniTarget2!.type, DeepLinkContentType.miniSeries);
      expect(miniTarget2.id, 789);

      final shortFilmTarget = deepLinkService.parseTarget(
        Uri.parse('https://filmytell.com/short-film/101'),
      );
      expect(shortFilmTarget, isNotNull);
      expect(shortFilmTarget!.type, DeepLinkContentType.shortFilm);
      expect(shortFilmTarget.id, 101);

      final shortTarget = deepLinkService.parseTarget(
        Uri.parse('https://filmytell.com/short/555'),
      );
      expect(shortTarget, isNotNull);
      expect(shortTarget!.type, DeepLinkContentType.short);
      expect(shortTarget.id, 555);
    });

    test('maintains backward compatibility with legacy /share/ links', () {
      final legacyMovieTarget = deepLinkService.parseTarget(
        Uri.parse('https://filmytell.com/share/movie/123'),
      );
      expect(legacyMovieTarget, isNotNull);
      expect(legacyMovieTarget!.type, DeepLinkContentType.movie);
      expect(legacyMovieTarget.id, 123);

      final legacySeriesTarget = deepLinkService.parseTarget(
        Uri.parse('https://filmytell.com/share/series/456'),
      );
      expect(legacySeriesTarget, isNotNull);
      expect(legacySeriesTarget!.type, DeepLinkContentType.series);
      expect(legacySeriesTarget.id, 456);

      final legacyOttShareTarget = deepLinkService.parseTarget(
        Uri.parse('https://filmytell.com/ott/share/miniseries/789'),
      );
      expect(legacyOttShareTarget, isNotNull);
      expect(legacyOttShareTarget!.type, DeepLinkContentType.miniSeries);
      expect(legacyOttShareTarget.id, 789);
    });

    test('parses custom scheme myapp:// deep links', () {
      final movieScheme = deepLinkService.parseTarget(
        Uri.parse('myapp://movie/123'),
      );
      expect(movieScheme, isNotNull);
      expect(movieScheme!.type, DeepLinkContentType.movie);
      expect(movieScheme.id, 123);

      final miniScheme = deepLinkService.parseTarget(
        Uri.parse('myapp://miniseries/789'),
      );
      expect(miniScheme, isNotNull);
      expect(miniScheme!.type, DeepLinkContentType.miniSeries);
      expect(miniScheme.id, 789);

      final shortFilmScheme = deepLinkService.parseTarget(
        Uri.parse('myapp://short-film/101'),
      );
      expect(shortFilmScheme, isNotNull);
      expect(shortFilmScheme!.type, DeepLinkContentType.shortFilm);
      expect(shortFilmScheme.id, 101);
    });
  });

  group('One Universal QR Code & ShareService', () {
    test(
        'prepareContentShare produces exactly ONE QR code linking to universal URL',
        () async {
      final movie = Content(
        id: 123,
        title: 'Universal Cinema',
        description: 'An extraordinary cinematic masterpiece on Filmytell.',
        type: 'MOVIE',
      );

      final shareData = await ShareService.instance.prepareContentShare(
        movie,
        contentType: DeepLinkContentType.movie,
      );

      // Verify QR link matches clean universal URL
      expect(shareData.qrLink.toString(), 'https://filmytell.com/movie/123');
      expect(shareData.qrLink.toString().contains('/share/'), isFalse);

      // Verify QR Code image is generated
      expect(shareData.qrCode.bytes.isNotEmpty, isTrue);

      // Verify share message contains title, universal URL and official store links
      expect(shareData.message.contains('Universal Cinema'), isTrue);
      expect(
          shareData.message.contains('https://filmytell.com/movie/123'), isTrue);
      expect(shareData.message.contains(AppConstant.playStoreLink), isTrue);
      expect(shareData.message.contains(AppConstant.appStoreLink), isTrue);
    });

    test('downloadAllQrImages returns single QR image path', () async {
      final movie = Content(
        id: 456,
        title: 'Series Hit',
        type: 'SERIES',
      );

      final shareData = await ShareService.instance.prepareContentShare(
        movie,
        contentType: DeepLinkContentType.series,
      );

      final paths = await ShareService.instance.downloadAllQrImages(shareData);
      expect(paths.length, 1);
    });
  });
}
