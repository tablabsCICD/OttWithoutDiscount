import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ott/app/core/network/anti_piracy_api_client.dart';
import 'package:ott/app/core/services/DeepLinkService.dart';
import 'package:ott/app/core/services/invoice_service.dart';
import 'package:ott/app/core/services/session_manager.dart';
import 'package:ott/app/core/utils/security_debug_log.dart';
import 'package:ott/app/core/utils/sharepreferences.dart';
import 'package:ott/app/pages/wallet%20page/WalletPage.dart';
import 'package:ott/app/provider/secure_playback_controller.dart';
import 'package:ott/app/provider/shorts_provider.dart';
import 'package:ott/app/provider/wallet_provider.dart';
import 'package:ott/app/widgets/content_share_sheet.dart';
import 'package:ott/app/widgets/playback_watermark_overlay.dart';
import 'package:ott/app/widgets/shimmer%20loader/shimmer_loader.dart';
import 'package:ott/app/widgets/video_skip_controls.dart';
import 'package:ott/data/models/anti_piracy_models.dart';
import 'package:ott/data/models/shorts.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

String _resolveShortPlaybackCountryCode() {
  final countryCode =
      WidgetsBinding.instance.platformDispatcher.locale.countryCode;
  final normalized = countryCode?.trim().toUpperCase();
  if (normalized != null && RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) {
    return normalized;
  }
  return 'IN';
}

class ShortsPlayerPage extends StatefulWidget {
  final ShortDetailModel short;
  const ShortsPlayerPage({super.key, required this.short});

  @override
  State<ShortsPlayerPage> createState() => _ShortsPlayerPageState();
}

