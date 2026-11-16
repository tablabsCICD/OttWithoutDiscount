// Movie Details page (iPhone layout):
//  * the scrollable content starts at, and is clipped to, the bottom edge of
//    the transparent app bar, so it never slides under the back button,
//    movie rating or age rating while scrolling;
//  * user reviews render as cards and degrade gracefully when the API omits
//    the name, profile image, date, rating or review text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/pages/movie%20details%20page/MovieDetailsPage.dart';
import 'package:ott/app/pages/movie%20details%20page/component/review_list_card.dart';
import 'package:ott/app/pages/watchlist%20page/component/DisplayTrailer.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/provider/offline_download_provider.dart';
import 'package:ott/app/provider/playMediaProvider.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/provider/videoProvider.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/models/response/getRatingsAndReview.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

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

class _MockVideoProvider extends VideoProvider {
  _MockVideoProvider(this._reviews);
  final List<Review> _reviews;

  @override
  List<Review> get reviewList => _reviews;

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

const _longText =
    'An absolutely gripping story from start to finish. The performances '
    'are outstanding, the background score lifts every scene and the '
    'cinematography is breathtaking. The second half drags slightly, but '
    'the climax more than makes up for it. Highly recommended for anyone '
    'who enjoys thoughtful, character driven cinema with a strong message. '
    'I would happily watch it again with family and friends this weekend.';

final _reviews = <Review>[
  Review(
    reviewId: 1,
    username: 'Priya Sharma',
    rating: 4,
    createdAt: DateTime(2026, 10, 12, 18, 30).millisecondsSinceEpoch,
    title: _longText,
    comment: _longText,
  ),
  // Missing name, image, date, rating and text.
  Review(reviewId: 2, username: 'null null'),
  // Text only in `comment`.
  Review(reviewId: 3, username: 'Arjun', rating: 5, comment: 'Loved it!'),
];

Widget _app() {
  final content = Content(
    id: 101,
    title: 'Cinematic Movie',
    type: 'movie',
    ratings: 4.2,
    ageRating: 'U/A',
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DashboardProvider>.value(
          value: _MockDashboardProvider(content)),
      ChangeNotifierProvider<VideoProvider>(
          create: (_) => _MockVideoProvider(_reviews)),
      ChangeNotifierProvider<OfflineDownloadProvider>(
          create: (_) => _MockOfflineDownloadProvider()),
      ChangeNotifierProvider<BookmarkProvider>(
          create: (_) => _MockBookmarkProvider()),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<PlayMediaProvider>(
          create: (_) => PlayMediaProvider()),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MovieDetailsPage(movieId: 101),
    ),
  );
}

/// iPhone 16 Pro–like logical size with a Dynamic Island safe area.
void _setIphone(WidgetTester tester, {double topInset = 59}) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.padding = FakeViewPadding(top: topInset * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);
}

Finder get _contentScrollView => find
    .ancestor(
      of: find.byType(TrailerPreview),
      matching: find.byType(SingleChildScrollView),
    )
    .first;

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('Movie details app bar boundary', () {
    for (final inset in [20.0, 47.0, 59.0]) {
      testWidgets('content starts below the app bar (top inset $inset)',
          (tester) async {
        _setIphone(tester, topInset: inset);
        await _pumpPage(tester);

        final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
        expect(appBarBottom, inset + FilmytellAppBarMetrics.compact);

        final clip = find
            .ancestor(of: _contentScrollView, matching: find.byType(ClipRect))
            .first;
        expect(tester.getRect(clip).top, appBarBottom);
        expect(tester.getRect(find.byType(TrailerPreview)).top,
            greaterThanOrEqualTo(appBarBottom));

        await tester.pump(const Duration(seconds: 4));
      });
    }

    testWidgets('scrolling keeps the app bar fixed and clips content under it',
        (tester) async {
      _setIphone(tester);
      await _pumpPage(tester);

      final appBarRect = tester.getRect(find.byType(AppBar));
      final backButton = find.byType(BackButton);
      final ageBadge = find.descendant(
          of: find.byType(AppBar), matching: find.text('U/A'));

      await tester.drag(_contentScrollView, const Offset(0, -400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // App bar and its contents did not move.
      expect(tester.getRect(find.byType(AppBar)), appBarRect);
      if (backButton.evaluate().isNotEmpty) {
        expect(tester.getRect(backButton).top,
            greaterThanOrEqualTo(appBarRect.top));
      }
      if (ageBadge.evaluate().isNotEmpty) {
        expect(tester.getRect(ageBadge).bottom,
            lessThanOrEqualTo(appBarRect.bottom));
      }

      // The trailer scrolled up past the app bar edge, but the clip that
      // paints it still starts at that edge.
      expect(tester.getRect(find.byType(TrailerPreview)).top,
          lessThan(appBarRect.bottom));
      final clip = find
          .ancestor(of: _contentScrollView, matching: find.byType(ClipRect))
          .first;
      expect(tester.getRect(clip).top, appBarRect.bottom);

      // Scroll back down: content returns to its original position.
      await tester.drag(_contentScrollView, const Offset(0, 1000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getRect(find.byType(TrailerPreview)).top,
          greaterThanOrEqualTo(appBarRect.bottom));

      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Review list cards', () {
    testWidgets('render real data and handle missing fields', (tester) async {
      _setIphone(tester);
      await _pumpPage(tester);
      await tester.scrollUntilVisible(
        find.byType(ReviewListCard).last,
        300,
        scrollable: find
            .descendant(of: _contentScrollView, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pump();

      expect(find.byType(ReviewListCard), findsNWidgets(3));
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('12 Oct 2026, 6:30 PM'), findsOneWidget);
      // Missing name falls back to the localized anonymous label.
      expect(find.text('Anonymous User'), findsOneWidget);
      // Text stored only in `comment` is shown.
      expect(find.text('Loved it!'), findsOneWidget);
      // No literal "null" leaks into the UI.
      expect(find.textContaining('null'), findsNothing);

      // Star rows only for reviews that have a rating: 4 + 5 filled.
      final cards = find.byType(ReviewListCard);
      int filledStars(int i) => find
          .descendant(of: cards.at(i), matching: find.byIcon(Icons.star_rounded))
          .evaluate()
          .length;
      int allStars(int i) =>
          filledStars(i) +
          find
              .descendant(
                  of: cards.at(i),
                  matching: find.byIcon(Icons.star_outline_rounded))
              .evaluate()
              .length;
      expect(filledStars(0), 4);
      expect(allStars(0), 5);
      expect(allStars(1), 0);
      expect(filledStars(2), 5);

      // Placeholder avatars: initial for named users, icon for anonymous.
      expect(
          find.descendant(of: cards.at(0), matching: find.text('P')),
          findsOneWidget);
      expect(
          find.descendant(
              of: cards.at(1), matching: find.byIcon(Icons.person_rounded)),
          findsOneWidget);

      // Long review collapses with Read more, expands, and collapses again.
      final readMore = find.descendant(
          of: cards.at(0), matching: find.text('Read More'));
      expect(readMore, findsOneWidget);
      await tester.ensureVisible(readMore);
      await tester.tap(readMore);
      await tester.pump();
      expect(
          find.descendant(of: cards.at(0), matching: find.text('Read Less')),
          findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('narrow iPhone width does not overflow', (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.padding = const FakeViewPadding(top: 20 * 2);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            children: [
              ReviewListCard(
                review: Review(
                  username:
                      'A very long user display name that keeps on going forever',
                  rating: 3,
                  createdAt: 0,
                  title: _longText,
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
