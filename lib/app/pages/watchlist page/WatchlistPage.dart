import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ott/app/core/utils/content_type.dart';
import 'package:ott/app/pages/movie%20details%20page/MovieDetailsPage.dart';
import 'package:ott/app/pages/series%20details%20page/seriesdetailspage.dart';
import 'package:ott/app/pages/watchlist%20page/component/playMoviePage.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/provider/offline_download_provider.dart';
import 'package:ott/app/provider/playMediaProvider.dart';
import 'package:ott/app/provider/purchaseContentProvider.dart';
import 'package:ott/app/widgets/ott_tv_focus.dart';
import 'package:ott/app/widgets/responsive_poster_image.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:ott/app/widgets/shimmer%20loader/comming_soon_shimmer.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';
import 'package:ott/app/widgets/movieCard.dart';
import 'package:ott/app/core/services/gifted_content_info_service.dart';

enum WatchlistFilter { available, gifted, expired, downloaded }

class WatchlistPage extends StatefulWidget {
  const WatchlistPage({
    super.key,
    this.initialFilter = WatchlistFilter.available,
  }) : giftedOnly = false;

  /// Profile -> "Gifted To You": the Watchlist "Gifted" list on its own
  /// screen. Same API, provider, cards and routing; only the filter chips are
  /// hidden and it gets its own title, empty, error and retry states.
  const WatchlistPage.giftedToYou({super.key})
      : initialFilter = WatchlistFilter.gifted,
        giftedOnly = true;

  final WatchlistFilter initialFilter;
  final bool giftedOnly;

  @override
  State<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  bool isLoading = true;
  bool isOffline = false;
  late WatchlistFilter selectedFilter;
  /// Gifted To You only: message of the last failed fetch (null = no error).
  String? _giftedLoadError;
  Future<void>? _giftedLoad;

  /// Gifted To You only: a card was tapped and its screen is opening / open.
  /// Ignores repeat taps so the player is not pushed twice.
  bool _openingContent = false;

