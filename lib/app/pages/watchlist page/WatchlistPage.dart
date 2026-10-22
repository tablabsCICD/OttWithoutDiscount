import 'dart:async';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

enum WatchlistFilter { available, gifted, expired, downloaded }

class WatchlistPage extends StatefulWidget {
  const WatchlistPage({
    super.key,
    this.initialFilter = WatchlistFilter.available,
  });

  final WatchlistFilter initialFilter;

  @override
  State<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  bool isLoading = true;
  bool isOffline = false;
  late WatchlistFilter selectedFilter;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    selectedFilter = widget.initialFilter;
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    _load();
  }

  Future<void> _load() async {
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

  Future<void> _fetchWatchlistContent(
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
        "Video is not available",
        isSuccess: false,
      );
      return;
    }

    Navigator.push(
      context,
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
    final title = item.title?.trim().isNotEmpty == true
        ? item.title!.trim()
        : 'this movie';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete download?'),
        content: Text(
          'Delete $title from this device? You can download it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final result = await context
          .read<OfflineDownloadProvider>()
          .deleteContent(item);
      if (!mounted) return;
      CustomToast.show(
        context,
        result['message']?.toString() ?? 'Download deleted.',
        isSuccess: result['success'] == true,
      );
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(
        context,
        'Could not delete the download: $error',
        isSuccess: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          lang.watchlist,
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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

  // 🔁 Segmented Toggle
  Widget _segmentedToggle(ThemeData theme) {
    final items = <({WatchlistFilter value, String label})>[
      (value: WatchlistFilter.available, label: "Available"),
      (value: WatchlistFilter.downloaded, label: "Downloaded"),
      (value: WatchlistFilter.gifted, label: "Gifted"),
      (value: WatchlistFilter.expired, label: "Expired"),
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
                      item.rentlDuration ?? 'NA',
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
                child: const Text(
                  "Expired",
                  style: TextStyle(
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
                child: const Text(
                  'Gifted',
                  style: TextStyle(
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_done_rounded,
                            color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Offline',
                          style: TextStyle(
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
                    message: 'Delete download',
                    child: Material(
                      color: Colors.black87,
                      shape: const CircleBorder(
                        side: BorderSide(color: Colors.white24),
                      ),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints:
                            const BoxConstraints.tightFor(width: 32, height: 32),
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
        onTap: content.active == true ? () => _playContent(item) : null,
        child: card,
      );
    }

    return OttTvFocus(
      onTap: content.active == true ? () => _playContent(item) : null,
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
            item.title ?? 'Movie',
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
    final emptyTitle = isOffline || selectedFilter == WatchlistFilter.downloaded
        ? "No downloaded content found"
        : "No content found";
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
  });

  final Content movie;
  final bool isActive;
  final bool isGifted;
  final bool isDownloaded;

  bool get active => isActive;
}
