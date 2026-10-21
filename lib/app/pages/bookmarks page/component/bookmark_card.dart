import 'package:flutter/material.dart';
import 'package:ott/app/pages/watchlist%20page/component/DisplayTrailer.dart';
import 'package:ott/app/core/utils/content_type.dart';
import 'package:ott/app/pages/movie%20details%20page/MovieDetailsPage.dart';
import 'package:ott/app/pages/series%20details%20page/seriesdetailspage.dart';
import 'package:ott/app/pages/shorts%20page/component/ShortsPlayerPage.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';
import 'package:ott/app/provider/shorts_provider.dart';
import 'package:ott/app/core/utils/sharepreferences.dart';
import 'package:ott/app/widgets/StarRatingWidget.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/models/shorts.dart';
import 'package:provider/provider.dart';

class BookmarkPosterCard extends StatelessWidget {
  final Content movie;

  const BookmarkPosterCard({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<BookmarkProvider>();
    final bool isBookmarked = provider.isBookmarkedLocally(movie.id ?? 0);

    final posterUrl = movie.posterUrlList?.isNotEmpty == true
        ? movie.posterUrlList!.first
        : "";

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => movie.isFeatured ?? true
                  ? TrailerPage(
                      trailerUrl: movie.trailerUrl ?? "",
                      isTrailerUrl: true,
                      content: movie,
                    )
                  : ContentType.isMovieLike(movie.type)
                      ? MovieDetailsPage(
                          movieId: movie.id ?? 0,
                          contentType: movie.type,
                        )
                      : SeriesDetailsPage(
                          seriesId: movie.id ?? 0, content: movie),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🎬 Poster
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: Image.network(
                    posterUrl,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.dividerColor,
                      child: const Icon(Icons.movie, size: 40),
                    ),
                  ),
                ),
              ),
            ),

            /// ⭐ Rating
            Row(
              children: [
                SizedBox(
                  width: 8,
                ),
                StarRatingWidget(
                  rating: movie.ratings ?? 0,
                ),
                Text(
                  " (${movie.ratingCount ?? 0})",
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.canvasColor.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 22,
                    color: theme.primaryColor,
                  ),
                  onPressed: () {
                    provider.toggleBookmark(movie);

                    CustomToast.show(
                      context,
                      isBookmarked
                          ? "${movie.title} removed from bookmarks"
                          : "${movie.title} added to bookmarks",
                      isSuccess: true,
                      duration: Duration(
                        seconds: 1,
                      ),
                    );
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                movie.title ?? "",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShortBookmarkPosterCard extends StatelessWidget {
  final ShortModel short;

  const ShortBookmarkPosterCard({super.key, required this.short});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookmarkProvider = context.watch<BookmarkProvider>();
    final bool isBookmarked =
        bookmarkProvider.isShortBookmarkedLocally(short.id);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final user =
              await LocalSharePreferences.localSharePreferences.getUser();
          await context
              .read<ShortProvider>()
              .fetchShortDetail(short.id, user?.id ?? 1);

          if (context.read<ShortProvider>().shortDetail != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShortsPlayerPage(
                  short: context.read<ShortProvider>().shortDetail!,
                ),
              ),
            );
          }
        },
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: Image.network(
                  short.posterUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: theme.dividerColor,
                    child: const Icon(Icons.movie, size: 40),
                  ),
                ),
              ),
            ), // Bottom gradient
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                ),
              ),
            ),
            Positioned(
              top: 5,
              right: 5,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 22,
                  color: theme.primaryColor,
                ),
                onPressed: () async {
                  await bookmarkProvider.toggleBookmarkShort(short);

                  CustomToast.show(
                    context,
                    isBookmarked
                        ? "${short.title} removed from bookmarks"
                        : "${short.title} added to bookmarks",
                    isSuccess: true,
                    duration: const Duration(seconds: 1),
                  );
                },
              ),
            ),
            Positioned(
              bottom: 3,
              left: 5,
              child: Text(
                short.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2), // x, y
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
