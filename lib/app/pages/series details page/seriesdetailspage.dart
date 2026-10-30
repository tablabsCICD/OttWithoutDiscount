import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ott/app/core/constant/api_constant.dart';
import 'package:ott/app/core/network/api_helper.dart';
import 'package:ott/app/core/services/DeepLinkService.dart';
import 'package:ott/app/core/utils/release_date_formatter.dart';
import 'package:ott/app/widgets/content_share_sheet.dart';
import 'package:ott/app/pages/watchlist%20page/component/DisplayTrailer.dart';
import 'package:ott/app/pages/wallet%20page/MovieBillingPage.dart';
import 'package:ott/app/pages/wallet%20page/SeriesBillingPage.dart';
import 'package:ott/app/pages/watchlist%20page/component/playMoviePage.dart';
import 'package:ott/app/pages/movie%20details%20page/component/actionButtonWidget.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/provider/offline_download_provider.dart';
import 'package:ott/app/provider/series_provider.dart';
import 'package:ott/app/provider/videoProvider.dart';
import 'package:ott/app/widgets/StarRatingWidget.dart';
import 'package:ott/app/widgets/customtextfield.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:ott/data/models/cast_member.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/models/seriesModel.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../provider/playMediaProvider.dart';
import '../movie details page/component/displayStar.dart';
import '../movie details page/component/starRating.dart';

class SeriesDetailsPage extends StatefulWidget {
  final int seriesId;
  final Content content;

  const SeriesDetailsPage({
    super.key,
    required this.seriesId,
    required this.content,
  });

  @override
  State<SeriesDetailsPage> createState() => _SeriesDetailsPageState();
}

