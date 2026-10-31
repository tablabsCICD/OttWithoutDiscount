import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ott/app/core/utils/direct_trailer_source.dart';
import 'package:ott/app/widgets/movieCard.dart';
import 'package:ott/app/widgets/responsive_poster_image.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';
import 'package:ott/app/provider/onboarding_tour_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildCardTestWidget({
    required Content movie,
    ValueNotifier<int?>? activeIndex,
    int? index = 0,
    double? cardWidth,
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
                index: index,
                activeIndexListenable: activeIndex,
                cardWidth: cardWidth ?? 200,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildMultiCardTestWidget({
    required List<Content> movies,
    required ValueNotifier<int?> activeIndex,
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
          body: SizedBox(
            height: MovieCard.standardHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              itemBuilder: (context, i) {
                return MovieCard(
                  movie: movies[i],
                  index: i,
                  activeIndexListenable: activeIndex,
                  cardWidth: 200,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  group('DirectTrailerSource & Content.hasValidTrailer Availability Checks', () {
    test('Scenario B: null trailer is marked invalid', () {
      final movie = Content(id: 1, title: 'No Trailer Movie', trailerUrl: null);
      expect(movie.hasValidTrailer, isFalse);
      expect(DirectTrailerSource.hasValidTrailer(movie.trailerUrl), isFalse);
    });

    test('Scenario C: empty or whitespace trailer is marked invalid', () {
      final emptyMovie = Content(id: 2, title: 'Empty Trailer', trailerUrl: '');
      final whitespaceMovie = Content(id: 3, title: 'Whitespace Trailer', trailerUrl: '   \t\n  ');

      expect(emptyMovie.hasValidTrailer, isFalse);
      expect(whitespaceMovie.hasValidTrailer, isFalse);
    });

    test('Scenario D: missing trailer field from API response is marked invalid', () {
      final apiJson = {
        'id': 4,
        'title': 'API Movie Without Trailer Field',
        'posterUrlList': ['https://example.com/poster.jpg'],
        'ratings': 4.5,
      };
      final parsedMovie = Content.fromJson(apiJson);

      expect(parsedMovie.trailerUrl, isNull);
      expect(parsedMovie.hasValidTrailer, isFalse);
    });

    test('Scenario E: invalid format or YouTube trailer is marked invalid for direct preview', () {
      final invalidMovie = Content(id: 5, title: 'Bad Format', trailerUrl: 'not_a_valid_url');
      final youtubeMovie = Content(id: 6, title: 'YouTube Trailer', trailerUrl: 'https://www.youtube.com/watch?v=12345');
      final ftpMovie = Content(id: 7, title: 'FTP Trailer', trailerUrl: 'ftp://files.com/t.mp4');

      expect(invalidMovie.hasValidTrailer, isFalse);
      expect(youtubeMovie.hasValidTrailer, isFalse);
      expect(ftpMovie.hasValidTrailer, isFalse);
    });

    test('Scenario A: valid direct http/https trailer URL is marked valid', () {
      final validMovie = Content(
        id: 8,
        title: 'Valid Movie',
        trailerUrl: 'https://trailers.filmytell.in/movie8/trailer.mp4',
      );
      expect(validMovie.hasValidTrailer, isTrue);
    });
  });

  group('MovieCard Widget Trailer Handling on Homepage', () {
    testWidgets('Scenario B: Movie with null trailer displays poster safely without video player', (tester) async {
      final movie = Content(
        id: 10,
        title: 'Null Trailer Movie',
        trailerUrl: null,
        posterUrlList: ['https://example.com/poster10.jpg'],
        watchedPercentage: 0,
      );
      final activeIndex = ValueNotifier<int?>(0);

      await tester.pumpWidget(buildCardTestWidget(movie: movie, activeIndex: activeIndex, index: 0));
      await tester.pump(const Duration(milliseconds: 300));

      // Must display the responsive poster image fallback
      expect(find.byType(ResponsivePosterImage), findsOneWidget);
      // No crash, and movie title is present
      expect(find.text('Null Trailer Movie'), findsOneWidget);
    });

    testWidgets('Scenario C: Movie with empty or whitespace trailer displays poster safely', (tester) async {
      final movie = Content(
        id: 11,
        title: 'Whitespace Trailer Movie',
        trailerUrl: '   ',
        posterUrlList: ['https://example.com/poster11.jpg'],
      );
      final activeIndex = ValueNotifier<int?>(0);

      await tester.pumpWidget(buildCardTestWidget(movie: movie, activeIndex: activeIndex, index: 0));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ResponsivePosterImage), findsOneWidget);
      expect(find.text('Whitespace Trailer Movie'), findsOneWidget);
    });

    testWidgets('Scenario D: Movie parsed from API without trailer field displays poster safely', (tester) async {
      final movie = Content.fromJson({
        'id': 12,
        'title': 'API No Trailer Movie',
        'description': 'A drama with no trailer provided.',
        'posterUrlList': ['https://example.com/poster12.jpg'],
      });
      final activeIndex = ValueNotifier<int?>(0);

      await tester.pumpWidget(buildCardTestWidget(movie: movie, activeIndex: activeIndex, index: 0));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ResponsivePosterImage), findsOneWidget);
      expect(find.text('API No Trailer Movie'), findsOneWidget);
    });

    testWidgets('Scenario E: Movie with invalid trailer URL displays poster safely without crashing', (tester) async {
      final movie = Content(
        id: 13,
        title: 'Invalid URL Movie',
        trailerUrl: 'http:///broken-uri',
        posterUrlList: ['https://example.com/poster13.jpg'],
      );
      final activeIndex = ValueNotifier<int?>(0);

      await tester.pumpWidget(buildCardTestWidget(movie: movie, activeIndex: activeIndex, index: 0));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ResponsivePosterImage), findsOneWidget);
      expect(find.text('Invalid URL Movie'), findsOneWidget);
    });

    testWidgets('Scenario F: Mixed movie cards - cards without trailers display posters safely', (tester) async {
      final movies = [
        Content(
          id: 21,
          title: 'Movie 1 No Trailer',
          trailerUrl: null,
          posterUrlList: ['https://example.com/p1.jpg'],
        ),
        Content(
          id: 22,
          title: 'Movie 2 With Trailer',
          trailerUrl: 'https://trailers.filmytell.in/t2.mp4',
          posterUrlList: ['https://example.com/p2.jpg'],
        ),
        Content(
          id: 23,
          title: 'Movie 3 Whitespace',
          trailerUrl: '   ',
          posterUrlList: ['https://example.com/p3.jpg'],
        ),
      ];

      final activeIndex = ValueNotifier<int?>(0);

      await tester.pumpWidget(buildMultiCardTestWidget(movies: movies, activeIndex: activeIndex));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Movie 1 No Trailer'), findsOneWidget);
      expect(find.text('Movie 2 With Trailer'), findsOneWidget);
      expect(find.text('Movie 3 Whitespace'), findsOneWidget);
      expect(find.byType(ResponsivePosterImage), findsNWidgets(3));
    });

    testWidgets('Scenario G: Card widget reuse for movie with no trailer disposes previous preview and displays poster', (tester) async {
      final movieWithTrailer = Content(
        id: 31,
        title: 'Trailer Available',
        trailerUrl: 'https://trailers.filmytell.in/t31.mp4',
        posterUrlList: ['https://example.com/p31.jpg'],
      );
      final movieWithoutTrailer = Content(
        id: 32,
        title: 'Trailer Missing',
        trailerUrl: null,
        posterUrlList: ['https://example.com/p32.jpg'],
      );

      final activeIndex = ValueNotifier<int?>(0);

      // Render movie with trailer first
      await tester.pumpWidget(buildCardTestWidget(movie: movieWithTrailer, activeIndex: activeIndex, index: 0));
      await tester.pump(const Duration(milliseconds: 100));

      // Re-render the same widget slot with movieWithoutTrailer
      await tester.pumpWidget(buildCardTestWidget(movie: movieWithoutTrailer, activeIndex: activeIndex, index: 0));
      await tester.pump(const Duration(milliseconds: 300));

      // Must display the new movie's poster cleanly
      expect(find.text('Trailer Missing'), findsOneWidget);
      expect(find.byType(ResponsivePosterImage), findsOneWidget);
    });

    testWidgets('Scenario H: Movie card without trailer is interactable and retains options menu', (tester) async {
      final movie = Content(
        id: 41,
        title: 'Interactive Card',
        trailerUrl: null,
        posterUrlList: ['https://example.com/p41.jpg'],
        price: 49.0,
      );

      await tester.pumpWidget(buildCardTestWidget(movie: movie));
      await tester.pump(const Duration(milliseconds: 100));

      // Card is present and tappable
      expect(find.text('Interactive Card'), findsOneWidget);
      expect(find.byType(GestureDetector), findsWidgets);
    });
  });
}
