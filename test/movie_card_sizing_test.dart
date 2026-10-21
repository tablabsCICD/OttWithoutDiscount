import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ott/app/widgets/movieCard.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    required Content movie,
    double? cardWidth,
    double? cardMargin,
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
              height: 270,
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
    posterUrlList: ['https://example.com/poster.jpg'],
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
    posterUrlList: ['https://example.com/portrait_poster.jpg'],
  );

  group('MovieCard Responsive Layout & Poster Fitting Tests', () {
    testWidgets('renders cleanly on small phone screen (320x568) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          movie: testMovie,
          cardWidth: 290,
          cardMargin: 4,
          surfaceSize: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('The March'), findsOneWidget);
      expect(find.text('₹ 49.0'), findsOneWidget);
    });

    testWidgets('renders cleanly on standard phone screen (390x844) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          movie: portraitMovie,
          cardWidth: 300,
          surfaceSize: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Red Envelope'), findsOneWidget);
    });

    testWidgets('renders cleanly on large phone screen (430x932) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(430 * 3, 932 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          movie: testMovie,
          cardWidth: 320,
          surfaceSize: const Size(430, 932),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('The March'), findsOneWidget);
    });

    testWidgets('renders cleanly on tablet screen (820x1180) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(820 * 2, 1180 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          movie: testMovie,
          cardWidth: 340,
          surfaceSize: const Size(820, 1180),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('The March'), findsOneWidget);
    });

    testWidgets('Image widget uses BoxFit.contain to prevent cropping',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(movie: testMovie),
      );
      await tester.pump();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final Image imageWidget = tester.widget(imageFinder);
      expect(imageWidget.fit, equals(BoxFit.contain));
      expect(imageWidget.alignment, equals(Alignment.center));
      await tester.pumpAndSettle();
    });
  });
}