class _ShortsPlayerPageState extends State<ShortsPlayerPage>
    with WidgetsBindingObserver {
  Player? _controller;
  VideoController? _videoController;
  SecurePlaybackController? _securePlaybackController;
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];
  final PageController _pageController = PageController();

  List<ShortPart> _parts = [];
  int _currentIndex = 0;

  bool _isLoadingPart = false;
  bool _isMetaExpanded = false;
  bool _hasVideoError = false;
  String? _videoErrorMessage;
  bool _handlingSecureAuthenticationFailure = false;

  int get totalParts => _parts.length;
  int? _parsePartId(ShortPart part) => int.tryParse(part.partId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final user = await LocalSharePreferences.localSharePreferences.getUser();
    if (!mounted) return;

    await context
        .read<ShortProvider>()
        .fetchShortDetail(widget.short.id, user?.id ?? 1);

    final detail = context.read<ShortProvider>().shortDetail;
    if (detail == null || detail.parts.isEmpty) return;

    setState(() {
      _parts = List.from(detail.parts);
    });

    await _loadPart(0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final secureController = _securePlaybackController;
    if (secureController != null) {
      secureController.removeListener(_onSecurePlaybackChanged);
      unawaited(secureController.stop());
      secureController.dispose();
    }
    for (final subscription in _playerSubscriptions) {
      unawaited(subscription.cancel());
    }
    _playerSubscriptions.clear();
    _controller?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_controller?.pause());
    }
  }

  Future<void> _refreshFromBackend() async {
    final user = await LocalSharePreferences.localSharePreferences.getUser();

    await context
        .read<ShortProvider>()
        .fetchShortDetail(widget.short.id, user?.id ?? 1);

    if (!mounted) return;

    final detail = context.read<ShortProvider>().shortDetail;
    if (detail == null) return;

    setState(() {
      _parts = List.from(detail.parts);
    });
  }

  Future<void> _handleShortPurchaseInvoice(ShortPart part) async {
    final user = await LocalSharePreferences.localSharePreferences.getUser();
    if (!mounted || user == null) return;

    try {
      final invoice = await InvoiceService.instance.generatePurchaseInvoice(
        PurchaseInvoiceData(
          user: user,
          contentTitle: widget.short.title,
          contentType: 'MINI SERIES',
          amount: part.coins.toDouble(),
          purchaseDate: DateTime.now(),
          itemTitle: part.title,
          itemSubtitle: 'Part ${part.partNumber}',
          rentalDuration: "3", //widget.short.rentlDuration,
        ),
      );

      if (!mounted) return;
      await InvoiceService.instance.showShareOptions(context, invoice);
    } catch (error) {
      if (!mounted) return;

    }
  }

  Future<void> _loadPart(int index) async {
    if (_isLoadingPart || index < 0 || index >= _parts.length) return;
    _isLoadingPart = true;

    try {
      if (mounted) {
        setState(() {
          _hasVideoError = false;
          _videoErrorMessage = null;
        });
      }

      final part = _parts[index];

      final oldSecureController = _securePlaybackController;
      _securePlaybackController = null;
      if (oldSecureController != null) {
        oldSecureController.removeListener(_onSecurePlaybackChanged);
        await oldSecureController.stop();
        oldSecureController.dispose();
      }
      final old = _controller;
      _controller = null;
      _videoController = null;
      for (final subscription in _playerSubscriptions) {
        await subscription.cancel();
      }
      _playerSubscriptions.clear();
      await old?.pause();
      await old?.dispose();

      if (!part.isFreePreview && !part.isPurchased) {
        final partId = _parsePartId(part);
        if (partId == null) {
          if (mounted) {
            setState(() {
              _hasVideoError = true;
              _videoErrorMessage = "Invalid video";
            });
          }
          return;
        }

        final wallet = context.read<WalletProvider>();
        await wallet.getBalance();

        if (wallet.walletBalance < part.coins) {
          await _showInsufficientBalanceDialog();
          return;
        }

        final purchaseResult = await context
            .read<ShortProvider>()
            .purchaseShortPart(partId: partId);

        /*  if (purchaseResult != null &&
            purchaseResult['alreadyPurchased'] != true) {
          await _handleShortPurchaseInvoice(part);
        } */

        await _refreshFromBackend();
      }

      final updated = _parts[index];
      if (!updated.isFreePreview && !updated.isPurchased) return;

      if (updated.videoUrl.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _hasVideoError = true;
            _videoErrorMessage = "Video unavailable";
          });
        }
        return;
      }

      final secureController = SecurePlaybackController(
          contentId: updated.partId,
          originalPlaybackUrl: updated.videoUrl,
          country: _resolveShortPlaybackCountryCode(),
          mediaLoader: _loadSecureMedia,
          pausePlayer: () async => _controller?.pause(),
          type: "SHORT_PART");
      _securePlaybackController = secureController;
      secureController.addListener(_onSecurePlaybackChanged);
      await secureController.start();

      if (!mounted ||
          secureController.state == SecurePlaybackState.accessDenied ||
          secureController.state == SecurePlaybackState.playbackError) {
        return;
      }

      final updatedPartId = _parsePartId(updated);
      if (updatedPartId != null) {
        await context.read<ShortProvider>().addShortView(partId: updatedPartId);
      }

      await _refreshFromBackend();

      setState(() {
        _currentIndex = index;
        _hasVideoError = false;
        _videoErrorMessage = null;
      });
    } finally {
      _isLoadingPart = false;
    }
  }

  void _onSecurePlaybackChanged() {
    if (!mounted) return;
    final controller = _securePlaybackController;
    if (controller == null) return;
    if (controller.failure == SecurePlaybackFailure.unauthenticated &&
        !_handlingSecureAuthenticationFailure) {
      _handlingSecureAuthenticationFailure = true;
      unawaited(SessionManager.instance.handleSessionExpired(
        'Your session has expired. Please sign in again.',
      ));
    }
    setState(() {
      _hasVideoError = controller.state == SecurePlaybackState.accessDenied ||
          controller.state == SecurePlaybackState.playbackError;
      _videoErrorMessage = controller.errorMessage;
    });
  }

  Future<SecureMediaRestoreResult> _loadSecureMedia(
    SignedPlaybackResponse authorization, {
    required bool isRefresh,
  }) async {
    final previousState = _controller?.state;
    final position = previousState?.position ?? Duration.zero;
    final wasPlaying = previousState?.playing ?? true;
    final volume = previousState?.volume ?? 100;
    final rate = previousState?.rate ?? 1;

    if (authorization.audioTracks.length > 1 ||
        authorization.subtitleTracks.length > 1) {
      SecurityDebugLog.event(
        'PLAYER',
        'Multiple supported external tracks were returned for the selected part; only one automatic track will be attached.',
      );
    }

    final old = _controller;
    _controller = null;
    _videoController = null;
    for (final subscription in _playerSubscriptions) {
      await subscription.cancel();
    }
    _playerSubscriptions.clear();
    await old?.pause();
    await old?.dispose();

    final player = Player();
    final videoController = VideoController(player);
    _playerSubscriptions
      ..add(player.stream.position.listen((_) {
        if (mounted) setState(() {});
      }))
      ..add(player.stream.duration.listen((_) {
        if (mounted) setState(() {});
      }))
      ..add(player.stream.playing.listen((isPlaying) {
        _securePlaybackController?.onPlayingChanged(isPlaying);
        if (mounted) setState(() {});
      }))
      ..add(player.stream.error.listen((error) {

        if (mounted) {
          setState(() {
            _hasVideoError = true;
            _videoErrorMessage = 'Failed to load video';
          });
        }
      }));

    try {
      await player.open(
        Media(
          authorization.urlToPlay,
          httpHeaders: authorization.httpHeaders,
        ),
        play: true,
      );
      final automaticAudio = getAutomaticAudioTrack(authorization.audioTracks);
      if (automaticAudio != null) {
        try {
          await player.setAudioTrack(
            AudioTrack.uri(
              automaticAudio.url,
              title: automaticAudio.label,
              language: automaticAudio.language,
            ),
          );
        } catch (_) {
          SecurityDebugLog.event(
            'PLAYER',
            'Automatic external part audio is unsupported; using manifest audio.',
          );
        }
      }
      final automaticSubtitle =
          getAutomaticSubtitleTrack(authorization.subtitleTracks);
      if (automaticSubtitle != null) {
        try {
          await player.setSubtitleTrack(
            SubtitleTrack.uri(
              automaticSubtitle.url,
              title: automaticSubtitle.label,
              language: automaticSubtitle.language,
            ),
          );
        } catch (_) {
          SecurityDebugLog.event(
            'PLAYER',
            'Automatic external part subtitle is unsupported; continuing playback.',
          );
        }
      }
      await player.setVolume(volume);
      if (isRefresh) {
        if (position > Duration.zero) await player.seek(position);
        await player.setRate(rate);
        if (!wasPlaying) await player.pause();
      }
    } catch (_) {
      await player.dispose();
      rethrow;
    }

    if (!mounted) {
      await player.dispose();
      throw StateError('Mini Series player was disposed');
    }
    setState(() {
      _controller = player;
      _videoController = videoController;
      _hasVideoError = false;
      _videoErrorMessage = null;
    });
    return SecureMediaRestoreResult(isPlaying: player.state.playing);
  }

  Future<void> _changePage(int index) async {
    if (_isMetaExpanded) {
      setState(() {
        _isMetaExpanded = false;
      });
    }
    await _loadPart(index);
  }

  Future<void> _showInsufficientBalanceDialog() async {
    final theme = Theme.of(context);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Insufficient Balance",
            style: TextStyle(
                color: theme.primaryColor, fontWeight: FontWeight.bold)),
        content: Text("You don't have enough coins.",
            style: TextStyle(color: theme.canvasColor)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text("Cancel", style: TextStyle(color: theme.canvasColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => WalletPage()));
            },
            child: const Text("Recharge"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balanceProvider = Provider.of<WalletProvider>(context);
    balanceProvider.getBalance();
    final orientation = MediaQuery.of(context).orientation;
    final shortsScrollDirection =
        orientation == Orientation.landscape ? Axis.horizontal : Axis.vertical;
    final isLandscape = orientation == Orientation.landscape;
    final useFullWidthPlayer =
        isLandscape || ResponsiveWidget.isMobile(context);
    final watermark = _securePlaybackController?.watermark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SizedBox(
          width: useFullWidthPlayer ? double.infinity : 450,
          child: Stack(
            children: [
              _videoBackground(),
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _togglePlayPause,
                onDoubleTap: _handleDoubleTapLike,
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: shortsScrollDirection,
                  itemCount: totalParts,
                  onPageChanged: _changePage,
                  itemBuilder: (_, i) => _overlay(i),
                ),
              ),
              if (watermark != null)
                PlaybackWatermarkOverlay(watermark: watermark),
              _backButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoBackground() {
    final controller = _controller;
    final videoController = _videoController;
    if (_hasVideoError) {
      return Positioned.fill(
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_disabled, color: Colors.white70, size: 32),
              const SizedBox(height: 8),
              Text(
                _videoErrorMessage ?? "Video unavailable",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    if (controller == null || videoController == null) {
      return const ShimmerLoader(
        height: double.infinity,
        width: double.infinity,
      );
    }

    final videoFit = MediaQuery.of(context).orientation == Orientation.landscape
        ? BoxFit.contain
        : BoxFit.cover;

    return Positioned.fill(
      child: Video(
        controller: videoController,
        fit: videoFit,
        controls: null,
      ),
    );
  }

  Widget _overlay(int index) {
    final part = _parts[index];
    final theme = Theme.of(context);
    final titleText = part.title.trim().isNotEmpty
        ? part.title.trim()
        : widget.short.title.trim();
    final descriptionText = widget.short.description.trim();
    final hasDescription = descriptionText.isNotEmpty;
    final showSeeMore =
        !_isMetaExpanded && (titleText.length > 36 || hasDescription);
    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: VideoSkipControls(
              onBackward: () => _seekBy(const Duration(seconds: -10)),
              onForward: () => _seekBy(const Duration(seconds: 10)),
              gap: 78,
              compact: true,
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 80,
          right: 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 1),
                      color: Colors.white10,
                    ),
                    child: ClipRRect(
                        borderRadius: BorderRadiusGeometry.circular(100),
                        child: Image.network(
                          part.thumbnail,
                          fit: BoxFit.cover,
                        )),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Text(
                    widget.short.creatorName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(
                          offset: Offset(2, 2), // x, y
                          blurRadius: 4,
                          color: Colors.black.withOpacity(0.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isMetaExpanded = !_isMetaExpanded;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        maxLines: _isMetaExpanded ? 3 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              offset: Offset(2, 2), // x, y
                              blurRadius: 4,
                              color: Colors.black.withOpacity(0.2),
                            ),
                          ],
                        ),
                      ),
                      if (_isMetaExpanded && hasDescription) ...[
                        const SizedBox(height: 3),
                        Text(
                          descriptionText,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            height: 1.35,
                            shadows: [
                              Shadow(
                                offset: Offset(2, 2), // x, y
                                blurRadius: 4,
                                color: Colors.black.withOpacity(0.2),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (showSeeMore) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "See more",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(
                                    offset: Offset(2, 2), // x, y
                                    blurRadius: 4,
                                    color: Colors.black.withOpacity(0.2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.expand_more,
                              size: 12,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  offset: Offset(2, 2), // x, y
                                  blurRadius: 4,
                                  color: Colors.black.withOpacity(0.2),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                      if (_isMetaExpanded) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "See less",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(
                                    offset: Offset(2, 2), // x, y
                                    blurRadius: 4,
                                    color: Colors.black.withOpacity(0.2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.expand_more,
                              size: 12,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  offset: Offset(2, 2), // x, y
                                  blurRadius: 4,
                                  color: Colors.black.withOpacity(0.2),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _rightButtons(index),
        _bottomEpisodeBar(),
        if (_controller != null)
          _controller!.state.playing
              ? SizedBox()
              : Center(
                  child: Icon(
                    Icons.play_arrow_sharp,
                    color: Colors.white60,
                    size: 50,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2), // x, y
                        blurRadius: 4,
                        color: Colors.black.withOpacity(0.3),
                      ),
                    ],
                  ),
                ),
      ],
    );
  }

  Widget _rightButtons(int index) {
    final part = _parts[index];
    final provider = context.watch<ShortProvider>();

    return Positioned(
      right: 12,
      bottom: 120,
      child: Column(
        children: [
          _actionBtn(
            part.isLiked ? Icons.favorite : Icons.favorite_border,
            "${part.likes}",
            provider.isLiking
                ? null
                : () async {
                    final partId = _parsePartId(part);
                    if (partId == null) return;
                    final ok = part.isLiked
                        ? await context
                            .read<ShortProvider>()
                            .unlikeShortPart(partId: partId)
                        : await context
                            .read<ShortProvider>()
                            .likeShortPart(partId: partId);

                    if (ok) await _refreshFromBackend();
                  },
            isActive: part.isLiked,
          ),
          const SizedBox(height: 18),
          _actionBtn(Icons.telegram_outlined, "share", () {
            _shareShortContent(context);
          }),
          //const SizedBox(height: 18),
          // _actionBtn(Icons.visibility_outlined, "${part.views}", null),
        ],
      ),
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool isActive = false,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Colors.black12),
            child: Icon(icon,
                size: 26, color: isActive ? theme.primaryColor : Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              shadows: [
                Shadow(
                  offset: Offset(2, 2), // x, y
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareShortContent(BuildContext context) {
    return showContentShareSheet(
      context,
      widget.short.toShareContent(),
      contentType: DeepLinkContentType.short,
      unavailableMessage: "Mini series details are not available yet",
    );
  }

  void _shareShort(BuildContext context, ShortPart short) async {
    final String shareText = '''
🎬 ${short.title ?? ''}

${short.durationSec ?? ''}

▶️ Watch here:
** filmytell navigation link **

📲 Download Filmytell App now!
'''
        .trim();

    if (kIsWeb) {
      // Flutter Web fallback → Copy to Clipboard
      await Clipboard.setData(ClipboardData(text: shareText));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Share text copied to clipboard"),
        ),
      );
    } else {
      // Android / iOS / Desktop
      await Share.share(
        shareText,
        subject: short.title ?? "Movie",
      );
    }
  }

  Widget _bottomEpisodeBar() {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 24,
      child: Column(
        children: [
          InkWell(
            onTap: _openEpisodes,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
              decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                  boxShadow: [
                    BoxShadow(color: Colors.black12),
                  ]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Episode ${_currentIndex + 1} / $totalParts",
                    style: TextStyle(
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
                  Icon(
                    Icons.expand_less,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2), // x, y
                        blurRadius: 4,
                        color: Colors.black.withOpacity(0.3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _videoProgressBar(),
        ],
      ),
    );
  }

  Widget _videoProgressBar() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    final duration = controller.state.duration.inMilliseconds;
    if (duration <= 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          ),
          child: Slider(
            min: 0,
            max: duration.toDouble(),
            value: controller.state.position.inMilliseconds
                .clamp(0, duration)
                .toDouble(),
            activeColor: theme.primaryColor,
            inactiveColor: Colors.white24,
            onChanged: (value) {
              controller.seek(Duration(milliseconds: value.round()));
            },
          ),
        ),
      ),
    );
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null) return;
    controller.state.playing ? controller.pause() : controller.play();
  }

  void _seekBy(Duration offset) {
    final controller = _controller;
    if (controller == null) return;
    unawaited(
      controller.seek(
        boundedSeekPosition(
          position: controller.state.position,
          duration: controller.state.duration,
          offset: offset,
        ),
      ),
    );
  }

  Future<void> _handleDoubleTapLike() async {
    final controller = _controller;
    if (controller == null || _parts.isEmpty) {
      return;
    }

    if (_currentIndex < 0 || _currentIndex >= _parts.length) return;
    final part = _parts[_currentIndex];
    final partId = _parsePartId(part);
    if (partId == null) return;
    final provider = context.read<ShortProvider>();
    if (provider.isLiking || part.isLiked) return;

    HapticFeedback.lightImpact();
    final ok = await provider.likeShortPart(partId: partId);

    if (ok) await _refreshFromBackend();
  }

  void _openEpisodes() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: GridView.builder(
            itemCount: totalParts,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (_, i) {
              final part = _parts[i];
              final active = i == _currentIndex;

              return GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  _pageController.jumpToPage(i);
                  await _loadPart(i);
                },
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: active ? theme.primaryColor : theme.cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: theme.canvasColor.withOpacity(.7)),
                      ),
                      child: Center(
                        child: Text(
                          "EP ${part.partNumber}",
                          style: TextStyle(
                            color: active ? Colors.white : theme.canvasColor,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(2, 2), // x, y
                                blurRadius: 4,
                                color: Colors.black.withOpacity(0.2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!part.isPurchased && !part.isFreePreview)
                      const Positioned(
                          right: 4, top: 4, child: Icon(Icons.lock, size: 14)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _backButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 12,
      child: InkWell(
        onTap: () {
          _controller?.pause();
          Navigator.pop(context);
        },
        child: const CircleAvatar(
          radius: 18,
          backgroundColor: Colors.black45,
          child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
