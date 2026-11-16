// The four content detail pages share one compact red app bar:
//   Movie & Short Film  -> MovieDetailsPage
//   Series & Mini Series -> SeriesDetailsPage
// Same height, colour, back button, title and star rating; no age rating in
// the bar (it stays in the page content); content never scrolls underneath.
import 'package:flutter/material.dart';
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
import 'package:ott/app/widgets/content_detail_app_bar.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/models/seriesModel.dart';
import 'package:ott/data/themes/custom_theme.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

const _red = Color(0xFFCD2027); // AppTheme primaryColor (light & dark)
const _statusBar = 59.0;
const _barBottom = _statusBar + FilmytellAppBarMetrics.compact;

// ---------------------------------------------------------------- mocks

class _MockDashboardProvider extends DashboardProvider {
  _MockDashboardProvider(this._content);
  final Content _content;
  @override
  Content get content => _content;
  @override
  Future<Content?> getContentById(int id) async => _content;
  @override
  Future<void> getCastByContentId(int id) async {}
  @override
  Future<void> getContinueWatchedMovieList(String type,
      {bool forceRefresh = false}) async {}
}

class _MockSeriesProvider extends SeriesProvider {
  _MockSeriesProvider(this._series);
  final SeriesEntity _series;
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

// ------------------------------------------------------------- fixtures

SeriesEntity _series(String title) => SeriesEntity(
      id: 88,
      title: title,
      description: 'desc',
      posterUrl: 'https://example.com/poster.jpg',
      seasons: [
        SeasonEntity(
          seasonId: 1,
          title: 'Season 1',
          seasonNumber: 1,
          description: 'Season 1',
          releaseDate: 0,
          price: 0,
          isSeasonPurchased: true,
          episodes: [
            for (var i = 1; i <= 8; i++)
              EpisodeEntity(
                episodeId: i,
                title: 'Episode $i',
                description: 'Episode $i',
                episodeNumber: i,
                runtime: 40,
                releaseDate: 0,
                posterUrl: 'https://example.com/ep$i.jpg',
                videoUrl: 'https://example.com/ep$i.mp4',
                isPurchased: true,
                isFree: false,
                isLocked: false,
                price: 0,
              ),
          ],
        ),
      ],
    );

Widget _providers(Widget home,
    {Content? dashboardContent, SeriesEntity? series}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DashboardProvider>.value(
          value: _MockDashboardProvider(dashboardContent ?? Content(id: 1))),
      if (series != null)
        ChangeNotifierProvider<SeriesProvider>.value(
            value: _MockSeriesProvider(series)),
      ChangeNotifierProvider<VideoProvider>(create: (_) => _MockVideoProvider()),
      ChangeNotifierProvider<OfflineDownloadProvider>(
          create: (_) => _MockOfflineDownloadProvider()),
      ChangeNotifierProvider<BookmarkProvider>(
          create: (_) => _MockBookmarkProvider()),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<PlayMediaProvider>(
          create: (_) => PlayMediaProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme, // as in main.dart
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Detail pages are always pushed on top of another screen, so the
      // back button is shown — mirror that here.
      initialRoute: '/detail',
      routes: {
        '/': (_) => const Scaffold(),
        '/detail': (_) => home,
      },
    ),
  );
}

Widget _moviePage({required String type, required String title}) {
  final content = Content(
    id: 101,
    title: title,
    type: type,
    ratings: 4.2,
    ageRating: 'U/A',
    teaserUrl: 'https://example.com/trailer.mp4',
  );
  return _providers(MovieDetailsPage(movieId: 101, contentType: type),
      dashboardContent: content);
}

Widget _seriesPage({required String type, required String title}) {
  final series = _series(title);
  return _providers(
    SeriesDetailsPage(
      seriesId: series.id,
      content: Content(
        id: series.id,
        title: title,
        type: type,
        ratings: 4.2,
        ageRating: 'U/A',
        teaserUrl: 'https://example.com/trailer.mp4',
      ),
    ),
    series: series,
  );
}

