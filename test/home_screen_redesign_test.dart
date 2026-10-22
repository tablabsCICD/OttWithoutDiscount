import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ott/app/core/constant/prefrense_constant.dart';
import 'package:ott/app/pages/home page/HomePage.dart';
import 'package:ott/app/widgets/movieCard.dart';
import 'package:ott/app/widgets/continue_watching_banner.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/models/response/get_dashboard_data.dart';
import 'package:ott/data/models/user.dart';
import 'package:ott/data/themes/custom_theme.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/provider/userProvider.dart';
import 'package:ott/app/provider/wallet_provider.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';
import 'package:ott/app/provider/onboarding_tour_provider.dart';

class TestDashboardProvider extends DashboardProvider {
  List<Content> _testContinueWatched = [];
  List<DashboardData> _testData = [];

  void setTestContinueWatched(List<Content> list) {
    _testContinueWatched = list;
    notifyListeners();
  }

  void setTestDashboardData(List<DashboardData> data) {
    _testData = data;
    notifyListeners();
  }

  @override
  List<Content> get continueWatchedMovies => _testContinueWatched;

  @override
  List<DashboardData> get dashboardData => _testData;

  @override
  bool get isLoading => false;

  @override
  Future<void> getContinueWatchedMovieList(String type) async {}

  @override
  Future<void> getDashboardData(String type, List<String> languages, int userId) async {}
}

class TestUserProvider extends UserProvider {
  @override
  Future<void> getUserById(int id) async {}
}

class TestWalletProvider extends WalletProvider {
  @override
  double get walletBalance => 150.0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testMovies = [
    Content(
      id: 1,
      title: 'Marathi Short Film Showcase',
      watchedPercentage: 40,
      genreList: ['Drama', 'Family'],
      type: 'movie',
      isRental: false,
      posterUrlList: ['https://example.com/movie1.jpg'],
      contentUrl: 'https://example.com/movie1.mp4',
      releaseDate: '2026-10-15',
    ),
    Content(
      id: 2,
      title: 'Trending Short Film',
      watchedPercentage: 0,
      genreList: ['Thriller'],
      type: 'movie',
      isRental: true,
      posterUrlList: ['https://example.com/movie2.jpg'],
      contentUrl: 'https://example.com/movie2.mp4',
      releaseDate: '2026-10-18',
    ),
  ];