class _SeriesDetailsPageState extends State<SeriesDetailsPage> {
  int _selectedSeasonIndex = 0;
  final TrailerPreviewController _trailerController =
      TrailerPreviewController();
  final TrailerPreviewController _teaserController = TrailerPreviewController();
  final ScrollController _tvScrollController = ScrollController();
  final FocusNode _heroFocusNode = FocusNode(debugLabel: 'seriesHero');
  Timer? _heroTrailerTimer;
  bool _isHeroTrailerPlaying = false;
  final ApiHelper _apiHelper = ApiHelper();
  List<CastMember> _seasonCastList = [];
  bool _isLoadingSeasonCast = false;
  int? _loadedSeasonId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadInitialData();
      context.read<PlayMediaProvider>().loadLocalResumes();
    });
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

  Future<void> _loadInitialData() async {
    final provider = context.read<SeriesProvider>();
    await provider.fetchSeriesDetails(widget.seriesId);
    await context
        .read<VideoProvider>()
        .getRatingReview(widget.content.id ?? widget.seriesId);

    if (!mounted) return;

    final seasons = provider.series?.seasons ?? [];
    if (seasons.isNotEmpty) {
      await _loadSeasonCast(seasons[_selectedSeasonIndex].seasonId);
    }
  }

  Future<void> _loadSeasonCast(int seasonId) async {
    if (_isLoadingSeasonCast && _loadedSeasonId == seasonId) {
      return;
    }

    setState(() {
      _isLoadingSeasonCast = true;
      _loadedSeasonId = seasonId;
    });

    try {
      final response = await _apiHelper.getApi(
        ApiConstant.getCastByContentIdAndSeasonId(widget.seriesId, seasonId),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
        final castData = responseBody['data']?['cast'] as List?;

        final castList = castData == null
            ? <CastMember>[]
            : castData
                .map(
                    (item) => CastMember.fromJson(item as Map<String, dynamic>))
                .where((cast) =>
                    cast.seasonId == null || cast.seasonId == seasonId)
                .toList();

        if (!mounted) return;
        setState(() {
          _seasonCastList = castList;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _seasonCastList = [];
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _seasonCastList = [];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingSeasonCast = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().getTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Consumer<SeriesProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return Center(
              child: CircularProgressIndicator(color: theme.primaryColor),
            );
          }

          if (provider.error != null) {
            return Center(child: Text(provider.error!));
          }

          SeriesEntity? series = provider.series;
          if (series == null) return const SizedBox();

          List<SeasonEntity> seasons = series.seasons;
          if (!ResponsiveWidget.isMobile(context)) {
            return _buildCinematicTvDetails(context, series, seasons, theme);
          }

          if (seasons.isEmpty) {
            return CustomScrollView(
              slivers: [
                _buildHero(series, theme),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveWidget.isDesktop(context) ? 64 : 16,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleBlock(series, theme),
                        const SizedBox(height: 24),
                        Text(
                          'No seasons available yet',
                          style: TextStyle(
                            color: theme.canvasColor.withOpacity(0.7),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 26),
                        _buildDetailsSection(context, widget.content, theme),
                        const SizedBox(height: 32),
                        _buildGallery(widget.content),
                        const SizedBox(height: 32),
                        _buildRatingAndReviewsSection(context, widget.content),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          if (_selectedSeasonIndex >= seasons.length) {
            _selectedSeasonIndex = 0;
          }

          SeasonEntity season = seasons[_selectedSeasonIndex];

          if (_loadedSeasonId != season.seasonId && !_isLoadingSeasonCast) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _loadSeasonCast(season.seasonId);
              }
            });
          }

          return CustomScrollView(
            slivers: [
              _buildHero(series, theme),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveWidget.isDesktop(context) ? 64 : 16,
                    vertical: 1,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleBlock(series, theme),
                      const SizedBox(height: 20),
                      _buildSeasonSelector(seasons, theme),
                      const SizedBox(height: 20),
                      _buildSeasonInfo(context, season, theme),
                      const SizedBox(height: 16),
                      _buildCastSection(context, season, theme),
                      const SizedBox(height: 16),
                      if (season.episodes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Text(
                              'No episodes available yet',
                              style: TextStyle(
                                color: theme.canvasColor.withOpacity(0.68),
                                fontSize: 15,
                              ),
                            ),
                          ),
                        )
                      else
                        ...season.episodes
                            .map((e) => _episodeTile(context, season, e, theme)),
                      Divider(),
                      const SizedBox(height: 26),
                      _buildDetailsSection(context, widget.content, theme),
                      const SizedBox(height: 32),
                      _buildGallery(widget.content),
                      const SizedBox(height: 32),
                      _buildRatingAndReviewsSection(context, widget.content),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCinematicTvDetails(
    BuildContext context,
    SeriesEntity series,
    List<SeasonEntity> seasons,
    ThemeData theme,
  ) {
    if (seasons.isNotEmpty && _selectedSeasonIndex >= seasons.length) {
      _selectedSeasonIndex = 0;
    }

    final season = seasons.isEmpty ? null : seasons[_selectedSeasonIndex];
    if (season != null &&
        _loadedSeasonId != season.seasonId &&
        !_isLoadingSeasonCast) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSeasonCast(season.seasonId);
      });
    }

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
            color: theme.scaffoldBackgroundColor,
            child: CustomScrollView(
              controller: _tvScrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: _buildCinematicHero(context, series, seasons, theme),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      ResponsiveWidget.isDesktop(context) ? 64 : 32,
                      8,
                      ResponsiveWidget.isDesktop(context) ? 64 : 32,
                      56,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (seasons.isEmpty)
                          _buildTvSectionTitle(theme, 'Episodes coming soon')
                        else ...[
                          _buildTvSectionTitle(theme, 'Seasons & Episodes'),
                          const SizedBox(height: 14),
                          _buildTvSeasonSelector(seasons, theme),
                          const SizedBox(height: 22),
                          _buildTvSeasonHeader(context, season!, theme),
                          const SizedBox(height: 18),
                          _buildTvEpisodeRail(context, season, theme),
                        ],
                        const SizedBox(height: 34),
                        _buildTvCastSection(context, season, theme),
                        const SizedBox(height: 34),
                        _buildTvRecommendationRails(context, theme),
                        const SizedBox(height: 34),
                        _buildDetailsSection(context, widget.content, theme),
                        const SizedBox(height: 28),
                        _buildGallery(widget.content),
                        const SizedBox(height: 28),
                        _buildRatingAndReviewsSection(context, widget.content),
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

  Widget _buildCinematicHero(
    BuildContext context,
    SeriesEntity series,
    List<SeasonEntity> seasons,
    ThemeData theme,
  ) {
    final size = MediaQuery.of(context).size;
    final heroHeight = (size.height * 0.78).clamp(560.0, 760.0);
    final resume = _findResumeEpisode(context, seasons);
    final trailerUrl = widget.content.teaserOrTrailerUrl;

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
            Image.network(
              series.posterUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
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
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
            Positioned(
              left: ResponsiveWidget.isDesktop(context) ? 64 : 32,
              top: MediaQuery.of(context).padding.top + 24,
              child: _buildTvBackButton(theme),
            ),
            Positioned(
              left: ResponsiveWidget.isDesktop(context) ? 64 : 32,
              right: size.width * 0.42,
              bottom: 54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    series.title,
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
                  _buildTvMetaRow(series, seasons, theme),
                  const SizedBox(height: 16),
                  Text(
                    series.description.isNotEmpty
                        ? series.description
                        : (widget.content.description ?? ''),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      fontSize: 17,
                      height: 1.42,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTvActionButtons(context, seasons, resume, theme),
                ],
              ),
            ),
            Positioned(
              right: ResponsiveWidget.isDesktop(context) ? 64 : 32,
              bottom: 70,
              width: ResponsiveWidget.isDesktop(context) ? 470 : 380,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _isHeroTrailerPlaying ? 1 : 0.74,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TrailerPreview(
                      trailerUrl: trailerUrl,
                      content: widget.content,
                      controller: _trailerController,
                      autoPlay: false,
                      muted: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTvMetaRow(
    SeriesEntity series,
    List<SeasonEntity> seasons,
    ThemeData theme,
  ) {
    final totalEpisodes =
        seasons.fold<int>(0, (sum, season) => sum + season.episodes.length);
    final releaseYear = _releaseYearText(widget.content.releaseDate);
    final genres = (widget.content.genreList ?? const <String>[])
        .where((item) => item.trim().isNotEmpty)
        .take(2)
        .join(' / ');
    final languages = (widget.content.languageList ?? const <LanguageList>[])
        .map((item) => item.language)
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .take(2)
        .join(' / ');

    final items = <String>[
      '${(widget.content.ratings ?? 0).toStringAsFixed(1)} rating',
      if (releaseYear.isNotEmpty) releaseYear,
      if (genres.isNotEmpty) genres,
      if (languages.isNotEmpty) languages,
      if ((widget.content.ageRating ?? '').trim().isNotEmpty)
        widget.content.ageRating!.trim(),
      '${seasons.length} ${seasons.length == 1 ? 'season' : 'seasons'}',
      '$totalEpisodes ${totalEpisodes == 1 ? 'episode' : 'episodes'}',
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) => _buildTvMetaPill(item, theme)).toList(),
    );
  }

  Widget _buildTvMetaPill(String text, ThemeData theme) {
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
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTvBackButton(ThemeData theme) {
    return _TvFocusableScale(
      onPressed: () {
        if (Navigator.canPop(context)) Navigator.pop(context);
      },
      child: IconButton(
        onPressed: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
        style: IconButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          fixedSize: const Size(52, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: const Icon(Icons.arrow_back_rounded, size: 28),
      ),
    );
  }

  Widget _buildTvActionButtons(
    BuildContext context,
    List<SeasonEntity> seasons,
    _ResumeEpisode? resume,
    ThemeData theme,
  ) {
    final firstPlayable = _firstPlayableEpisode(seasons);
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _tvActionButton(
          theme: theme,
          label: resume == null ? 'Watch Now' : 'Resume Watching',
          icon: resume == null ? Icons.play_arrow_rounded : Icons.restart_alt,
          emphasized: true,
          onPressed: () {
            final target = resume ?? firstPlayable;
            if (target != null) {
              _playEpisode(context, target.season, target.episode);
            } else if (seasons.isNotEmpty && seasons.first.episodes.isNotEmpty) {
              _purchaseEpisode(
                  context, seasons.first, seasons.first.episodes.first);
            }
          },
        ),
        _tvActionButton(
          theme: theme,
          label: 'Watch Trailer',
          icon: Icons.movie_creation_outlined,
          onPressed: _openTrailer,
        ),
        _buildDownloadButton(context, theme),
        _tvActionButton(
          theme: theme,
          label: 'Share',
          icon: Icons.ios_share_rounded,
          onPressed: () => showContentShareSheet(
            context,
            widget.content,
            contentType: DeepLinkContentType.series,
            unavailableMessage: "Series details are not available yet",
          ),
        ),
        _tvActionButton(
          theme: theme,
          label: 'Gift',
          icon: LucideIcons.gift,
          onPressed: () => _showGiftDialog(context, widget.content),
        ),
      ],
    );
  }

  Widget _buildDownloadButton(BuildContext context, ThemeData theme) {
    final contentId = widget.content.id;
    final canDownload = contentId != null &&
        widget.content.isDownloadable == true &&
        (widget.content.contentUrl?.trim().isNotEmpty ?? false);
    if (!canDownload) {
      return _tvActionButton(
        theme: theme,
        label: 'Download',
        icon: Icons.download_rounded,
        onPressed: () => CustomToast.show(
          context,
          'Download is not available for this series.',
          isSuccess: false,
        ),
      );
    }

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
                      ? await offlineProvider.deleteContent(widget.content)
                      : await offlineProvider.downloadContent(widget.content);
                  if (!context.mounted) return;
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
    return _TvFocusableScale(
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

  Widget _buildTvSeasonSelector(List<SeasonEntity> seasons, ThemeData theme) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: seasons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final selected = index == _selectedSeasonIndex;
          return _TvFocusableScale(
            onPressed: () {
              setState(() => _selectedSeasonIndex = index);
              _loadSeasonCast(seasons[index].seasonId);
            },
            child: ChoiceChip(
              selected: selected,
              label: Text('Season ${seasons[index].seasonNumber}'),
              selectedColor: theme.primaryColor,
              backgroundColor: Colors.red.withOpacity(0.1),
              labelStyle: TextStyle(
                color: selected
                    ? Colors.white
                    : theme.canvasColor.withOpacity(0.82),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              side: BorderSide(color: theme.canvasColor.withOpacity(0.14)),
              onSelected: (_) {
                setState(() => _selectedSeasonIndex = index);
                _loadSeasonCast(seasons[index].seasonId);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTvSeasonHeader(
    BuildContext context,
    SeasonEntity season,
    ThemeData theme,
  ) {
    final isSeasonPurchased =
        (widget.content.isRental == true) || season.isSeasonPurchased;
    final effectiveSeasonPrice = season.price > 0
        ? season.price.toDouble()
        : (widget.content.price != null ? widget.content.price!.toDouble() : 0.0);
    final canPurchaseSeason = !isSeasonPurchased && effectiveSeasonPrice > 0;
    final priceLabel =
        effectiveSeasonPrice.truncateToDouble() == effectiveSeasonPrice
            ? effectiveSeasonPrice.toInt().toString()
            : effectiveSeasonPrice.toStringAsFixed(2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Season ${season.seasonNumber}: ${season.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.canvasColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                season.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.canvasColor.withOpacity(0.68),
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (widget.content.isFeatured == true)
          _buildReleaseDateHighlight(context, season)
        else if (canPurchaseSeason)
          _tvActionButton(
            theme: theme,
            label: 'Rent Season ₹$priceLabel',
            icon: Icons.lock_open_rounded,
            emphasized: true,
            onPressed: () => _purchaseSeason(context, season),
          ),
      ],
    );
  }

  Widget _buildTvEpisodeRail(
    BuildContext context,
    SeasonEntity season,
    ThemeData theme,
  ) {
    if (season.episodes.isEmpty) {
      return Text(
        'No episodes available yet',
        style: TextStyle(color: theme.canvasColor.withOpacity(0.7), fontSize: 16),
      );
    }

    return SizedBox(
      height: 300,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: season.episodes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          return _buildTvEpisodeCard(
            context,
            season,
            season.episodes[index],
            theme,
          );
        },
      ),
    );
  }

  Widget _buildTvEpisodeCard(
    BuildContext context,
    SeasonEntity season,
    EpisodeEntity episode,
    ThemeData theme,
  ) {
    final isSeasonPurchased =
        (widget.content.isRental == true) || season.isSeasonPurchased;
    final canPlay =
        isSeasonPurchased || episode.isPurchased || episode.isFree;
    final progress = _episodeProgress(context, season, episode);
    final hasProgress = progress > 0.02;

    return _TvFocusableScale(
      width: 360,
      onPressed: () {
        if (canPlay) {
          _playEpisode(context, season, episode);
        } else {
          _purchaseEpisode(context, season, episode);
        }
      },
      child: Container(
        width: 360,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.canvasColor.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              child: Stack(
                children: [
                  Container(
                    height: 190,
                    width: 360,
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: Image.network(
                      episode.posterUrl,
                      height: 190,
                      width: 360,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => Container(
                        height: 190,
                        width: 360,
                        color: Colors.grey.shade900,
                        child: const Icon(Icons.broken_image,
                            color: Colors.white54, size: 34),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.68),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    heightFactor: 3.1,
                    child: Icon(
                      canPlay ? Icons.play_circle_fill : Icons.lock_rounded,
                      color: Colors.white,
                      size: 54,
                    ),
                  ),
                  if (hasProgress)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: Colors.white24,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(theme.primaryColor),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          episode.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.canvasColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${episode.runtime} min',
                        style: TextStyle(
                          color: theme.canvasColor.withOpacity(0.65),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasProgress
                        ? 'Continue watching - ${(progress * 100).round()}%'
                        : 'Episode ${episode.episodeNumber}',
                    style: TextStyle(
                      color: hasProgress
                          ? theme.primaryColor
                          : theme.canvasColor.withOpacity(0.62),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    episode.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.canvasColor.withOpacity(0.64),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTvCastSection(
    BuildContext context,
    SeasonEntity? season,
    ThemeData theme,
  ) {
    if (season == null) return const SizedBox.shrink();
    return _buildCastSection(context, season, theme);
  }

  Widget _buildTvRecommendationRails(BuildContext context, ThemeData theme) {
    final rows = context.watch<DashboardProvider>().dashboardData;
    final rails = rows
        .where((row) => (row.movies ?? const <Content>[]).isNotEmpty)
        .take(4)
        .toList();
    if (rails.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rails) ...[
          _buildTvSectionTitle(theme, _railTitle(row.category)),
          const SizedBox(height: 14),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: (row.movies ?? const <Content>[])
                  .where((item) => item.id != widget.content.id)
                  .length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final items = (row.movies ?? const <Content>[])
                    .where((item) => item.id != widget.content.id)
                    .toList();
                return _buildTvRecommendationCard(context, items[index], theme);
              },
            ),
          ),
          const SizedBox(height: 28),
        ],
      ],
    );
  }

  Widget _buildTvRecommendationCard(
    BuildContext context,
    Content content,
    ThemeData theme,
  ) {
    final image = (content.posterUrlList ?? const <String>[]).isNotEmpty
        ? content.posterUrlList!.first
        : '';
    return _TvFocusableScale(
      width: 300,
      onPressed: () {
        if ((content.type ?? '').toLowerCase() == 'series' &&
            content.id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SeriesDetailsPage(
                seriesId: content.id!,
                content: content,
              ),
            ),
          );
        }
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
              style: TextStyle(
                color: theme.canvasColor,
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
              style: TextStyle(color: theme.canvasColor.withOpacity(0.58)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTvSectionTitle(ThemeData theme, String title) {
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
    if (raw.toLowerCase().contains('latest')) return 'Recommended Series';
    if (raw.toLowerCase().contains('upcoming')) return 'Related Content';
    return raw;
  }

  void _queueHeroTrailerAutoplay() {
    _heroTrailerTimer?.cancel();
    _heroTrailerTimer = Timer(const Duration(seconds: 2), () {
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

  _ResumeEpisode? _firstPlayableEpisode(List<SeasonEntity> seasons) {
    final isSeriesPurchased = widget.content.isRental == true;
    for (final season in seasons) {
      final isSeasonPurchased = isSeriesPurchased || season.isSeasonPurchased;
      for (final episode in season.episodes) {
        if (isSeasonPurchased || episode.isPurchased || episode.isFree) {
          return _ResumeEpisode(season, episode);
        }
      }
    }
    return null;
  }

  _ResumeEpisode? _findResumeEpisode(
    BuildContext context,
    List<SeasonEntity> seasons,
  ) {
    _ResumeEpisode? best;
    int bestSeconds = 0;
    final provider = context.watch<PlayMediaProvider>();
    for (final season in seasons) {
      for (final episode in season.episodes) {
        final seconds = provider.getLocalResume(
          contentId: widget.content.id ?? widget.seriesId,
          seasonId: season.seasonId,
          episodeId: episode.episodeId,
        );
        if (seconds > bestSeconds) {
          bestSeconds = seconds;
          best = _ResumeEpisode(season, episode);
        }
      }
    }
    return bestSeconds > 5 ? best : null;
  }

  double _episodeProgress(
    BuildContext context,
    SeasonEntity season,
    EpisodeEntity episode,
  ) {
    final resumeSeconds = context.watch<PlayMediaProvider>().getLocalResume(
          contentId: widget.content.id ?? widget.seriesId,
          seasonId: season.seasonId,
          episodeId: episode.episodeId,
        );
    return episode.runtime > 0
        ? (resumeSeconds / (episode.runtime * 60)).clamp(0.0, 1.0)
        : 0.0;
  }

  Future<void> _playEpisode(
    BuildContext context,
    SeasonEntity season,
    EpisodeEntity episode,
  ) async {
    final videoUrl = episode.videoUrl?.trim();
    if (videoUrl == null || videoUrl.isEmpty) {
      CustomToast.show(
        context,
        "Episode video is not available at the moment.",
        isSuccess: false,
      );
      return;
    }
    _stopHeroTrailer();
    await _trailerController.disposePlayer?.call();
    await _teaserController.disposePlayer?.call();
    if (!context.mounted) return;
    final allSeasons =
        context.read<SeriesProvider>().series?.seasons ?? [season];
    final shouldRefresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PlayMediaPage(
          videoUrl: videoUrl,
          content: widget.content,
          seasonIndex: season.seasonId,
          episodeIndex: episode.episodeId,
          seasons: allSeasons,
        ),
      ),
    );

    if (shouldRefresh == true && context.mounted) {
      context.read<DashboardProvider>().getContinueWatchedMovieList("SERIES");
    }
  }

  Future<void> _purchaseEpisode(
    BuildContext context,
    SeasonEntity season,
    EpisodeEntity episode,
  ) async {
    _stopHeroTrailer();
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SeriesBillingPage(
          seriesId: widget.seriesId,
          episodeId: episode.episodeId,
          amount: episode.price.toDouble(),
          isSeason: false,
          seriesTitle: widget.content.title,
          itemTitle: episode.title,
          rentalDuration: widget.content.rentlDuration,
        ),
      ),
    );

    if (result == true && context.mounted) {
      CustomToast.show(context, "Episode unlocked! Enjoy watching 🎬",
          isSuccess: true);
      await context.read<SeriesProvider>().fetchSeriesDetails(widget.seriesId);
    }
  }

  Future<void> _purchaseSeason(
    BuildContext context,
    SeasonEntity season,
  ) async {
    _stopHeroTrailer();
    final effectivePrice = season.price > 0
        ? season.price.toDouble()
        : (widget.content.price != null
            ? widget.content.price!.toDouble()
            : 0.0);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SeriesBillingPage(
          seriesId: widget.seriesId,
          seasonId: season.seasonId,
          amount: effectivePrice,
          isSeason: true,
          seriesTitle: widget.content.title,
          itemTitle: season.title,
          rentalDuration: widget.content.rentlDuration,
        ),
      ),
    );

    if (result == true && context.mounted) {
      CustomToast.show(context, "Season unlocked! Enjoy watching 🎬",
          isSuccess: true);
      await context.read<SeriesProvider>().fetchSeriesDetails(widget.seriesId);
    }
  }

  Future<void> _openTrailer() async {
    _stopHeroTrailer();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrailerPage(
          trailerUrl: widget.content.teaserOrTrailerUrl,
          isTrailerUrl: true,
          content: widget.content,
        ),
      ),
    );
  }

  void _showGiftDialog(BuildContext context, Content seriesContent) {
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
                        "Gift This Series",
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Enter how many people you'd like to gift this series to.",
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
                                movie: seriesContent,
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

  String _releaseYearText(dynamic releaseDate) {
    if (releaseDate == null) return '';
    if (releaseDate is DateTime) return releaseDate.year.toString();
    final numeric = releaseDate is int
        ? releaseDate
        : int.tryParse(releaseDate.toString().trim());
    if (numeric != null && numeric > 1000000000) {
      final dt = numeric > 100000000000
          ? DateTime.fromMillisecondsSinceEpoch(numeric)
          : DateTime.fromMillisecondsSinceEpoch(numeric * 1000);
      return dt.year.toString();
    }
    final text = releaseDate.toString().trim();
    if (text.length >= 4) return text.substring(0, 4);
    return text;
  }

  // ---------------- HERO ----------------

  SliverAppBar _buildHero(series, ThemeData theme) {
    final bool isMobile = ResponsiveWidget.isMobile(context);
    final bool isTablet = ResponsiveWidget.isTablet(context);

    return SliverAppBar(
      automaticallyImplyLeading: !(kIsWeb || ResponsiveWidget.isTv(context)),
      pinned: true,
      expandedHeight: isMobile
          ? 250
          : isTablet
              ? 420
              : 560,
      forceMaterialTransparency: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      foregroundColor: theme.canvasColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            /// 🎬 Background Poster
            Image.network(
              series.posterUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
            ),

            /// 🌗 Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: theme.brightness == Brightness.dark
                      ? const [
                          Colors.black87,
                          Colors.black87,
                          Colors.black,
                        ]
                      : [
                          Colors.black54,
                          theme.scaffoldBackgroundColor.withOpacity(0.7),
                          theme.scaffoldBackgroundColor,
                        ],
                ),
              ),
            ),

            /// ▶ Trailer Preview (Responsive)
            if (isMobile)
              _buildMobileTrailer()
            else
              _buildDesktopTabletTrailer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTrailer() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: TrailerPreview(
              trailerUrl: widget.content.teaserOrTrailerUrl,
              content: widget.content,
              controller: _trailerController,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTabletTrailer() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Container(
        height: ResponsiveWidget.isTablet(context) ? 240 : 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.grey.withOpacity(0.4),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: TrailerPreview(
              trailerUrl: widget.content.teaserOrTrailerUrl,
              content: widget.content,
              controller: _trailerController,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- TITLE BLOCK ----------------

  Widget _buildTitleBlock(series, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          series.title,
          style: TextStyle(
            fontSize: ResponsiveWidget.isDesktop(context) ? 32 : 24,
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            StarRatingWidget(
              rating: double.parse(
                widget.content.ratings!.toStringAsFixed(2),
              ),
            ),
            Text(
              " (${widget.content.ratingCount ?? 0})",
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: theme.canvasColor.withOpacity(0.7), height: 1.4),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          series.description,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style:
              TextStyle(color: theme.canvasColor.withOpacity(0.7), height: 1.4),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ActionButtonWidget(
              label: 'Share',
              icon: Icons.qr_code_2_rounded,
              onTap: () => showContentShareSheet(
                context,
                widget.content,
                contentType: DeepLinkContentType.series,
                unavailableMessage: "Series details are not available yet",
              ),
            ),
            _buildGifting(context, widget.content),
          ],
        ),
      ],
    );
  }

  Widget _buildGifting(BuildContext context, Content seriesContent) {
    final theme = Theme.of(context);
    final TextEditingController countController = TextEditingController();

    return ActionButtonWidget(
      label: 'Gift Series',
      icon: LucideIcons.gift,
      onTap: () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return Dialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: ResponsiveWidget.isMobile(dialogContext)
                      ? double.infinity
                      : 400,
                  child: Stack(
                    children: [
                      Positioned.fill(
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
                          Row(
                            children: [
                              Icon(
                                LucideIcons.gift,
                                color: theme.primaryColor,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "Gift This Series",
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Enter how many people you'd like to gift this series to.",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.canvasColor,
                            ),
                          ),
                          const SizedBox(height: 4),
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
                                      dialogContext,
                                      'Please enter valid number',
                                      isSuccess: false,
                                    );
                                    return;
                                  }

                                  Navigator.pop(dialogContext);
                                  _trailerController.pause?.call();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MovieBillingPage(
                                        movie: seriesContent,
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
        ).whenComplete(countController.dispose);
      },
    );
  }

  // ---------------- SEASON SELECTOR ----------------

  Widget _buildSeasonSelector(List seasons, ThemeData theme) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: seasons.length,
        itemBuilder: (context, i) {
          final selected = i == _selectedSeasonIndex;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedSeasonIndex = i);
              _loadSeasonCast(seasons[i].seasonId);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? theme.primaryColor : theme.cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "Season ${seasons[i].seasonNumber}",
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : theme.canvasColor.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------- SEASON INFO ----------------

  Widget _buildSeasonInfo(
      BuildContext context, SeasonEntity season, ThemeData theme) {
    final isSeasonPurchased =
        (widget.content.isRental == true) || season.isSeasonPurchased;
    final effectiveSeasonPrice = season.price > 0
        ? season.price.toDouble()
        : (widget.content.price != null
            ? widget.content.price!.toDouble()
            : 0.0);
    final canPurchaseSeason = !isSeasonPurchased && effectiveSeasonPrice > 0;
    final priceLabel =
        effectiveSeasonPrice.truncateToDouble() == effectiveSeasonPrice
            ? effectiveSeasonPrice.toInt().toString()
            : effectiveSeasonPrice.toStringAsFixed(2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Season ${season.seasonNumber}: ${season.title}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.canvasColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                season.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.canvasColor.withOpacity(0.7)),
              ),
              const SizedBox(height: 6),
              widget.content.isFeatured == true
                  ? _buildReleaseDateHighlight(context, season)
                  : canPurchaseSeason
                      ? Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              disabledBackgroundColor:
                                  theme.canvasColor.withOpacity(0.2),
                              disabledForegroundColor:
                                  theme.canvasColor.withOpacity(0.6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _purchaseSeason(context, season),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "Rent complete Season ₹$priceLabel",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox()
              //: SizedBox(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReleaseDateHighlight(
    BuildContext context,
    dynamic item, {
    bool centered = false,
  }) {
    final theme = Theme.of(context);
    dynamic rawDate;
    if (item is SeasonEntity) {
      rawDate = item.releaseDate > 0
          ? item.releaseDate
          : widget.content.releaseDate;
    } else if (item is Content) {
      rawDate = item.releaseDate;
    } else {
      rawDate = item ?? widget.content.releaseDate;
    }

    final releaseDateText = formatReleaseDate(rawDate).trim();
    final displayText = (releaseDateText.isNotEmpty)
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

  Widget _buildCastSection(
    BuildContext context,
    SeasonEntity season,
    ThemeData theme,
  ) {
    final lang = AppLocalizations.of(context)!;
    final fallbackCast = (widget.content.castList ?? const [])
        .where((name) => name.trim().isNotEmpty)
        .map((name) => CastMember(name: name.trim()))
        .toList();
    final castList =
        _seasonCastList.isNotEmpty ? _seasonCastList : fallbackCast;

    if (_isLoadingSeasonCast && _loadedSeasonId == season.seasonId) {
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
            color: ResponsiveWidget.isMobile(context)
                ? theme.canvasColor
                : theme.primaryColor,
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
                    return _buildCastCard(context, castList[index]);
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
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          if (role.isNotEmpty)
            Text(
              "($role)",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
              ),
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

  // ---------------- EPISODE TILE ----------------

  Widget _episodeTile(
    BuildContext context,
    SeasonEntity season,
    EpisodeEntity ep,
    ThemeData theme,
  ) {
    final isSeasonPurchased =
        (widget.content.isRental == true) || season.isSeasonPurchased;
    final canPlay = isSeasonPurchased || ep.isPurchased || ep.isFree;
    final resumeSeconds = context.watch<PlayMediaProvider>().getLocalResume(
          contentId: widget.content.id ?? widget.seriesId,
          seasonId: season.seasonId,
          episodeId: ep.episodeId,
        );

    final progress = ep.runtime > 0
        ? (resumeSeconds / (ep.runtime * 60)).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () {
        if (canPlay) {
          _playEpisode(context, season, ep);
        } else {
          _purchaseEpisode(context, season, ep);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            /// ================= MAIN CONTENT =================
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 🎬 POSTER
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 80,
                          color: Colors.black,
                          alignment: Alignment.center,
                          child: Image.network(
                            ep.posterUrl,
                            width: 120,
                            height: 80,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            errorBuilder: (_, __, ___) => Container(
                              width: 120,
                              height: 80,
                              color: Colors.grey.shade800,
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.white54,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.play_circle_fill,
                          color: Colors.white70,
                          size: 28,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  /// 📄 DETAILS
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ep.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.canvasColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Ep. ${ep.episodeNumber} • ${ep.runtime} min",
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.canvasColor.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ep.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.canvasColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// 🔐 PRICE BUTTON (if locked)
                  if (!canPlay)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _purchaseEpisode(context, season, ep),
                        child: Text(
                          "₹${ep.price}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            /// ================= WATCH PROGRESS =================
            if (progress > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Colors.grey.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation(theme.primaryColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection(
      BuildContext context, Content movie, ThemeData theme) {
    final lang = AppLocalizations.of(context)!;
    TextStyle titleStyle = TextStyle(
      color: theme.canvasColor,
      fontWeight: FontWeight.bold,
    );
    TextStyle contentStyle = TextStyle(
      color: theme.canvasColor.withOpacity(0.7),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        //  border: Border.all(color: theme.canvasColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        columnWidths: const {
          0: IntrinsicColumnWidth(),
          1: FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          /*   _buildTableRow(
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
          _buildTableRow(lang.runtime, "${movie.runtime ?? 0} min", titleStyle,
              contentStyle),
          () {
            final seasons = context.read<SeriesProvider>().series?.seasons;
            final selectedSeason = (seasons != null &&
                    _selectedSeasonIndex < seasons.length)
                ? seasons[_selectedSeasonIndex]
                : (seasons != null && seasons.isNotEmpty ? seasons.first : null);
            final double? seasonPrice = selectedSeason?.price != null &&
                    selectedSeason!.price > 0
                ? selectedSeason.price.toDouble()
                : null;
            final num? effectivePrice =
                (movie.price != null && movie.price! > 0)
                    ? movie.price
                    : seasonPrice;
            final String priceString = effectivePrice != null &&
                    effectivePrice > 0
                ? '₹${effectivePrice.toStringAsFixed(effectivePrice.truncateToDouble() == effectivePrice ? 0 : 2)}'
                : (movie.price != null && movie.price! > 0
                    ? '₹${movie.price}'
                    : (movie.price?.toString() ?? 'N/A'));
            return _buildTableRow(
                lang.price, priceString, titleStyle, contentStyle);
          }(),
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
          _buildTableRow(
              lang.releaseDate,
              formatReleaseDate(movie.releaseDate).isNotEmpty
                  ? formatReleaseDate(movie.releaseDate)
                  : (movie.releaseDate?.toString() ?? 'N/A'),
              titleStyle,
              contentStyle),
          _buildTableRow(
              lang.languages,
              (movie.languageList?.map((e) => e.language) ?? []).join(', '),
              titleStyle,
              contentStyle),
          _buildTableRow(
              lang.rating,
              '${double.parse(
                (movie.ratings ?? 0.0).toStringAsFixed(1),
              )} ⭐',
              titleStyle,
              contentStyle),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Text('$title:', style: titleStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Text(content, style: contentStyle),
        ),
      ],
    );
  }

  Widget _buildRatingAndReviewsSection(BuildContext context, Content content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRatingReviewSection(context, content),
        const SizedBox(height: 16),
        _buildReviewList(),
      ],
    );
  }

  Widget _buildRatingReviewSection(BuildContext context, Content content) {
    final selectedThemeData =
        Provider.of<ThemeProvider>(context, listen: true).getTheme;

    return Consumer<VideoProvider>(
      builder: (context, provider, child) => Column(
        children: [
          const Text(
            "Rate your experience",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          StarRating(
            rating: provider.rating,
            onRatingChanged: (rating) =>
                setState(() => provider.rating = rating),
          ),
          const SizedBox(height: 7),
          Container(
            height: 90,
            margin: const EdgeInsets.all(10.0),
            padding: const EdgeInsets.only(bottom: 16.0),
            child: TextField(
              maxLines: 9,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [CapitalizeSentencesTextInputFormatter()],
              style: const TextStyle(color: Colors.white),
              controller: provider.reviewController,
              decoration: const InputDecoration(
                hintText: "Your Feedback!",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 7),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: selectedThemeData.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () async {
              final contentId = content.id ?? widget.seriesId;
              if (provider.rating == 0) {
                CustomToast.show(context, "Please select rating..",
                    isSuccess: false);
                return;
              }

              final result = await provider.saveRatingReview(contentId);
              if (!mounted) return;

              final message = result['message']?.toString().trim();
              if (result['success'] != true) {
                CustomToast.show(
                  context,
                  message != null && message.isNotEmpty
                      ? message
                      : "something went wrong to submit review",
                  isSuccess: false,
                );
                return;
              }

              CustomToast.show(
                context,
                message != null && message.isNotEmpty
                    ? message
                    : 'review submitted successfully',
                isSuccess: true,
              );
              await context.read<VideoProvider>().getRatingReview(contentId);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child:
                  Text("Submit Review", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewList() {
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
            final formattedDate =
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
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      StarDisplay(
                          value: provider.reviewList[index].rating ?? 5),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          formattedDate,
                          style: const TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    provider.reviewList[index].title.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(thickness: 2),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------- GALLERY ----------------

  Widget _buildGallery(Content content) {
    final theme = Theme.of(context);
    final posters = content.posterUrlList ?? [];
    final teaserUrl = _galleryVideoUrl(content);
    final hasPosters = posters.isNotEmpty;
    final hasTeaser = teaserUrl.isNotEmpty;

    if (!hasPosters && !hasTeaser) return const SizedBox.shrink();

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
            itemCount: posters.length + (hasTeaser ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (hasTeaser && index == 0) {
                return SizedBox(
                  width: 320,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: TrailerPreview(
                      trailerUrl: teaserUrl,
                      content: content,
                      controller: _teaserController,
                    ),
                  ),
                );
              }

              final posterIndex = hasTeaser ? index - 1 : index;
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 320,
                  height: 180,
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Image.network(
                    posters[posterIndex],
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
}

class _ResumeEpisode {
  const _ResumeEpisode(this.season, this.episode);

  final SeasonEntity season;
  final EpisodeEntity episode;
}

class _TvFocusableScale extends StatefulWidget {
  const _TvFocusableScale({
    required this.child,
    required this.onPressed,
    this.width,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double? width;

  @override
  State<_TvFocusableScale> createState() => _TvFocusableScaleState();
}

class _TvFocusableScaleState extends State<_TvFocusableScale> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _focused || _hovered;

  @override
  Widget build(BuildContext context) {
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
