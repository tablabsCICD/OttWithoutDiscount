import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ott/app/core/utils/content_type.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';
import 'package:ott/app/provider/onboarding_tour_provider.dart';
import 'package:ott/app/widgets/movieCard.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestCard(Content movie) {
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
              width: MovieCard.mobileCardWidth,
              child: MovieCard(
                movie: movie,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Homepage MovieCard Price vs Watch Now Display Rules', () {
    // 1. Unpurchased MOVIE -> Price
    testWidgets('1. Unpurchased MOVIE displays content price',
        (WidgetTester tester) async {
      final movie = Content(
        id: 101,
        title: 'Action Movie',
        type: ContentType.movie,
        price: 99.0,
        isRental: false,
      );

      await tester.pumpWidget(buildTestCard(movie));
      await tester.pumpAndSettle();

      expect(find.text('₹ 99.0'), findsOneWidget);
      expect(find.text('Watch Now'), findsNothing);
    });

    // 2. Purchased MOVIE -> Watch Now
    testWidgets('2. Purchased MOVIE displays Watch Now',
        (WidgetTester tester) async {
      final movie = Content(
        id: 102,
        title: 'Action Movie',
        type: ContentType.movie,
        price: 99.0,
        isRental: true,
      );

      await tester.pumpWidget(buildTestCard(movie));
      await tester.pumpAndSettle();

      expect(find.text('Watch Now'), findsOneWidget);
      expect(find.text('₹ 99.0'), findsNothing);
    });

    // 3. Unpurchased SERIES -> Watch Now
    testWidgets('3. Unpurchased SERIES displays Watch Now',
        (WidgetTester tester) async {
      final movie = Content(
        id: 103,
        title: 'Crime Series',
        type: ContentType.series,
        price: 199.0,
        isRental: false,
      );

      await tester.pumpWidget(buildTestCard(movie));
      await tester.pumpAndSettle();

      expect(find.text('Watch Now'), findsOneWidget);
      expect(find.text('₹ 199.0'), findsNothing);
    });

    // 4. Purchased SERIES -> Watch Now
    testWidgets('4. Purchased SERIES displays Watch Now',
        (WidgetTester tester) async {
      final movie = Content(
        id: 104,
        title: 'Crime Series',
        type: ContentType.series,
        price: 199.0,
        isRental: true,
      );

      await tester.pumpWidget(buildTestCard(movie));
      await tester.pumpAndSettle();

      expect(find.text('Watch Now'), findsOneWidget);
      expect(find.text('₹ 199.0'), findsNothing);
    });

    // 5. Unpurchased MINI SERIES -> Price
    testWidgets('5. Unpurchased MINI SERIES displays content price',
        (WidgetTester tester) async {
      final movie = Content(
        id: 105,
        title: 'Mini Drama',
        type: ContentType.miniSeries,
        price: 149.0,
        isRental: false,
      );

      await tester.pumpWidget(buildTestCard(movie));
      await tester.pumpAndSettle();

      expect(find.text('₹ 149.0'), findsOneWidget);
      expect(find.text('Watch Now'), findsNothing);
    });

    // 6. Purchased MINI SERIES -> Watch Now
    testWidgets('6. Purchased MINI SERIES displays Watch Now',
        (WidgetTester tester) async {
      final movie = Content(
        id: 106,
        title: 'Mini Drama',
        type: ContentType.miniSeries,
        price: 149.0,
        isRental: true,
      );

      await tester.pumpWidget(buildTestCard(movie));
      await tester.pumpAndSettle();

      expect(find.text('Watch Now'), findsOneWidget);
      expect(find.text('₹ 149.0'), findsNothing);
    });

    // 7. Unpurchased MADIOO -> Price
    testWidgets('7. Unpurchased MADIOO displays content price',
        (WidgetTester tester) async {
      final movie = Content(
        id: 107,
        title: 'Madioo Special',
        type: ContentType.madioo,
        price: 49.0,
        isRental: false,
      );

      await tester.pumpWidget(buildTestCard(movie));
      await tester.pumpAndSettle();

      expect(find.text('₹ 49.0'), findsOneWidget);
      expect(find.text('Watch Now'), findsNothing);
    });

    // 8. Purchased MADIOO -> Watch Now
    testWidgets('8. Purchased MADIOO displays Watch Now',
        (WidgetTester tester) async {
      final movie = Content(
        id: 108,
        title: 'Madioo Special',
        type: ContentType.madioo,
        price: 49.0,
        isRental: true,
      );

      await tester.pumpWidget(buildTestCard(movie));
      await tester.pumpAndSettle();

      expect(find.text('Watch Now'), findsOneWidget);
      expect(find.text('₹ 49.0'), findsNothing);
    });

    // 9. Unpurchased SHORT_FILM -> Price
    testWidgets('9. Unpurchased SHORT_FILM displays content price',
        (WidgetTester tester) async {
      final movie = Content(
        id: 109,
        title: 'Short Story',
        type: ContentType.shortFilm,
        price: 29.0,
        isRental: false,
      );

      await tester.pumpWidget(buildTestCard(movie));
      await tester.pumpAndSettle();

      expect(find.text('₹ 29.0'), findsOneWidget);
      expect(find.text('Watch Now'), findsNothing);
    });

    // 10. Purchased SHORT_FILM -> Watch Now
    testWidgets('10. Purchased SHORT_FILM displays Watch Now',
        (WidgetTester tester) async {
      final movie = Content(
        id: 110,
        title: 'Short Story',
        type: ContentType.shortFilm,
        price: 29.0,
        isRental: true,
      );

      await tester.pumpWidget(buildTestCard(movie));
      await tester.pumpAndSettle();

      expect(find.text('Watch Now'), findsOneWidget);
      expect(find.text('₹ 29.0'), findsNothing);
    });

    // Logged-out / null isRental behavior
    testWidgets('Logged-out user (isRental is null) displays price for unpurchased non-series',
        (WidgetTester tester) async {
      final movie = Content(
        id: 111,
        title: 'Guest Movie',
        type: ContentType.movie,
        price: 79.0,
        isRental: null,
      );

      await tester.pumpWidget(buildTestCard(movie));
      await tester.pumpAndSettle();

      expect(find.text('₹ 79.0'), findsOneWidget);
      expect(find.text('Watch Now'), findsNothing);
    });

    testWidgets('Logged-out user (isRental is null) still displays Watch Now for series',
        (WidgetTester tester) async {
      final movie = Content(
        id: 112,
        title: 'Guest Series',
        type: ContentType.series,
        price: 199.0,
        isRental: null,
      );

      await tester.pumpWidget(buildTestCard(movie));
      await tester.pumpAndSettle();

      expect(find.text('Watch Now'), findsOneWidget);
      expect(find.text('₹ 199.0'), findsNothing);
    });
  });
}
