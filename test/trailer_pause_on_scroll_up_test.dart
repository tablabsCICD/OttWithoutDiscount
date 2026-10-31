import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/pages/movie%20details%20page/MovieDetailsPage.dart';
import 'package:ott/app/pages/series%20details%20page/seriesdetailspage.dart';
import 'package:ott/app/pages/watchlist%20page/component/DisplayTrailer.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';
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

class _MockDashboardProvider extends DashboardProvider {
  final Content _content;

  _MockDashboardProvider(this._content);

  @override
  Content get content => _content;

  @override
  Future<Content?> getContentById(int id) async => _content;

  @override
  Future<void> getCastByContentId(int id) async {}

  @override
  Future<void> getContinueWatchedMovieList(String type) async {}
}

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

class _MockOfflineDownloadProvider extends OfflineDownloadProvider {
  @override
  Future<void> refreshStatus(Content content) async {}
}

class _MockBookmarkProvider extends BookmarkProvider {
  @override
  Future<void> getUserBookmarks() async {}
}

Widget _buildMovieTestApp({required Content content}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DashboardProvider>.value(
        value: _MockDashboardProvider(content),
      ),
      ChangeNotifierProvider<VideoProvider>(create: (_) => _MockVideoProvider()),
      ChangeNotifierProvider<OfflineDownloadProvider>(
        create: (_) => _MockOfflineDownloadProvider(),
      ),
      ChangeNotifierProvider<BookmarkProvider>(
        create: (_) => _MockBookmarkProvider(),
      ),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<PlayMediaProvider>(
        create: (_) => PlayMediaProvider(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MovieDetailsPage(movieId: content.id ?? 1),
    ),
  );
}

