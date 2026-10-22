import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:ott/app/pages/watchlist%20page/component/playMoviePage.dart';
import 'package:ott/app/widgets/responsive_poster_image.dart';
import 'package:ott/app/widgets/shimmer%20loader/shimmer_loader.dart';

/// A wide, cinematic Continue Watching banner featuring a left-side
/// information panel, playback progress bar, circular Resume button,
/// right-side backdrop artwork with a smooth gradient transition,
/// and bottom circular pagination indicators.
class ContinueWatchingBanner extends StatefulWidget {
  final List<Content> items;
  final String selectedType;
  final VoidCallback? onPlaybackFinished;

  const ContinueWatchingBanner({
    super.key,
    required this.items,
    this.selectedType = 'MOVIE',
    this.onPlaybackFinished,
  });

  @override
  State<ContinueWatchingBanner> createState() => _ContinueWatchingBannerState();
}

class _ContinueWatchingBannerState extends State<ContinueWatchingBanner> {
  late final PageController _pageController;
  int _currentIndex = 0;

  static const Color _bannerBackground = Colors.black;
  static const Color _brandRed = Color(0xFFE50914);
  static const Color _inactiveDotColor = Color(0xFF555562);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant ContinueWatchingBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentIndex >= widget.items.length && widget.items.isNotEmpty) {
      _currentIndex = widget.items.length - 1;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Resolves and prioritizes high-resolution landscape backdrop artwork
  /// for the Continue Watching banner.
  static List<String> getBackdropCandidates(Content movie) {
    final rawList = <String?>[
      if (movie.posterUrlList != null) ...movie.posterUrlList!,
    ];
    final sanitized = ResponsivePosterImage.sanitizeAndPrioritizeUrls(rawList);
    if (sanitized.isEmpty) return const [];

    final scored = sanitized.map((url) {
      int score = 0;
      final lower = url.toLowerCase();

      // Prioritize confirmed landscape and high-resolution backdrop keywords
      if (lower.contains('backdrop') ||
          lower.contains('landscape') ||
          lower.contains('horizontal') ||
          lower.contains('1600x900') ||
          lower.contains('1920x1080') ||
          lower.contains('1280x720') ||
          lower.contains('wide') ||
          lower.contains('banner') ||
          lower.contains('hero')) {
        score += 80;
      }

      // Demote thumbnails or portrait-specific assets
      if (lower.contains('thumb') ||
          lower.contains('small') ||
          lower.contains('portrait') ||
          lower.contains('vertical') ||
          lower.contains('_2x3') ||
          lower.contains('avatar')) {
        score -= 40;
      }

      // Check aspect ratio from in-memory cache
      final ratio = ResponsivePosterImage.getAspectRatio(url);
      if (ratio != null) {
        if (ratio >= 1.5) {
          score += 100;
        } else if (ratio < 1.0) {
          score -= 60;
        }
      }

      // Check dimensions from in-memory cache
      final dim = ResponsivePosterImage.getDimensions(url);
      if (dim != null) {
        if (dim.width >= 1200) score += 40;
        if (dim.width >= 1600 && dim.height >= 900) score += 60;
        if (dim.width < 400 && dim.height < 400) score -= 30;
      }

      return MapEntry(url, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  Future<void> _playContent(BuildContext context, Content movie) async {
    if (movie.id == null) return;

    final dashboardProvider = context.read<DashboardProvider>();
    final navigator = Navigator.of(context);

    Content contentToPlay = movie;
    var contentUrl = contentToPlay.contentUrl;

    if (contentUrl == null || contentUrl.trim().isEmpty) {
      final fetchedContent = await dashboardProvider.getContentById(movie.id!);
      if (!mounted) return;

      if (fetchedContent != null) {
        fetchedContent.watchedSeconds ??= movie.watchedSeconds;
        fetchedContent.watchedPercentage ??= movie.watchedPercentage;
        fetchedContent.seasonId ??= movie.seasonId;
        fetchedContent.episodeId ??= movie.episodeId;
        contentToPlay = fetchedContent;
        contentUrl = contentToPlay.contentUrl;
      }
    }

    if (!mounted || !context.mounted) return;

    if (contentUrl == null || contentUrl.trim().isEmpty) {
      CustomToast.show(
        context,
        "Video is not available",
        isSuccess: false,
      );
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => PlayMediaPage(
          videoUrl: contentUrl!,
          content: contentToPlay,
          seasonIndex: contentToPlay.seasonId ?? 0,
          episodeIndex: contentToPlay.episodeId ?? 0,
          seasons: contentToPlay.type?.toLowerCase() == "series" ? [] : null,
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      dashboardProvider.getContinueWatchedMovieList(widget.selectedType);
      widget.onPlaybackFinished?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final bool isDesktop = totalWidth >= 1024;
        final bool isTablet = totalWidth >= 600 && totalWidth < 1024;
        final bool isMobile = totalWidth < 600;
        final bool isNarrow = totalWidth < 360;

        // Calculate height dynamically from available width using 16:9 aspect ratio:
        // height = width * 9 / 16
        final double standard16x9Height = totalWidth * 9 / 16;
        final double bannerHeight = isDesktop
            ? standard16x9Height.clamp(280.0, 500.0)
            : standard16x9Height;

        final double infoWidth = totalWidth *
            (isDesktop ? 0.44 : (isTablet ? 0.48 : (isNarrow ? 0.55 : 0.52)));

        final double progressBarWidth =
            isNarrow ? 130.0 : (isMobile ? 160.0 : (isTablet ? 190.0 : 210.0));

        final bool hasMultiple = widget.items.length > 1;

        return Container(
          height: bannerHeight,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: _bannerBackground,
          ),
          clipBehavior: Clip.none,
          child: Stack(
            children: [
              // Page content
              if (hasMultiple)
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.items.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final movie = widget.items[index];
                    return _buildBannerSlide(
                      movie: movie,
                      infoWidth: infoWidth,
                      progressBarWidth: progressBarWidth,
                      isMobile: isMobile,
                      isTablet: isTablet,
                      isNarrow: isNarrow,
                    );
                  },
                )
              else
                _buildBannerSlide(
                  movie: widget.items.first,
                  infoWidth: infoWidth,
                  progressBarWidth: progressBarWidth,
                  isMobile: isMobile,
                  isTablet: isTablet,
                  isNarrow: isNarrow,
                ),

              // Bottom circular pagination indicators
              if (hasMultiple)
                Positioned(
                  bottom: isNarrow ? 8.0 : (isMobile ? 10.0 : 12.0),
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.items.length, (idx) {
                      final bool isActive = idx == _currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 3.5),
                        width: 7.0,
                        height: 7.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? _brandRed : _inactiveDotColor,
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBannerSlide({
    required Content movie,
    required double infoWidth,
    required double progressBarWidth,
    required bool isMobile,
    required bool isTablet,
    required bool isNarrow,
  }) {
    final backdropCandidates = getBackdropCandidates(movie);
    final primaryBackdropUrl = backdropCandidates.isNotEmpty
        ? backdropCandidates.first
        : (movie.posterUrlList != null && movie.posterUrlList!.isNotEmpty
            ? movie.posterUrlList!.first
            : null);

    final int percentage = (movie.watchedPercentage ?? 0).clamp(0, 100);
    final String? genre = (movie.genreList != null && movie.genreList!.isNotEmpty)
        ? movie.genreList!.first
        : null;

    final String progressGenreText = (genre != null && genre.trim().isNotEmpty)
        ? '$percentage% watched | $genre'
        : '$percentage% watched';

    final double progressFraction = (percentage / 100.0).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Complete Landscape Artwork (spans entire banner with BoxFit.contain, zero cropping)
        Positioned.fill(
          child: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: ResponsivePosterImage(
              imageUrl: primaryBackdropUrl,
              imageUrls: backdropCandidates,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              isDecorativeBackdrop: false,
              enableAmbientBackdrop: false,
              backgroundColor: Colors.black,
              loadingProgressColor: _brandRed,
              errorIconColor: Colors.white24,
              fallbackBuilder: () => Container(
                color: const Color(0xFF14141B),
                child: const Center(
                  child: Icon(
                    Icons.movie_outlined,
                    color: Colors.white24,
                    size: 44,
                  ),
                ),
              ),
            ),
          ),
        ),

        // 2. Smooth horizontal gradient transition overlay
        // Solid black on the far left, smoothly softening to transparent across the right
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.0, 0.28, 0.55, 0.85, 1.0],
                colors: [
                  Colors.black,
                  Color(0xF0000000), // ~94% solid black behind primary text
                  Color(0x66000000), // ~40% black
                  Color(0x0D000000), // ~5% black
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // 3. Subtle bottom gradient overlay for pagination indicator readability
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0.0, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.70),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // 4. Left side: Information Panel
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: infoWidth,
          child: Padding(
            padding: EdgeInsets.only(
              left: isNarrow ? 14.0 : (isMobile ? 18.0 : 26.0),
              right: 12.0,
              top: isNarrow ? 8.0 : (isMobile ? 12.0 : 16.0),
              bottom: isNarrow ? 14.0 : (isMobile ? 18.0 : 24.0),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: infoWidth - (isNarrow ? 26.0 : (isMobile ? 30.0 : 38.0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                // 1. Section heading: Continue Watching
                Text(
                  'Continue Watching',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: isNarrow
                        ? 11.5
                        : (isMobile ? 13.0 : (isTablet ? 14.0 : 15.0)),
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.88),
                    letterSpacing: 0.2,
                  ),
                ),

                SizedBox(height: isNarrow ? 3.0 : (isMobile ? 4.0 : 6.0)),

                // 2. Movie Title (prominent, bold, max 2 lines with ellipsis)
                Text(
                  movie.title ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: isNarrow
                        ? 20.0
                        : (isMobile ? 24.0 : (isTablet ? 28.0 : 32.0)),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),

                SizedBox(height: isNarrow ? 4.0 : (isMobile ? 6.0 : 8.0)),

                // 3. Watching progress and genre
                Text(
                  progressGenreText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: isNarrow
                        ? 11.5
                        : (isMobile ? 12.5 : (isTablet ? 13.0 : 14.0)),
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),

                SizedBox(height: isNarrow ? 6.0 : (isMobile ? 8.0 : 10.0)),

                // 4. Horizontal playback progress bar (constrained width matching column)
                SizedBox(
                  width: progressBarWidth,
                  height: 4.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progressFraction,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _brandRed,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: isNarrow ? 10.0 : (isMobile ? 14.0 : 18.0)),

                // 5. Resume button (circular red play button + white Resume label)
                Semantics(
                  button: true,
                  label: 'Resume ${movie.title ?? "movie"}',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _playContent(context, movie),
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4.0,
                          horizontal: 2.0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: isNarrow
                                  ? 32.0
                                  : (isMobile
                                      ? 36.0
                                      : (isTablet ? 40.0 : 42.0)),
                              height: isNarrow
                                  ? 32.0
                                  : (isMobile
                                      ? 36.0
                                      : (isTablet ? 40.0 : 42.0)),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _brandRed,
                                boxShadow: [
                                  BoxShadow(
                                    color: _brandRed.withValues(alpha: 0.45),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: isNarrow
                                    ? 20.0
                                    : (isMobile
                                        ? 22.0
                                        : (isTablet ? 25.0 : 27.0)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Resume',
                              style: GoogleFonts.inter(
                                fontSize: isNarrow
                                    ? 13.5
                                    : (isMobile
                                        ? 15.0
                                        : (isTablet ? 15.5 : 16.5)),
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
      ],
    );
  }
}

/// Shimmer skeleton loader for the Continue Watching banner matching its
/// landscape proportions and component layout.
class ContinueWatchingBannerShimmer extends StatelessWidget {
  const ContinueWatchingBannerShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        final bool isDesktop = totalWidth >= 1024;
        final bool isTablet = totalWidth >= 600 && totalWidth < 1024;
        final bool isMobile = totalWidth < 600;
        final bool isNarrow = totalWidth < 360;

        // Calculate height dynamically from available width using 16:9 aspect ratio:
        // height = width * 9 / 16
        final double standard16x9Height = totalWidth * 9 / 16;
        final double bannerHeight = isDesktop
            ? standard16x9Height.clamp(280.0, 500.0)
            : standard16x9Height;

        final double infoWidth = totalWidth *
            (isDesktop ? 0.44 : (isTablet ? 0.48 : (isNarrow ? 0.55 : 0.52)));

        final double progressBarWidth =
            isNarrow ? 130.0 : (isMobile ? 160.0 : (isTablet ? 190.0 : 210.0));

        return Container(
          height: bannerHeight,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.black,
          ),
          clipBehavior: Clip.none,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: infoWidth,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: isMobile ? 18.0 : 26.0,
                    right: 12.0,
                    top: isMobile ? 12.0 : 18.0,
                    bottom: isMobile ? 18.0 : 24.0,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      ShimmerLoader(
                        width: isMobile ? 110 : 130,
                        height: 14,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 10),
                      ShimmerLoader(
                        width: isMobile ? 140 : 180,
                        height: isMobile ? 18 : 22,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 6),
                      ShimmerLoader(
                        width: isMobile ? 100 : 130,
                        height: isMobile ? 18 : 22,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 10),
                      ShimmerLoader(
                        width: isMobile ? 90 : 110,
                        height: 12,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 10),
                      ShimmerLoader(
                        width: progressBarWidth,
                        height: 4.0,
                        borderRadius: 999,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ShimmerLoader(
                            width: isMobile ? 36 : 40,
                            height: isMobile ? 36 : 40,
                            borderRadius: 999,
                            shape: BoxShape.circle,
                          ),
                          const SizedBox(width: 10),
                          const ShimmerLoader(
                            width: 60,
                            height: 16,
                            borderRadius: 4,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ],
          ),
        );
      },
    );
  }
}
