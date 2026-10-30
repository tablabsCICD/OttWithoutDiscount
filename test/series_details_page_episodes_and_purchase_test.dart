import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/pages/series%20details%20page/seriesdetailspage.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/provider/offline_download_provider.dart';
import 'package:ott/app/provider/playMediaProvider.dart';
import 'package:ott/app/provider/series_provider.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/provider/videoProvider.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/models/response/SeriesDetailsResponse.dart';
import 'package:ott/data/models/seriesModel.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeSeriesProvider extends SeriesProvider {
  final SeriesEntity? _testSeries;
  final bool _testLoading;
  final String? _testError;

  _FakeSeriesProvider({
    SeriesEntity? series,
    bool isLoading = false,
    String? error,
  })  : _testSeries = series,
        _testLoading = isLoading,
        _testError = error;

  @override
  bool get isLoading => _testLoading;

  @override
  String? get error => _testError;

  @override
  SeriesEntity? get series => _testSeries;

  @override
  Future<void> fetchSeriesDetails(int seriesId) async {}
}

class _FakeVideoProvider extends VideoProvider {
  @override
  Future<Map<String, Object>> getRatingReview(int movieId) async =>
      <String, Object>{};
}

Widget _buildTestWidget({
  required SeriesProvider seriesProvider,
  required Content content,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SeriesProvider>.value(value: seriesProvider),
      ChangeNotifierProvider<VideoProvider>(create: (_) => _FakeVideoProvider()),
      ChangeNotifierProvider<PlayMediaProvider>(
          create: (_) => PlayMediaProvider()),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<OfflineDownloadProvider>(
          create: (_) => OfflineDownloadProvider()),
      ChangeNotifierProvider<DashboardProvider>(
          create: (_) => DashboardProvider()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SeriesDetailsPage(
        seriesId: content.id ?? 9,
        content: content,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SeriesDetailsResponse JSON Parsing and Resilience', () {
    test('parses series details response with null safety and alternate keys', () {
      final json = {
        'data': {
          'seriesId': 101,
          'title': 'Test Thriller',
          'description': 'A mystery series',
          'posterUrl': 'https://example.com/poster.jpg',
          'userData': {
            'isRental': false,
            'isPurchased': false,
            'isRent': false,
          },
          'seasons': [
            {
              'seasonId': 1,
              'seasonNumber': 1,
              'title': 'Season 1',
              'description': 'Season 1 synopsis',
              'price': '49.0',
              'seasonPurchased': false,
              'episodes': [
                {
                  'episodeId': 1001,
                  'episodeNumber': 1,
                  'title': 'The Beginning',
                  'description': 'Episode 1 intro',
                  'runtime': 42,
                  'price': 10,
                  'isFree': true,
                  'contentUrl': 'https://example.com/stream.m3u8',
                },
                {
                  'episodeId': 1002,
                  'episodeNumber': 2,
                  'title': 'The Plot Thickens',
                  'description': 'Episode 2 drama',
                  'runtime': 45,
                  'price': '15.0',
                  'episodePurchased': true,
                  'url': 'https://example.com/stream2.m3u8',
                }
              ]
            }
          ]
        }
      };

      final response = SeriesDetailsResponse.fromJson(json);
      expect(response.data, isNotNull);
      expect(response.data!.seriesId, 101);
      expect(response.data!.title, 'Test Thriller');
      expect(response.data!.seasons.length, 1);

      final season = response.data!.seasons.first;
      expect(season.seasonId, 1);
      expect(season.price, 49.0);
      expect(season.isSeasonPurchased, false);
      expect(season.episodes.length, 2);

      final ep1 = season.episodes[0];
      expect(ep1.episodeId, 1001);
      expect(ep1.title, 'The Beginning');
      expect(ep1.isFree, true);
      expect(ep1.videoUrl, 'https://example.com/stream.m3u8');

      final ep2 = season.episodes[1];
      expect(ep2.episodeId, 1002);
      expect(ep2.isPurchased, true);
      expect(ep2.price, 15.0);
      expect(ep2.videoUrl, 'https://example.com/stream2.m3u8');
    });

    test('parses series details response when episodes list is null without error', () {
      final json = {
        'data': {
          'seriesId': 102,
          'title': 'Coming Soon Series',
          'description': 'Description',
          'seasons': [
            {
              'seasonId': 2,
              'seasonNumber': 1,
              'title': 'Season 1',
              'episodes': null,
            }
          ]
        }
      };

      final response = SeriesDetailsResponse.fromJson(json);
      expect(response.data, isNotNull);
      expect(response.data!.seasons.first.episodes, isEmpty);
    });
  });

  group('Series Details Page - Episode Listing and Empty State', () {
    testWidgets('displays episode listing with titles, details and prices on mobile for unpurchased series',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testSeason = SeasonEntity(
        seasonId: 1,
        seasonNumber: 1,
        title: 'Season 1',
        description: 'Season 1 description',
        releaseDate: 0,
        price: 99.0,
        isSeasonPurchased: false,
        episodes: [
          EpisodeEntity(
            episodeId: 11,
            episodeNumber: 1,
            title: 'Pilot Episode',
            description: 'Pilot synopsis',
            runtime: 30,
            releaseDate: 0,
            price: 15.0,
            isFree: false,
            isPurchased: false,
            isLocked: true,
            videoUrl: 'https://example.com/ep1.mp4',
            posterUrl: 'https://example.com/ep1.jpg',
          ),
          EpisodeEntity(
            episodeId: 12,
            episodeNumber: 2,
            title: 'Second Episode',
            description: 'Second synopsis',
            runtime: 32,
            releaseDate: 0,
            price: 15.0,
            isFree: false,
            isPurchased: false,
            isLocked: true,
            videoUrl: 'https://example.com/ep2.mp4',
            posterUrl: 'https://example.com/ep2.jpg',
          ),
        ],
      );

      final testSeries = SeriesEntity(
        id: 10,
        title: 'Awesome Drama',
        description: 'Awesome drama description',
        posterUrl: 'https://example.com/series.jpg',
        seasons: [testSeason],
      );

      final testContent = Content(
        id: 10,
        title: 'Awesome Drama',
        description: 'Awesome drama description',
        price: 99.0,
        ratings: 4.8,
        ratingCount: 120,
        isRental: false,
      );

      await tester.pumpWidget(
        _buildTestWidget(
          seriesProvider: _FakeSeriesProvider(series: testSeries),
          content: testContent,
        ),
      );
      await tester.pump();

      // Verify title block and season info
      expect(find.text('Awesome Drama'), findsOneWidget);
      expect(find.text('Season 1: Season 1'), findsOneWidget);

      // Verify episode listing
      expect(find.text('Pilot Episode'), findsOneWidget);
      expect(find.text('Second Episode'), findsOneWidget);
      expect(find.text('Ep. 1 • 30 min'), findsOneWidget);
      expect(find.text('Ep. 2 • 32 min'), findsOneWidget);

      // Verify separate season buy button is visible with correct price
      expect(find.text('Rent complete Season ₹99'), findsOneWidget);

      // Verify locked episode price buttons are visible separately
      expect(find.text('₹15.0'), findsNWidgets(2));
    });

    testWidgets('displays episode rail and rent season button on TV for unpurchased series',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testSeason = SeasonEntity(
        seasonId: 1,
        seasonNumber: 1,
        title: 'Season 1',
        description: 'Season 1 description',
        releaseDate: 0,
        price: 99.0,
        isSeasonPurchased: false,
        episodes: [
          EpisodeEntity(
            episodeId: 11,
            episodeNumber: 1,
            title: 'Pilot Episode',
            description: 'Pilot synopsis',
            runtime: 30,
            releaseDate: 0,
            price: 15.0,
            isFree: false,
            isPurchased: false,
            isLocked: true,
            videoUrl: 'https://example.com/ep1.mp4',
            posterUrl: 'https://example.com/ep1.jpg',
          ),
        ],
      );

      final testSeries = SeriesEntity(
        id: 10,
        title: 'Awesome Drama',
        description: 'Awesome drama description',
        posterUrl: 'https://example.com/series.jpg',
        seasons: [testSeason],
      );

      final testContent = Content(
        id: 10,
        title: 'Awesome Drama',
        description: 'Awesome drama description',
        price: 99.0,
        ratings: 4.8,
        ratingCount: 120,
        isRental: false,
      );

      await tester.pumpWidget(
        _buildTestWidget(
          seriesProvider: _FakeSeriesProvider(series: testSeries),
          content: testContent,
        ),
      );
      await tester.pump();

      // TV Season Header displays Rent Season button
      expect(find.text('Rent Season ₹99'), findsOneWidget);
      expect(find.text('Pilot Episode'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
    });

    testWidgets('displays minimal empty-state message when season has no episodes (mobile)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testSeason = SeasonEntity(
        seasonId: 1,
        seasonNumber: 1,
        title: 'Season 1',
        description: 'No episodes yet',
        releaseDate: 0,
        price: 50.0,
        isSeasonPurchased: false,
        episodes: [],
      );

      final testSeries = SeriesEntity(
        id: 12,
        title: 'Empty Series',
        description: 'Description',
        posterUrl: 'https://example.com/empty.jpg',
        seasons: [testSeason],
      );

      final testContent = Content(
        id: 12,
        title: 'Empty Series',
        price: 50.0,
        ratings: 4.0,
      );

      await tester.pumpWidget(
        _buildTestWidget(
          seriesProvider: _FakeSeriesProvider(series: testSeries),
          content: testContent,
        ),
      );
      await tester.pump();

      expect(find.text('No episodes available yet'), findsOneWidget);
    });
  });

  group('Series Details Page - Purchase Status and Price Display', () {
    testWidgets('when user has purchased series (isRental is true), episodes are unlocked without price buttons',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testSeason = SeasonEntity(
        seasonId: 1,
        seasonNumber: 1,
        title: 'Season 1',
        description: 'Purchased season',
        releaseDate: 0,
        price: 99.0,
        isSeasonPurchased: false, // backend may have only set series level rental
        episodes: [
          EpisodeEntity(
            episodeId: 101,
            episodeNumber: 1,
            title: 'Ep 1 Unlocked',
            description: 'Synopsis',
            runtime: 25,
            releaseDate: 0,
            price: 20.0,
            isFree: false,
            isPurchased: false,
            isLocked: true,
            videoUrl: 'https://example.com/ep1.mp4',
            posterUrl: 'https://example.com/ep1.jpg',
          ),
        ],
      );

      final testSeries = SeriesEntity(
        id: 20,
        title: 'Purchased Series',
        description: 'Purchased series description',
        posterUrl: 'https://example.com/series.jpg',
        seasons: [testSeason],
      );

      // User has rented the series
      final testContent = Content(
        id: 20,
        title: 'Purchased Series',
        price: 99.0,
        ratings: 5.0,
        isRental: true,
      );

      await tester.pumpWidget(
        _buildTestWidget(
          seriesProvider: _FakeSeriesProvider(series: testSeries),
          content: testContent,
        ),
      );
      await tester.pump();

      // Episode title is present
      expect(find.text('Ep 1 Unlocked'), findsOneWidget);

      // No locked episode price button is displayed
      expect(find.text('₹20.0'), findsNothing);

      // Season rent button is not displayed since series is already rented
      expect(find.text('Rent complete Season ₹99'), findsNothing);
    });

    testWidgets('when user has purchased the season, episodes are unlocked and rent season button is hidden',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testSeason = SeasonEntity(
        seasonId: 1,
        seasonNumber: 1,
        title: 'Season 1',
        description: 'Purchased season',
        releaseDate: 0,
        price: 80.0,
        isSeasonPurchased: true,
        episodes: [
          EpisodeEntity(
            episodeId: 201,
            episodeNumber: 1,
            title: 'Purchased Ep 1',
            description: 'Synopsis',
            runtime: 40,
            releaseDate: 0,
            price: 20.0,
            isFree: false,
            isPurchased: false,
            isLocked: true,
            videoUrl: 'https://example.com/ep1.mp4',
            posterUrl: 'https://example.com/ep1.jpg',
          ),
        ],
      );

      final testSeries = SeriesEntity(
        id: 30,
        title: 'Season Purchased Series',
        description: 'Description',
        posterUrl: 'https://example.com/series.jpg',
        seasons: [testSeason],
      );

      final testContent = Content(
        id: 30,
        title: 'Season Purchased Series',
        price: 80.0,
        ratings: 4.5,
        isRental: false,
      );

      await tester.pumpWidget(
        _buildTestWidget(
          seriesProvider: _FakeSeriesProvider(series: testSeries),
          content: testContent,
        ),
      );
      await tester.pump();

      expect(find.text('Purchased Ep 1'), findsOneWidget);
      expect(find.text('₹20.0'), findsNothing);
      expect(find.text('Rent complete Season ₹80'), findsNothing);
    });

    testWidgets('season purchase button remains accessible even if a single episode is purchased',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testSeason = SeasonEntity(
        seasonId: 1,
        seasonNumber: 1,
        title: 'Season 1',
        description: 'Season description',
        releaseDate: 0,
        price: 150.0,
        isSeasonPurchased: false,
        episodes: [
          EpisodeEntity(
            episodeId: 301,
            episodeNumber: 1,
            title: 'Episode 1 (Purchased)',
            description: 'Synopsis 1',
            runtime: 35,
            releaseDate: 0,
            price: 25.0,
            isFree: false,
            isPurchased: true, // User previously bought episode 1
            isLocked: false,
            videoUrl: 'https://example.com/ep1.mp4',
            posterUrl: 'https://example.com/ep1.jpg',
          ),
          EpisodeEntity(
            episodeId: 302,
            episodeNumber: 2,
            title: 'Episode 2 (Locked)',
            description: 'Synopsis 2',
            runtime: 38,
            releaseDate: 0,
            price: 25.0,
            isFree: false,
            isPurchased: false,
            isLocked: true,
            videoUrl: 'https://example.com/ep2.mp4',
            posterUrl: 'https://example.com/ep2.jpg',
          ),
        ],
      );

      final testSeries = SeriesEntity(
        id: 40,
        title: 'Multi-Episode Series',
        description: 'Description',
        posterUrl: 'https://example.com/series.jpg',
        seasons: [testSeason],
      );

      final testContent = Content(
        id: 40,
        title: 'Multi-Episode Series',
        price: 150.0,
        ratings: 4.9,
        isRental: false,
      );

      await tester.pumpWidget(
        _buildTestWidget(
          seriesProvider: _FakeSeriesProvider(series: testSeries),
          content: testContent,
        ),
      );
      await tester.pump();

      // Rent complete season button should still be available so user can purchase the full season!
      expect(find.text('Rent complete Season ₹150'), findsOneWidget);

      // Episode 1 has no price button (unlocked)
      // Episode 2 has price button (locked)
      expect(find.text('₹25.0'), findsOneWidget);
    });

    testWidgets('details section shows formatted price with currency symbol',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testSeason = SeasonEntity(
        seasonId: 1,
        seasonNumber: 1,
        title: 'Season 1',
        description: 'Description',
        releaseDate: 0,
        price: 199.0,
        isSeasonPurchased: false,
        episodes: [],
      );

      final testSeries = SeriesEntity(
        id: 50,
        title: 'Price Test Series',
        description: 'Description',
        posterUrl: 'https://example.com/series.jpg',
        seasons: [testSeason],
      );

      final testContent = Content(
        id: 50,
        title: 'Price Test Series',
        price: 199.0,
        ratings: 4.2,
      );

      await tester.pumpWidget(
        _buildTestWidget(
          seriesProvider: _FakeSeriesProvider(series: testSeries),
          content: testContent,
        ),
      );
      await tester.pump();

      // Verify ₹199 appears in the details table
      expect(find.text('₹199'), findsOneWidget);
    });
  });
}
