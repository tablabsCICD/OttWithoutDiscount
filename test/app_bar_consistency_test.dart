// App bar design system: FilmytellAppBar main (56) / compact (48) variants
// with consistent styling. (Content detail pages: see
// content_detail_app_bar_test.dart.)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';

void _setIphone(WidgetTester tester) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);
}

void main() {
  group('FilmytellAppBar variants', () {
    Future<Rect> pumpBar(WidgetTester tester, PreferredSizeWidget bar) async {
      _setIphone(tester);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(primaryColor: const Color(0xFFCD2027)),
        home: Scaffold(appBar: bar, body: const SizedBox()),
      ));
      return tester.getRect(find.byType(AppBar));
    }

    testWidgets('main variant is 56pt below the status bar', (tester) async {
      final rect =
          await pumpBar(tester, const FilmytellAppBar.main(title: 'Watchlist'));
      expect(rect.height, 59 + FilmytellAppBarMetrics.main);
      expect(FilmytellAppBarMetrics.main, 56);
      final title = tester.widget<Text>(find.text('Watchlist'));
      expect(title.maxLines, 1);
      final style = DefaultTextStyle.of(
              tester.element(find.text('Watchlist')))
          .style;
      expect(style.fontSize, FilmytellAppBarMetrics.mainTitleSize);
      expect(style.fontWeight, FontWeight.w700);
    });

    testWidgets('compact variant is 48pt, branded, flat, centered',
        (tester) async {
      final rect = await pumpBar(
          tester, const FilmytellAppBar(title: 'Notifications'));
      expect(rect.height, 59 + FilmytellAppBarMetrics.compact);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.toolbarHeight, 48);
      expect(appBar.backgroundColor, const Color(0xFFCD2027));
      expect(appBar.foregroundColor, Colors.white);
      expect(appBar.elevation, 0);
      expect(appBar.scrolledUnderElevation, 0);
      expect(appBar.centerTitle, isTrue);
      final style = DefaultTextStyle.of(
              tester.element(find.text('Notifications')))
          .style;
      expect(style.fontSize, FilmytellAppBarMetrics.compactTitleSize);
    });

    testWidgets('long titles ellipsize instead of overflowing',
        (tester) async {
      await pumpBar(
          tester,
          const FilmytellAppBar(
              title: 'A very very long secondary screen title that keeps going '
                  'and going past the available width'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('custom leading (e.g. Edit Profile discard dialog) is kept',
        (tester) async {
      var tapped = false;
      await pumpBar(
        tester,
        FilmytellAppBar(
          title: 'Edit Profile',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_sharp),
            onPressed: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_sharp));
      expect(tapped, isTrue);
    });
  });
}
