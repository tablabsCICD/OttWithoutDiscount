import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ott/app/widgets/movieCard.dart';
import 'package:ott/app/widgets/responsive_poster_image.dart';
import 'package:ott/app/pages/home page/category_content_page.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';
import 'package:ott/app/provider/onboarding_tour_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
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
        home: Scaffold(
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
    );
  }

  Widget buildCategoryTestWidget({
    required List<Content> contents,
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
        home: CategoryContentPage(
          categoryTitle: 'Action Blockbusters',
          contents: contents,
        ),
      ),
    );
  }

  final testMovie = Content(
    id: 101,
    title: 'The March',
    ratings: 5.0,
    ratingCount: 2,
    price: 49.0,
    releaseDate: '13-10-2026',
    genreList: ['Drama', 'Action'],
    type: 'movie',
    isRental: false,
    posterUrlList: ['https://example.com/poster_16_9.jpg'],
  );

  final portraitMovie = Content(
    id: 102,
    title: 'Red Envelope Special Edition With Long Title That Might Wrap',
    ratings: 4.5,
    ratingCount: 150,
    price: 99.0,
    releaseDate: '2026-05-15',
    genreList: ['Thriller', 'Mystery', 'Crime'],
    type: 'movie',
    isRental: true,
    posterUrlList: ['https://example.com/portrait_poster_2_3.jpg'],
  );

  final squarePosterMovie = Content(
    id: 103,
    title: 'Square Poster Indie Feature',
    ratings: 4.2,
    ratingCount: 40,
    price: 39.0,
    releaseDate: '2026-06-20',
    genreList: ['Indie', 'Documentary'],
    type: 'movie',
    isRental: false,
    posterUrlList: ['https://example.com/square_poster_1_1.jpg'],
  );

  final verticalPosterMovie = Content(
    id: 104,
    title: 'Vertical Cinematic Showcase',
    ratings: 4.7,
    ratingCount: 88,
    price: 59.0,
    releaseDate: '2026-07-04',
    genreList: ['Sci-Fi', 'Adventure'],
    type: 'movie',
    isRental: true,
    posterUrlList: ['https://example.com/vertical_poster_9_16.jpg'],
  );

  final ultrawidePosterMovie = Content(
    id: 105,
    title: 'Panoramic Epic Panorama',
    ratings: 4.9,
    ratingCount: 210,
    price: 79.0,
    releaseDate: '2026-08-15',
    genreList: ['Epic', 'Historical'],
    type: 'movie',
    isRental: false,
    posterUrlList: ['https://example.com/panoramic_poster_21_9.jpg'],
  );

  final sampleMovieList = [
    testMovie,
    portraitMovie,
    squarePosterMovie,
    verticalPosterMovie,
    ultrawidePosterMovie,
  ];

  group('MovieCard Dimension Standardization & Breakpoints', () {
    testWidgets('calculates correct standardized widths across all platforms',
        (WidgetTester tester) async {
      Future<double> getResolvedWidth(Size size) async {
        late double width;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size),
            child: Builder(
              builder: (context) {
                width = MovieCard.cardWidthFor(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        return width;
      }

      // Android phones
      expect(await getResolvedWidth(const Size(360, 800)), equals(MovieCard.mobileCardWidth)); // 260.0
      expect(await getResolvedWidth(const Size(412, 915)), equals(MovieCard.mobileCardWidth)); // 260.0

      // iOS iPhones
      expect(await getResolvedWidth(const Size(390, 844)), equals(MovieCard.mobileCardWidth)); // 260.0
      expect(await getResolvedWidth(const Size(430, 932)), equals(MovieCard.mobileCardWidth)); // 260.0

      // Tablets
      expect(await getResolvedWidth(const Size(768, 1024)), equals(MovieCard.tabletCardWidth)); // 270.0
      expect(await getResolvedWidth(const Size(820, 1180)), equals(MovieCard.tabletCardWidth)); // 270.0

      // Web 13" and 14" Laptops
      expect(await getResolvedWidth(const Size(1280, 800)), equals(MovieCard.laptopCardWidth)); // 285.0
      expect(await getResolvedWidth(const Size(1440, 900)), equals(MovieCard.laptopCardWidth)); // 285.0

      // Web 15" and 16" Laptops
      expect(await getResolvedWidth(const Size(1536, 960)), equals(MovieCard.laptopCardWidth)); // 285.0
      expect(await getResolvedWidth(const Size(1728, 1080)), equals(MovieCard.laptopCardWidth)); // 285.0

      // Web Desktop & Ultra-wide monitors
      expect(await getResolvedWidth(const Size(1920, 1080)), equals(MovieCard.desktopCardWidth)); // 300.0
      expect(await getResolvedWidth(const Size(2560, 1440)), equals(MovieCard.desktopCardWidth)); // 300.0
    });

    testWidgets('card width remains stable when resizing within the same laptop breakpoint',
        (WidgetTester tester) async {
      Future<double> getResolvedWidth(double width) async {
        late double cardWidth;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: Size(width, 900)),
            child: Builder(
              builder: (context) {
                cardWidth = MovieCard.cardWidthFor(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        return cardWidth;
      }

      // Check stability across various laptop widths in the 1024..1799 range
      final width1050 = await getResolvedWidth(1050);
      final width1280 = await getResolvedWidth(1280);
      final width1440 = await getResolvedWidth(1440);
      final width1600 = await getResolvedWidth(1600);
      final width1750 = await getResolvedWidth(1750);

      expect(width1050, equals(MovieCard.laptopCardWidth));
      expect(width1280, equals(MovieCard.laptopCardWidth));
      expect(width1440, equals(MovieCard.laptopCardWidth));
      expect(width1600, equals(MovieCard.laptopCardWidth));
      expect(width1750, equals(MovieCard.laptopCardWidth));
    });

    test('verifies standard card height and poster aspect ratio constants', () {
      expect(MovieCard.standardHeight, equals(220.0));
      expect(MovieCard.standardPosterAspectRatio, equals(16 / 9));
      expect(MovieCard.mobileCardWidth, equals(300.0));
      expect(MovieCard.tabletCardWidth, equals(300.0));
      expect(MovieCard.laptopCardWidth, equals(300.0));
      expect(MovieCard.desktopCardWidth, equals(300.0));
    });
  });

  group('MovieCard Widget Sizing Across Device Screens', () {
    testWidgets('renders standardized 300px card on Android phone (360x800) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          movie: testMovie,
          surfaceSize: const Size(360, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final cardSize = tester.getSize(find.byType(MovieCard));
      expect(cardSize.width, equals(MovieCard.mobileCardWidth));
      expect(cardSize.height, equals(MovieCard.standardHeight));
      expect(find.text('The March'), findsOneWidget);
    });

    testWidgets('renders standardized 300px card on iPhone (390x844) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          movie: portraitMovie,
          surfaceSize: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final cardSize = tester.getSize(find.byType(MovieCard));
      expect(cardSize.width, equals(MovieCard.mobileCardWidth));
      expect(cardSize.height, equals(MovieCard.standardHeight));
      expect(find.textContaining('Red Envelope'), findsOneWidget);
    });

    testWidgets('renders standardized 300px card on Tablet (820x1180) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(820 * 2, 1180 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          movie: testMovie,
          surfaceSize: const Size(820, 1180),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final cardSize = tester.getSize(find.byType(MovieCard));
      expect(cardSize.width, equals(MovieCard.tabletCardWidth));
      expect(cardSize.height, equals(MovieCard.standardHeight));
    });

    testWidgets('renders standardized 300px card on 14-inch Laptop (1440x900) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440 * 1, 900 * 1);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          movie: testMovie,
          surfaceSize: const Size(1440, 900),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final cardSize = tester.getSize(find.byType(MovieCard));
      expect(cardSize.width, equals(MovieCard.laptopCardWidth));
      expect(cardSize.height, equals(MovieCard.standardHeight));
    });

    testWidgets('renders standardized 300px card on Desktop Monitor (1920x1080) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920 * 1, 1080 * 1);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          movie: testMovie,
          surfaceSize: const Size(1920, 1080),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final cardSize = tester.getSize(find.byType(MovieCard));
      expect(cardSize.width, equals(MovieCard.desktopCardWidth));
      expect(cardSize.height, equals(MovieCard.standardHeight));
    });
  });

  group('Smart Poster Display Strategy (Contain Foreground + Ambient Background)', () {
    testWidgets('Poster container uses BoxFit.contain with Alignment.center by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(movie: testMovie));
      await tester.pump();

      final responsiveFinder = find.descendant(
        of: find.byType(MovieCard),
        matching: find.byType(ResponsivePosterImage),
      );
      expect(responsiveFinder, findsOneWidget);
      final ResponsivePosterImage responsive = tester.widget(responsiveFinder);
      expect(responsive.fit, equals(BoxFit.contain));
      expect(responsive.alignment, equals(Alignment.center));
      await tester.pumpAndSettle();
    });

    testWidgets('Poster matching container aspect ratio displays normally without ambient background',
        (WidgetTester tester) async {
      // In MovieCard standard sizing, media area is 16:9 (1600x900)
      const matchingUrl = 'https://example.com/poster_matching.jpg';
      final matchingMovie = Content(
        id: 199,
        title: 'Matching Ratio Movie',
        posterUrlList: [matchingUrl],
        type: 'movie',
      );
      ResponsivePosterImage.aspectRatioCache[matchingUrl] = 16 / 9;

      await tester.pumpWidget(buildTestWidget(movie: matchingMovie));
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final Image imageWidget = tester.widget(imageFinder);
      expect(imageWidget.fit, equals(BoxFit.cover));
      expect(imageWidget.alignment, equals(Alignment.center));
      await tester.pumpAndSettle();
    });

    testWidgets('2:3 portrait poster differing from container renders ambient background and contain foreground',
        (WidgetTester tester) async {
      ResponsivePosterImage.aspectRatioCache['https://example.com/portrait_poster_2_3.jpg'] = 2 / 3;
      await tester.pumpWidget(buildTestWidget(movie: portraitMovie));
      await tester.pump();

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.length, equals(2));
      expect(images[0].fit, equals(BoxFit.cover)); // ambient background
      expect(images[1].fit, equals(BoxFit.contain)); // foreground poster
      expect(images[1].alignment, equals(Alignment.center));
      await tester.pumpAndSettle();
    });

    testWidgets('1:1 square poster differing from container renders ambient background and contain foreground',
        (WidgetTester tester) async {
      ResponsivePosterImage.aspectRatioCache['https://example.com/square_poster_1_1.jpg'] = 1.0;
      await tester.pumpWidget(buildTestWidget(movie: squarePosterMovie));
      await tester.pump();

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.length, equals(2));
      expect(images[0].fit, equals(BoxFit.cover));
      expect(images[1].fit, equals(BoxFit.contain));
      await tester.pumpAndSettle();
    });

    testWidgets('9:16 vertical poster differing from container renders ambient background and contain foreground',
        (WidgetTester tester) async {
      ResponsivePosterImage.aspectRatioCache['https://example.com/vertical_poster_9_16.jpg'] = 9 / 16;
      await tester.pumpWidget(buildTestWidget(movie: verticalPosterMovie));
      await tester.pump();

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.length, equals(2));
      expect(images[0].fit, equals(BoxFit.cover));
      expect(images[1].fit, equals(BoxFit.contain));
      await tester.pumpAndSettle();
    });

    testWidgets('21:9 panoramic poster differing from container renders ambient background and contain foreground',
        (WidgetTester tester) async {
      ResponsivePosterImage.aspectRatioCache['https://example.com/panoramic_poster_21_9.jpg'] = 21 / 9;
      await tester.pumpWidget(buildTestWidget(movie: ultrawidePosterMovie));
      await tester.pump();

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.length, equals(2));
      expect(images[0].fit, equals(BoxFit.cover));
      expect(images[1].fit, equals(BoxFit.contain));
      await tester.pumpAndSettle();
    });

    testWidgets('poster container has black background',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(movie: portraitMovie));
      await tester.pump();

      final containerWithBlackBg = find.byWidgetPredicate(
        (w) => w is Container && w.color == Colors.black,
      );
      expect(containerWithBlackBg, findsWidgets,
          reason: 'Poster container must use black background');
      await tester.pumpAndSettle();
    });
  });

  group('CategoryContentPage Responsive Grid Layout', () {
    testWidgets('renders cleanly on phone (390x844) with standardized card widths',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildCategoryTestWidget(
          contents: sampleMovieList,
          surfaceSize: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Action Blockbusters'), findsOneWidget);
      expect(find.text('The March'), findsOneWidget);

      // Verify cards in grid use standardized mobileCardWidth (260.0)
      final cardFinder = find.byWidgetPredicate(
        (w) => w is MovieCard && w.cardWidth == MovieCard.mobileCardWidth,
      );
      expect(cardFinder, findsWidgets);
    });

    testWidgets('renders cleanly on 14-inch Laptop (1440x900) with multi-column standardized cards',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440 * 1, 900 * 1);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildCategoryTestWidget(
          contents: sampleMovieList,
          surfaceSize: const Size(1440, 900),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Action Blockbusters'), findsOneWidget);

      // Verify cards in grid use standardized laptopCardWidth (285.0)
      final cardFinder = find.byWidgetPredicate(
        (w) => w is MovieCard && w.cardWidth == MovieCard.laptopCardWidth,
      );
      expect(cardFinder, findsWidgets);
    });

    testWidgets('renders cleanly on Desktop (1920x1080) with desktopCardWidth',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920 * 1, 1080 * 1);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildCategoryTestWidget(
          contents: sampleMovieList,
          surfaceSize: const Size(1920, 1080),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Action Blockbusters'), findsOneWidget);

      // Verify cards in grid use standardized desktopCardWidth (300.0)
      final cardFinder = find.byWidgetPredicate(
        (w) => w is MovieCard && w.cardWidth == MovieCard.desktopCardWidth,
      );
      expect(cardFinder, findsWidgets);
    });
  });
}
