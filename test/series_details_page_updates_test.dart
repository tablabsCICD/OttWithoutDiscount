import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/pages/series%20details%20page/seriesdetailspage.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/provider/offline_download_provider.dart';
import 'package:ott/app/provider/playMediaProvider.dart';
import 'package:ott/app/provider/series_provider.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/provider/videoProvider.dart';
import 'package:ott/data/models/cast_member.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/models/seriesModel.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _MockSeriesProvider extends SeriesProvider {
  final SeriesEntity? _series;
  final bool _isLoading;
  final String? _error;

  _MockSeriesProvider({
    SeriesEntity? series,
    bool isLoading = false,
    String? error,
  })  : _series = series,
        _isLoading = isLoading,
        _error = error;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  SeriesEntity? get series => _series;

  @override
  Future<void> fetchSeriesDetails(int seriesId) async {}
}

class _MockVideoProvider extends VideoProvider {
  @override
  Future<Map<String, Object>> getRatingReview(int movieId) async =>
      <String, Object>{'success': true, 'data': []};
}

Widget _wrapSeriesPage({
  required SeriesProvider seriesProvider,
  required Content content,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SeriesProvider>.value(value: seriesProvider),
      ChangeNotifierProvider<VideoProvider>(create: (_) => _MockVideoProvider()),
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
        seriesId: content.id ?? 10,
        content: content,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Requirement 5: CastMember JSON Parsing and Robustness', () {
    test('parses standard cast member JSON correctly', () {
      final json = {
        'id': 1,
        'name': 'John Doe',
        'role': 'Protagonist',
        'image': 'https://example.com/john.jpg',
        'seasonId': 1,
        'contentId': 10,
      };
      final member = CastMember.fromJson(json);
      expect(member.castId, 1);
      expect(member.name, 'John Doe');
      expect(member.role, 'Protagonist');
      expect(member.image, 'https://example.com/john.jpg');
      expect(member.seasonId, 1);
      expect(member.contentId, 10);
    });

    test('parses alternate keys from backend API variants', () {
      final json = {
        'castId': '42',
        'actorName': 'Jane Smith',
        'character': 'Detective',
        'posterUrl': 'https://example.com/jane.jpg',
        'seriesId': '101',
      };
      final member = CastMember.fromJson(json);
      expect(member.castId, 42);
      expect(member.name, 'Jane Smith');
      expect(member.role, 'Detective');
      expect(member.image, 'https://example.com/jane.jpg');
      expect(member.contentId, 101);
    });

    test('parses crew keys (job, department, img)', () {
      final json = {
        'crewId': 7,
        'fullName': 'Christopher Nolan',
        'job': 'Director',
        'img': 'https://example.com/nolan.jpg',
      };
      final member = CastMember.fromJson(json);
      expect(member.castId, 7);
      expect(member.name, 'Christopher Nolan');
      expect(member.role, 'Director');
      expect(member.image, 'https://example.com/nolan.jpg');
    });

    test('handles generic Map<dynamic, dynamic> and nulls safely without exceptions', () {
      final Map<dynamic, dynamic> dynamicMap = {
        'id': '99',
        'name': null,
        'role': null,
        'image': null,
      };
      final member = CastMember.fromJson(dynamicMap);
      expect(member.castId, 99);
      expect(member.name, isNull);
      expect(member.role, isNull);
      expect(member.image, isNull);
    });
  });

  group('Requirement 1 & 2: Buy Episode Hidden & Gallery Hidden', () {
    final testSeason = SeasonEntity(
      seasonId: 1,
      seasonNumber: 1,
      title: 'Season 1',
      description: 'First season',
      releaseDate: 0,
      price: 100,
      isSeasonPurchased: false,
      episodes: [
        EpisodeEntity(
          episodeId: 101,
          episodeNumber: 1,
          title: 'Episode One',
          description: 'Desc 1',
          runtime: 30,
          releaseDate: 0,
          price: 20,
          isFree: false,
          isPurchased: false,
          isLocked: true,
          videoUrl: '',
          posterUrl: 'https://example.com/ep1.jpg',
        ),
      ],
    );

    final testSeries = SeriesEntity(
      id: 10,
      title: 'Drama Series',
      description: 'Drama series description',
      posterUrl: 'https://example.com/series.jpg',
      seasons: [testSeason],
    );

    final testContent = Content(
      id: 10,
      title: 'Drama Series',
      description: 'Drama series description',
      isRental: false,
      teaserUrl: 'https://example.com/teaser.mp4',
      posterUrlList: ['https://example.com/poster1.jpg'],
      castList: ['Actor A', 'Actor B'],
      directorList: ['Director X'],
    );

    testWidgets('Buy Episode price button is hidden on Series Details page', (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrapSeriesPage(
          seriesProvider: _MockSeriesProvider(series: testSeries),
          content: testContent,
        ),
      );
      await tester.pump();

      // Episode is visible
      expect(find.text('Episode One'), findsOneWidget);
      // Episode price button (₹20.0) must NOT be displayed
      expect(find.text('₹20.0'), findsNothing);
      expect(find.text('₹20'), findsNothing);

      // Rent Season option is preserved
      expect(find.text('Rent complete Season ₹100'), findsOneWidget);
    });

    testWidgets('Gallery section and its trailer are hidden on Series Details page', (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrapSeriesPage(
          seriesProvider: _MockSeriesProvider(series: testSeries),
          content: testContent,
        ),
      );
      await tester.pump();

      // Gallery header must not be rendered
      expect(find.text('Gallery'), findsNothing);
    });
  });

  group('Requirement 3 & 4: Rating & Review for Paid vs Unpaid Users', () {
    final testSeason = SeasonEntity(
      seasonId: 1,
      seasonNumber: 1,
      title: 'Season 1',
      description: 'First season',
      releaseDate: 0,
      price: 100,
      isSeasonPurchased: false,
      episodes: [
        EpisodeEntity(
          episodeId: 101,
          episodeNumber: 1,
          title: 'Episode One',
          description: 'Desc 1',
          runtime: 30,
          releaseDate: 0,
          price: 20,
          isFree: false,
          isPurchased: false,
          isLocked: true,
          videoUrl: '',
          posterUrl: 'https://example.com/ep1.jpg',
        ),
      ],
    );

    testWidgets('Rating & Review is hidden for unpaid users', (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final unpaidSeries = SeriesEntity(
        id: 10,
        title: 'Drama Series',
        description: 'Drama series description',
        posterUrl: 'https://example.com/series.jpg',
        seasons: [testSeason],
      );

      final unpaidContent = Content(
        id: 10,
        title: 'Drama Series',
        isRental: false,
      );

      await tester.pumpWidget(
        _wrapSeriesPage(
          seriesProvider: _MockSeriesProvider(series: unpaidSeries),
          content: unpaidContent,
        ),
      );
      await tester.pump();

      // Rating and reviews controls must NOT be displayed for unpaid users
      expect(find.text('Rate your experience'), findsNothing);
      expect(find.text('Your Feedback!'), findsNothing);
      expect(find.text('Submit'), findsNothing);
    });

    testWidgets('Rating & Review is displayed for paid users (content isRental = true)', (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final paidSeries = SeriesEntity(
        id: 10,
        title: 'Drama Series',
        description: 'Drama series description',
        posterUrl: 'https://example.com/series.jpg',
        seasons: [testSeason],
      );

      final paidContent = Content(
        id: 10,
        title: 'Drama Series',
        isRental: true, // User purchased the series!
      );

      await tester.pumpWidget(
        _wrapSeriesPage(
          seriesProvider: _MockSeriesProvider(series: paidSeries),
          content: paidContent,
        ),
      );
      await tester.pump();

      // Rating and reviews controls MUST be displayed for paid users
      expect(find.text('Rate your experience'), findsOneWidget);
      expect(find.text('Your Feedback!'), findsOneWidget);
    });

    testWidgets('Rating & Review is displayed when user purchased a season', (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final seasonPurchasedSeason = SeasonEntity(
        seasonId: 1,
        seasonNumber: 1,
        title: 'Season 1',
        description: 'First season',
        releaseDate: 0,
        price: 100,
        isSeasonPurchased: true, // User purchased this season!
        episodes: [
          EpisodeEntity(
            episodeId: 101,
            episodeNumber: 1,
            title: 'Episode One',
            description: 'Desc 1',
            runtime: 30,
            releaseDate: 0,
            price: 20,
            isFree: false,
            isPurchased: false,
            isLocked: false,
            videoUrl: '',
            posterUrl: 'https://example.com/ep1.jpg',
          ),
        ],
      );

      final paidSeasonSeries = SeriesEntity(
        id: 10,
        title: 'Drama Series',
        description: 'Drama series description',
        posterUrl: 'https://example.com/series.jpg',
        seasons: [seasonPurchasedSeason],
      );

      final content = Content(
        id: 10,
        title: 'Drama Series',
        isRental: false,
      );

      await tester.pumpWidget(
        _wrapSeriesPage(
          seriesProvider: _MockSeriesProvider(series: paidSeasonSeries),
          content: content,
        ),
      );
      await tester.pump();

      expect(find.text('Rate your experience'), findsOneWidget);
      expect(find.text('Your Feedback!'), findsOneWidget);
    });
  });

  group('Requirement 5: Cast & Crew UI Rendering and Resilience', () {
    testWidgets('renders Cast and Crew from Content fallback metadata without crashing', (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final season = SeasonEntity(
        seasonId: 1,
        seasonNumber: 1,
        title: 'Season 1',
        description: 'First season',
        releaseDate: 0,
        price: 100,
        isSeasonPurchased: false,
        episodes: [],
      );

      final series = SeriesEntity(
        id: 10,
        title: 'Drama Series',
        description: 'Drama series description',
        posterUrl: 'https://example.com/series.jpg',
        seasons: [season],
      );

      final content = Content(
        id: 10,
        title: 'Drama Series',
        isRental: false,
        castList: ['Alice Wonder', 'Bob Hope'],
        directorList: ['Charlie Brown'],
      );

      await tester.pumpWidget(
        _wrapSeriesPage(
          seriesProvider: _MockSeriesProvider(series: series),
          content: content,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // Verify Cast and Crew sections are displayed
      expect(find.text('Cast'), findsOneWidget);
      expect(find.text('Alice Wonder'), findsOneWidget);
      expect(find.text('Crew'), findsOneWidget);
      expect(find.text('Charlie Brown'), findsOneWidget);
    });

    testWidgets('gracefully handles empty Cast & Crew without rendering errors', (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final season = SeasonEntity(
        seasonId: 1,
        seasonNumber: 1,
        title: 'Season 1',
        description: 'First season',
        releaseDate: 0,
        price: 100,
        isSeasonPurchased: false,
        episodes: [],
      );

      final series = SeriesEntity(
        id: 10,
        title: 'Drama Series',
        description: 'Drama series description',
        posterUrl: 'https://example.com/series.jpg',
        seasons: [season],
      );

      final content = Content(
        id: 10,
        title: 'Drama Series',
        isRental: false,
        castList: [],
        directorList: [],
      );

      await tester.pumpWidget(
        _wrapSeriesPage(
          seriesProvider: _MockSeriesProvider(series: series),
          content: content,
        ),
      );
      await tester.pump();

      // Does not throw exceptions, neither Cast nor Crew is displayed
      expect(find.text('Cast'), findsNothing);
      expect(find.text('Crew'), findsNothing);
    });
  });

  group('Runtime Formatting: hh:mm:ss', () {
    testWidgets('displays episode runtime formatted as hh:mm:ss on mobile and TV', (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final season = SeasonEntity(
        seasonId: 1,
        seasonNumber: 1,
        title: 'Season 1',
        description: 'First season',
        releaseDate: 0,
        price: 100,
        isSeasonPurchased: false,
        episodes: [
          EpisodeEntity(
            episodeId: 101,
            episodeNumber: 1,
            title: 'Episode One',
            description: 'Desc 1',
            runtime: 45, // 45 minutes -> 00:45:00
            releaseDate: 0,
            price: 20,
            isFree: false,
            isPurchased: false,
            isLocked: true,
            videoUrl: '',
            posterUrl: 'https://example.com/ep1.jpg',
          ),
          EpisodeEntity(
            episodeId: 102,
            episodeNumber: 2,
            title: 'Episode Two',
            description: 'Desc 2',
            runtime: 75, // 75 minutes -> 01:15:00
            releaseDate: 0,
            price: 20,
            isFree: false,
            isPurchased: false,
            isLocked: true,
            videoUrl: '',
            posterUrl: 'https://example.com/ep2.jpg',
          ),
        ],
      );

      final series = SeriesEntity(
        id: 10,
        title: 'Drama Series',
        description: 'Drama series description',
        posterUrl: 'https://example.com/series.jpg',
        seasons: [season],
      );

      final content = Content(
        id: 10,
        title: 'Drama Series',
        isRental: false,
        runtime: 120, // 120 minutes -> 02:00:00
      );

      await tester.pumpWidget(
        _wrapSeriesPage(
          seriesProvider: _MockSeriesProvider(series: series),
          content: content,
        ),
      );
      await tester.pump();

      // Check episode runtimes in hh:mm:ss
      expect(find.text('Ep. 1 • 00:45:00'), findsOneWidget);
      expect(find.text('Ep. 2 • 01:15:00'), findsOneWidget);

      // Check series details table runtime in hh:mm:ss
      expect(find.text('02:00:00'), findsOneWidget);
    });
  });
}
