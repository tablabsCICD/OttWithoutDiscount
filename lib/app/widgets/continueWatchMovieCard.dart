import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ott/app/core/utils/sharepreferences.dart';
import 'package:ott/app/core/services/DeepLinkService.dart';
import 'package:ott/app/core/utils/direct_trailer_source.dart';
import 'package:ott/app/core/utils/content_type.dart';
import 'package:ott/app/core/utils/release_date_formatter.dart';
import 'package:ott/app/core/utils/security_debug_log.dart';
import 'package:ott/app/pages/watchlist%20page/component/DisplayTrailer.dart';
import 'package:ott/app/pages/movie%20details%20page/MovieDetailsPage.dart';
import 'package:ott/app/pages/series%20details%20page/seriesdetailspage.dart';
import 'package:ott/app/pages/watchlist%20page/component/playMoviePage.dart';
import 'package:ott/app/pages/wallet%20page/MovieBillingPage.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/provider/bookmarkProvider.dart';
import 'package:ott/app/provider/userProvider.dart';
import 'package:ott/app/widgets/StarRatingWidget.dart';
import 'package:ott/app/widgets/customtextfield.dart';
import 'package:ott/app/widgets/content_share_sheet.dart';
import 'package:ott/app/widgets/responsive_poster_image.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'package:ott/data/models/content.dart';

class ContinueWatchMovieCard extends StatefulWidget {
  static const double standardHeight = 250.0;
  static const double standardPosterAspectRatio = 16 / 9;
  static const double mobileCardWidth = 300.0;
  static const double tabletCardWidth = 300.0;
  static const double laptopCardWidth = 300.0;
  static const double desktopCardWidth = 300.0;
  static const double itemWidth = 300;
  static const double itemMargin = 5;
  static const double itemExtent = itemWidth + (itemMargin * 2);

  final Content movie;
  final ValueListenable<int?>? activeIndexListenable;
  final int? index;
  final bool enableTrailerPreview;
  final bool isShortFilmTab;

  const ContinueWatchMovieCard({
    super.key,
    required this.movie,
    this.activeIndexListenable,
    this.index,
    this.enableTrailerPreview = true,
    this.isShortFilmTab = false,
  });

  /// Resolves the standardized card width for the given context based on
  /// platform and responsive viewport breakpoints.
  static double cardWidthFor(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 340) {
      return (screenWidth - 24).clamp(200.0, 300.0);
    }
    return itemWidth; // 300.0 like before
  }

  /// Resolves the standardized item extent (card width + margins).
  static double cardExtentFor(BuildContext context, [double margin = itemMargin]) {
    return cardWidthFor(context) + (margin * 2);
  }

  @override
  State<ContinueWatchMovieCard> createState() => _ContinueWatchMovieCardState();
}

class _ContinueWatchMovieCardState extends State<ContinueWatchMovieCard> {
  static _ContinueWatchMovieCardState? _activePreviewState;
  Player? _previewPlayer;
  VideoController? _videoController;
  final List<StreamSubscription<dynamic>> _previewSubscriptions = [];
  bool _isHovered = false;
  bool _isMuted = true;
  bool _isVideoInitialized = false;
  bool _isPreviewPlaying = false;
  bool _isAutoPlayActive = false;
  bool _isStartingPreview = false;
  Timer? _playDelayTimer;
  Future<void>? _previewStartFuture;

  String? _directPreviewUrl(String? rawUrl) {
    final value = DirectTrailerSource.fromBackend(rawUrl);
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return null;

    final host = uri.host.toLowerCase();
    final isYoutube = host.contains('youtube.com') || host == 'youtu.be';
    if (isYoutube) return null;

    return value;
  }

  @override
  void initState() {
    super.initState();
    if (widget.enableTrailerPreview) {
      widget.activeIndexListenable?.addListener(_handleActiveIndexChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<BookmarkProvider>()
          .isBookmarked(widget.movie.id ?? 0)
          .then((value) {
        if (!mounted) return;
        if (value) {
          context.read<BookmarkProvider>().addBookmark(widget.movie.id ?? 0);
        }
      });

      if (mounted && widget.enableTrailerPreview) {
        _handleActiveIndexChanged();
      }
    });
  }

