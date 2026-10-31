import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/provider/playMediaProvider.dart';
import 'package:ott/app/widgets/continue_watching_banner.dart';
import 'package:ott/app/widgets/continueWatchMovieCard.dart';
import 'package:ott/app/widgets/responsive_poster_image.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Content Model Episode Parsing and Display Title Tests', () {
    test('parses episode fields from flat backend keys', () {
      final json = {
        'id': 100,
        'title': 'Mirzapur',
        'type': 'SERIES',
        'seasonId': 10,
        'episodeId': 102,
        'seriesId': 100,
        'seriesTitle': 'Mirzapur',
        'seasonNumber': 1,
        'episodeNumber': 2,
        'episodeTitle': 'Gooda',
        'episodePosterUrl': 'https://cdn.example.com/mirzapur_s1_e2.jpg',
        'watchedSeconds': 640,
        'watchedPercentage': 40,
      };

      final content = Content.fromJson(json);
      expect(content.id, 100);
      expect(content.seasonId, 10);
      expect(content.episodeId, 102);
      expect(content.seriesId, 100);
      expect(content.seriesTitle, 'Mirzapur');
      expect(content.seasonNumber, 1);
      expect(content.episodeNumber, 2);
      expect(content.episodeTitle, 'Gooda');
      expect(content.episodePosterUrl, 'https://cdn.example.com/mirzapur_s1_e2.jpg');
      expect(content.watchedSeconds, 640);
      expect(content.watchedPercentage, 40);
      expect(content.displayTitle, 'Mirzapur • S1:E2 - Gooda');
    });

    test('parses episode fields from snake_case and nested structures', () {
      final json = {
        'id': 200,
        'title': 'Sacred Games',
        'content_type': 'SERIES',
        'watchedSeconds': 300,
        'watchedPercentage': 25,
        'episode': {
          'id': 505,
          'episode_number': 3,
          'title': 'Aswathama',
          'posterUrl': 'https://cdn.example.com/sg_e3.jpg',
        },
        'season': {
          'id': 20,
          'season_number': 1,
        },
      };

      final content = Content.fromJson(json);
      expect(content.episodeId, 505);
      expect(content.seasonId, 20);
      expect(content.seasonNumber, 1);
      expect(content.episodeNumber, 3);
      expect(content.episodeTitle, 'Aswathama');
      expect(content.episodePosterUrl, 'https://cdn.example.com/sg_e3.jpg');
      expect(content.displayTitle, 'Sacred Games • S1:E3 - Aswathama');
    });

    test('movie displayTitle returns original movie title without episode format', () {
      final movie = Content(
        id: 301,
        title: 'Inception',
        type: 'MOVIE',
        watchedSeconds: 1200,
        watchedPercentage: 35,
      );
      expect(movie.displayTitle, 'Inception');
    });

    test('series episode displayTitle handles missing seriesTitle or episodeTitle gracefully', () {
      final epWithoutSeriesTitle = Content(
        id: 401,
        title: 'Chapter Two',
        type: 'SERIES',
        seasonNumber: 2,
        episodeNumber: 5,
        episodeTitle: 'Chapter Two',
        episodeId: 405,
      );
      expect(epWithoutSeriesTitle.displayTitle, 'S2:E5 • Chapter Two');

      final epWithoutTitle = Content(
        id: 402,
        title: 'Stranger Things',
        type: 'SERIES',
        seriesTitle: 'Stranger Things',
        seasonNumber: 1,
        episodeNumber: 4,
        episodeId: 404,
      );
      expect(epWithoutTitle.displayTitle, 'Stranger Things • S1:E4');
    });
  });

  group('PlayMediaProvider Local Episode Progress Persistence Tests', () {
    test('saveLocalResume persists episode metadata to SharedPreferences', () async {
      final provider = PlayMediaProvider();

      await provider.saveLocalResume(
        contentId: 50,
        seasonId: 5,
        episodeId: 501,
        episodeTitle: 'Pilot',
        episodeNumber: 1,
        seasonNumber: 1,
        episodePosterUrl: 'https://cdn.example.com/pilot.jpg',
        seriesTitle: 'Breaking Bad',
        seconds: 450,
        totalDuration: 3000,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(provider.getLocalResume(contentId: 50, seasonId: 5, episodeId: 501), 450);

      // Verify specific episode meta was stored
      final meta = await provider.getSavedEpisodeMeta(contentId: 50, seasonId: 5, episodeId: 501);
      expect(meta, isNotNull);
      expect(meta!['seriesId'], 50);
      expect(meta['episodeId'], 501);
      expect(meta['episodeTitle'], 'Pilot');
      expect(meta['episodeNumber'], 1);
      expect(meta['seasonNumber'], 1);
      expect(meta['seriesTitle'], 'Breaking Bad');
      expect(meta['watchedSeconds'], 450);
      expect(meta['watchedPercentage'], 15);

      // Verify series last episode was updated
      final lastMetaStr = prefs.getString('series_last_episode_50');
      expect(lastMetaStr, isNotNull);
      final lastMeta = jsonDecode(lastMetaStr!) as Map<String, dynamic>;
      expect(lastMeta['episodeId'], 501);
    });

    test('different episodes of same series preserve separate progress positions', () async {
      final provider = PlayMediaProvider();

      await provider.saveLocalResume(
        contentId: 77,
        seasonId: 1,
        episodeId: 101,
        seconds: 800,
      );

      await provider.saveLocalResume(
        contentId: 77,
        seasonId: 1,
        episodeId: 102,
        seconds: 300,
      );

      expect(provider.getLocalResume(contentId: 77, seasonId: 1, episodeId: 101), 800);
      expect(provider.getLocalResume(contentId: 77, seasonId: 1, episodeId: 102), 300);
    });
  });

  group('Continue Watching Completion Rules (< 95%) Tests', () {
    test('filters completed episodes (>= 95%) from continue watching list', () {
      final items = [
        Content(id: 1, title: 'Ep 1', watchedPercentage: 100),
        Content(id: 2, title: 'Ep 2', watchedPercentage: 95),
        Content(id: 3, title: 'Ep 3', watchedPercentage: 94),
        Content(id: 4, title: 'Ep 4', watchedPercentage: 10),
      ];

      final activeContinueWatching =
          items.where((item) => (item.watchedPercentage ?? 0) < 95).toList();

      expect(activeContinueWatching.length, 2);
      expect(activeContinueWatching[0].id, 3);
      expect(activeContinueWatching[1].id, 4);
    });
  });

  group('ContinueWatchingBanner Series Episode Display Widget Tests', () {
    final seriesEpisode = Content(
      id: 900,
      title: 'Dark Secrets',
      seriesTitle: 'Dark Secrets',
      episodeTitle: 'The Whispering Forest',
      seasonNumber: 1,
      episodeNumber: 2,
      episodeId: 902,
      seasonId: 91,
      watchedPercentage: 42,
      genreList: ['Mystery'],
      type: 'SERIES',
      episodePosterUrl: 'https://example.com/ep2_thumb.jpg',
      posterUrlList: ['https://example.com/series_backdrop.jpg'],
      contentUrl: 'https://example.com/ep2.m3u8',
    );

    Widget buildBannerWidget(Content item) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<DashboardProvider>(
            create: (_) => DashboardProvider(),
          ),
          ChangeNotifierProvider<PlayMediaProvider>(
            create: (_) => PlayMediaProvider(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ContinueWatchingBanner(
              items: [item],
            ),
          ),
        ),
      );
    }

    testWidgets('renders episode display title and episode thumbnail in banner',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildBannerWidget(seriesEpisode));
      await tester.pumpAndSettle();

      // Heading must remain 'Continue Watching'
      expect(find.text('Continue Watching'), findsOneWidget);

      // Title must show the specific episode title with series and S:E info
      expect(
        find.text('Dark Secrets • S1:E2 - The Whispering Forest'),
        findsOneWidget,
      );

      // Progress text must show watched percentage
      expect(find.text('42% watched | Mystery'), findsOneWidget);

      // Verify Resume button semantics uses the episode display title
      final resumeSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.label?.contains('The Whispering Forest') ?? false),
      );
      expect(resumeSemantics, findsOneWidget);

      // Verify episode poster is prioritized in backdrop candidates
      final candidates = ContinueWatchingBanner.getBackdropCandidates(seriesEpisode);
      expect(candidates.first, 'https://example.com/ep2_thumb.jpg');
    });

    testWidgets('renders movie title without episode formatting in banner',
        (WidgetTester tester) async {
      final movie = Content(
        id: 800,
        title: 'Interstellar',
        type: 'MOVIE',
        watchedPercentage: 60,
        genreList: ['Sci-Fi'],
        posterUrlList: ['https://example.com/interstellar_backdrop.jpg'],
        contentUrl: 'https://example.com/interstellar.mp4',
      );

      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildBannerWidget(movie));
      await tester.pumpAndSettle();

      expect(find.text('Continue Watching'), findsOneWidget);
      expect(find.text('Interstellar'), findsOneWidget);
      expect(find.text('60% watched | Sci-Fi'), findsOneWidget);
    });
  });

  group('ContinueWatchMovieCard Series Episode Display Tests', () {
    final seriesEpisode = Content(
      id: 950,
      title: 'Cyber City',
      seriesTitle: 'Cyber City',
      episodeTitle: 'Neon Shadows',
      seasonNumber: 1,
      episodeNumber: 1,
      episodeId: 951,
      seasonId: 95,
      watchedPercentage: 55,
      ratings: 4.5,
      genreList: ['Action'],
      type: 'SERIES',
      episodePosterUrl: 'https://example.com/neon_shadows.jpg',
      posterUrlList: ['https://example.com/cyber_city.jpg'],
    );

    testWidgets('ContinueWatchMovieCard displays episode title and uses episode poster',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DashboardProvider>(
              create: (_) => DashboardProvider(),
            ),
            ChangeNotifierProvider<BookmarkProvider>(
              create: (_) => BookmarkProvider(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  height: 220,
                  width: ContinueWatchMovieCard.itemExtent,
                  child: ContinueWatchMovieCard(
                    movie: seriesEpisode,
                    enableTrailerPreview: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Cyber City • S1:E1 - Neon Shadows'),
        findsOneWidget,
      );

      final posterFinder = find.byWidgetPredicate(
        (w) => w is ResponsivePosterImage && w.imageUrl == 'https://example.com/neon_shadows.jpg',
      );
      expect(posterFinder, findsOneWidget);
    });
  });
}