void _setIphone(WidgetTester tester, {Size size = const Size(393, 852)}) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = size * 3;
  tester.view.padding =
      const FakeViewPadding(top: _statusBar * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Geometry + styling snapshot of the detail app bar on screen.
Map<String, Object?> _barSnapshot(WidgetTester tester) {
  final barFinder = find.byType(ContentDetailAppBar);
  expect(barFinder, findsOneWidget);
  final appBar = tester.widget<AppBar>(
      find.descendant(of: barFinder, matching: find.byType(AppBar)));
  final back = find.descendant(of: barFinder, matching: find.byType(BackButton));
  return {
    'rect': tester.getRect(barFinder),
    'color': appBar.backgroundColor,
    'toolbarHeight': appBar.toolbarHeight,
    'centerTitle': appBar.centerTitle,
    'back': back.evaluate().isEmpty ? null : tester.getRect(back),
    'starSize': find
            .descendant(of: barFinder, matching: find.byIcon(Icons.star_rounded))
            .evaluate()
            .isEmpty
        ? null
        : tester
            .widget<Icon>(find.descendant(
                of: barFinder, matching: find.byIcon(Icons.star_rounded)))
            .size,
  };
}

final _pages = <String, Widget Function(String title)>{
  'Movie': (t) => _moviePage(type: 'MOVIE', title: t),
  'Short Film': (t) => _moviePage(type: 'SHORT_FILM', title: t),
  'Series': (t) => _seriesPage(type: 'SERIES', title: t),
  'Mini Series': (t) => _seriesPage(type: 'MINI SERIES', title: t),
};

// ---------------------------------------------------------------- tests

void main() {
  group('ContentDetailAppBar', () {
    Future<void> pumpBar(WidgetTester tester, ContentDetailAppBar bar,
        {double width = 393}) async {
      _setIphone(tester, size: Size(width, 852));
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(primaryColor: _red),
        home: Scaffold(appBar: bar, body: const SizedBox()),
      ));
    }

    testWidgets('compact red bar: white back button, title and star rating',
        (tester) async {
      await pumpBar(
          tester, const ContentDetailAppBar(title: 'Dharau', rating: 4.5));
      expect(tester.getRect(find.byType(AppBar)).height, _barBottom);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, _red);
      expect(appBar.foregroundColor, Colors.white);
      expect(appBar.iconTheme?.color, Colors.white);
      expect(appBar.centerTitle, isFalse);
      expect(find.text('Dharau'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      final star = tester.widget<Icon>(find.byIcon(Icons.star_rounded));
      expect(star.color, Colors.white);
      expect(star.size, ContentDetailAppBar.ratingIconSize);
      final ratingText = tester.widget<Text>(find.text('4.5'));
      expect(ratingText.style?.color, Colors.white);
    });

    testWidgets('formats API ratings with one decimal', (tester) async {
      for (final entry in {5.0: '5.0', 4.0: '4.0', 3.5: '3.5', 2.0: '2.0',
          4.25: '4.3'}.entries) {
        await pumpBar(
            tester, ContentDetailAppBar(title: 'T', rating: entry.key));
        expect(find.text(entry.value), findsOneWidget,
            reason: '${entry.key} -> ${entry.value}');
      }
    });

    testWidgets('missing or zero rating is hidden without layout issues',
        (tester) async {
      for (final rating in <double?>[null, 0]) {
        await pumpBar(
            tester, ContentDetailAppBar(title: 'No Rating', rating: rating));
        expect(find.byIcon(Icons.star_rounded), findsNothing);
        expect(find.text('No Rating'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('title sits next to the back button and never overlaps it',
        (tester) async {
      _setIphone(tester, size: const Size(320, 568));
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(primaryColor: _red),
        home: Navigator(
          onGenerateInitialRoutes: (_, __) => [
            MaterialPageRoute<void>(builder: (_) => const SizedBox()),
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                appBar: ContentDetailAppBar(
                  title: 'An Extremely Long Mini Series Title That Will Never '
                      'Fit Inside The Compact Toolbar Of A Small iPhone',
                  rating: 3.5,
                ),
              ),
            ),
          ],
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);

      final text = tester.widget<Text>(find.textContaining('Extremely Long'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);

      final back = tester.getRect(find.byType(BackButton));
      final title = tester.getRect(find.textContaining('Extremely Long'));
      expect(title.left, greaterThanOrEqualTo(back.right));
      expect(title.left - back.right, lessThan(8),
          reason: 'title starts right after the back button');
      final star = tester.getRect(find.byIcon(Icons.star_rounded));
      expect(title.right, lessThanOrEqualTo(star.left),
          reason: 'title never overlaps the rating');
      expect(find.text('3.5'), findsOneWidget, reason: 'rating stays visible');
      expect(tester.getRect(find.text('3.5')).right, lessThanOrEqualTo(320));
      expect((title.center.dy - back.center.dy).abs(), lessThan(1),
          reason: 'vertically aligned');
    });

    testWidgets('back button pops the route', (tester) async {
      _setIphone(tester);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                appBar: ContentDetailAppBar(title: 'Detail'),
              ),
            )),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsNothing);
    });
  });

  group('All four detail pages use the identical app bar', () {
    final snapshots = <String, Map<String, Object?>>{};

    for (final entry in _pages.entries) {
      testWidgets('${entry.key} detail page', (tester) async {
        _setIphone(tester);
        await _pump(tester, entry.value('${entry.key} Title'));

        final snap = _barSnapshot(tester);
        snapshots[entry.key] = snap;

        expect(snap['color'], _red);
        expect(snap['toolbarHeight'], FilmytellAppBarMetrics.compact);
        expect((snap['rect'] as Rect).top, 0);
        expect((snap['rect'] as Rect).bottom, _barBottom);
        expect(snap['centerTitle'], isFalse);
        expect(snap['back'], isNotNull);
        // Actual API rating (4.2) in the bar, no age rating in the bar...
        final bar = find.byType(ContentDetailAppBar);
        expect(find.descendant(of: bar, matching: find.text('4.2')),
            findsOneWidget);
        expect(snap['starSize'], ContentDetailAppBar.ratingIconSize);
        expect(find.descendant(of: bar, matching: find.text('U/A')),
            findsNothing);
        // ...and age rating + rating still in the page content.
        expect(
            find.descendant(
                of: find.byType(Scrollable).first,
                matching: find.text('U/A', skipOffstage: false),
                skipOffstage: false),
            findsWidgets);
        expect(
            find.descendant(
                of: find.byType(Scrollable).first,
                matching: find.textContaining('4.2', skipOffstage: false),
                skipOffstage: false),
            findsWidgets);
        expect(
            find.descendant(
                of: find.byType(ContentDetailAppBar),
                matching: find.text('${entry.key} Title')),
            findsOneWidget);

        // Content (trailer) starts below the bar.
        expect(tester.getRect(find.byType(TrailerPreview).first).top,
            greaterThanOrEqualTo(_barBottom));

        // Scroll: the bar does not move, resize or get covered.
        final scrollable = find.byType(Scrollable).first;
        await tester.drag(scrollable, const Offset(0, -700));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.getRect(find.byType(ContentDetailAppBar)),
            snap['rect']);
        expect(tester.hitTestOnBinding(
                (snap['rect'] as Rect).center).path.any((e) =>
            e.target is RenderObject &&
            (e.target as RenderObject).debugCreator.toString().contains(
                'AppBar')), isTrue,
            reason: 'taps in the bar area must hit the bar, not content');

        await tester.drag(scrollable, const Offset(0, 1400));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.getRect(find.byType(ContentDetailAppBar)),
            snap['rect']);
        expect(tester.takeException(), isNull);

        await tester.pump(const Duration(seconds: 4));
      });
    }

    test('geometry and styling match across all four pages', () {
      expect(snapshots.keys,
          containsAll(['Movie', 'Short Film', 'Series', 'Mini Series']));
      final reference = snapshots['Movie']!;
      for (final entry in snapshots.entries) {
        for (final key in [
          'rect',
          'color',
          'toolbarHeight',
          'centerTitle',
          'starSize',
        ]) {
          expect(entry.value[key], reference[key],
              reason: '${entry.key} differs from Movie in $key');
        }
        final back = entry.value['back'] as Rect?;
        final refBack = reference['back'] as Rect?;
        if (back != null && refBack != null) {
          expect(back, refBack, reason: '${entry.key} back button position');
        }
      }
    });
  });

  testWidgets('iPhone landscape keeps the same compact red bar',
      (tester) async {
    _setIphone(tester, size: const Size(852, 393));
    await _pump(tester, _seriesPage(type: 'SERIES', title: 'Landscape'));
    final snap = _barSnapshot(tester);
    expect(snap['color'], _red);
    expect(snap['toolbarHeight'], FilmytellAppBarMetrics.compact);
    // Only one back button (the cinematic hero's own is hidden).
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });
}
