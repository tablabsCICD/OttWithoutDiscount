import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ott/app/widgets/movieCard.dart';
import 'package:ott/app/widgets/continueWatchMovieCard.dart';
import 'package:ott/app/widgets/responsive_poster_image.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';
import 'package:ott/app/provider/onboarding_tour_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ResponsivePosterImage.dimensionCache.clear();
    ResponsivePosterImage.aspectRatioCache.clear();
  });

  Widget buildMovieCardHost({
    required Content movie,
    double? cardWidth,
    double? cardMargin = 0,
    Size surfaceSize = const Size(390, 844),
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BookmarkProvider>(
          create: (_) => BookmarkProvider(),
        ),
        ChangeNotifierProvider<OnboardingTourProvider>(
          create: (_) => OnboardingTourProvider(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: surfaceSize),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                height: MovieCard.standardHeight,
                child: MovieCard(
                  movie: movie,
                  cardWidth: cardWidth,
                  cardMargin: cardMargin,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildContinueWatchCardHost({
    required Content movie,
    Size surfaceSize = const Size(390, 844),
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BookmarkProvider>(
          create: (_) => BookmarkProvider(),
        ),
        ChangeNotifierProvider<OnboardingTourProvider>(
          create: (_) => OnboardingTourProvider(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: surfaceSize),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                height: ContinueWatchMovieCard.standardHeight,
                width: ContinueWatchMovieCard.itemExtent,
                child: ContinueWatchMovieCard(
                  movie: movie,
                  enableTrailerPreview: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('1. Aspect Ratio Discovery & Caching System', () {
    test('Correctly identifies 1600x900 (16:9 landscape) images', () {
      const url = 'https://filmytell.com/posters/landscape_1600x900.jpg';
      ResponsivePosterImage.dimensionCache[url] = const Size(1600, 900);
      ResponsivePosterImage.aspectRatioCache[url] = 1600 / 900;

      expect(ResponsivePosterImage.getDimensions(url), const Size(1600, 900));
      expect(ResponsivePosterImage.getAspectRatio(url), closeTo(1.777, 0.001));
      expect(ResponsivePosterImage.isLandscape(url), isTrue);
      expect(ResponsivePosterImage.isPortrait(url), isFalse);
      expect(ResponsivePosterImage.isSquare(url), isFalse);
    });

    test('Correctly identifies 1000x1500 (2:3 standard portrait) posters', () {
      const url = 'https://filmytell.com/posters/portrait_1000x1500.jpg';
      ResponsivePosterImage.dimensionCache[url] = const Size(1000, 1500);
      ResponsivePosterImage.aspectRatioCache[url] = 1000 / 1500;

      expect(ResponsivePosterImage.getDimensions(url), const Size(1000, 1500));
      expect(ResponsivePosterImage.getAspectRatio(url), closeTo(0.666, 0.001));
      expect(ResponsivePosterImage.isLandscape(url), isFalse);
      expect(ResponsivePosterImage.isPortrait(url), isTrue);
      expect(ResponsivePosterImage.isSquare(url), isFalse);
    });

    test('Correctly identifies 1000x1000 (1:1 square) images', () {
      const url = 'https://filmytell.com/posters/square_1000x1000.jpg';
      ResponsivePosterImage.dimensionCache[url] = const Size(1000, 1000);
      ResponsivePosterImage.aspectRatioCache[url] = 1.0;

      expect(ResponsivePosterImage.isLandscape(url), isFalse);
      expect(ResponsivePosterImage.isPortrait(url), isFalse);
      expect(ResponsivePosterImage.isSquare(url), isTrue);
    });

    test('Correctly identifies 1080x1920 (9:16 vertical stories/shorts)', () {
      const url = 'https://filmytell.com/posters/vertical_1080x1920.jpg';
      ResponsivePosterImage.dimensionCache[url] = const Size(1080, 1920);
      ResponsivePosterImage.aspectRatioCache[url] = 1080 / 1920;

      expect(ResponsivePosterImage.isPortrait(url), isTrue);
      expect(ResponsivePosterImage.isLandscape(url), isFalse);
      expect(ResponsivePosterImage.isSquare(url), isFalse);
    });

    test('Correctly identifies 2560x1080 (21:9 ultrawide) images', () {
      const url = 'https://filmytell.com/posters/ultrawide_2560x1080.jpg';
      ResponsivePosterImage.dimensionCache[url] = const Size(2560, 1080);
      ResponsivePosterImage.aspectRatioCache[url] = 2560 / 1080;

      expect(ResponsivePosterImage.isLandscape(url), isTrue);
      expect(ResponsivePosterImage.isPortrait(url), isFalse);
    });
  });

  group('2. URL Sanitization & Candidate Prioritization', () {
    test('Sanitizes schema-relative URLs to HTTPS', () {
      final sanitized =
          ResponsivePosterImage.sanitizeUrl('//cdn.filmytell.com/movie.jpg');
      expect(sanitized, 'https://cdn.filmytell.com/movie.jpg');
    });

    test('Upgrades insecure HTTP to HTTPS', () {
      final sanitized =
          ResponsivePosterImage.sanitizeUrl('http://cdn.filmytell.com/movie.jpg');
      expect(sanitized, 'https://cdn.filmytell.com/movie.jpg');
    });

    test('Resolves relative paths with base URL', () {
      final sanitized =
          ResponsivePosterImage.sanitizeUrl('/uploads/poster.jpg');
      expect(sanitized, isNotNull);
      expect(sanitized!.startsWith('https://'), isTrue);
      expect(sanitized.endsWith('/uploads/poster.jpg'), isTrue);
    });

    test('Prioritizes S3 and Filmytell CDNs above third-party hosts', () {
      final rawList = [
        'https://external-host.com/movie.jpg',
        'https://filmytell-ott.s3.ap-south-1.amazonaws.com/movie.jpg',
        'https://cdn.filmytell.com/movie.jpg',
      ];
      final prioritized =
          ResponsivePosterImage.sanitizeAndPrioritizeUrls(rawList);

      expect(prioritized.first, contains('amazonaws.com'));
      expect(prioritized[1], contains('filmytell.com'));
      expect(prioritized.last, contains('external-host.com'));
    });
  });

  group('3. ResponsivePosterImage Widget Behavior', () {
    testWidgets('Uses BoxFit.contain by default and centers image',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 260,
              height: 185,
              child: ResponsivePosterImage(
                imageUrl: 'https://filmytell.com/sample.jpg',
              ),
            ),
          ),
        ),
      );

      final widgetFinder = find.byType(ResponsivePosterImage);
      expect(widgetFinder, findsOneWidget);

      final responsiveWidget =
          tester.widget<ResponsivePosterImage>(widgetFinder);
      expect(responsiveWidget.fit, BoxFit.contain);
      expect(responsiveWidget.alignment, Alignment.center);
      expect(responsiveWidget.backgroundColor, Colors.black);
      expect(responsiveWidget.isDecorativeBackdrop, isFalse);
    });

    testWidgets('Enforces BoxFit.cover when isDecorativeBackdrop is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 220,
              child: ResponsivePosterImage(
                imageUrl: 'https://filmytell.com/backdrop.jpg',
                isDecorativeBackdrop: true,
              ),
            ),
          ),
        ),
      );

      final widgetFinder = find.byType(ResponsivePosterImage);
      expect(widgetFinder, findsOneWidget);

      final responsiveWidget =
          tester.widget<ResponsivePosterImage>(widgetFinder);
      expect(responsiveWidget.isDecorativeBackdrop, isTrue);

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.fit, BoxFit.cover);
    });

    testWidgets('Renders fallback widget when URL list is empty',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: ResponsivePosterImage(
                imageUrl: null,
                imageUrls: const [],
                fallbackBuilder: () => const Text('FALLBACK_POSTER'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('FALLBACK_POSTER'), findsOneWidget);
    });
  });

  group('4. Card Dimension Stability Across Differing Poster Aspect Ratios', () {
    final landscape16x9Movie = Content(
      id: 201,
      title: 'Landscape 16:9 Movie',
      posterUrlList: [
        'https://filmytell-ott.s3.ap-south-1.amazonaws.com/landscape_1600x900.jpg',
      ],
      price: 99.0,
      releaseDate: '2026-10-21',
      ratings: 4.8,
      type: 'movie',
      isRental: false,
    );

    final portrait2x3Movie = Content(
      id: 202,
      title: 'Portrait 2:3 Movie',
      posterUrlList: [
        'https://filmytell-ott.s3.ap-south-1.amazonaws.com/portrait_1000x1500.jpg',
      ],
      price: 99.0,
      releaseDate: '2026-10-21',
      ratings: 4.8,
      type: 'movie',
      isRental: false,
    );

    final square1x1Movie = Content(
      id: 203,
      title: 'Square 1:1 Movie',
      posterUrlList: [
        'https://filmytell-ott.s3.ap-south-1.amazonaws.com/square_1000x1000.jpg',
      ],
      price: 99.0,
      releaseDate: '2026-10-21',
      ratings: 4.8,
      type: 'movie',
      isRental: false,
    );

    final ultrawide21x9Movie = Content(
      id: 204,
      title: 'Ultrawide 21:9 Movie',
      posterUrlList: [
        'https://filmytell-ott.s3.ap-south-1.amazonaws.com/ultrawide_2560x1080.jpg',
      ],
      price: 99.0,
      releaseDate: '2026-10-21',
      ratings: 4.8,
      type: 'movie',
      isRental: false,
    );

    testWidgets(
        'Card dimensions remain perfectly identical between 16:9 landscape and 2:3 portrait',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Render 16:9 Landscape Card
      await tester.pumpWidget(
        buildMovieCardHost(movie: landscape16x9Movie, cardWidth: 260.0),
      );
      await tester.pumpAndSettle();

      final landscapeCardFinder = find.byType(MovieCard);
      expect(landscapeCardFinder, findsOneWidget);
      final Size landscapeSize = tester.getSize(landscapeCardFinder);

      // Render 2:3 Portrait Card
      await tester.pumpWidget(
        buildMovieCardHost(movie: portrait2x3Movie, cardWidth: 260.0),
      );
      await tester.pumpAndSettle();

      final portraitCardFinder = find.byType(MovieCard);
      expect(portraitCardFinder, findsOneWidget);
      final Size portraitSize = tester.getSize(portraitCardFinder);

      // Verify dimensions are identical (not resized based on individual poster aspect ratios)
      expect(landscapeSize.width, equals(portraitSize.width));
      expect(landscapeSize.height, equals(portraitSize.height));
      expect(landscapeSize.width, equals(260.0));
      expect(landscapeSize.height, equals(MovieCard.standardHeight));
    });

    testWidgets(
        'Card dimensions remain identical across Square (1:1) and Ultrawide (21:9)',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildMovieCardHost(movie: square1x1Movie, cardWidth: 260.0),
      );
      await tester.pumpAndSettle();
      final Size squareSize = tester.getSize(find.byType(MovieCard));

      await tester.pumpWidget(
        buildMovieCardHost(movie: ultrawide21x9Movie, cardWidth: 260.0),
      );
      await tester.pumpAndSettle();
      final Size ultrawideSize = tester.getSize(find.byType(MovieCard));

      expect(squareSize.width, equals(260.0));
      expect(squareSize.height, equals(MovieCard.standardHeight));
      expect(ultrawideSize.width, equals(260.0));
      expect(ultrawideSize.height, equals(MovieCard.standardHeight));
    });

    testWidgets(
        'MovieCard uses ResponsivePosterImage with BoxFit.contain for complete edge visibility',
        (tester) async {
      await tester.pumpWidget(
        buildMovieCardHost(movie: landscape16x9Movie, cardWidth: 260.0),
      );
      await tester.pumpAndSettle();

      final responsiveFinder = find.descendant(
        of: find.byType(MovieCard),
        matching: find.byType(ResponsivePosterImage),
      );
      expect(responsiveFinder, findsOneWidget);

      final responsiveWidget =
          tester.widget<ResponsivePosterImage>(responsiveFinder);
      expect(responsiveWidget.fit, BoxFit.contain);
      expect(responsiveWidget.isDecorativeBackdrop, isFalse);
      expect(responsiveWidget.backgroundColor, Colors.black);
    });

    testWidgets(
        'ContinueWatchMovieCard uses ResponsivePosterImage with BoxFit.contain',
        (tester) async {
      await tester.pumpWidget(
        buildContinueWatchCardHost(
          movie: landscape16x9Movie,
        ),
      );
      await tester.pumpAndSettle();

      final responsiveFinder = find.descendant(
        of: find.byType(ContinueWatchMovieCard),
        matching: find.byType(ResponsivePosterImage),
      );
      expect(responsiveFinder, findsOneWidget);

      final responsiveWidget =
          tester.widget<ResponsivePosterImage>(responsiveFinder);
      expect(responsiveWidget.fit, BoxFit.contain);
      expect(responsiveWidget.isDecorativeBackdrop, isFalse);
      expect(responsiveWidget.backgroundColor, Colors.black);
    });
  });

  group('5. Cross-Platform Responsive Breakpoints & Sizing', () {
    final testMovie = Content(
      id: 301,
      title: 'Breakpoint Movie',
      posterUrlList: [
        'https://filmytell-ott.s3.ap-south-1.amazonaws.com/poster.jpg',
      ],
      price: 49.0,
      type: 'movie',
      isRental: false,
    );

    testWidgets('Android standard phone (360x800) keeps 260px width',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildMovieCardHost(movie: testMovie, surfaceSize: const Size(360, 800)),
      );
      await tester.pumpAndSettle();

      final Size cardSize = tester.getSize(find.byType(MovieCard));
      expect(cardSize.width, equals(MovieCard.mobileCardWidth)); // 260.0
      expect(cardSize.height, equals(MovieCard.standardHeight)); // 270.0
    });

    testWidgets('iPhone standard (390x844) keeps 260px width',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildMovieCardHost(movie: testMovie, surfaceSize: const Size(390, 844)),
      );
      await tester.pumpAndSettle();

      final Size cardSize = tester.getSize(find.byType(MovieCard));
      expect(cardSize.width, equals(MovieCard.mobileCardWidth)); // 260.0
      expect(cardSize.height, equals(MovieCard.standardHeight)); // 270.0
    });

    testWidgets('Tablet (820x1180) standardizes to 270px width',
        (tester) async {
      tester.view.physicalSize = const Size(820, 1180);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildMovieCardHost(
          movie: testMovie,
          surfaceSize: const Size(820, 1180),
        ),
      );
      await tester.pumpAndSettle();

      final Size cardSize = tester.getSize(find.byType(MovieCard));
      expect(cardSize.width, equals(MovieCard.tabletCardWidth)); // 270.0
      expect(cardSize.height, equals(MovieCard.standardHeight)); // 270.0
    });

    testWidgets('Web Laptop (1024x768) standardizes to 285px width',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildMovieCardHost(
          movie: testMovie,
          surfaceSize: const Size(1024, 768),
        ),
      );
      await tester.pumpAndSettle();

      final Size cardSize = tester.getSize(find.byType(MovieCard));
      expect(cardSize.width, equals(MovieCard.laptopCardWidth)); // 285.0
      expect(cardSize.height, equals(MovieCard.standardHeight)); // 270.0
    });

    testWidgets('Web Desktop (1920x1080) standardizes to 300px width',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildMovieCardHost(
          movie: testMovie,
          surfaceSize: const Size(1920, 1080),
        ),
      );
      await tester.pumpAndSettle();

      final Size cardSize = tester.getSize(find.byType(MovieCard));
      expect(cardSize.width, equals(MovieCard.desktopCardWidth)); // 300.0
      expect(cardSize.height, equals(MovieCard.standardHeight)); // 270.0
    });
  });
}