  /// Profile sub-pages are hosted in a nested Navigator inside the
  /// NavigationPage tab body (ProfileDetailShell). The player and details
  /// must go on the root Navigator: inside the tab body the player's
  /// landscape lock switches NavigationPage to its wide layout, which rebuilds
  /// that nested Navigator and drops the player, and system back skips it.
  /// The Watchlist tab itself already uses the root Navigator.
  NavigatorState get _contentNavigator =>
      Navigator.of(context, rootNavigator: widget.giftedOnly);
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    selectedFilter = widget.initialFilter;
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    _load();
  }

  Future<void> _load() {
    if (!widget.giftedOnly) return _loadWatchlist();
    // Gifted To You: never run two fetches at once (connectivity change,
    // retry and pull-to-refresh can overlap).
    return _giftedLoad ??=
        _loadGifted().whenComplete(() => _giftedLoad = null);
  }

  Future<void> _loadGifted() async {
    final purchaseProvider = context.read<PurchaseContentProvider>();
    final offlineProvider = context.read<OfflineDownloadProvider>();
    await context.read<PlayMediaProvider>().loadLocalResumes();
    await _updateConnectionStatus();
    // Keeps the "Offline" badge on gifted cards that are also downloaded.
    await offlineProvider.loadDownloadedContents();
    String? error;
    if (isOffline) {
      if (!mounted) return;
      error = AppLocalizations.of(context)!.msgNoInternetConnection;
    } else {
      final result = await _fetchWatchlistContent(
        purchaseProvider,
        WatchlistFilter.gifted,
      );
      if (result['success'] != true) {
        error = result['message']?.toString();
        if (error == null || error.trim().isEmpty) {
          if (!mounted) return;
          error = AppLocalizations.of(context)!.msgSomethingWentWrongTryAgain;
        }
      }
    }
    if (mounted) {
      setState(() {
        _giftedLoadError = error;
        isLoading = false;
      });
    }
  }

  Future<void> _retryGifted() async {
    setState(() {
      _giftedLoadError = null;
      isLoading = true;
    });
    await _load();
  }

  Future<void> _loadWatchlist() async {
    final purchaseProvider =
        Provider.of<PurchaseContentProvider>(context, listen: false);
    final offlineProvider =
        Provider.of<OfflineDownloadProvider>(context, listen: false);
    await context.read<PlayMediaProvider>().loadLocalResumes();
    await _updateConnectionStatus();
    await offlineProvider.loadDownloadedContents();
    if (!isOffline) {
      await _fetchWatchlistContent(purchaseProvider, selectedFilter);
    }
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _updateConnectionStatus() async {
    _setConnectionStatus(await Connectivity().checkConnectivity());
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOffline = isOffline;
    _setConnectionStatus(results);
    if (wasOffline != isOffline) {
      _load();
    }
  }

  void _setConnectionStatus(List<ConnectivityResult> connectivityResults) {
    isOffline = !connectivityResults.any(
      (result) => result != ConnectivityResult.none,
    );
  }

  Future<void> _onFilterSelected(WatchlistFilter filter) async {
    if (selectedFilter == filter) return;

    setState(() {
      selectedFilter = filter;
      isLoading = true;
    });

    final purchaseProvider =
        Provider.of<PurchaseContentProvider>(context, listen: false);
    final offlineProvider =
        Provider.of<OfflineDownloadProvider>(context, listen: false);
    await _updateConnectionStatus();
    await offlineProvider.loadDownloadedContents();
    if (!isOffline) {
      await _fetchWatchlistContent(purchaseProvider, filter);
    }

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  Future<Map<String, Object>> _fetchWatchlistContent(
    PurchaseContentProvider purchaseProvider,
    WatchlistFilter filter,
  ) {
    final isGifted = filter == WatchlistFilter.gifted;
    final isExpired = filter == WatchlistFilter.expired;

    return purchaseProvider.getPurchaseContent(
      isGifted: isGifted,
      isExpired: isExpired,
    );
  }

  /// Gifted items are routed by content type: movies and short films play
  /// directly, series and mini-series open their detail screen (they have no
  /// single video to play). Other tabs keep their existing behavior.
  void _openContent(Content item) {
    if (widget.giftedOnly) {
      unawaited(_openGiftedContent(item));
      return;
    }
    if (selectedFilter == WatchlistFilter.gifted && item.id != null) {
      final type = ContentType.normalize(item.type);
      if (type == ContentType.series ||
          type == ContentType.miniSeries ||
          type == 'MINI_SERIES') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SeriesDetailsPage(seriesId: item.id!, content: item),
          ),
        );
        return;
      }
    }
    _playContent(item);
  }

  /// Gifted To You: same routing as the Watchlist Gifted tab, opened on the
  /// root Navigator, once per tap.
  Future<void> _openGiftedContent(Content item) async {
    if (_openingContent || item.id == null) return;
    _openingContent = true;
    try {
      final type = ContentType.normalize(item.type);
      if (type == ContentType.series ||
          type == ContentType.miniSeries ||
          type == 'MINI_SERIES') {
        await _contentNavigator.push(
          MaterialPageRoute(
            builder: (_) =>
                SeriesDetailsPage(seriesId: item.id!, content: item),
          ),
        );
      } else {
        await _playContent(item);
      }
    } finally {
      _openingContent = false;
    }
  }

  /// Gifted To You card tap: the content's details page (Movie / Short Film
  /// -> MovieDetailsPage, Series / Mini Series -> SeriesDetailsPage), same as
  /// the Home card, on the root Navigator so it survives the player's
  /// landscape switch and Back returns here. Once per tap.
  Future<void> _openGiftedDetails(Content item) async {
    if (_openingContent || item.id == null) return;
    _openingContent = true;
    try {
      await _contentNavigator.push(
        MaterialPageRoute(
          builder: (_) => ContentType.isMovieLike(item.type)
              ? MovieDetailsPage(movieId: item.id!, contentType: item.type)
              : SeriesDetailsPage(seriesId: item.id!, content: item),
        ),
      );
    } finally {
      _openingContent = false;
    }
  }

  Future<void> _playContent(Content item) async {
    if (item.id == null) return;

    Content contentToPlay = item;
    var contentUrl = contentToPlay.contentUrl;
    final localResumeSeconds = context.read<PlayMediaProvider>().getLocalResume(
          contentId: item.id!,
          seasonId: item.seasonId,
          episodeId: item.episodeId,
        );
    final latestResumeSeconds = (item.watchedSeconds ?? 0) > localResumeSeconds
        ? item.watchedSeconds ?? 0
        : localResumeSeconds;

    // Watchlist items come from the purchase API, which can already contain
    // a playable URL but not the latest continue-watching fields. Refresh the
    // content before playback so watchlist behaves like Continue Watching.
    if (!isOffline) {
      final fetchedContent =
          await context.read<DashboardProvider>().getContentById(item.id!);
      if (!mounted) return;

      if (fetchedContent != null) {
        // Downloaded copies often keep the progress value that existed when
        // the file was saved (usually 0). Prefer the newest local resume when
        // it is ahead of the server/offline snapshot.
        if ((fetchedContent.watchedSeconds ?? 0) < latestResumeSeconds) {
          fetchedContent.watchedSeconds = latestResumeSeconds;
        }
        fetchedContent.watchedPercentage ??= item.watchedPercentage;
        contentToPlay = fetchedContent;
        contentUrl = contentToPlay.contentUrl;
      }
    }

    if ((contentToPlay.watchedSeconds ?? 0) < latestResumeSeconds) {
      contentToPlay.watchedSeconds = latestResumeSeconds;
    }
    contentToPlay.watchedPercentage ??= item.watchedPercentage;

    final offlinePath = await context
        .read<OfflineDownloadProvider>()
        .getOfflinePath(contentToPlay);
    if (offlinePath != null && offlinePath.trim().isNotEmpty) {
      contentUrl = offlinePath;
    }

    if (contentUrl == null || contentUrl.trim().isEmpty) {
      CustomToast.show(
        context,
        AppLocalizations.of(context)!.cardVideoNotAvailable,
        isSuccess: false,
      );
      return;
    }

    // Awaited so the Gifted To You tap guard stays set while the player is
    // open; the Watchlist tab does not wait on it.
    await _contentNavigator.push(
      MaterialPageRoute(
        builder: (_) => PlayMediaPage(
          content: contentToPlay,
          seasons: null,
          videoUrl: contentUrl!,
          seasonIndex: 0,
          episodeIndex: 0,
        ),
      ),
    );
  }

  Future<void> _deleteDownload(Content item) async {
    final lang = AppLocalizations.of(context)!;
    final title = item.title?.trim().isNotEmpty == true
        ? item.title!.trim()
        : lang.giftThisMovie;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(lang.watchlistDeleteDownloadTitle),
        content: Text(
          lang.watchlistDeleteDownloadMessage(title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(lang.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: Text(lang.profileDelete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final result =
          await context.read<OfflineDownloadProvider>().deleteContent(item);
      if (!mounted) return;
      CustomToast.show(
        context,
        result['message']?.toString() ?? lang.watchlistDownloadDeleted,
        isSuccess: result['success'] == true,
      );
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(
        context,
        lang.watchlistCouldNotDeleteDownload('$error'),
        isSuccess: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = AppLocalizations.of(context)!;

    if (widget.giftedOnly) return _buildGiftedToYou(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: FilmytellAppBar.main(title: lang.watchlist),
      body: Column(
        children: [
          _segmentedToggle(theme),
          Expanded(
            child: isLoading
                ? const ComingSoonShimmer(
                    showSegmentedToggle: false,
                    showActionButton: false,
                  )
                : Consumer2<PurchaseContentProvider, OfflineDownloadProvider>(
                    builder: (_, purchaseProvider, offlineProvider, __) {
                      final items = _buildEntries(
                        purchaseProvider: purchaseProvider,
                        offlineProvider: offlineProvider,
                      );

                      if (items.isEmpty) {
                        return _emptyState(theme, showSegmentedToggle: false);
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: items.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              ResponsiveWidget.isMobile(context) ? 1 : 3,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 16 / 9,
                        ),
                        itemBuilder: (_, i) => _netflixCard(context, items[i]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Profile -> Gifted To You. Reuses the gifted fetch, entry building and
  /// cards of the Watchlist "Gifted" tab.
  Widget _buildGiftedToYou(BuildContext context) {
    final theme = Theme.of(context);
    final lang = AppLocalizations.of(context)!;

    Widget body;
    if (isLoading) {
      body = const ComingSoonShimmer(
        showSegmentedToggle: false,
        showActionButton: false,
      );
    } else if (_giftedLoadError != null) {
      body = _giftedMessage(
        theme,
        icon: isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
        title: _giftedLoadError!,
        action: OutlinedButton.icon(
          onPressed: _retryGifted,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(lang.retry),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.primaryColor,
            side: BorderSide(color: theme.primaryColor),
          ),
        ),
      );
    } else {
      body = Consumer2<PurchaseContentProvider, OfflineDownloadProvider>(
        builder: (_, purchaseProvider, offlineProvider, __) {
          final items = _buildEntries(
            purchaseProvider: purchaseProvider,
            offlineProvider: offlineProvider,
          );
          if (items.isEmpty) {
            return _giftedMessage(
              theme,
              icon: Icons.card_giftcard_rounded,
              title: lang.giftedToYouEmptyTitle,
              message: lang.giftedToYouEmptyMessage,
            );
          }
          return _giftedGrid(items);
        },
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: FilmytellAppBar(title: lang.giftedToYou),
      body: RefreshIndicator(
        color: theme.primaryColor,
        onRefresh: _load,
        child: body,
      ),
    );
  }

  /// Gifted cards use the Home page [MovieCard] in the same responsive grid
  /// as the Home category pages (fixed card width / height, centered).
  /// Tapping opens the content directly (player / series details).
  Widget _giftedGrid(List<_WatchlistEntry> items) {
    const double gap = 12;
    const double horizontalPadding = 12;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - horizontalPadding * 2;
        // Columns from the standard card width, then cards widen to fill the
        // row exactly (no empty space beside them).
        final baseWidth = MovieCard.cardWidthFor(context);
        final crossAxisCount =
            math.max(1, ((availableWidth + gap) / (baseWidth + gap)).floor());
        final cardWidth =
            (availableWidth - (crossAxisCount - 1) * gap) / crossAxisCount;
        // Same title/details area as the standard card; the 16:9 poster grows
        // with the width.
        final detailsHeight = MovieCard.standardHeight -
            baseWidth / MovieCard.standardPosterAspectRatio;
        final cardHeight =
            cardWidth / MovieCard.standardPosterAspectRatio + detailsHeight;

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              horizontalPadding, 12, horizontalPadding, 24),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (_, i) {
            final entry = items[i];
            return Center(
              child: MovieCard(
                key: ValueKey('giftedCard-${entry.movie.id}'),
                movie: entry.movie,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                cardMargin: 0,
                isGifted: true,
                giftInfo: entry.giftInfo,
                // Card tap -> details page; Watch Now -> player.
                onOpen: () => unawaited(_openGiftedDetails(entry.movie)),
                onWatchNow: () => _onGiftedWatchNow(entry),
              ),
            );
          },
        );
      },
    );
  }

  void _onGiftedWatchNow(_WatchlistEntry entry) {
    if (!entry.active) {
      CustomToast.show(
        context,
        AppLocalizations.of(context)!.watchlistExpired,
        isSuccess: false,
      );
      return;
    }
    _openContent(entry.movie);
  }

  /// Scrollable (so pull-to-refresh works) centered empty / error message.
  Widget _giftedMessage(
    ThemeData theme, {
    required IconData icon,
    required String title,
    String? message,
    Widget? action,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 72,
                      color: theme.canvasColor.withValues(alpha: 0.6)),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.canvasColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.canvasColor.withValues(alpha: 0.7),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: 20),
                    action,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔁 Segmented Toggle
  Widget _segmentedToggle(ThemeData theme) {
    final lang = AppLocalizations.of(context)!;
    final items = <({WatchlistFilter value, String label})>[
      (value: WatchlistFilter.available, label: lang.billingAvailable),
      (value: WatchlistFilter.downloaded, label: lang.detailsDownloaded),
      (value: WatchlistFilter.gifted, label: lang.watchlistGifted),
      (value: WatchlistFilter.expired, label: lang.watchlistExpired),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        height: 35,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (_, index) {
            final item = items[index];
            return _filterChip(
              theme,
              item.value,
              item.label,
            );
          },
        ),
      ),
    );
  }

  Widget _filterChip(
    ThemeData theme,
    WatchlistFilter value,
    String label,
  ) {
    final selected = selectedFilter == value;

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),

        // ✅ Selected state (like your image)
        color: selected ? theme.primaryColor : Colors.transparent,

        border: Border.all(
          color: selected
              ? theme.primaryColor
              : theme.canvasColor.withOpacity(0.6),
        ),

        boxShadow: selected
            ? [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : [],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : theme.primaryColor,
        ),
      ),
    );

    if (ResponsiveWidget.isMobile(context)) {
      return GestureDetector(
        onTap: () => _onFilterSelected(value),
        child: chip,
      );
    }

    return OttTvFocus(
      onTap: () => _onFilterSelected(value),
      borderRadius: 10,
      scale: 1.04,
      child: chip,
    );
  }

  List<_WatchlistEntry> _buildEntries({
    required PurchaseContentProvider purchaseProvider,
    required OfflineDownloadProvider offlineProvider,
  }) {
    final entriesById = <int, _WatchlistEntry>{};

    for (final userContent in purchaseProvider.userContentList) {
      final movie = userContent.movie;
      final movieId = movie?.id;
      if (movie == null || movieId == null) continue;

      entriesById[movieId] = _WatchlistEntry(
        movie: movie
          ..watchedPercentage ??= userContent.contentPercentage?.round(),
        isActive: userContent.active ?? false,
        isGifted: userContent.isGifted ?? false,
        isDownloaded: offlineProvider.isDownloaded(movieId),
        giftInfo: userContent.isGifted == true
            ? GiftedContentInfo.fromUserContent(userContent)
            : null,
      );
    }

    if (isOffline || selectedFilter == WatchlistFilter.downloaded) {
      for (final movie in offlineProvider.downloadedContents) {
        final movieId = movie.id;
        if (movieId == null) continue;
        final existingMovie = entriesById[movieId]?.movie;

        if ((movie.watchedSeconds ?? 0) <
            (existingMovie?.watchedSeconds ?? 0)) {
          movie.watchedSeconds = existingMovie?.watchedSeconds;
        }
        if ((movie.watchedPercentage ?? 0) <
            (existingMovie?.watchedPercentage ?? 0)) {
          movie.watchedPercentage = existingMovie?.watchedPercentage;
        }

        entriesById[movieId] = _WatchlistEntry(
          movie: movie,
          isActive: true,
          isGifted: entriesById[movieId]?.isGifted ?? false,
          isDownloaded: true,
          giftInfo: entriesById[movieId]?.giftInfo,
        );
      }
    }

    return entriesById.values.where((entry) {
      if (isOffline) {
        return entry.isDownloaded;
      }

      switch (selectedFilter) {
        case WatchlistFilter.available:
          return true;
        case WatchlistFilter.downloaded:
          return entry.isDownloaded;
        case WatchlistFilter.gifted:
          return true;
        case WatchlistFilter.expired:
          return true;
      }
    }).toList();
  }

  Widget _netflixCard(BuildContext context, _WatchlistEntry content) {
    final theme = Theme.of(context);
    final lang = AppLocalizations.of(context)!;
    final item = content.movie;

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: _posterBackground(item),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black54,
                    Colors.black87,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      item.rentlDuration ?? lang.cardNotApplicable,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ❌ Expired overlay
          if (content.active == false)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.55),
                alignment: Alignment.center,
                child: Text(
                  lang.watchlistExpired,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // 🎁 Gifted badge
          if (content.isGifted == true)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  lang.watchlistGifted,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (content.isDownloaded)
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.download_done_rounded,
                            color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          lang.watchlistOffline,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: lang.watchlistDeleteDownload,
                    child: Material(
                      color: Colors.black87,
                      shape: const CircleBorder(
                        side: BorderSide(color: Colors.white24),
                      ),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                            width: 32, height: 32),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white, size: 18),
                        onPressed: () => _deleteDownload(item),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if ((item.watchedPercentage ?? 0) > 0 &&
              (item.watchedPercentage ?? 0) < 95)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: (item.watchedPercentage! / 100).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
              ),
            ),
        ],
      ),
    );

    if (ResponsiveWidget.isMobile(context)) {
      return GestureDetector(
        onTap: content.active == true ? () => _openContent(item) : null,
        child: card,
      );
    }

    return OttTvFocus(
      onTap: content.active == true ? () => _openContent(item) : null,
      borderRadius: 16,
      scale: 1.035,
      child: card,
    );
  }

  Widget _posterBackground(Content item) {
    final posterUrl =
        item.posterUrlList?.isNotEmpty == true ? item.posterUrlList!.first : '';

    return ResponsivePosterImage(
      imageUrl: posterUrl,
      imageUrls: item.posterUrlList,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      backgroundColor: Colors.black,
      fallbackBuilder: () => _offlinePosterFallback(item),
    );
  }

  Widget _offlinePosterFallback(Content item) {
    return Container(
      color: Colors.black26,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie_creation_outlined,
              color: Colors.white70, size: 42),
          const SizedBox(height: 10),
          Text(
            item.title ?? AppLocalizations.of(context)!.cardTypeMovie,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(ThemeData theme, {bool showSegmentedToggle = true}) {
    final lang = AppLocalizations.of(context)!;
    final emptyTitle = isOffline || selectedFilter == WatchlistFilter.downloaded
        ? lang.watchlistNoDownloadedContentFound
        : lang.noContentFound;
    return Column(
      children: [
        if (showSegmentedToggle) _segmentedToggle(theme),
        const Spacer(),
        Icon(Icons.video_library_outlined,
            size: 80, color: theme.canvasColor.withOpacity(0.6)),
        const SizedBox(height: 12),
        Text(
          emptyTitle,
          style: TextStyle(
            color: theme.canvasColor,
            fontSize: 16,
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _WatchlistEntry {
  const _WatchlistEntry({
    required this.movie,
    required this.isActive,
    required this.isGifted,
    required this.isDownloaded,
    this.giftInfo,
  });

  final Content movie;
  final bool isActive;
  final bool isGifted;
  final bool isDownloaded;

  /// Gift dates / status (gifted items only), shown on Gifted To You cards.
  final GiftedContentInfo? giftInfo;

  bool get active => isActive;
}
