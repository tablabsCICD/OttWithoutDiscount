import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ott/app/core/services/DeepLinkService.dart';
import 'package:ott/app/core/utils/content_type.dart';
import 'package:ott/app/core/constant/image_constant.dart';
import 'package:ott/app/pages/watchlist%20page/component/DisplayTrailer.dart';
import 'package:ott/app/pages/wallet%20page/MovieBillingPage.dart';
import 'package:ott/app/pages/movie%20details%20page/component/actionButtonWidget.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/provider/offline_download_provider.dart';
import 'package:ott/app/provider/videoProvider.dart';
import 'package:ott/app/widgets/StarRatingWidget.dart';
import 'package:ott/app/widgets/content_share_sheet.dart';
import 'package:ott/app/widgets/customtextfield.dart';
import 'package:ott/data/models/cast_member.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../widgets/show_toast.dart';
import '../watchlist page/component/playMoviePage.dart';
import 'component/displayStar.dart';
import 'component/starRating.dart';

class MovieDetailsPage extends StatefulWidget {
  final int movieId;
  final String? contentType;

  const MovieDetailsPage({
    super.key,
    required this.movieId,
    this.contentType,
  });

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage> {
  static const double _mediaPlayerBottomMargin = 24;

  String get _contentType {
    final loadedType = context.read<DashboardProvider>().content.type;
    final resolved = ContentType.normalize(loadedType ?? widget.contentType);
    return resolved.isEmpty ? ContentType.movie : resolved;
  }

  bool isLoading = true;
  bool _contentLoadCompleted = false;
  bool _contentLoadFailed = false;
  bool _isDescriptionExpanded = false;
  final TrailerPreviewController _trailerController =
      TrailerPreviewController();
  final TrailerPreviewController _teaserController = TrailerPreviewController();
  final ScrollController _tvScrollController = ScrollController();
  final FocusNode _heroFocusNode = FocusNode(debugLabel: 'movieHero');
  Timer? _heroTrailerTimer;
  bool _isHeroTrailerPlaying = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    });
  }

  Future<void> _fetchData() async {
    final dashboardProvider =
        Provider.of<DashboardProvider>(context, listen: false);
    try {
      final content = await dashboardProvider.getContentById(widget.movieId);
      final hasValidContent = content?.id == widget.movieId;

      if (!hasValidContent) {
        if (mounted) {
          setState(() {
            _contentLoadFailed = true;
            _contentLoadCompleted = true;
            isLoading = false;
          });
        }
        return;
      }
      final loadedContent = content!;

      await dashboardProvider.getCastByContentId(widget.movieId);
      await Provider.of<VideoProvider>(context, listen: false)
          .getRatingReview(widget.movieId);
      if (mounted) {
        await Provider.of<OfflineDownloadProvider>(context, listen: false)
            .refreshStatus(loadedContent);
        await Provider.of<BookmarkProvider>(context, listen: false)
            .getUserBookmarks();
        await dashboardProvider.getContinueWatchedMovieList(
          ContentType.normalize(loadedContent.type ?? widget.contentType),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _contentLoadFailed = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _contentLoadCompleted = true;
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _trailerController.pause?.call();
    _teaserController.pause?.call();
    _heroTrailerTimer?.cancel();
    _tvScrollController.dispose();
    _heroFocusNode.dispose();
    super.dispose();
  }

  Future<void> _playMovie(Content movie) async {
    if (movie.id == null) return;

    Content contentToPlay = movie;
    var contentUrl = contentToPlay.contentUrl?.trim();

    if (contentUrl == null || contentUrl.isEmpty) {
      final fetchedContent =
          await context.read<DashboardProvider>().getContentById(movie.id!);
      if (!mounted) return;

      if (fetchedContent != null) {
        fetchedContent.watchedSeconds ??= movie.watchedSeconds;
        fetchedContent.watchedPercentage ??= movie.watchedPercentage;
        contentToPlay = fetchedContent;
        contentUrl = contentToPlay.contentUrl?.trim();
      }
    }

    if (contentUrl == null || contentUrl.isEmpty) {
      contentUrl = (contentToPlay.trailerUrl ?? contentToPlay.teaserUrl)?.trim();
    }

    if (contentUrl == null || contentUrl.isEmpty) {
      CustomToast.show(
        context,
        "Video is not available",
        isSuccess: false,
      );
      return;
    }

    final sanitizedUrl = Uri.encodeFull(contentUrl);

    await _trailerController.disposePlayer?.call();
    await _teaserController.disposePlayer?.call();
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayMediaPage(
          seasons: null,
          seasonIndex: 0,
          episodeIndex: 0,
          videoUrl: sanitizedUrl,
          content: contentToPlay,
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      context
          .read<DashboardProvider>()
          .getContinueWatchedMovieList(_contentType);
    });
  }

  @override
  Widget build(BuildContext context) {
    var selectedThemeData =
        Provider.of<ThemeProvider>(context, listen: true).getTheme;

    Content? movieContent =
        Provider.of<DashboardProvider>(context, listen: true).content;

    if (isLoading || !_contentLoadCompleted) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
        ),
      );
    }

    if (_contentLoadFailed) {
      return _buildContentUnavailableScaffold(selectedThemeData);
    }

    return Scaffold(
      backgroundColor: selectedThemeData.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: !(kIsWeb || ResponsiveWidget.isTv(context)),
        forceMaterialTransparency: true,
        foregroundColor: Colors.white,
        title: !ResponsiveWidget.isMobile(context)
            ? const Text('')
            : StarRatingWidget(
                rating: double.parse(
                  (Provider.of<DashboardProvider>(context).content.ratings ??
                          0.0)
                      .toStringAsFixed(1),
                ),
                starSize: 20,
                textSize: 16,
              ),
        actions: [
          _ageRating(movieContent.ageRating),
          SizedBox(
            width: 5,
          )
        ],
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Consumer<DashboardProvider>(
          builder: (context, provider, child) {
            final content = provider.content;

            return Stack(
              children: [
                !ResponsiveWidget.isMobile(context)
                    ? _buildCinematicTvView(content, selectedThemeData)
                    : _buildMobileView(content, selectedThemeData),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContentUnavailableScaffold(ThemeData selectedThemeData) {
    final lang = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: selectedThemeData.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: !(kIsWeb || ResponsiveWidget.isTv(context)),
        forceMaterialTransparency: true,
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.alertCircle,
                color: selectedThemeData.primaryColor,
                size: 46,
              ),
              const SizedBox(height: 14),
              Text(
                lang.noContentAvailable,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selectedThemeData.canvasColor,
                  fontSize: ResponsiveWidget.isMobile(context) ? 18 : 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "This content is currently unavailable. Please try again later.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selectedThemeData.canvasColor.withOpacity(0.7),
                  fontSize: ResponsiveWidget.isMobile(context) ? 14 : 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCinematicTvView(Content content, ThemeData selectedThemeData) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isHeroTrailerPlaying && _heroTrailerTimer == null) {
        _queueHeroTrailerAutoplay();
      }
    });

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.goBack): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              if (Navigator.canPop(context)) Navigator.pop(context);
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: ColoredBox(
            color: Colors.black,
            child: CustomScrollView(
              controller: _tvScrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: _buildTvHero(content, selectedThemeData),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      ResponsiveWidget.isDesktop(context) ? 64 : 32,
                      10,
                      ResponsiveWidget.isDesktop(context) ? 64 : 32,
                      56,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTvCastRail(context, content, selectedThemeData),
                        const SizedBox(height: 34),
                        _buildTvRecommendationRails(
                          context,
                          content,
                          selectedThemeData,
                        ),
                        const SizedBox(height: 34),
                        _buildDetailsSection(context, content),
                        const SizedBox(height: 28),
                        _buildGallery(context, content, previewAutoPlay: false),
                        const SizedBox(height: 28),
                        _buildRatingAndReviewsSection(context, content),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTvHero(Content content, ThemeData theme) {
    final size = MediaQuery.of(context).size;
    final heroHeight = (size.height * 0.78).clamp(560.0, 760.0);
    final backdrop = _heroImage(content);
    final hasResume = (content.watchedSeconds ?? 0) > 5 ||
        (content.watchedPercentage ?? 0) > 0;

    return Focus(
      focusNode: _heroFocusNode,
      autofocus: true,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          _queueHeroTrailerAutoplay();
        } else {
          _stopHeroTrailer();
        }
      },
      child: SizedBox(
        height: heroHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(backdrop),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 520),
              opacity: _isHeroTrailerPlaying ? 0.74 : 1,
              child: const SizedBox.expand(),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Colors.black12, Colors.black87, Colors.black],
                  stops: [0, 0.48, 1],
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent, Colors.black],
                  stops: [0, 0.46, 1],
                ),
              ),
            ),
            Positioned(
              left: ResponsiveWidget.isDesktop(context) ? 64 : 32,
              right: kIsWeb ? size.width * 0.52 : size.width * 0.43,
              bottom: 54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    content.title ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: ResponsiveWidget.isDesktop(context) ? 56 : 42,
                      height: 1.02,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTvMetaRow(content, theme),
                  const SizedBox(height: 16),
                  _buildExpandableDescription(
                    content.description ?? 'N/A',
                    theme,
                    maxCollapsedLines: 4,
                  ),
                  const SizedBox(height: 24),
                  content.isFeatured == true
                      ? _buildReleaseDateHighlight(context, content)
                      : _buildTvActionButtons(context, content, theme,
                          hasResume: hasResume),
                ],
              ),
            ),
            Positioned(
              right: ResponsiveWidget.isDesktop(context) ? 64 : 32,
              bottom: 70,
              width: kIsWeb
                  ? 620
                  : ResponsiveWidget.isDesktop(context)
                      ? 500
                      : 390,
              child: _buildTvTrailerPanel(content, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTvTrailerPanel(Content content, ThemeData theme) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: _isHeroTrailerPlaying ? 1 : 0.76,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: TrailerPreview(
                  trailerUrl: content.teaserOrTrailerUrl,
                  content: content,
                  controller: _trailerController,
                  autoPlay: false,
                  muted: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTvMetaRow(Content content, ThemeData theme) {
    final genres = (content.genreList ?? const <String>[])
        .where((item) => item.trim().isNotEmpty)
        .take(2)
        .join(' / ');
    final languages = (content.languageList ?? const <LanguageList>[])
        .map((item) => item.language)
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .take(2)
        .join(' / ');
    final items = <String>[
      '${(content.ratings ?? 0).toStringAsFixed(1)} rating',
      if (_releaseYearText(content.releaseDate).isNotEmpty)
        _releaseYearText(content.releaseDate),
      if ((content.runtime ?? 0) > 0) '${content.runtime} min',
      if (genres.isNotEmpty) genres,
      if (languages.isNotEmpty) languages,
      _qualityBadge(content),
      if ((content.ageRating ?? '').trim().isNotEmpty)
        content.ageRating!.trim(),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) => _buildTvMetaPill(item)).toList(),
    );
  }

  Widget _buildTvMetaPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildTvActionButtons(
    BuildContext context,
    Content content,
    ThemeData theme, {
    required bool hasResume,
  }) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _tvActionButton(
          theme: theme,
          label: content.isRental == true
              ? (hasResume ? 'Resume' : 'Watch Now')
              : 'Rent Rs ${content.price ?? 0}',
          icon: content.isRental == true
              ? (hasResume ? Icons.restart_alt : Icons.play_arrow_rounded)
              : Icons.lock_open_rounded,
          emphasized: true,
          onPressed: () {
            if (content.isRental == true) {
              _playMovie(content);
            } else {
              showDialog(
                context: context,
                builder: (_) => _buildConfirmationBox(context, content),
              );
            }
          },
        ),
        _tvActionButton(
          theme: theme,
          label: 'Watch Trailer',
          icon: Icons.movie_creation_outlined,
          onPressed: () => _openTrailer(content),
        ),
        _buildTvDownloadButton(context, content, theme),
        _tvActionButton(
          theme: theme,
          label: 'Share',
          icon: Icons.ios_share_rounded,
          onPressed: () => showContentShareSheet(
            context,
            content,
            contentType: _contentType == ContentType.shortFilm
                ? DeepLinkContentType.shortFilm
                : DeepLinkContentType.movie,
            unavailableMessage: "Movie details are not available yet",
          ),
        ),
        _tvActionButton(
          theme: theme,
          label: 'Gift',
          icon: LucideIcons.gift,
          onPressed: () => _showGiftDialog(context, content),
        ),
      ],
    );
  }

  Widget _buildTvBookmarkButton(
    BuildContext context,
    Content content,
    ThemeData theme,
  ) {
    final bookmarkProvider = context.watch<BookmarkProvider>();
    final id = content.id ?? 0;
    final isBookmarked = bookmarkProvider.isBookmarkedLocally(id);

    return _tvActionButton(
      theme: theme,
      label: isBookmarked ? 'Watchlisted' : 'Add to Watchlist',
      icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
      onPressed: id == 0
          ? null
          : () async {
              final wasBookmarked =
                  context.read<BookmarkProvider>().isBookmarkedLocally(id);
              await context.read<BookmarkProvider>().toggleBookmark(content);
              if (!mounted) return;
              CustomToast.show(
                context,
                wasBookmarked
                    ? '${content.title} removed from bookmarks'
                    : '${content.title} added to bookmarks',
                isSuccess: true,
              );
            },
    );
  }

  Widget _buildTvDownloadButton(
    BuildContext context,
    Content content,
    ThemeData theme,
  ) {
    if (!_canDownloadOffline(content)) {
      return _tvActionButton(
        theme: theme,
        label: 'Download',
        icon: Icons.download_rounded,
        onPressed: () => CustomToast.show(
          context,
          'Download is not available for this movie.',
          isSuccess: false,
        ),
      );
    }

    final contentId = content.id;
    if (contentId == null) return const SizedBox.shrink();

    return Consumer<OfflineDownloadProvider>(
      builder: (context, offlineProvider, _) {
        final isDownloading = offlineProvider.isDownloading(contentId);
        final isDownloaded = offlineProvider.isDownloaded(contentId);
        final progress = offlineProvider.progressFor(contentId);
        return _tvActionButton(
          theme: theme,
          label: isDownloading
              ? 'Downloading ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%'
              : isDownloaded
                  ? 'Downloaded'
                  : 'Download',
          icon: isDownloaded ? Icons.download_done_rounded : Icons.download,
          onPressed: isDownloading
              ? null
              : () async {
                  final result = isDownloaded
                      ? await offlineProvider.deleteContent(content)
                      : await offlineProvider.downloadContent(content);
                  if (!mounted) return;
                  CustomToast.show(
                    context,
                    result['message']?.toString() ?? 'Download updated',
                    isSuccess: result['success'] == true,
                  );
                },
        );
      },
    );
  }

  Widget _tvActionButton({
    required ThemeData theme,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool emphasized = false,
  }) {
    return _MovieTvFocusableScale(
      onPressed: onPressed,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          backgroundColor: emphasized
              ? theme.primaryColor
              : theme.primaryColor.withOpacity(0.82),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withOpacity(0.08),
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          minimumSize: const Size(0, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          shadowColor: theme.primaryColor.withOpacity(0.45),
          elevation: emphasized ? 12 : 4,
        ),
      ),
    );
  }

  Widget _buildTvCastRail(
    BuildContext context,
    Content content,
    ThemeData theme,
  ) {
    final provider = context.watch<DashboardProvider>();
    final fallbackCastList = (content.castList ?? const [])
        .where((name) => name.trim().isNotEmpty)
        .map((name) => CastMember(name: name.trim()))
        .toList();
    final castList =
        provider.castList.isNotEmpty ? provider.castList : fallbackCastList;

    if (provider.isLoadingCast) {
      return Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      );
    }

    if (castList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTvSectionTitle('Cast & Crew'),
        const SizedBox(height: 14),
        SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: castList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) =>
                _buildTvCastCard(context, castList[index], theme),
          ),
        ),
      ],
    );
  }

  Widget _buildTvCastCard(
    BuildContext context,
    CastMember cast,
    ThemeData theme,
  ) {
    final imageUrl = cast.image?.trim() ?? '';
    final displayName =
        (cast.name?.trim().isNotEmpty ?? false) ? cast.name!.trim() : 'N/A';
    final role =
        (cast.role?.trim().isNotEmpty ?? false) ? cast.role!.trim() : '';

    return _MovieTvFocusableScale(
      width: 132,
      onPressed: () {},
      child: SizedBox(
        width: 132,
        child: Column(
          children: [
            Container(
              height: 104,
              width: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
              ),
              child: ClipOval(
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildCastInitial(theme, displayName),
                      )
                    : _buildCastInitial(theme, displayName),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (role.isNotEmpty)
              Text(
                role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.58),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTvRecommendationRails(
    BuildContext context,
    Content current,
    ThemeData theme,
  ) {
    final dashboard = context.watch<DashboardProvider>();
    final rows = dashboard.dashboardData
        .where((row) => (row.movies ?? const <Content>[]).isNotEmpty)
        .take(3)
        .toList();
    final continueItems = dashboard.continueWatchedMovies
        .where((item) => item.id != null && item.id != current.id)
        .toList();

    if (rows.isEmpty && continueItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (continueItems.isNotEmpty) ...[
          _buildTvContentRail(
            context,
            'Continue Watching',
            continueItems,
            theme,
          ),
          const SizedBox(height: 28),
        ],
        for (final row in rows) ...[
          _buildTvContentRail(
            context,
            _railTitle(row.category),
            (row.movies ?? const <Content>[])
                .where((item) => item.id != current.id)
                .toList(),
            theme,
          ),
          const SizedBox(height: 28),
        ],
      ],
    );
  }

  Widget _buildTvContentRail(
    BuildContext context,
    String title,
    List<Content> items,
    ThemeData theme,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTvSectionTitle(title),
        const SizedBox(height: 14),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) =>
                _buildTvMovieCard(context, items[index], theme),
          ),
        ),
      ],
    );
  }

  Widget _buildTvMovieCard(
    BuildContext context,
    Content content,
    ThemeData theme,
  ) {
    final image = _heroImage(content) ?? '';
    return _MovieTvFocusableScale(
      width: 300,
      onPressed: content.id == null
          ? null
          : () {
              _stopHeroTrailer();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MovieDetailsPage(
                    movieId: content.id!,
                    contentType: content.type,
                  ),
                ),
              );
            },
      child: SizedBox(
        width: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 300,
                height: 170,
                color: Colors.black,
                child: Image.network(
                  image,
                  width: 300,
                  height: 170,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => Container(
                    width: 300,
                    height: 170,
                    color: Colors.grey.shade900,
                    child: const Icon(Icons.movie, color: Colors.white54),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              content.title ?? 'Untitled',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if ((content.ageRating ?? '').isNotEmpty) content.ageRating,
                if ((content.genreList ?? const <String>[]).isNotEmpty)
                  content.genreList!.first,
              ].whereType<String>().join('  |  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withOpacity(0.58)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTvSectionTitle(String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: TextStyle(
        color: theme.primaryColor,
        fontSize: 24,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  String _railTitle(String? category) {
    final raw = category?.trim();
    if (raw == null || raw.isEmpty) return 'More Like This';
    if (raw.toLowerCase().contains('trending')) return 'Trending';
    if (raw.toLowerCase().contains('latest')) return 'Recommended';
    if (raw.toLowerCase().contains('upcoming')) return 'More Like This';
    return raw;
  }

  void _queueHeroTrailerAutoplay() {
    _heroTrailerTimer?.cancel();
    _heroTrailerTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _heroTrailerTimer = null;
      _trailerController.mute?.call();
      _trailerController.play?.call();
      setState(() => _isHeroTrailerPlaying = true);
    });
  }

  void _stopHeroTrailer() {
    _heroTrailerTimer?.cancel();
    _heroTrailerTimer = null;
    _trailerController.pause?.call();
    if (_isHeroTrailerPlaying) {
      setState(() => _isHeroTrailerPlaying = false);
    }
  }

  Future<void> _openTrailer(Content content) async {
    _stopHeroTrailer();
    // Movie-detail responses can expose the playable promotional video as
    // either teaserUrl or trailerUrl. Use the model's established resolver;
    // both fields are promotional media and neither enters secure playback.
    final trailerUrl = content.teaserOrTrailerUrl?.trim() ?? '';
    if (kDebugMode) {
      debugPrint('TRAILER_FLOW: Trailer button clicked');
      debugPrint('TRAILER_FLOW: Trailer URL resolved');
    }
    if (trailerUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trailer is not available.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrailerPage(
          trailerUrl: trailerUrl,
          isTrailerUrl: true,
          content: content,
        ),
      ),
    );
  }

  void _showGiftDialog(BuildContext context, Content movie) {
    final theme = Theme.of(context);
    final TextEditingController countController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: theme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.gift,
                          color: theme.primaryColor, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        "Gift This Movie",
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Enter how many people you'd like to gift this movie to.",
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.canvasColor),
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    backgroundColor: theme.scaffoldBackgroundColor,
                    isDigits: true,
                    controller: countController,
                    hintText: "Number of recipients",
                    textInputType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text("Cancel",
                            style: TextStyle(color: theme.canvasColor)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        onPressed: () {
                          final count = int.tryParse(countController.text);
                          if (count == null || count <= 0) {
                            CustomToast.show(
                              dialogContext,
                              'Please enter valid number',
                              isSuccess: false,
                            );
                            return;
                          }

                          Navigator.pop(dialogContext);
                          _stopHeroTrailer();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MovieBillingPage(
                                movie: movie,
                                giftCount: count,
                              ),
                            ),
                          );
                        },
                        child: const Text("Continue",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(countController.dispose);
  }

  String? _heroImage(Content content) {
    final posters = content.posterUrlList ?? const <String>[];
    if (posters.isNotEmpty) return posters.first;
    return null;
  }

  String _releaseYearText(dynamic releaseDate) {
    final text = releaseDate?.toString().trim() ?? '';
    if (text.length >= 4) return text.substring(0, 4);
    return text;
  }

  String _qualityBadge(Content content) {
    final formats = [
      ...(content.audioFormatList ?? const <String>[]),
      ...(content.subtitleLanguageList ?? const <String>[]),
    ].join(' ').toLowerCase();
    if (formats.contains('4k') || formats.contains('uhd')) return '4K';
    return 'HD';
  }

  // Kept as the legacy non-mobile layout reference; TV/tablet now use
  // _buildCinematicTvView while mobile remains on _buildMobileView.
  // ignore: unused_element
  Widget _buildDesktopView(Content content, ThemeData selectedThemeData) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackground(
          content.posterUrlList != null && content.posterUrlList!.isNotEmpty
              ? content.posterUrlList![0]
              : null,
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.8),
                Colors.black.withOpacity(0.9),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              width: 1,
                              color: Colors.white.withOpacity(0.5),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 10,
                              right: 10,
                              top: 6,
                              bottom: 6,
                            ),
                            child: Text(
                              content.title ?? "",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: selectedThemeData.primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        StarRatingWidget(
                          rating: double.parse(
                            (content.ratings ?? 0.0).toStringAsFixed(1),
                          ),
                          starSize: 20,
                          textSize: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${content.ratingCount ?? '0'} reviews)',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const Spacer(),
                        _ageRating(content.ageRating ?? ""),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const SizedBox(height: 16),
                    content.isFeatured == true
                        ? _buildReleaseDateHighlight(
                            context,
                            content,
                            centered: true,
                          )
                        : Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildButtons(context, content),
                            ],
                          ),
                    const SizedBox(height: 16),
                    _buildCastSection(context, content),
                    const SizedBox(height: 16),
                    Text(
                      "  ${content.description ?? 'N/A'}",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailsSection(context, content),
                    const SizedBox(height: 16),
                    _buildGallery(context, content),
                    const SizedBox(height: 16),
                    _buildRatingAndReviewsSection(context, content),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 20, right: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 500,
                        height: 500,
                        child: TrailerPreview(
                          trailerUrl: content.teaserOrTrailerUrl,
                          content: content,
                          controller: _trailerController,
                        ),
                      ),
                    ),
                    /*  SizedBox(
                      height: 100,
                    ),
                    if (content.posterUrlList != null &&
                        content.posterUrlList!.isNotEmpty) ...[
                      Text(
                        "Gallery",
                        style: TextStyle(
                          color: selectedThemeData.primaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 160,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: content.posterUrlList!.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                content.posterUrlList![index],
                                width: 320,
                                fit: BoxFit.cover,
                              ),
                            );
                          },
                        ),
                      ),
                    ], */
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileView(Content content, ThemeData selectedThemeData) {
    final backgroundImage =
        content.posterUrlList != null && content.posterUrlList!.isNotEmpty
            ? content.posterUrlList!.first
            : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackground(backgroundImage),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.8),
                Colors.black.withOpacity(0.9),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 95),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: TrailerPreview(
                    trailerUrl: content.teaserOrTrailerUrl,
                    content: content,
                    controller: _trailerController,
                  ),
                ),
              ),
              const SizedBox(height: _mediaPlayerBottomMargin),
              Text(
                content.title ?? "",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: selectedThemeData.primaryColor,
                ),
              ),
              Row(
                children: [
                  Text(
                    (content.genreList != null && content.genreList!.isNotEmpty)
                        ? content.genreList!.join(' | ')
                        : 'N/A',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              _buildExpandableDescription(
                content.description ?? 'N/A',
                selectedThemeData,
                maxCollapsedLines: 3,
              ),
              const SizedBox(height: 8),
              content.isFeatured == true
                  ? _buildReleaseDateHighlight(context, content)
                  : Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildButtons(context, content),
                      ],
                    ),
              const SizedBox(height: 12),
              _buildCastSection(context, content),
              const SizedBox(height: 10),
              _buildDetailsSection(context, content),
              const SizedBox(height: 16),
              _buildGallery(context, content),
              const SizedBox(height: 16),
              _buildRatingAndReviewsSection(context, content),
              const SizedBox(height: 24),
              /*   const SizedBox(height: 35),
              if (content.posterUrlList != null &&
                  content.posterUrlList!.isNotEmpty) ...[
                Text(
                  "Gallery",
                  style: TextStyle(
                    color: selectedThemeData.primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: content.posterUrlList!.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          content.posterUrlList![index],
                          width: 320,
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 35),
                content.isRental == true
                    ? _buildRatingReviewSection(context, content)
                    : SizedBox.shrink(),
                const SizedBox(height: 35),
              ], */
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackground(String? imageUrl) {
    return imageUrl != null && imageUrl.isNotEmpty
        ? Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: Colors.grey),
          )
        : Container(color: Colors.black);
  }

  Widget _buildGallery(
    BuildContext context,
    Content content, {
    bool previewAutoPlay = true,
  }) {
    final theme = Theme.of(context);
    final posters = content.posterUrlList ?? [];

    if (posters.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Gallery",
          style: TextStyle(
            color: theme.primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: posters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 320,
                  height: 180,
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Image.network(
                    posters[index],
                    width: 320,
                    height: 180,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => Container(
                      width: 320,
                      color: Colors.black26,
                      child: Icon(
                        Icons.broken_image,
                        color: theme.canvasColor.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _galleryVideoUrl(Content content) {
    final teaserUrl = content.teaserUrl?.trim() ?? '';
    if (teaserUrl.isNotEmpty) return teaserUrl;

    return content.trailerUrl?.trim() ?? '';
  }

  Widget _buildReleaseDateHighlight(
    BuildContext context,
    Content content, {
    bool centered = false,
  }) {
    final theme = Theme.of(context);
    final releaseDateText = content.releaseDate?.toString().trim();
    final displayText = (releaseDateText != null && releaseDateText.isNotEmpty)
        ? 'Release On: $releaseDateText'
        : 'Release On: Coming Soon';

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.65),
        ),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: theme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );

    if (!centered) {
      return child;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [child],
    );
  }

  Widget _ageRating(String? ageRating) {
    return ageRating != null && ageRating.isNotEmpty
        ? Tooltip(
            preferBelow: false,
            showDuration: const Duration(seconds: 2),
            waitDuration: const Duration(seconds: 1),
            message: ageRating == 'U'
                ? 'Universal Age'
                : ageRating == 'U/A'
                    ? 'Parental Guidance'
                    : 'Adults Only',
            child: Image.asset(
              height: 40,
              width: 60,
              ageRating == 'U'
                  ? ImageConstant.ageUniversal
                  : ageRating == 'U/A'
                      ? ImageConstant.ageParentalGuidance
                      : ImageConstant.ageAdultsOnly,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.grey),
            ),
          )
        : Container(color: Colors.black);
  }

  Widget _buildGifting(BuildContext context, Content movie,
      {bool iconOnly = false}) {
    final theme = Theme.of(context);
    final TextEditingController countController = TextEditingController();

    return Center(
      child: ActionButtonWidget(
        label: 'Gift Movie',
        icon: LucideIcons.gift,
        iconOnly: iconOnly,
        onTap: () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return Dialog(
                backgroundColor: theme.cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: ResponsiveWidget.isMobile(context)
                        ? double.infinity
                        : 400,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 1,
                          left: 1,
                          right: 1,
                          bottom: 1,
                          child: Icon(
                            LucideIcons.gift,
                            size: 200,
                            color: theme.canvasColor.withOpacity(0.1),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Icon(LucideIcons.gift,
                                    color: theme.primaryColor, size: 28),
                                const SizedBox(width: 10),
                                Text(
                                  "Gift This Movie",
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Description
                            Text(
                              "Enter how many people you’d like to gift this movie to.",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.canvasColor,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Input field
                            CustomTextField(
                              backgroundColor: theme.scaffoldBackgroundColor,
                              isDigits: true,
                              controller: countController,
                              hintText: "Number of recipients",
                              textInputType: TextInputType.number,
                            ),
                            const SizedBox(height: 24),

                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    "Cancel",
                                    style: TextStyle(color: theme.canvasColor),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                  onPressed: () {
                                    final count =
                                        int.tryParse(countController.text);
                                    if (count == null || count <= 0) {
                                      CustomToast.show(
                                          context, 'Please enter valid number',
                                          isSuccess: false);
                                      return;
                                    }

                                    Navigator.pop(context);
                                    _trailerController.pause?.call();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MovieBillingPage(
                                          movie: movie,
                                          giftCount: count,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Continue",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildButtons(BuildContext context, Content movie) {
    final lang = AppLocalizations.of(context)!;
    final contentType = (movie.type ?? '').toLowerCase();

    final canPlay = contentType.isNotEmpty;

    final canDownloadOffline = _canDownloadOffline(movie);
    final showIconOnlyButtons = canDownloadOffline;

    /// 👉 First Row Buttons
    final buttons = <Widget>[
      Expanded(
        child: movie.isRental == false
            ? ActionButtonWidget(
                label: '${lang.rent} ₹${movie.price}',
                icon: Icons.movie,
                iconOnly: showIconOnlyButtons,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => _buildConfirmationBox(context, movie),
                  );
                },
              )
            : ActionButtonWidget(
                label: contentType == "movie"
                    ? lang.watchMovie
                    : contentType == "series"
                        ? lang.watchSeries
                        : "Watch Now",
                icon: Icons.play_circle_fill,
                iconOnly: showIconOnlyButtons,
                onTap: () {
                  if (!canPlay) {
                    CustomToast.show(
                      context,
                      "Video is not available",
                      isSuccess: false,
                    );
                    return;
                  }

                  _playMovie(movie);
                },
              ),
      ),
      if (canDownloadOffline) ...[
        const SizedBox(width: 12),
        Expanded(
          child: _buildDownloadActionButton(
            context,
            movie,
            iconOnly: showIconOnlyButtons,
          ),
        ),
      ],
    ];

    /// 👉 Second Row Buttons
    buttons.addAll([
      const SizedBox(width: 12),
      Expanded(
        child: _buildGifting(
          context,
          movie,
          iconOnly: showIconOnlyButtons,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _buildShareActionButton(
          context,
          movie,
          iconOnly: showIconOnlyButtons,
        ),
      ),
    ]);

    return Row(children: buttons);
  }

  bool _canDownloadOffline(Content movie) {
    final contentType = ContentType.normalize(movie.type ?? widget.contentType);
    return movie.isRental == true &&
        movie.isDownloadable == true &&
        (ContentType.isMovieLike(contentType) ||
            ContentType.isSeries(contentType)) &&
        (movie.contentUrl?.trim().isNotEmpty ?? false);
  }

  Widget _buildDownloadActionButton(BuildContext context, Content movie,
      {bool iconOnly = false}) {
    final contentId = movie.id;
    if (contentId == null) {
      return const SizedBox.shrink();
    }

    return Consumer<OfflineDownloadProvider>(
      builder: (context, offlineProvider, _) {
        final isDownloading = offlineProvider.isDownloading(contentId);
        final isDownloaded = offlineProvider.isDownloaded(contentId);
        final progress = offlineProvider.progressFor(contentId);

        return ActionButtonWidget(
          label: isDownloading
              ? 'Downloading ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%'
              : isDownloaded
                  ? 'Remove Offline'
                  : 'Download',
          icon: isDownloaded ? Icons.delete_outline : Icons.download_rounded,
          iconOnly: iconOnly,
          onTap: () async {
            if (isDownloading) return;

            final result = isDownloaded
                ? await offlineProvider.deleteContent(movie)
                : await offlineProvider.downloadContent(movie);

            if (!mounted) return;
            CustomToast.show(
              context,
              result['message']?.toString() ?? 'Action completed.',
              isSuccess: result['success'] == true,
            );
          },
        );
      },
    );
  }

  Widget _buildCastSection(BuildContext context, Content content) {
    final theme = Theme.of(context);
    final provider = Provider.of<DashboardProvider>(context);
    final apiCastList = provider.castList;
    final fallbackCastList = (content.castList ?? const [])
        .where((name) => name.trim().isNotEmpty)
        .map((name) => CastMember(name: name.trim()))
        .toList();
    final castList = apiCastList.isNotEmpty ? apiCastList : fallbackCastList;

    if (provider.isLoadingCast) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.primaryColor,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Cast and Crew",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        castList.isEmpty
            ? SizedBox.shrink()
            : SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: castList.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    if (castList.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final cast = castList[index];
                    return _buildCastCard(context, cast);
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildCastCard(BuildContext context, CastMember cast) {
    final theme = Theme.of(context);
    final imageUrl = cast.image?.trim() ?? '';
    final displayName =
        (cast.name?.trim().isNotEmpty ?? false) ? cast.name!.trim() : 'N/A';
    final role =
        (cast.role?.trim().isNotEmpty ?? false) ? cast.role!.trim() : '';

    return SizedBox(
      width: 84,
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.cardColor,
            ),
            child: ClipOval(
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildCastInitial(theme, displayName),
                    )
                  : _buildCastInitial(theme, displayName),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 11, color: Colors.white),
          ),
          if (role.isNotEmpty)
            Text(
              "($role)",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildCastInitial(ThemeData theme, String displayName) {
    return Center(
      child: Text(
        displayName[0].toUpperCase(),
        style: TextStyle(
          color: theme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
    );
  }

  // Widget _buildShareButton(BuildContext context, Content movie) {
  //   return ActionButtonWidget(
  //     label: "Share",
  //     icon: Icons.share,
  //     onTap: () => _shareMovie(context, movie),
  //   );
  // }

  Widget _buildShareActionButton(BuildContext context, Content movie,
      {bool iconOnly = false}) {
    return ActionButtonWidget(
      label: 'Share',
      icon: Icons.qr_code_2_rounded,
      iconOnly: iconOnly,
      onTap: () => showContentShareSheet(
        context,
        movie,
        contentType: _contentType == ContentType.shortFilm
            ? DeepLinkContentType.shortFilm
            : DeepLinkContentType.movie,
        unavailableMessage: "Movie details are not available yet",
      ),
    );
  }

  Widget _buildExpandableDescription(
    String text,
    ThemeData theme, {
    int maxCollapsedLines = 3,
  }) {
    final cleanText = text.trim();
    if (cleanText.isEmpty || cleanText == 'N/A') {
      return Text(
        'N/A',
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontWeight: FontWeight.normal,
        ),
      );
    }

    final isLongText = cleanText.length > 130;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cleanText,
          textAlign: TextAlign.left,
          maxLines: _isDescriptionExpanded ? null : maxCollapsedLines,
          overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontWeight: FontWeight.normal,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        if (isLongText)
          InkWell(
            onTap: () {
              setState(() {
                _isDescriptionExpanded = !_isDescriptionExpanded;
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isDescriptionExpanded ? "Read Less" : "Read More",
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isDescriptionExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: theme.primaryColor,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConfirmationBox(BuildContext context, Content movie) {
    var selectedThemeData =
        Provider.of<ThemeProvider>(context, listen: true).getTheme;
    final lang = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: selectedThemeData.cardColor,
      title: Center(
        child: Text(
          movie.title ?? "",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color:
                selectedThemeData.primaryColor, // Apply text color from theme
          ),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${lang.price}: ${movie.price ?? 0.0}',
            style: TextStyle(
              fontSize: 14,
              color: selectedThemeData.secondaryHeaderColor, // Theme text color
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${lang.rentDuration}: ${movie.rentlDuration ?? ''}',
            style: TextStyle(
              fontSize: 14,
              color: selectedThemeData.secondaryHeaderColor, // Theme text color
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Do you want to rent this ${movie.type}?',
            style: TextStyle(
              fontSize: 14,
              color: selectedThemeData.primaryColor, // Theme text color
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: selectedThemeData.cardColor,
            foregroundColor: selectedThemeData.canvasColor,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            //_trailerController.pause?.call();
            Navigator.of(context).pop(); // Close the dialog
          },
          child: Text(lang.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: selectedThemeData.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            _trailerController.pause?.call();
            Navigator.of(context).pop(); // Close the dialog
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => MovieBillingPage(
                  movie: movie,
                ),
              ),
            );

            if (result == true && mounted) {
              await _fetchData();
            }
          },
          child: Text("Continue"),
        ),
      ],
    );
  }

  Widget _buildDetailsSection(BuildContext context, Content movie) {
    final lang = AppLocalizations.of(context)!;
    final languages = (movie.languageList ?? const [])
        .map((e) => e.language?.trim())
        .where((language) => language != null && language.isNotEmpty)
        .cast<String>()
        .join(', ');
    TextStyle titleStyle = const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    );
    TextStyle contentStyle = const TextStyle(
      color: Colors.white70,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
          //  border: Border.all(color: Colors.white24),
          // borderRadius: BorderRadius.circular(8),
          ),
      child: Table(
        columnWidths: const {
          0: IntrinsicColumnWidth(),
          1: FlexColumnWidth(),
        },
        /*   border: TableBorder.symmetric(
          inside: BorderSide(color: Colors.white12, width: 0.5),
        ), */
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          /*    _buildTableRow(
              lang.cast,
              (movie.castList != null && movie.castList!.isNotEmpty)
                  ? movie.castList!.join(', ')
                  : 'N/A',
              titleStyle,
              contentStyle), */
          _buildTableRow(
              lang.genres,
              (movie.genreList != null && movie.genreList!.isNotEmpty)
                  ? movie.genreList!.join(', ')
                  : 'N/A',
              titleStyle,
              contentStyle),
          _buildTableRow(lang.runtime, movie.runtime?.toString() ?? 'N/A',
              titleStyle, contentStyle),
          _buildTableRow(lang.price, movie.price?.toString() ?? 'N/A',
              titleStyle, contentStyle),
          _buildTableRow(
              lang.rentDuration,
              movie.rentlDuration?.toString() ?? 'N/A',
              titleStyle,
              contentStyle),
          _buildTableRow(
              lang.mediaHouse,
              movie.mediaHouseName?.toString() ?? 'N/A',
              titleStyle,
              contentStyle),
          _buildTableRow(lang.releaseDate, movie.releaseDate ?? 'N/A',
              titleStyle, contentStyle),
          _buildTableRow(
              lang.languages,
              languages.isNotEmpty ? languages : 'N/A',
              titleStyle,
              contentStyle),
          _buildTableRow(
              lang.rating,
              '${double.parse(
                (movie.ratings ?? 0.0).toStringAsFixed(1),
              )} ⭐',
              titleStyle,
              contentStyle),
          /*    _buildTableRow(
              lang.audioFormat,
              (movie.audioFormatList ?? []).join(', '),
              titleStyle,
              contentStyle),
          _buildTableRow(
              lang.subtitle,
              (movie.subtitleLanguageList ?? []).join(', '),
              titleStyle,
              contentStyle), */
          _buildTableRow(lang.ageRating, movie.ageRating ?? 'N/A', titleStyle,
              contentStyle),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String title, String content, TextStyle titleStyle,
      TextStyle contentStyle) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Text('$title:', style: titleStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(content, style: contentStyle),
        ),
      ],
    );
  }

  Widget _buildRatingAndReviewsSection(BuildContext context, Content content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (content.isRental == true) ...[
          _buildRatingReviewSection(context, content),
          const SizedBox(height: 16),
        ],
        getChatList(),
      ],
    );
  }

  Widget _buildRatingReviewSection(BuildContext context, Content content) {
    var selectedThemeData =
        Provider.of<ThemeProvider>(context, listen: true).getTheme;
    return Consumer<VideoProvider>(
      builder: (context, provider, child) => Column(
        children: [
          Text(
            "Rate your experience",
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
          ),
          StarRating(
            rating: provider.rating,
            onRatingChanged: (rating) =>
                setState(() => provider.rating = rating),
          ),
          SizedBox(
            height: 7,
          ),
          Container(
            height: 90,
            margin: EdgeInsets.all(10.0),
            padding: EdgeInsets.only(bottom: 16.0),
            child: TextField(
              maxLines: 9,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [CapitalizeSentencesTextInputFormatter()],
              style: TextStyle(
                // Input text color
                color: Colors.white,
              ),
              controller: provider.reviewController,
              decoration: InputDecoration(
                hintText: "Your Feedback!",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            height: 7,
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: selectedThemeData.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () async {
              if (content.id == null) {
                CustomToast.show(context, "Movie details are not available yet",
                    isSuccess: false);
                return;
              }

              // if (provider.reviewController.text.isNotEmpty) {
              if (provider.rating == 0) {
                CustomToast.show(context, "Please select rating..",
                    isSuccess: false);
              } else {
                var result = await provider.saveRatingReview(content.id!);
                if (result['success'] != true) {
                  final message = result['message']?.toString().trim();
                  CustomToast.show(
                      context,
                      message != null && message.isNotEmpty
                          ? message
                          : "something went wrong to submit review",
                      isSuccess: false);
                } else {
                  final message = result['message']?.toString().trim();
                  CustomToast.show(
                      context,
                      message != null && message.isNotEmpty
                          ? message
                          : 'review submitted successfully',
                      isSuccess: true);
                  await _fetchData();
                }
              }
              /* } else {
                CustomToast.show(context, "Please give some comments",
                    isSuccess: false);
              } */
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child:
                  Text("Submit Review", style: TextStyle(color: Colors.white)),
            ),
          ),
          /*  Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              getChatList(),
            ],
          ), */
        ],
      ),
    );
  }

  Widget getChatList() {
    return Consumer<VideoProvider>(
      builder: (context, provider, child) {
        if (provider.reviewList.isEmpty) {
          return const SizedBox.shrink();
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.reviewList.length,
          itemBuilder: (BuildContext context, int index) {
            DateTime date = DateTime.now();
            if (provider.reviewList[index].createdAt != null) {
              date = DateTime.fromMillisecondsSinceEpoch(
                  provider.reviewList[index].createdAt!);
            }
            String formattedDate =
                DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
            final username = provider.reviewList[index].username;
            final displayName = username == null || username == "null null"
                ? "Anonymous User"
                : username;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        height: 40,
                        width: 40,
                        child: CircleAvatar(
                          backgroundImage:
                              provider.reviewList[index].userProfile != null
                                  ? NetworkImage(
                                      provider.reviewList[index].userProfile!)
                                  : null,
                          radius: 50,
                          child: provider.reviewList[index].userProfile == null
                              ? const Icon(Icons.person, size: 25)
                              : null,
                        ),
                      ),
                      const SizedBox(
                        width: 15,
                      ),
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white),
                        ),
                      )
                    ],
                  ),
                  Row(
                    children: [
                      StarDisplay(
                          value: provider.reviewList[index].rating ?? 5),
                      const SizedBox(
                        width: 10,
                      ),
                      Flexible(
                        child: Text(formattedDate,
                            style: const TextStyle(
                                fontWeight: FontWeight.normal,
                                fontSize: 12,
                                color: Colors.white)),
                      )
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Text(provider.reviewList[index].title.toString(),
                      style: const TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 12,
                          color: Colors.white)),
                  const SizedBox(
                    height: 10,
                  ),
                  const Divider(
                    thickness: 2,
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MovieTvFocusableScale extends StatefulWidget {
  const _MovieTvFocusableScale({
    required this.child,
    required this.onPressed,
    this.width,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double? width;

  @override
  State<_MovieTvFocusableScale> createState() => _MovieTvFocusableScaleState();
}

class _MovieTvFocusableScaleState extends State<_MovieTvFocusableScale> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _focused || _hovered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FocusableActionDetector(
      enabled: widget.onPressed != null,
      mouseCursor: widget.onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onShowFocusHighlight: (value) {
        if (value) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
        }
        if (mounted) setState(() => _focused = value);
      },
      onShowHoverHighlight: (value) {
        if (mounted) setState(() => _hovered = value);
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: AnimatedScale(
        scale: _active ? 1.055 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: widget.width,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: widget.child,
        ),
      ),
    );
  }
}