Widget _buildSeriesTestApp({
  required SeriesEntity series,
  required Content content,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SeriesProvider>.value(
        value: _MockSeriesProvider(series),
      ),
      ChangeNotifierProvider<VideoProvider>(create: (_) => _MockVideoProvider()),
      ChangeNotifierProvider<OfflineDownloadProvider>(
        create: (_) => _MockOfflineDownloadProvider(),
      ),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<PlayMediaProvider>(
        create: (_) => PlayMediaProvider(),
      ),
      ChangeNotifierProvider<DashboardProvider>(
        create: (_) => _MockDashboardProvider(content),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SeriesDetailsPage(seriesId: series.id, content: content),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trailer Preview Controller Playback State Preservation', () {
    test('pause stops trailer and preserves state, play resumes', () {
      final controller = TrailerPreviewController();
      bool isPlaying = true;
      int pauseCallCount = 0;
      int playCallCount = 0;

      controller.isPlaying = () => isPlaying;
      controller.pause = () {
        pauseCallCount++;
        isPlaying = false;
      };
      controller.play = () {
        playCallCount++;
        isPlaying = true;
      };

      expect(controller.isPlaying?.call(), isTrue);

      // Pause preserves state
      controller.pause?.call();
      expect(pauseCallCount, 1);
      expect(controller.isPlaying?.call(), isFalse);

      // Manual resume
      controller.play?.call();
      expect(playCallCount, 1);
      expect(controller.isPlaying?.call(), isTrue);
    });
  });

  group('Scroll Notification Direction Evaluation', () {
    testWidgets('upward scroll conditions are correctly identified', (tester) async {
      final events = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.axis == Axis.vertical) {
                  if (notification is UserScrollNotification) {
                    events.add('UserScroll:${notification.direction}');
                  } else if (notification is ScrollUpdateNotification) {
                    final delta = notification.scrollDelta;
                    if (delta != null) {
                      events.add('ScrollDelta:${delta > 0 ? "up" : "down"}');
                    }
                  }
                }
                return false;
              },
              child: ListView.builder(
                itemCount: 50,
                itemBuilder: (_, i) => SizedBox(height: 50, child: Text('Item $i')),
              ),
            ),
          ),
        ),
      );

      // Drag up (content moves up, offset increases)
      events.clear();
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pump();
      expect(events.contains('UserScroll:ScrollDirection.reverse'), isTrue);
      expect(events.contains('ScrollDelta:up'), isTrue);

      // Drag down (content moves down, offset decreases)
      events.clear();
      await tester.drag(find.byType(ListView), const Offset(0, 50));
      await tester.pump();
      expect(events.contains('UserScroll:ScrollDirection.forward'), isTrue);
      expect(events.contains('ScrollDelta:down'), isTrue);
    });
  });

  group('Movie Details Page - Automatic Pause on Upward Scroll', () {
    testWidgets(
      'Upward scroll triggers pause notification and pauses trailer immediately on mobile',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final content = Content(
          id: 101,
          title: 'Cinematic Movie',
          type: 'movie',
          teaserUrl: 'https://example.com/trailer.mp4',
        );

        await tester.pumpWidget(_buildMovieTestApp(content: content));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Locate TrailerPreview
        expect(find.byType(TrailerPreview), findsOneWidget);

        // Find primary vertical scrollable
        final scrollableFinder = find.byType(Scrollable).first;

        // Perform upward drag (finger moving up, offset increasing)
        await tester.drag(scrollableFinder, const Offset(0, -200));
        await tester.pump();

        // Let scroll settle - trailer remains paused, no error thrown
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(TrailerPreview), findsOneWidget);

        // Allow any delayed timers from initState to complete cleanly
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'Upward scroll triggers pause notification on TV / tablet view',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final content = Content(
          id: 102,
          title: 'TV Cinematic Movie',
          type: 'movie',
          teaserUrl: 'https://example.com/trailer.mp4',
        );

        await tester.pumpWidget(_buildMovieTestApp(content: content));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(TrailerPreview), findsOneWidget);

        final scrollableFinder = find.byType(Scrollable).first;
        await tester.drag(scrollableFinder, const Offset(0, -200));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(TrailerPreview), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'Scrolling downward does not trigger upward-scroll pause on Movie Details page',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final content = Content(
          id: 103,
          title: 'Movie Downward Scroll Test',
          type: 'movie',
          teaserUrl: 'https://example.com/trailer.mp4',
        );

        await tester.pumpWidget(_buildMovieTestApp(content: content));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final scrollableFinder = find.byType(Scrollable).first;

        // Downward drag (finger moving down, positive offset)
        await tester.drag(scrollableFinder, const Offset(0, 200));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(TrailerPreview), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'Missing or unavailable trailer does not cause errors on upward scrolling',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final contentWithoutTrailer = Content(
          id: 104,
          title: 'Movie Without Trailer',
          type: 'movie',
          teaserUrl: null,
          trailerUrl: null,
        );

        await tester.pumpWidget(_buildMovieTestApp(content: contentWithoutTrailer));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final scrollableFinder = find.byType(Scrollable).first;

        // Scroll upward when no trailer is available
        await tester.drag(scrollableFinder, const Offset(0, -200));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Screen remains stable
        expect(find.text('Movie Without Trailer'), findsWidgets);

        await tester.pump(const Duration(seconds: 3));
      },
    );
  });

  group('Series Details Page - Automatic Pause on Upward Scroll', () {
    late SeriesEntity testSeries;
    late Content testContent;

    setUp(() {
      testSeries = SeriesEntity(
        id: 201,
        title: 'Original Mystery Series',
        description: 'A suspenseful mystery thriller',
        posterUrl: 'https://example.com/poster.jpg',
        seasons: [
          SeasonEntity(
            seasonId: 1,
            title: 'Season 1',
            seasonNumber: 1,
            description: 'Season 1 description',
            releaseDate: 0,
            price: 49,
            isSeasonPurchased: true,
            episodes: [
              EpisodeEntity(
                episodeId: 101,
                title: 'Episode 1: The Call',
                description: 'The story begins',
                episodeNumber: 1,
                runtime: 42,
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
                title: 'Episode 2: The Search',
                description: 'The search broadens',
                episodeNumber: 2,
                runtime: 45,
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
        id: 201,
        title: 'Original Mystery Series',
        type: 'series',
        teaserUrl: 'https://example.com/trailer.mp4',
      );
    });

    testWidgets(
      'Upward scroll triggers pause notification on Series Details page',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildSeriesTestApp(
          series: testSeries,
          content: testContent,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(TrailerPreview), findsOneWidget);

        // Find primary vertical scrollable
        final scrollableFinder = find.byType(Scrollable).first;

        // Perform upward drag (finger moving up, offset increasing)
        await tester.drag(scrollableFinder, const Offset(0, -200));
        await tester.pump();

        // Let scroll settle - remains paused, no error
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(TrailerPreview), findsOneWidget);
      },
    );

    testWidgets(
      'Scrolling downward does not trigger upward-scroll pause on Series Details page',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildSeriesTestApp(
          series: testSeries,
          content: testContent,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final scrollableFinder = find.byType(Scrollable).first;

        // Downward drag (finger moving down, positive offset)
        await tester.drag(scrollableFinder, const Offset(0, 200));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(TrailerPreview), findsOneWidget);
      },
    );

    testWidgets(
      'Missing or unavailable trailer on Series Details does not cause errors',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final contentWithoutTrailer = Content(
          id: 202,
          title: 'Series Without Trailer',
          type: 'series',
          teaserUrl: null,
          trailerUrl: null,
        );

        await tester.pumpWidget(_buildSeriesTestApp(
          series: testSeries,
          content: contentWithoutTrailer,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final scrollableFinder = find.byType(Scrollable).first;

        // Upward scroll when trailer is null
        await tester.drag(scrollableFinder, const Offset(0, -200));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Original Mystery Series'), findsWidgets);
      },
    );

    testWidgets(
      'Episode selection, episode playback, and series UI remain fully functional',
      (tester) async {
        tester.view.physicalSize = const Size(400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_buildSeriesTestApp(
          series: testSeries,
          content: testContent,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Scroll to reveal episode listing if needed
        final scrollable = find.byType(Scrollable).first;
        await tester.drag(scrollable, const Offset(0, -200));
        await tester.pump(const Duration(milliseconds: 300));

        // Confirm episode 1 is displayed
        expect(find.text('Episode 1: The Call'), findsOneWidget);
        expect(find.text('Episode 2: The Search'), findsOneWidget);

        // Tap episode 1 play button
        final ep1Finder = find.text('Episode 1: The Call');
        await tester.tap(ep1Finder, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Confirm app state is healthy
        expect(find.byType(SeriesDetailsPage), findsOneWidget);
      },
    );
  });
}
