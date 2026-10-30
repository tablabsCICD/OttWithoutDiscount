import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ott/app/core/utils/content_type.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';
import 'package:ott/app/provider/onboarding_tour_provider.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/widgets/customtextfield.dart';
import 'package:ott/app/widgets/movieCard.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/themes/custom_theme.dart';
import 'package:ott/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'isDark': true});
  });

  group('Theme Configurations (AppTheme)', () {
    testWidgets('Light theme has white scaffold, black canvas, and light card',
        (tester) async {
      final theme = AppTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
      expect(theme.canvasColor, const Color(0xFF000000));
      expect(theme.cardColor, Colors.grey[100]);
      expect(theme.primaryColor, const Color(0xFFCD2027));
      expect(theme.colorScheme.brightness, Brightness.light);
    });

    testWidgets('Dark theme has black scaffold, white canvas, and dark card',
        (tester) async {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(theme.canvasColor, const Color(0xFFFFFFFF));
      expect(theme.cardColor, Colors.grey[900]);
      expect(theme.primaryColor, const Color(0xFFCD2027));
      expect(theme.colorScheme.brightness, Brightness.dark);
    });
  });

  group('ThemeProvider Toggle and State', () {
    test('ThemeProvider initializes with given theme and toggles correctly', () async {
      final themeProvider = ThemeProvider(isDark: true);
      expect(themeProvider.isDark, isTrue);
      expect(themeProvider.getTheme.brightness, Brightness.dark);

      await themeProvider.toggleTheme();
      expect(themeProvider.isDark, isFalse);
      expect(themeProvider.getTheme.brightness, Brightness.light);

      await themeProvider.toggleTheme();
      expect(themeProvider.isDark, isTrue);
      expect(themeProvider.getTheme.brightness, Brightness.dark);
    });
  });

  group('MovieCard Theme Consistency', () {
    Widget buildTestCardWithTheme({
      required Content movie,
      required ThemeData theme,
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
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
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

    testWidgets('MovieCard uses light theme cardColor and canvasColor in Light Mode',
        (WidgetTester tester) async {
      final movie = Content(
        id: 101,
        title: 'Theme Test Movie',
        type: ContentType.movie,
        genreList: ['Drama'],
        price: 99.0,
      );

      await tester.pumpWidget(
        buildTestCardWithTheme(
          movie: movie,
          theme: AppTheme.lightTheme,
        ),
      );
      await tester.pumpAndSettle();

      // Find the card container
      final animatedContainerFinder = find.byType(AnimatedContainer);
      expect(animatedContainerFinder, findsWidgets);

      final animatedContainer =
          tester.widget<AnimatedContainer>(animatedContainerFinder.first);
      final decoration = animatedContainer.decoration as BoxDecoration?;
      expect(decoration?.color, AppTheme.lightTheme.cardColor);

      // Verify title text color matches canvasColor (black)
      final titleFinder = find.text('Theme Test Movie');
      expect(titleFinder, findsOneWidget);
      final titleText = tester.widget<Text>(titleFinder);
      expect(titleText.style?.color, AppTheme.lightTheme.canvasColor);
    });

    testWidgets('MovieCard uses dark theme cardColor and canvasColor in Dark Mode',
        (WidgetTester tester) async {
      final movie = Content(
        id: 102,
        title: 'Dark Theme Movie',
        type: ContentType.movie,
        genreList: ['Thriller'],
        price: 149.0,
      );

      await tester.pumpWidget(
        buildTestCardWithTheme(
          movie: movie,
          theme: AppTheme.darkTheme,
        ),
      );
      await tester.pumpAndSettle();

      final animatedContainerFinder = find.byType(AnimatedContainer);
      expect(animatedContainerFinder, findsWidgets);

      final animatedContainer =
          tester.widget<AnimatedContainer>(animatedContainerFinder.first);
      final decoration = animatedContainer.decoration as BoxDecoration?;
      expect(decoration?.color, AppTheme.darkTheme.cardColor);

      // Verify title text color matches canvasColor (white)
      final titleFinder = find.text('Dark Theme Movie');
      expect(titleFinder, findsOneWidget);
      final titleText = tester.widget<Text>(titleFinder);
      expect(titleText.style?.color, AppTheme.darkTheme.canvasColor);
    });
  });

  group('CustomTextField Dynamic Theme Updates', () {
    testWidgets('CustomTextField rebuilds with updated theme when theme toggles',
        (WidgetTester tester) async {
      final themeProvider = ThemeProvider(isDark: true);
      final controller = TextEditingController();

      Widget buildTestApp() {
        return ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
          child: Consumer<ThemeProvider>(
            builder: (context, tp, _) {
              return MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: tp.isDark ? ThemeMode.dark : ThemeMode.light,
                home: Scaffold(
                  body: CustomTextField(
                    controller: controller,
                    hintText: 'Search or enter...',
                    textInputType: TextInputType.text,
                    label: 'Test Label',
                  ),
                ),
              );
            },
          ),
        );
      }

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // In Dark Theme: label text color is canvasColor (white)
      final labelFinder = find.text('Test Label');
      expect(labelFinder, findsOneWidget);
      var labelWidget = tester.widget<Text>(labelFinder);
      expect(labelWidget.style?.color, AppTheme.darkTheme.canvasColor);

      // Toggle to Light Theme
      await themeProvider.toggleTheme();
      await tester.pumpAndSettle();

      // In Light Theme: label text color updates to canvasColor (black)
      labelWidget = tester.widget<Text>(labelFinder);
      expect(labelWidget.style?.color, AppTheme.lightTheme.canvasColor);
    });
  });

  group('Bottom Navigation Theme Consistency', () {
    testWidgets(
        'Bottom navigation colors adapt dynamically when ThemeProvider changes mode',
        (WidgetTester tester) async {
      final themeProvider = ThemeProvider(isDark: false); // starts in Light Mode

      Widget buildNavApp() {
        return ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
          child: Consumer<ThemeProvider>(
            builder: (context, tp, _) {
              final activeTheme = tp.getTheme;
              return MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: tp.isDark ? ThemeMode.dark : ThemeMode.light,
                home: Scaffold(
                  backgroundColor: activeTheme.scaffoldBackgroundColor,
                  bottomNavigationBar: BottomNavigationBar(
                    type: BottomNavigationBarType.fixed,
                    currentIndex: 0,
                    backgroundColor: activeTheme.scaffoldBackgroundColor,
                    selectedItemColor: activeTheme.primaryColor,
                    unselectedItemColor: activeTheme.canvasColor,
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.search),
                        label: 'Search',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }

      await tester.pumpWidget(buildNavApp());
      await tester.pumpAndSettle();

      // Light Mode Check
      var navBar = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(navBar.backgroundColor, AppTheme.lightTheme.scaffoldBackgroundColor);
      expect(navBar.unselectedItemColor, AppTheme.lightTheme.canvasColor);
      expect(navBar.selectedItemColor, AppTheme.lightTheme.primaryColor);

      // Switch to Dark Mode
      await themeProvider.toggleTheme();
      await tester.pumpAndSettle();

      // Dark Mode Check
      navBar = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(navBar.backgroundColor, AppTheme.darkTheme.scaffoldBackgroundColor);
      expect(navBar.unselectedItemColor, AppTheme.darkTheme.canvasColor);
      expect(navBar.selectedItemColor, AppTheme.darkTheme.primaryColor);
    });
  });
}