  Widget buildHomeScreenTestWidget({
    Size surfaceSize = const Size(390, 844),
    List<Content>? continueWatchList,
  }) {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesConstant.currentUser: jsonEncode(
        User(
          id: 1,
          firstName: 'Filmytell',
          lastName: 'User',
          emailId: 'user@filmytell.com',
          dob: '01-01-1995',
          age: '30',
          profilePhoto: '',
        ).toJson(),
      ),
      SharedPreferencesConstant.isUserLoggedIn: true,
      'staged_reg_completed_step_dobAndEmail': true,
      'staged_reg_completed_step_name': true,
      'staged_reg_completed_step_location': true,
    });

    final dashboardProvider = TestDashboardProvider();
    dashboardProvider.setTestContinueWatched(continueWatchList ?? [testMovies.first]);
    dashboardProvider.setTestDashboardData([
      DashboardData(
        language: 'Marathi',
        category: 'Latest Short Films',
        movies: testMovies,
      ),
      DashboardData(
        language: 'Trending',
        category: 'Short Films',
        movies: testMovies,
      ),
    ]);

    final userProvider = TestUserProvider();
    userProvider.userObject = User(
      id: 1,
      firstName: 'Filmytell',
      lastName: 'User',
      emailId: 'user@filmytell.com',
      dob: '01-01-1995',
      age: '30',
      profilePhoto: '',
      selectedLanguages: ['English'],
    );

    final walletProvider = TestWalletProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(isDark: true),
        ),
        ChangeNotifierProvider<DashboardProvider>.value(
          value: dashboardProvider,
        ),
        ChangeNotifierProvider<UserProvider>.value(
          value: userProvider,
        ),
        ChangeNotifierProvider<WalletProvider>.value(
          value: walletProvider,
        ),
        ChangeNotifierProvider<BookmarkProvider>(
          create: (_) => BookmarkProvider(),
        ),
        ChangeNotifierProvider<OnboardingTourProvider>(
          create: (_) => OnboardingTourProvider(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomePage(),
      ),
    );
  }

  Future<void> pumpHomeScreen(WidgetTester tester) async {
    await tester.pumpWidget(buildHomeScreenTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
  }

  Future<void> cleanUpHomeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('Home Screen UI Recreation & Redesign Tests', () {
    testWidgets(
        '1. App Bar has solid red primaryColor background without transparency across mobile & desktop',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpHomeScreen(tester);

      final sliverAppBarFinder = find.byType(SliverAppBar);
      expect(sliverAppBarFinder, findsOneWidget);

      final SliverAppBar appBar = tester.widget(sliverAppBarFinder);
      expect(appBar.forceMaterialTransparency, isFalse,
          reason: 'App bar must have solid red background without transparency');
      expect(appBar.backgroundColor, equals(AppTheme.darkTheme.primaryColor),
          reason: 'App bar must use the solid Filmytell red primaryColor');

      // Verify Filmytell logo size in app bar
      final logoFinder = find.descendant(
        of: sliverAppBarFinder,
        matching: find.byType(Image),
      );
      expect(logoFinder, findsWidgets);
      final Image logoImage = tester.widget(logoFinder.first);
      expect(logoImage.height, greaterThanOrEqualTo(48.0),
          reason: 'Logo must be prominently sized to fill app bar height');

      // Controls on right: search, notifications, language, wallet, profile
      expect(find.byIcon(Icons.search), findsWidgets);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(find.byIcon(Icons.language), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);

      // Verify circular icon backgrounds are subtle and translucent (10-20% opacity)
      final searchIconContainer = find.ancestor(
        of: find.byIcon(Icons.search),
        matching: find.byType(Container),
      );
      expect(searchIconContainer, findsWidgets);
      final Container container = tester.widget(searchIconContainer.first);
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color?.opacity, inInclusiveRange(0.10, 0.20),
          reason: 'Action icon circular background must have subtle 10-20% opacity');
      expect(decoration?.border, isNull,
          reason: 'Action icon circular container must not have thick or bright borders');

      await cleanUpHomeScreen(tester);
    });

    testWidgets(
        '2. Category navigation area renders on a black background directly below the app bar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpHomeScreen(tester);

      // Check category tabs exist: Movies, Short Film, Series, Mini Series
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Short Film'), findsOneWidget);
      expect(find.text('Series'), findsOneWidget);
      expect(find.text('Mini Series'), findsOneWidget);

      // Verify selected tab has bright red accent background
      final movieTabFinder = find.ancestor(
        of: find.text('Movies'),
        matching: find.byType(AnimatedContainer),
      );
      expect(movieTabFinder, findsOneWidget);

      final AnimatedContainer movieTabContainer = tester.widget(movieTabFinder);
      final decoration = movieTabContainer.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0xFFE50914)),
          reason: 'Selected category tab must be highlighted in red accent');

      await cleanUpHomeScreen(tester);
    });

    testWidgets(
        '3. Continue Watching spans the full available content width without horizontal padding',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpHomeScreen(tester);

      final bannerFinder = find.byType(ContinueWatchingBanner);
      expect(bannerFinder, findsOneWidget);

      // Check width of ContinueWatchingBanner matches the device screen width (390.0)
      final bannerSize = tester.getSize(bannerFinder);
      expect(bannerSize.width, equals(390.0),
          reason: 'Continue Watching banner must span the full available device width');

      // Left-side title & progress scoped to ContinueWatchingBanner
      expect(find.descendant(of: bannerFinder, matching: find.text('Continue Watching')), findsOneWidget);
      expect(find.descendant(of: bannerFinder, matching: find.text('Marathi Short Film Showcase')), findsOneWidget);
      expect(find.descendant(of: bannerFinder, matching: find.text('40% watched | Drama')), findsOneWidget);
      expect(find.descendant(of: bannerFinder, matching: find.text('Resume')), findsOneWidget);

      await cleanUpHomeScreen(tester);
    });

    testWidgets(
        '4. MovieCard media area is proportionally expanded and clipped to top rounded corners',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpHomeScreen(tester);

      final movieCardFinder = find.byType(MovieCard);
      expect(movieCardFinder, findsWidgets);

      // Verify MovieCard standard height and poster aspect ratio constant
      expect(MovieCard.standardHeight, equals(220.0));
      expect(MovieCard.standardPosterAspectRatio, closeTo(16 / 9, 0.001));

      // Verify top rounded corner clipping via ClipRRect
      final clipRRectFinder = find.descendant(
        of: movieCardFinder.first,
        matching: find.byType(ClipRRect),
      );
      expect(clipRRectFinder, findsWidgets);

      final ClipRRect clipRRect = tester.widget(clipRRectFinder.first);
      final borderRadius = clipRRect.borderRadius as BorderRadius;
      expect(borderRadius.topLeft.x, greaterThan(0));
      expect(borderRadius.topRight.x, greaterThan(0));
      expect(borderRadius.bottomLeft.x, equals(0),
          reason: 'Media is clipped only to the top rounded corners');
      expect(borderRadius.bottomRight.x, equals(0));

      await cleanUpHomeScreen(tester);
    });

    testWidgets(
        '5. MovieCard compact details section sits directly below media area with 2-line title wrapping',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpHomeScreen(tester);

      final titleFinder = find.text('Marathi Short Film Showcase');
      expect(titleFinder, findsWidgets);

      final Text titleText = tester.widget(titleFinder.first);
      expect(titleText.maxLines, equals(2),
          reason: 'Titles must support wrapping to a maximum of 2 lines');
      expect(titleText.overflow, equals(TextOverflow.ellipsis));

      // Watch Now button exists
      final watchNowFinder = find.text('Watch Now');
      expect(watchNowFinder, findsWidgets);

      await cleanUpHomeScreen(tester);
    });

    testWidgets(
        '6. Section headings have white text for title and red accent for See All with arrow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpHomeScreen(tester);

      // Heading: Marathi - Latest Short Films
      final sectionTitleFinder = find.text('Marathi - Latest Short Films');
      expect(sectionTitleFinder, findsOneWidget);

      final Text sectionTitle = tester.widget(sectionTitleFinder);
      expect(sectionTitle.style?.color, equals(Colors.white));

      // See All action
      final seeAllFinder = find.text('See All');
      expect(seeAllFinder, findsWidgets);

      final Text seeAllText = tester.widget(seeAllFinder.first);
      expect(seeAllText.style?.color, equals(const Color(0xFFE50914)),
          reason: 'See All action must use Filmytell red accent');

      final arrowFinder = find.byIcon(Icons.arrow_forward_ios_rounded);
      expect(arrowFinder, findsWidgets);
      final Icon arrowIcon = tester.widget(arrowFinder.first);
      expect(arrowIcon.color, equals(const Color(0xFFE50914)));

      await cleanUpHomeScreen(tester);
    });
  });
}