  Widget _watchProgressBar(ThemeData theme) {
    final progress = (widget.movie.watchedPercentage ?? 0) / 100;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0.3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          minHeight: 4,
          backgroundColor: theme.cardColor,
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.primaryColor, // Netflix-style
          ),
        ),
      ),
    );
  }

  void _toggleMute() {
    final player = _previewPlayer;
    setState(() {
      _isMuted = !_isMuted;
    });
    player?.setVolume(_isMuted ? 0 : 100);
  }

  Future<bool> _ensureVideoInitialized() async {
    if (_isVideoInitialized) return true;

    final trailerUrl = _directPreviewUrl(widget.movie.trailerUrl);
    if (trailerUrl == null) return false;

    final player = Player();
    final controller = VideoController(player);

    try {
      _previewSubscriptions
        ..add(player.stream.completed.listen((completed) {
          if (completed && _isPreviewPlaying) {
            player.seek(Duration.zero);
            player.play();
          }
        }))
        ..add(player.stream.position.listen((_) {
          if (mounted) setState(() {});
        }))
        ..add(player.stream.duration.listen((_) {
          if (mounted) setState(() {});
        }))
        ..add(player.stream.error.listen((error) {
          _stopPreview();
          if (_activePreviewState == this) {
            _activePreviewState = null;
          }
        }));

      SecurityDebugLog.event(
        'TRAILER',
        'Continue-watching preview is using the direct backend trailer URL.',
      );
      await player.open(Media(trailerUrl), play: false);
      await player.setVolume(_isMuted ? 0 : 100);

      _previewPlayer = player;
      _videoController = controller;

      if (mounted) {
        setState(() => _isVideoInitialized = true);
      }
      return true;
    } catch (e) {
      await player.dispose();
      _disposeVideoController();
      return false;
    }
  }

  void _disposeVideoController() {
    for (final subscription in _previewSubscriptions) {
      unawaited(subscription.cancel());
    }
    _previewSubscriptions.clear();
    _previewPlayer?.dispose();
    _previewPlayer = null;
    _videoController = null;
    _isVideoInitialized = false;
  }

  Future<void> _disposePreviewBeforeSecurePlayback() async {
    _playDelayTimer?.cancel();
    _isAutoPlayActive = false;
    await _previewStartFuture;
    for (final subscription in _previewSubscriptions) {
      await subscription.cancel();
    }
    _previewSubscriptions.clear();
    final player = _previewPlayer;
    _previewPlayer = null;
    _videoController = null;
    _isVideoInitialized = false;
    _isPreviewPlaying = false;
    if (_activePreviewState == this) _activePreviewState = null;
    if (player != null) {
      SecurityDebugLog.event(
        'TRAILER',
        'Awaiting continue-watching preview disposal before secure playback.',
      );
      await player.dispose();
      SecurityDebugLog.event(
        'TRAILER',
        'Continue-watching preview disposal completed before secure playback.',
      );
    }
  }

  @override
  void didUpdateWidget(covariant ContinueWatchMovieCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.enableTrailerPreview != widget.enableTrailerPreview) {
      oldWidget.activeIndexListenable
          ?.removeListener(_handleActiveIndexChanged);
      _playDelayTimer?.cancel();
      _stopPreview();
      if (!widget.enableTrailerPreview) {
        _disposeVideoController();
      } else {
        widget.activeIndexListenable?.addListener(_handleActiveIndexChanged);
        _handleActiveIndexChanged();
      }
    } else if (widget.enableTrailerPreview &&
        oldWidget.activeIndexListenable != widget.activeIndexListenable) {
      oldWidget.activeIndexListenable
          ?.removeListener(_handleActiveIndexChanged);
      widget.activeIndexListenable?.addListener(_handleActiveIndexChanged);
      _handleActiveIndexChanged();
    } else if (widget.enableTrailerPreview && oldWidget.index != widget.index) {
      _handleActiveIndexChanged();
    }

    if (oldWidget.movie.trailerUrl != widget.movie.trailerUrl) {
      _playDelayTimer?.cancel();
      _stopPreview();
      _disposeVideoController();
    }
  }

  @override
  void dispose() {
    if (_activePreviewState == this) {
      _activePreviewState = null;
    }
    if (widget.enableTrailerPreview) {
      widget.activeIndexListenable?.removeListener(_handleActiveIndexChanged);
    }
    _playDelayTimer?.cancel();
    _disposeVideoController();
    super.dispose();
  }

  void _handleHover(bool hovering) {
    if (!widget.enableTrailerPreview) return;

    setState(() => _isHovered = hovering);

    if (hovering) {
      _schedulePreview();
    } else {
      _playDelayTimer?.cancel();
      _stopPreview();
      if (_activePreviewState == this) {
        _activePreviewState = null;
      }
    }
  }

  void _handleActiveIndexChanged() {
    if (!widget.enableTrailerPreview) return;

    final activeIndex = widget.activeIndexListenable?.value;
    final shouldAutoPlay = _isAutoPlayDevice &&
        widget.index != null &&
        activeIndex != null &&
        activeIndex == widget.index;

    if (shouldAutoPlay == _isAutoPlayActive) return;
    _isAutoPlayActive = shouldAutoPlay;

    if (shouldAutoPlay) {
      _schedulePreview();
    } else {
      _playDelayTimer?.cancel();
      _stopPreview();
      if (_activePreviewState == this) {
        _activePreviewState = null;
      }
    }
  }

  bool get _isAutoPlayDevice {
    if (kIsWeb) {
      return true;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  void _schedulePreview() {
    if (_playDelayTimer != null) return;
    if (_isStartingPreview || _isPreviewPlaying) return;
    if (!_isPlayTriggerActive) return;

    if (_isAutoPlayActive && !_isHovered) {
      _beginPreviewStart();
      return;
    }

    _playDelayTimer = Timer(const Duration(milliseconds: 250), () {
      _playDelayTimer = null;
      _beginPreviewStart();
    });
  }

  void _beginPreviewStart() {
    final future = _startPreviewIfEligible();
    _previewStartFuture = future;
    unawaited(future.whenComplete(() {
      if (identical(_previewStartFuture, future)) {
        _previewStartFuture = null;
      }
    }));
  }

  bool get _isPlayTriggerActive {
    return _isHovered || _isAutoPlayActive;
  }

  Future<void> _startPreviewIfEligible() async {
    if (!mounted) return;
    if (!_isPlayTriggerActive) return;
    if (_isStartingPreview || _isPreviewPlaying) return;

    _isStartingPreview = true;
    try {
      _activatePreview();

      final ready = await _ensureVideoInitialized();
      if (!ready || !mounted) {
        if (_activePreviewState == this) {
          _activePreviewState = null;
        }
        _stopPreview();
        return;
      }

      if (!_isPlayTriggerActive) {
        _stopPreview();
        return;
      }

      _ensureMuted();

      await _previewPlayer!.play();
      if (!mounted) return;
      setState(() => _isPreviewPlaying = true);
    } catch (e) {
      _stopPreview();
      if (_activePreviewState == this) {
        _activePreviewState = null;
      }
    } finally {
      _isStartingPreview = false;
    }
  }

  void _activatePreview() {
    if (_activePreviewState == this) return;
    final previous = _activePreviewState;
    _activePreviewState = this;
    previous?._stopPreview(external: true);
  }

  void _ensureMuted() {
    final player = _previewPlayer;
    if (player == null) return;
    if (!_isMuted) {
      setState(() => _isMuted = true);
    }
    player.setVolume(0);
  }

  void _stopPreview({bool external = false}) {
    final player = _previewPlayer;
    if (player == null || !_isVideoInitialized) return;

    try {
      player.pause();
      player.seek(Duration.zero);
    } catch (e) {}

    if (!mounted) return;
    setState(() {
      _isPreviewPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = AppLocalizations.of(context)!;
    final posterUrl = widget.movie.posterUrlList?.isNotEmpty == true
        ? widget.movie.posterUrlList!.first
        : null;
    final showPreview = _isPreviewPlaying;
    final cardWidth = ContinueWatchMovieCard.cardWidthFor(context);
    final highlightColor = theme.brightness == Brightness.light
        ? const Color.fromARGB(255, 185, 169, 169)
        : const Color.fromARGB(255, 58, 49, 49);
    return Stack(children: [
      Focus(
        canRequestFocus: ResponsiveWidget.isTabletOrTv(context),
        onFocusChange: (hasFocus) {
          if (ResponsiveWidget.isTabletOrTv(context)) {
            _handleHover(hasFocus);
          }
        },
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.gameButtonA) {
            _playContent();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          onEnter: (_) => _handleHover(true),
          onExit: (_) => _handleHover(false),
          child: GestureDetector(
            onTap: _playContent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: cardWidth,
              //  margin: const EdgeInsets.all(ContinueWatchMovieCard.itemMargin),
              margin: EdgeInsets.only(
                left: ContinueWatchMovieCard.itemMargin,
                right: ContinueWatchMovieCard.itemMargin,
                bottom: ContinueWatchMovieCard.itemMargin,
                top: showPreview ? 4 : 12, // 👈 selected card moves slightly up
              ),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: showPreview ? highlightColor : Colors.transparent,
                  width: showPreview ? 2.5 : 1,
                ),
                boxShadow: showPreview
                    ? [
                        BoxShadow(
                          color: highlightColor.withValues(alpha: 0.35),
                          blurRadius: 18,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  /// 🎬 POSTER + PROGRESS BAR STACK
                  Expanded(
                    child: Container(
                      color: Colors.black,
                      child: _buildMediaPreview(
                        posterUrl,
                        theme,
                        widget.movie,
                        showPreview,
                      ),
                    ),
                  ),

                  /// 📄 MOVIE TITLE & INFO BELOW POSTER
                  _buildContentSection(theme, lang),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);

    /*/// ⋮ OPTIONS BUTTON
        _optionButton(context, widget.movie),*/
  }

  Widget _buildMediaPreview(
      String? posterUrl, ThemeData theme, Content content, bool showPreview) {
    if (showPreview && _isVideoInitialized && _videoController != null) {
      return Container(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: Video(
                controller: _videoController!,
                fit: BoxFit.contain,
                controls: null,
              ),
            ),
            Positioned(
              bottom: 5,
              left: 0,
              right: 0,
              child: _previewProgress(),
            ),
            Positioned(
              right: 5,
              bottom: 5,
              child: Semantics(
                button: true,
                label: _isMuted ? 'Unmute trailer' : 'Mute trailer',
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    padding: const EdgeInsets.all(2),
                    constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
                    iconSize: 12,
                    tooltip: _isMuted ? 'Unmute trailer' : 'Mute trailer',
                    icon: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                    ),
                    onPressed: _toggleMute,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ResponsivePosterImage(
            imageUrl: posterUrl,
            imageUrls: content.posterUrlList,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            backgroundColor: Colors.black,
            loadingProgressColor: theme.primaryColor,
            errorIconColor: theme.canvasColor.withValues(alpha: 0.3),
          ),

          /// 🔥 CONTINUE WATCHING BAR
          if ((widget.movie.watchedPercentage ?? 0) > 0)
            _watchProgressBar(theme),
        ],
      ),
    );
  }

  Widget _buildContentSection(ThemeData theme, AppLocalizations lang) {
    final movie = widget.movie;
    final title = movie.title ?? 'No Title';
    final percentage = movie.watchedPercentage;
    final rating = movie.ratings ?? 0.0;
    final price = movie.price ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rating > 0) ...[
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StarRatingWidget(
                                rating: rating,
                              ),
                              Text(
                                " (${movie.ratingCount ?? 0})",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.canvasColor.withValues(alpha: 0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                ],
                SizedBox(
                  height: 38,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.canvasColor,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  TextSpan(
                    style: TextStyle(
                      color: theme.canvasColor.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    children: [
                      if (percentage != null && percentage > 0) ...[
                        TextSpan(text: '${percentage.toInt()}% watched'),
                        if (movie.genreList != null && movie.genreList!.isNotEmpty)
                          const TextSpan(text: ' | '),
                      ],
                      if (movie.genreList != null && movie.genreList!.isNotEmpty)
                        TextSpan(text: movie.genreList!.join(', '))
                      else if (movie.releaseDate != null)
                        TextSpan(text: formatReleaseDate(movie.releaseDate)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (price > 0 && (percentage == null || percentage == 0)) ...[
            const SizedBox(width: 6),
            movie.isFeatured == true
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: theme.primaryColor.withValues(alpha: 0.9),
                    ),
                    child: const Text(
                      "Watch Trailer",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : _buildPriceButton(theme, lang, price),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceButton(
      ThemeData theme, AppLocalizations lang, double price) {
    final movie = widget.movie;
    final isRental = movie.isRental ?? false;
    final isShortFilm = widget.isShortFilmTab ||
        ContentType.normalize(movie.type) == ContentType.shortFilm;

    return GestureDetector(
      onTap: () => movie.type!.toLowerCase() == 'series'
          ? _openDetails()
          : isRental
              ? _playMovie()
              : _showCupertinoDialog(context, movie),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: theme.primaryColor.withValues(alpha: 0.9),
        ),
        child: Text(
          movie.type!.toLowerCase() == 'series'
              ? isRental
                  ? (isShortFilm ? 'Watch Now' : 'Watch Series')
                  : 'Rent Series'
              : isRental
                  ? isShortFilm
                  ? 'Watch Now'
                  : movie.type?.toLowerCase() == "movie"
                  ? lang.watchMovie
                  : lang.watchSeries
                  : "₹ $price",
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _openDetails() {
    final movie = widget.movie;

    if (movie.id == null || movie.type == null) return;

    if (ContentType.isMovieLike(movie.type)) {
      _playContent();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => movie.isFeatured == true
              ? TrailerPage(
                  trailerUrl: movie.teaserOrTrailerUrl ?? "",
                  isTrailerUrl: true,
                  content: movie)
              : ContentType.isMovieLike(movie.type)
                  ? MovieDetailsPage(
                      movieId: movie.id!,
                      contentType: movie.type,
                    )
                  : SeriesDetailsPage(seriesId: movie.id!, content: movie),
        ),
      );
    }
  }

  Widget _previewProgress() {
    final player = _previewPlayer;
    if (player == null) return const SizedBox.shrink();

    final duration = player.state.duration.inMilliseconds;
    if (duration <= 0) return const SizedBox.shrink();

    final value = (player.state.position.inMilliseconds / duration)
        .clamp(0.0, 1.0)
        .toDouble();

    return LinearProgressIndicator(
      value: value,
      minHeight: 3,
      color: Colors.red,
      backgroundColor: Colors.white24,
    );
  }

  Future<void> _playContent() async {
    final movie = widget.movie;
    if (movie.id == null) return;

    Content contentToPlay = movie;
    var contentUrl = contentToPlay.contentUrl;

    if (contentUrl == null || contentUrl.trim().isEmpty) {
      final fetchedContent =
          await context.read<DashboardProvider>().getContentById(movie.id!);
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

    if (contentUrl == null || contentUrl.trim().isEmpty) {
      CustomToast.show(
        context,
        "Video is not available",
        isSuccess: false,
      );
      return;
    }

    await _disposePreviewBeforeSecurePlayback();
    if (!mounted) return;
    Navigator.push(
      context,
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
      context
          .read<DashboardProvider>()
          .getContinueWatchedMovieList(contentToPlay.type ?? "MOVIE");
    });
  }

  void _playMovie() {
    final movie = widget.movie;
    if (movie.id == null) return;
    _playContent();
  }

  void _showCupertinoDialog(BuildContext context, Content movie) {
    final theme = Theme.of(context);
    final lang = AppLocalizations.of(context)!;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('₹ ${movie.price ?? 0}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text(
              '${lang.rentDuration}: ${movie.rentlDuration ?? 'NA'}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.canvasColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Do you want to rent ${movie.title ?? ''}?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.primaryColor,
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            textStyle: TextStyle(color: theme.canvasColor),
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            textStyle: TextStyle(color: theme.primaryColor),
            child: const Text("Continue"),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MovieBillingPage(movie: movie),
                ),
              ).then((result) {
                if (result == true) {
                  _refreshAfterPurchase();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAfterPurchase() async {
    final user = await LocalSharePreferences().getUser();
    if (!mounted || user == null) return;

    final userProvider = context.read<UserProvider>();
    final dashboardProvider = context.read<DashboardProvider>();

    final type = (widget.movie.type ?? "MOVIE").toUpperCase();
    final languages = userProvider.userObject.selectedLanguages ?? [];
    final langList = languages.isEmpty ? ["English"] : languages;

    await dashboardProvider.getDashboardData(type, langList, user.id!);
  }

  Widget _optionButton(BuildContext context, Content movie) {
    final theme = Theme.of(context);
    final bool isSeries = movie.type?.toLowerCase() == "series";

    final bookmarkProvider = context.watch<BookmarkProvider>();
    final bool isBookmarked =
        bookmarkProvider.isBookmarkedLocally(movie.id ?? 0);

    final ValueNotifier<bool> isDialOpen = ValueNotifier(false);
    final TextEditingController countController = TextEditingController();

    return Positioned(
      top: 12,
      right: 12,
      child: SpeedDial(
        openCloseDial: isDialOpen,
        onPress: () => isDialOpen.value = !isDialOpen.value,
        icon: Icons.more_vert,
        activeIcon: Icons.close,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        overlayColor: Colors.black,
        overlayOpacity: 0.3,
        elevation: 2,
        direction: SpeedDialDirection.down,
        buttonSize: const Size(30, 30),
        childrenButtonSize: const Size(30, 35),
        spacing: 2,
        children: [
          movie.isRental!
              ? SpeedDialChild()
              : SpeedDialChild(
                  label: isBookmarked ? "Remove Bookmark" : "Bookmark",
                  labelBackgroundColor: theme.cardColor,
                  labelStyle: TextStyle(
                    color: theme.canvasColor,
                    fontSize: 10,
                  ),
                  child: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 14,
                    color: Colors.white,
                  ),
                  backgroundColor: theme.primaryColor,
                  onTap: () async {
                    final bool wasBookmarked =
                        bookmarkProvider.isBookmarkedLocally(movie.id ?? 0);

                    await bookmarkProvider.toggleBookmark(movie);

                    CustomToast.show(
                      context,
                      wasBookmarked
                          ? "${movie.title} removed from bookmarks"
                          : "${movie.title} added to bookmarks",
                      isSuccess: true,
                    );

                    isDialOpen.value = false;
                  },
                ),

          /// 🔗 Share
          SpeedDialChild(
            label: "Share",
            labelBackgroundColor: theme.cardColor,
            labelStyle: TextStyle(
              color: theme.canvasColor,
              fontSize: 10,
            ),
            child: const Icon(Icons.share, size: 14, color: Colors.white),
            backgroundColor: theme.primaryColor,
            onTap: () {
              isDialOpen.value = false;
              _shareMovie(context, movie);
            },
          ),

          /// 🎁 Gift (movies only)
          if (!isSeries)
            SpeedDialChild(
              label: "Gift",
              labelBackgroundColor: theme.cardColor,
              labelStyle: TextStyle(
                color: theme.canvasColor,
                fontSize: 10,
              ),
              child:
                  const Icon(LucideIcons.gift, size: 14, color: Colors.white),
              backgroundColor: theme.primaryColor,
              onTap: () {
                isDialOpen.value = false;
                _showGiftDialog(context, movie, countController);
              },
            ),
        ],
      ),
    );
  }

  void _shareMovie(BuildContext context, Content movie) async {
    if (movie.id == null || movie.id! <= 0) {
      CustomToast.show(
        context,
        "Content details are not available yet",
        isSuccess: false,
      );
      return;
    }

    final normalized = ContentType.normalize(movie.type);
    final contentType = normalized == ContentType.shortFilm
        ? DeepLinkContentType.shortFilm
        : normalized == ContentType.series
            ? DeepLinkContentType.series
            : normalized == ContentType.miniSeries
                ? DeepLinkContentType.miniSeries
                : DeepLinkContentType.movie;

    showContentShareSheet(
      context,
      movie,
      contentType: contentType,
    );
  }

  void _showGiftDialog(
    BuildContext context,
    Content movie,
    TextEditingController countController,
  ) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          insetPadding: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: ResponsiveWidget.isMobile(context) ? double.infinity : 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.gift,
                          color: theme.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        "Gift Movie",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "How many people do you want to gift this movie to?",
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.canvasColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    controller: countController,
                    hintText: "Recipients",
                    isDigits: true,
                    textInputType: TextInputType.number,
                    backgroundColor: theme.scaffoldBackgroundColor,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          final count =
                              int.tryParse(countController.text.trim());
                          if (count == null || count <= 0) {
                            CustomToast.show(
                              context,
                              'Enter a valid number',
                              isSuccess: false,
                            );
                            return;
                          }

                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MovieBillingPage(
                                movie: movie,
                                giftCount: count,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          "Continue",
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
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
  }
}
