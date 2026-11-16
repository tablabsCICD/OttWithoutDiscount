import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:ott/app/widgets/content_type_chip.dart';
import 'package:ott/app/pages/bookmarks page/component/bookmark_card.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';
import 'package:ott/app/core/utils/content_type.dart';
import 'package:ott/data/models/content.dart';
import 'package:provider/provider.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';

enum BookmarkFilter { movies, series, shorts, shortFilms }

class BookmarkPage extends StatefulWidget {
  const BookmarkPage({super.key});

  @override
  State<BookmarkPage> createState() => _BookmarkPageState();
}

class _BookmarkPageState extends State<BookmarkPage> {
  BookmarkFilter selectedFilter = BookmarkFilter.movies;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BookmarkProvider>().getUserBookmarks();
      context.read<BookmarkProvider>().getUserBookmarkShort();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: FilmytellAppBar.main(title: lang.bookmarkMyBookmarks),
      body: Consumer<BookmarkProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return Center(
                child: CircularProgressIndicator(
              color: theme.primaryColor,
            ));
          }

          final allBookmarks = provider.bookmarksList;
          final allShortBookmarks = provider.shortBookmarksList;
          final bool hasAnyBookmarks =
              allBookmarks.isNotEmpty || allShortBookmarks.isNotEmpty;

          if (!hasAnyBookmarks) {
            return _emptyState(theme, message: lang.bookmarkNoBookmarksAdded);
          }

          if (selectedFilter == BookmarkFilter.shorts) {
            if (allShortBookmarks.isEmpty) {
              return _emptyState(
                theme,
                message: lang.bookmarkNoBookmarksFound,
              );
            }

            return Column(
              children: [
                _segmentedToggle(theme),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;

                      int crossAxisCount = 2;
                      if (width >= 1400) {
                        crossAxisCount = 6;
                      } else if (width >= 1100) {
                        crossAxisCount = 5;
                      } else if (width >= 800) {
                        crossAxisCount = 4;
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 24,
                          childAspectRatio: 9 / 16,
                        ),
                        itemCount: allShortBookmarks.length,
                        itemBuilder: (context, index) {
                          final short = allShortBookmarks[index];
                          return ShortBookmarkPosterCard(short: short);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          }

          final filteredBookmarks = _filterBookmarks(allBookmarks);
          if (filteredBookmarks.isEmpty) {
            return _emptyState(
              theme,
              message: lang.bookmarkNoBookmarksFound,
            );
          }

          return Column(
            children: [
              _segmentedToggle(theme),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;

                    int crossAxisCount = 1;
                    if (width >= 1400) {
                      crossAxisCount = 4;
                    } else if (width >= 1100) {
                      crossAxisCount = 3;
                    } else if (width >= 800) {
                      crossAxisCount = 2;
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 24,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: filteredBookmarks.length,
                      itemBuilder: (context, index) {
                        final movie = filteredBookmarks[index];
                        return BookmarkPosterCard(movie: movie);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Content> _filterBookmarks(List<Content> bookmarks) {
    switch (selectedFilter) {
      case BookmarkFilter.movies:
        return bookmarks
            .where(
                (item) => ContentType.normalize(item.type) == ContentType.movie)
            .toList();
      case BookmarkFilter.series:
        return bookmarks
            .where((item) => (item.type ?? '').toLowerCase() == 'series')
            .toList();
      case BookmarkFilter.shorts:
        return [];
      case BookmarkFilter.shortFilms:
        return bookmarks
            .where((item) =>
                ContentType.normalize(item.type) == ContentType.shortFilm)
            .toList();
    }
  }

  /// Filter chips styled exactly like the Home page content-type chips.
  Widget _segmentedToggle(ThemeData theme) {
    final lang = AppLocalizations.of(context)!;
    final items = <({BookmarkFilter value, String label})>[
      (value: BookmarkFilter.movies, label: lang.movie),
      (value: BookmarkFilter.series, label: lang.series),
      (value: BookmarkFilter.shorts, label: lang.minSeries),
      (value: BookmarkFilter.shortFilms, label: lang.shortFilm),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ContentTypeChip(
                  label: item.label,
                  selected: selectedFilter == item.value,
                  onTap: () {
                    if (selectedFilter == item.value) return;
                    setState(() => selectedFilter = item.value);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme, {required String message}) {
    return Center(
      child: Column(
        children: [
          _segmentedToggle(theme),
          const Spacer(),
          Icon(
            Icons.bookmark_border,
            color: theme.canvasColor,
            size: 60,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              color: theme.canvasColor,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
