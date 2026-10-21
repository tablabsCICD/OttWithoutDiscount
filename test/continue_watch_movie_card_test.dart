import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ott/app/widgets/continueWatchMovieCard.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    required Content movie,
    Size surfaceSize = const Size(390, 844),
  }) {
    return MultiProvider(
      providers: [
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
                movie: movie,
                enableTrailerPreview: false,
              ),
            ),
          ),
        ),
      ),
    );
  }

  final continueMovie = Content(
    id: 201,
    title: 'The March',
    watchedPercentage: 45,
    ratings: 4.8,
    ratingCount: 12,
    price: 49.0,
    releaseDate: '13-10-2026',
    genreList: ['Drama', 'Action'],
    type: 'movie',
    isRental: false,
    posterUrlList: ['https://example.com/poster.jpg'],
  );

  final longTitleMovie = Content(
    id: 202,
    title: 'An Extremely Long Movie Title That Should Be Truncated Gracefully With Ellipsis',
    watchedPercentage: 80,
    ratings: 4.0,
    ratingCount: 50,
    price: 99.0,
    releaseDate: '2026-05-15',
    genreList: ['Thriller', 'Suspense', 'Crime', 'Mystery'],
    type: 'movie',
    isRental: true,
    posterUrlList: ['https://example.com/portrait_poster.jpg'],
  );

  group('ContinueWatchMovieCard UI & Title Placement Tests', () {
    testWidgets('renders title below poster on standard phone (390x844) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(movie: continueMovie));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify title is rendered
      final titleFinder = find.text('The March');
      expect(titleFinder, findsOneWidget);

      // Verify percentage watched is rendered
      expect(find.textContaining('45% watched'), findsOneWidget);

      // Verify progress bar is rendered
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Verify title position is below the poster (Image widget or Expanded poster container)
      final posterFinder = find.byType(Expanded).first;
      final posterTopLeft = tester.getTopLeft(posterFinder);
      final titleTopLeft = tester.getTopLeft(titleFinder);

      expect(titleTopLeft.dy, greaterThan(posterTopLeft.dy),
          reason: 'Title should appear vertically below the poster');
    });

    testWidgets('renders cleanly on small phone (320x568) without RenderFlex overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(
        movie: continueMovie,
        surfaceSize: const Size(320, 568),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('The March'), findsOneWidget);
    });

    testWidgets('renders cleanly on large phone (430x932) without RenderFlex overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(430 * 3, 932 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(
        movie: continueMovie,
        surfaceSize: const Size(430, 932),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('The March'), findsOneWidget);
    });

    testWidgets('renders cleanly on tablet (820x1180) without RenderFlex overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(820 * 2, 1180 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(
        movie: continueMovie,
        surfaceSize: const Size(820, 1180),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('The March'), findsOneWidget);
    });

    testWidgets('handles long movie titles gracefully without overflowing',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(movie: longTitleMovie));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('An Extremely Long Movie Title'), findsOneWidget);
      expect(find.textContaining('80% watched'), findsOneWidget);
    });

    testWidgets('poster image uses BoxFit.contain to preserve aspect ratio',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(movie: continueMovie));
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final Image imageWidget = tester.widget(imageFinder);
      expect(imageWidget.fit, equals(BoxFit.contain));
      expect(imageWidget.alignment, equals(Alignment.center));
      await tester.pumpAndSettle();
    });

    testWidgets('captures continue watching card visual preview',
        (WidgetTester tester) async {
      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BookmarkProvider>(
              create: (_) => BookmarkProvider(),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              cardColor: const Color(0xFF1E1E1E),
              canvasColor: Colors.white,
              primaryColor: const Color(0xFFE50914),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.black,
                    child: SizedBox(
                      height: 220,
                      width: ContinueWatchMovieCard.itemExtent,
                      child: ContinueWatchMovieCard(
                        movie: continueMovie,
                        enableTrailerPreview: false,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final file = File(
              '/Users/swatinavale/.gemini/antigravity-ide/brain/4691e041-5989-4c52-90fb-9cf07b12d26f/continue_watch_card_preview.png');
          await file.writeAsBytes(byteData.buffer.asUint8List());
        }
      });
    });
  });
}
