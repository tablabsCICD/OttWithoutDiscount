import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/pages/series%20details%20page/seriesdetailspage.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/provider/offline_download_provider.dart';
import 'package:ott/app/provider/playMediaProvider.dart';
import 'package:ott/app/provider/series_provider.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/provider/videoProvider.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/models/seriesModel.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeSeriesProvider extends SeriesProvider {
  final SeriesEntity _testSeries;
  _FakeSeriesProvider(this._testSeries);

  @override
  bool get isLoading => false;

  @override
  SeriesEntity? get series => _testSeries;

  @override
  Future<void> fetchSeriesDetails(int seriesId) async {}
}

class _FakeVideoProvider extends VideoProvider {
  @override
  Future<Map<String, Object>> getRatingReview(int movieId) async =>
      <String, Object>{};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'SeriesDetailsPage renders SeasonEntity with releaseDate when isFeatured is true without TypeError',
      (WidgetTester tester) async {
    final testSeason = SeasonEntity(
      seasonId: 1,
      seasonNumber: 1,
      title: 'Season 1',
      description: 'Test season description',
      releaseDate: 1793318400000,
      price: 1.0,
      isSeasonPurchased: false,
      episodes: [],
    );

    final testSeries = SeriesEntity(
      id: 9,
      title: 'Test Series',
      description: 'Test series description',
      posterUrl: 'https://example.com/poster.jpg',
      seasons: [testSeason],
    );

    final testContent = Content(
      id: 9,
      title: 'Test Series',
      description: 'Test series description',
      isFeatured: true,
      releaseDate: 1793318400000,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SeriesProvider>(
            create: (_) => _FakeSeriesProvider(testSeries),
          ),
          ChangeNotifierProvider<VideoProvider>(
            create: (_) => _FakeVideoProvider(),
          ),
          ChangeNotifierProvider<PlayMediaProvider>(
            create: (_) => PlayMediaProvider(),
          ),
          ChangeNotifierProvider<ThemeProvider>(
            create: (_) => ThemeProvider(),
          ),
          ChangeNotifierProvider<OfflineDownloadProvider>(
            create: (_) => OfflineDownloadProvider(),
          ),
          ChangeNotifierProvider<DashboardProvider>(
            create: (_) => DashboardProvider(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SeriesDetailsPage(
            seriesId: 9,
            content: testContent,
          ),
        ),
      ),
    );

    await tester.pump();

    // Verify no crash and release date highlight is displayed
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Release On:'), findsWidgets);
  });
}
