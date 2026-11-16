import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/core/services/gifted_content_info_service.dart';
import 'package:ott/app/core/utils/content_type.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';
import 'package:ott/app/provider/onboarding_tour_provider.dart';
import 'package:ott/app/widgets/movieCard.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/models/response/purchesContentListResponse.dart';
import 'package:ott/data/themes/custom_theme.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

void main() {
  group('parseApiDate', () {
    test('epoch milliseconds and seconds', () {
      final ms = DateTime(2026, 11, 25, 10).millisecondsSinceEpoch;
      expect(parseApiDate(ms), DateTime(2026, 11, 25, 10));
      expect(parseApiDate(ms ~/ 1000), DateTime(2026, 11, 25, 10));
      expect(parseApiDate('$ms'), DateTime(2026, 11, 25, 10));
    });

    test('date-only string is a local calendar date', () {
      expect(parseApiDate('2026-11-25'), DateTime(2026, 11, 25));
    });

    test('date-time strings and Java LocalDateTime arrays', () {
      expect(parseApiDate('2026-11-25 08:30:00'), DateTime(2026, 11, 25, 8, 30));
      expect(parseApiDate([2026, 11, 25]), DateTime(2026, 11, 25));
      expect(parseApiDate([2026, 11, 25, 8, 30]), DateTime(2026, 11, 25, 8, 30));
    });

    test('missing or unusable values are null (never a fake date)', () {
      for (final v in [null, '', 'null', 0, -5, 'soon', [2026], <int>[]]) {
        expect(parseApiDate(v), isNull, reason: '$v');
      }
    });
  });

  group('GiftedContentInfo.statusAt', () {
    final now = DateTime(2026, 11, 16, 12);

    test('active, expiring soon (<= 3 days) and expired', () {
      expect(GiftedContentInfo(expiresOn: DateTime(2026, 11, 30)).statusAt(now),
          GiftStatus.active);
      expect(GiftedContentInfo(expiresOn: DateTime(2026, 11, 18)).statusAt(now),
          GiftStatus.expiringSoon);
      expect(GiftedContentInfo(expiresOn: DateTime(2026, 11, 15)).statusAt(now),
          GiftStatus.expired);
    });

    test('no expiry date: status unknown, not assumed', () {
      final info = GiftedContentInfo(giftedOn: DateTime(2026, 11, 1));
      expect(info.statusAt(now), isNull);
      expect(info.hasDetails, isTrue);
      expect(const GiftedContentInfo().hasDetails, isFalse);
    });

    test('API active=false means expired even without an expiry date', () {
      const info = GiftedContentInfo(active: false);
      expect(info.statusAt(now), GiftStatus.expired);
      expect(info.hasDetails, isTrue);
      expect(
          GiftedContentInfo(active: false, expiresOn: DateTime(2026, 12, 31))
              .statusAt(now),
          GiftStatus.expired);
    });

    test('built from the existing gifted-content model fields', () {
      final item = UserContent.fromJson({
        'isGifted': true,
        'dateFrom': '2026-11-01',
        'dateTo': '2026-11-25',
      });
      final info = GiftedContentInfo.fromUserContent(item);
      expect(info.giftedOn, DateTime(2026, 11, 1));
      expect(info.expiresOn, DateTime(2026, 11, 25));
    });
  });

  test('Gifted To You row is recognised by its category name', () {
    expect(GiftedContentInfoService.isGiftedCategory('Gifted To You'), isTrue);
    expect(GiftedContentInfoService.isGiftedCategory('GIFTED_TO_YOU'), isTrue);
    expect(GiftedContentInfoService.isGiftedCategory('Trending'), isFalse);
    expect(GiftedContentInfoService.isGiftedCategory(null), isFalse);
  });

  group('Gifted To You card', () {
    final movie = Content(
      id: 7,
      title: 'Gifted Movie',
      type: ContentType.movie,
      price: 49.0,
      genreList: const ['Drama'],
    );

    Widget card({
      required bool isGifted,
      GiftedContentInfo? info,
      ThemeData? theme,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BookmarkProvider()),
          ChangeNotifierProvider(create: (_) => OnboardingTourProvider()),
        ],
        child: MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                height: MovieCard.standardHeight,
                width: MovieCard.mobileCardWidth,
                child: MovieCard(movie: movie, isGifted: isGifted, giftInfo: info),
              ),
            ),
          ),
        ),
      );
    }

    for (final entry in {
      'light': AppTheme.lightTheme,
      'dark': AppTheme.darkTheme,
    }.entries) {
      testWidgets('badge + expiry, no overflow (${entry.key})', (tester) async {
        final expiry = DateTime.now().add(const Duration(days: 30));
        await tester.pumpWidget(card(
          isGifted: true,
          info: GiftedContentInfo(expiresOn: expiry),
          theme: entry.value,
        ));
        await tester.pumpAndSettle();
        expect(find.text('GIFTED'), findsOneWidget);
        expect(find.textContaining('Expires on'), findsOneWidget);
        expect(find.text('Drama'), findsNothing,
            reason: 'gift line replaces the genre line (no extra height)');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('expired gift shows Expired', (tester) async {
      await tester.pumpWidget(card(
        isGifted: true,
        info: GiftedContentInfo(
            expiresOn: DateTime.now().subtract(const Duration(days: 1))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets('no gift dates: badge only, genre line kept', (tester) async {
      await tester.pumpWidget(card(isGifted: true));
      await tester.pumpAndSettle();
      expect(find.text('GIFTED'), findsOneWidget);
      expect(find.text('Drama'), findsOneWidget);
    });

    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      testWidgets(
          'card widened to fill a phone grid row (Gifted To You page) '
          'does not overflow (${theme.brightness.name})', (tester) async {
        // 412pt phone, 12pt padding each side, one column.
        const width = 412.0 - 24;
        const detailsHeight = MovieCard.standardHeight -
            MovieCard.mobileCardWidth / MovieCard.standardPosterAspectRatio;
        const height = width / MovieCard.standardPosterAspectRatio + detailsHeight;
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => BookmarkProvider()),
            ChangeNotifierProvider(create: (_) => OnboardingTourProvider()),
          ],
          child: MaterialApp(
            theme: theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: MovieCard(
                    movie: movie,
                    cardWidth: width,
                    cardHeight: height,
                    cardMargin: 0,
                    isGifted: true,
                    giftInfo: GiftedContentInfo(
                        expiresOn: DateTime.now().add(const Duration(days: 9))),
                    onOpen: () {},
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(MovieCard)), const Size(width, height));
        expect(find.text('GIFTED'), findsOneWidget);
      });
    }

    testWidgets(
        'card tap opens details; Watch Now plays without triggering the card',
        (tester) async {
      var opened = 0;
      var watched = 0;
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BookmarkProvider()),
          ChangeNotifierProvider(create: (_) => OnboardingTourProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                height: MovieCard.standardHeight,
                width: MovieCard.mobileCardWidth,
                child: MovieCard(
                  movie: movie,
                  isGifted: true,
                  onOpen: () => opened++,
                  onWatchNow: () => watched++,
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Watch Now'), findsOneWidget,
          reason: 'gifted cards show Watch Now instead of the price');
      expect(find.text('₹ 49.0'), findsNothing);

      await tester.tap(find.text('Watch Now'));
      await tester.pumpAndSettle();
      expect(watched, 1);
      expect(opened, 0, reason: 'Watch Now must not trigger the card tap');

      await tester.tap(find.text('Gifted Movie')); // title
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(watched, 1);
    });

    testWidgets('other rows are unchanged', (tester) async {
      await tester.pumpWidget(card(isGifted: false));
      await tester.pumpAndSettle();
      expect(find.text('GIFTED'), findsNothing);
      expect(find.text('Drama'), findsOneWidget);
    });
  });
}
