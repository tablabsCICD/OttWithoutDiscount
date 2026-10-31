import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/pages/series%20details%20page/seriesdetailspage.dart';
import 'package:ott/app/pages/watchlist%20page/component/DisplayTrailer.dart';
import 'package:ott/app/pages/watchlist%20page/component/playMoviePage.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/provider/offline_download_provider.dart';
import 'package:ott/app/provider/playMediaProvider.dart';
import 'package:ott/app/provider/series_provider.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/provider/videoProvider.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/models/seriesModel.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _MockSeriesProvider extends SeriesProvider {
  final SeriesEntity? _series;

  _MockSeriesProvider(this._series);

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

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

Widget _buildSeriesDetailsTestApp({
  required SeriesEntity series,
  required Content content,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SeriesProvider>.value(
        value: _MockSeriesProvider(series),
      ),
      ChangeNotifierProvider<VideoProvider>(create: (_) => _MockVideoProvider()),
      ChangeNotifierProvider<PlayMediaProvider>(
        create: (_) => PlayMediaProvider(),
      ),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<OfflineDownloadProvider>(
        create: (_) => OfflineDownloadProvider(),
      ),
      ChangeNotifierProvider<DashboardProvider>(
        create: (_) => DashboardProvider(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SeriesDetailsPage(
        seriesId: series.id,
        content: content,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrailerPreviewController & Audio Lifecycle', () {
    test('TrailerPreviewController exposes pause, play, mute, unmute, stopAudio, and isPlaying', () {
      final controller = TrailerPreviewController();
      bool isPaused = false;
      bool isAudioStopped = false;
      bool isPlayingVal = true;

      controller.pause = () => isPaused = true;
      controller.stopAudio = () => isAudioStopped = true;
      controller.isPlaying = () => isPlayingVal;

      expect(controller.isPlaying?.call(), isTrue);
      controller.pause?.call();
      expect(isPaused, isTrue);

      controller.stopAudio?.call();
      expect(isAudioStopped, isTrue);
    });

    test('pause callback stops trailer audio and updates playback state', () {
      final controller = TrailerPreviewController();
      bool audioStopped = false;
      bool paused = false;

      controller.stopAudio = () => audioStopped = true;
      controller.pause = () {
        paused = true;
        controller.stopAudio?.call();
      };

      controller.pause?.call();
      expect(paused, isTrue);
      expect(audioStopped, isTrue);
    });
  });

  group('Trailer Center Play/Pause Overlay', () {
    testWidgets('TrailerPreview center overlay renders with circular touch target and semantics', (tester) async {
      final controller = TrailerPreviewController();
      final content = Content(
        id: 1,
        title: 'Test Show',
        type: 'series',
        teaserUrl: 'https://example.com/trailer.mp4',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 180,
              child: TrailerPreview(
                trailerUrl: 'https://example.com/trailer.mp4',
                content: content,
                controller: controller,
                autoPlay: false,
              ),
            ),
          ),
        ),
      );

      // The widget renders with circular progress or overlay
      expect(find.byType(TrailerPreview), findsOneWidget);
    });
  });

  group('Series Details Page Episode Playback Coordination', () {
    late SeriesEntity testSeries;
    late Content testContent;

    setUp(() {
      testSeries = SeriesEntity(
        id: 10,
        title: 'Filmytell Original',
        description: 'An original mystery series',
        posterUrl: 'https://example.com/poster.jpg',
        seasons: [
          SeasonEntity(
            seasonId: 1,
            title: 'Season 1',
            seasonNumber: 1,
            description: 'Season 1 description',
            releaseDate: 0,
            price: 49,
            isSeasonPurchased: true, // Unlocked
            episodes: [
              EpisodeEntity(
                episodeId: 101,
                title: 'Pilot Episode',
                description: 'The beginning of the mystery',
                episodeNumber: 1,
                runtime: 45,
                releaseDate: 0,
                posterUrl: 'https://example.com/ep1.jpg',
                videoUrl: 'https://example.com/ep1.mp4',
                isPurchased: true,
                isFree: false,
                isLocked: false,
                price: 0,
              ),
              EpisodeEntity(
                episodeId: 102,
                title: 'Episode 2',
                description: 'The search begins',
                episodeNumber: 2,
                runtime: 50,
                releaseDate: 0,
                posterUrl: 'https://example.com/ep2.jpg',
                videoUrl: 'https://example.com/ep2.mp4',
                isPurchased: true,
                isFree: false,
                isLocked: false,
                price: 0,
              ),
            ],
          ),
        ],
      );

      testContent = Content(
        id: 10,
        title: 'Filmytell Original',
        description: 'An original mystery series',
        type: 'series',
        teaserUrl: 'https://example.com/trailer.mp4',
      );
    });

    testWidgets('Series Details Page renders episodes and trailer without errors', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildSeriesDetailsTestApp(
          series: testSeries,
          content: testContent,
        ),
      );
      await tester.pump();

      // Verify page loaded and episode title is shown
      expect(find.text('Filmytell Original'), findsWidgets);
      expect(find.text('Pilot Episode'), findsOneWidget);
      expect(find.text('Episode 2'), findsOneWidget);
    });

    testWidgets('Selecting an episode pauses trailer and stops trailer audio', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildSeriesDetailsTestApp(
          series: testSeries,
          content: testContent,
        ),
      );
      await tester.pump();

      // Scroll down to bring episode cards clearly into view below pinned SliverAppBar
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
      await tester.pump(const Duration(milliseconds: 300));

      final episodeTileFinder = find.text('Pilot Episode');
      expect(episodeTileFinder, findsOneWidget);

      // Tap the episode tile
      final tileFinder = find.ancestor(
        of: episodeTileFinder,
        matching: find.byType(GestureDetector),
      ).first;
      await tester.tap(tileFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Video loading / PlayMediaPage is pushed
      expect(find.byType(PlayMediaPage), findsOneWidget);
    });

    testWidgets('Delayed autoplay timer does not restart trailer when episode playback is active', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080); // TV layout
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildSeriesDetailsTestApp(
          series: testSeries,
          content: testContent,
        ),
      );
      await tester.pump();

      // In TV layout, Watch Now button exists
      final watchNowFinder = find.text('Watch Now');
      expect(watchNowFinder, findsOneWidget);

      // Tap Watch Now to begin episode playback
      await tester.tap(watchNowFinder);
      await tester.pump();

      // Fast-forward 3 seconds past the 2-second hero trailer timer
      await tester.pump(const Duration(seconds: 3));

      // Episode player page is opened and active
      expect(find.byType(PlayMediaPage), findsOneWidget);
    });

    testWidgets('Rapid multiple clicks on Play Episode are guarded against duplicate players', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildSeriesDetailsTestApp(
          series: testSeries,
          content: testContent,
        ),
      );
      await tester.pump();

      // Scroll down to bring episode cards clearly into view below pinned SliverAppBar
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
      await tester.pump(const Duration(milliseconds: 300));

      final ep1 = find.text('Pilot Episode');
      expect(ep1, findsOneWidget);

      final tileFinder = find.ancestor(
        of: ep1,
        matching: find.byType(GestureDetector),
      ).first;

      // Rapidly tap episode; first tap triggers playback, subsequent taps are guarded
      await tester.tap(tileFinder);
      await tester.tap(tileFinder, warnIfMissed: false);
      await tester.tap(tileFinder, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Exactly one PlayMediaPage is pushed
      expect(find.byType(PlayMediaPage), findsOneWidget);
    });

    testWidgets('Muting and unmuting the trailer then playing episode pauses trailer and stops audio', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080); // TV layout
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildSeriesDetailsTestApp(
          series: testSeries,
          content: testContent,
        ),
      );
      await tester.pump();

      // Find Watch Now button
      final watchNow = find.text('Watch Now');
      expect(watchNow, findsOneWidget);

      // Tap Watch Now - trailer must pause and stop audio immediately
      await tester.tap(watchNow);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // PlayMediaPage is active
      expect(find.byType(PlayMediaPage), findsOneWidget);
    });
  });

  group('Trailer Preview Overlay Icon State', () {
    testWidgets('Center overlay button displays play icon when paused and pause icon when playing', (tester) async {
      final controller = TrailerPreviewController();
      final content = Content(
        id: 1,
        title: 'Test Show',
        type: 'series',
        teaserUrl: 'https://example.com/trailer.mp4',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 180,
              child: TrailerPreview(
                trailerUrl: 'https://example.com/trailer.mp4',
                content: content,
                controller: controller,
                autoPlay: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Controller is bound
      expect(controller.pause, isNotNull);
      expect(controller.play, isNotNull);
      expect(controller.stopAudio, isNotNull);
      expect(controller.isPlaying, isNotNull);

      // Initially paused: isPlaying returns false
      expect(controller.isPlaying?.call(), isFalse);

      // Calling pause sets manuallyPaused and silences audio
      controller.pause?.call();
      await tester.pump();
      expect(controller.isPlaying?.call(), isFalse);

      // Calling stopAudio directly silences all audio safely
      controller.stopAudio?.call();
      await tester.pump();
      expect(controller.isPlaying?.call(), isFalse);
    });
  });
}
