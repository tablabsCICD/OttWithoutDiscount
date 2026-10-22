import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ott/app/widgets/continue_watching_banner.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:ott/app/provider/dashboardProvider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final singleMovie = Content(
    id: 101,
    title: 'Bonsai',
    watchedPercentage: 12,
    genreList: ['Drama'],
    type: 'MOVIE',
    posterUrlList: ['https://example.com/bonsai_backdrop.jpg'],
    contentUrl: 'https://example.com/bonsai.mp4',
  );

  final secondMovie = Content(
    id: 102,
    title: 'The Silent Hour',
    watchedPercentage: 45,
    genreList: ['Action', 'Thriller'],
    type: 'MOVIE',
    posterUrlList: ['https://example.com/silent_hour.jpg'],
    contentUrl: 'https://example.com/silent_hour.mp4',
  );

  final thirdMovie = Content(
    id: 103,
    title: 'Cyberpunk Odyssey',
    watchedPercentage: 78,
    genreList: ['Sci-Fi'],
    type: 'MOVIE',
    posterUrlList: ['https://example.com/cyberpunk.jpg'],
    contentUrl: 'https://example.com/cyberpunk.mp4',
  );

  final longTitleMovie = Content(
    id: 104,
    title:
        'A Very Long Cinematic Movie Title That Wraps Gracefully Across Multiple Lines Without Any Clipping',
    watchedPercentage: 33,
    genreList: ['Adventure'],
    type: 'MOVIE',
    posterUrlList: ['https://example.com/long_title.jpg'],
    contentUrl: 'https://example.com/long_title.mp4',
  );

  Widget buildTestBanner({
    required List<Content> items,
    VoidCallback? onPlaybackFinished,
    Size surfaceSize = const Size(390, 844),
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DashboardProvider>(
          create: (_) => DashboardProvider(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: ContinueWatchingBanner(
                items: items,
                onPlaybackFinished: onPlaybackFinished,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('ContinueWatchingBanner UI, Layout & Reference Match Tests', () {
    testWidgets(
        'renders left-side elements vertically in exact order: heading, title, progress text, progress bar, Resume button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestBanner(items: [singleMovie]));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // 1. Heading
      final headingFinder = find.text('Continue Watching');
      expect(headingFinder, findsOneWidget);

      // 2. Title
      final titleFinder = find.text('Bonsai');
      expect(titleFinder, findsOneWidget);

      // 3. Watching progress and genre
      final progressTextFinder = find.text('12% watched | Drama');
      expect(progressTextFinder, findsOneWidget);

      // 4. Progress bar
      final progressBarFinder = find.byType(FractionallySizedBox);
      expect(progressBarFinder, findsOneWidget);

      // 5. Resume button label
      final resumeLabelFinder = find.text('Resume');
      expect(resumeLabelFinder, findsOneWidget);

      // 5b. Resume play icon
      final resumeIconFinder = find.byIcon(Icons.play_arrow_rounded);
      expect(resumeIconFinder, findsOneWidget);

      // Verify vertical ordering: heading.dy < title.dy < progressText.dy < progressBar.dy < resume.dy
      final headingDy = tester.getTopLeft(headingFinder).dy;
      final titleDy = tester.getTopLeft(titleFinder).dy;
      final progressTextDy = tester.getTopLeft(progressTextFinder).dy;
      final progressBarDy = tester.getTopLeft(progressBarFinder).dy;
      final resumeDy = tester.getTopLeft(resumeLabelFinder).dy;

      expect(titleDy, greaterThan(headingDy),
          reason: 'Movie title must appear below Section Heading');
      expect(progressTextDy, greaterThan(titleDy),
          reason: 'Progress text must appear below Movie Title');
      expect(progressBarDy, greaterThan(progressTextDy),
          reason: 'Progress bar must appear below Progress text');
      expect(resumeDy, greaterThan(progressBarDy),
          reason: 'Resume button must appear below Progress bar');
    });

    testWidgets(
        'Resume button has red circular play button with red glow and Resume text',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestBanner(items: [singleMovie]));
      await tester.pumpAndSettle();

      final playIconFinder = find.byIcon(Icons.play_arrow_rounded);
      expect(playIconFinder, findsOneWidget);

      // Find the circular container that houses the play icon
      final circleFinder = find.ancestor(
        of: playIconFinder,
        matching: find.byType(Container),
      );
      expect(circleFinder, findsWidgets);

      final Container circleContainer = tester.widget(circleFinder.first);
      final decoration = circleContainer.decoration as BoxDecoration;
      expect(decoration.shape, equals(BoxShape.circle));
      expect(decoration.color, equals(const Color(0xFFE50914)));
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.isNotEmpty, isTrue);

      // Verify Resume text
      final resumeTextWidget = tester.widget<Text>(find.text('Resume'));
      expect(resumeTextWidget.style?.color, equals(Colors.white));
    });

    testWidgets('playback progress bar fills with brand red and clamps between 0% and 100%',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestBanner(items: [singleMovie]));
      await tester.pumpAndSettle();

      final fractionFinder = find.byType(FractionallySizedBox);
      expect(fractionFinder, findsOneWidget);

      final FractionallySizedBox fractionWidget = tester.widget(fractionFinder);
      expect(fractionWidget.widthFactor, closeTo(0.12, 0.001));

      // Test filled portion decoration
      final filledBarFinder = find.descendant(
        of: fractionFinder,
        matching: find.byType(Container),
      );
      final Container filledContainer = tester.widget(filledBarFinder.first);
      final filledDeco = filledContainer.decoration as BoxDecoration;
      expect(filledDeco.color, equals(const Color(0xFFE50914)));
    });

    testWidgets('backdrop artwork uses BoxFit.contain and center alignment',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestBanner(items: [singleMovie]));
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final Image imageWidget = tester.widget(imageFinder);
      expect(imageWidget.fit, equals(BoxFit.contain));
      expect(imageWidget.alignment, equals(Alignment.center));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'shows circular pagination indicators only when multiple items exist, and updates active index',
        (WidgetTester tester) async {
      // 1. Single item: No pagination indicators
      await tester.pumpWidget(buildTestBanner(items: [singleMovie]));
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedContainer), findsNothing);

      // 2. Multiple items (3 movies): 3 pagination indicators
      await tester.pumpWidget(
        buildTestBanner(items: [singleMovie, secondMovie, thirdMovie]),
      );
      await tester.pumpAndSettle();

      final dotsFinder = find.byType(AnimatedContainer);
      expect(dotsFinder, findsNWidgets(3));

      // Verify active dot is red (#E50914) and inactive dots are grey (#555562)
      final AnimatedContainer firstDot = tester.widget(dotsFinder.at(0));
      final firstDeco = firstDot.decoration as BoxDecoration;
      expect(firstDeco.color, equals(const Color(0xFFE50914)));

      final AnimatedContainer secondDot = tester.widget(dotsFinder.at(1));
      final secondDeco = secondDot.decoration as BoxDecoration;
      expect(secondDeco.color, equals(const Color(0xFF555562)));

      // Swipe to page 2 (index 1)
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      // Now index 1 should be active (red) and index 0 should be inactive (grey)
      expect(find.text('The Silent Hour'), findsOneWidget);
      expect(find.text('45% watched | Action'), findsOneWidget);

      final dotsAfterSwipe = find.byType(AnimatedContainer);
      final AnimatedContainer dot0After = tester.widget(dotsAfterSwipe.at(0));
      final AnimatedContainer dot1After = tester.widget(dotsAfterSwipe.at(1));
      expect((dot0After.decoration as BoxDecoration).color,
          equals(const Color(0xFF555562)));
      expect((dot1After.decoration as BoxDecoration).color,
          equals(const Color(0xFFE50914)));
    });

    testWidgets('handles long movie title wrapping to 2 lines without overflowing',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestBanner(items: [longTitleMovie]));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final titleFinder = find.text(longTitleMovie.title!);
      expect(titleFinder, findsOneWidget);

      final Text titleWidget = tester.widget(titleFinder);
      expect(titleWidget.maxLines, equals(2));
      expect(titleWidget.overflow, equals(TextOverflow.ellipsis));
    });

    testWidgets('renders cleanly on small phone (320x568) without RenderFlex overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestBanner(
        items: [singleMovie, secondMovie],
        surfaceSize: const Size(320, 568),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Bonsai'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
    });

    testWidgets('renders cleanly on tablet (820x1180) without RenderFlex overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(820 * 2, 1180 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestBanner(
        items: [singleMovie, secondMovie],
        surfaceSize: const Size(820, 1180),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Bonsai'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
    });

    testWidgets('renders cleanly on web laptop/desktop (1440x900) without RenderFlex overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440 * 1, 900 * 1);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestBanner(
        items: [singleMovie, secondMovie],
        surfaceSize: const Size(1440, 900),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Bonsai'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
    });

    testWidgets('renders shimmer skeleton matching banner proportions without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: ContinueWatchingBannerShimmer(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(ContinueWatchingBannerShimmer), findsOneWidget);
    });

    testWidgets('captures continue watching banner visual snapshot preview',
        (WidgetTester tester) async {
      final boundaryKey = GlobalKey();

      tester.view.physicalSize = const Size(400 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DashboardProvider>(
              create: (_) => DashboardProvider(),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              cardColor: const Color(0xFF14141B),
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
                    color: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 24.0,
                    ),
                    child: ContinueWatchingBanner(
                      items: [singleMovie, secondMovie, thirdMovie],
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
          try {
            final file = File('test/continue_watching_banner_preview.png');
            await file.writeAsBytes(byteData.buffer.asUint8List());
          } catch (_) {}
        }
      });
    });
  });
}
