import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:http/http.dart' as http;
import 'package:ott/app/core/network/anti_piracy_api_client.dart';
import 'package:ott/app/core/services/anti_piracy_service.dart';
import 'package:ott/app/core/services/web_offline_media_store.dart';
import 'package:ott/app/core/utils/security_debug_log.dart';
import 'package:ott/app/core/services/session_manager.dart';
import 'package:ott/app/provider/secure_playback_controller.dart';
import 'package:ott/data/models/anti_piracy_models.dart';
import 'package:ott/data/models/seriesModel.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart' as native_video;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart' as youtube;

import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/widgets/playback_watermark_overlay.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:ott/app/widgets/video_skip_controls.dart';
import 'package:ott/app/core/utils/content_type.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import '../../../provider/offline_download_provider.dart';
import '../../../provider/playMediaProvider.dart';

String? _extractYoutubeId(String urlOrId) {
  final value = urlOrId.trim();
  if (value.isEmpty) return null;

  final converted = youtube.YoutubePlayer.convertUrlToId(value);
  if (converted != null && converted.isNotEmpty) return converted;

  final looksLikeVideoId = RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(value);
  return looksLikeVideoId ? value : null;
}

String _resolvePlaybackCountryCode() {
  final countryCode =
      WidgetsBinding.instance.platformDispatcher.locale.countryCode;
  final normalized = countryCode?.trim().toUpperCase();
  if (normalized != null && RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) {
    return normalized;
  }
  return 'IN';
}

class PlayMediaPage extends StatefulWidget {
  final Content? content;
  final int? seasonIndex;
  final int? episodeIndex;
  final List<SeasonEntity>? seasons;
  final String videoUrl;

  const PlayMediaPage({
    super.key,
    required this.videoUrl,
    this.content,
    this.seasonIndex,
    this.episodeIndex,
    this.seasons,
  });

  @override
  State<PlayMediaPage> createState() => _PlayMediaPageState();
}

class _PlayMediaPageState extends State<PlayMediaPage>
    with WidgetsBindingObserver {
  static int _nextPlayerId = 0;

  Player? _player;
  native_video.VideoPlayerController? _androidSecurePlayer;
  int? _activePlayerId;
  VideoController? _videoController;
  youtube.YoutubePlayerController? _youtubeController;
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];
  Timer? _progressTimer;
  Timer? _controlsHideTimer;

  bool _loading = true;
  bool _hasPlaybackError = false;
  bool _handlingEnd = false;
  Duration _lastSavedPosition = Duration.zero;
  bool _wakelockEnabled = false;
  bool _firstFrameRendered = false;
  bool _isDisposed = false;
  bool _isExiting = false;
  int _setupToken = 0;
  bool _isOfflinePlayback = false;
  String? _playbackMessage;
  String? _currentRemotePlaybackUrl;
  String? _currentAuthorizedPlaybackUrl;
  Map<String, String> _currentAuthorizedHttpHeaders = const {};
  SecurePlaybackController? _securePlaybackController;
  bool _handlingSecureAuthenticationFailure = false;
  bool _controlsVisible = true;
  bool _isSeeking = false;
  bool _resumeAfterLifecyclePause = false;
  int? _currentSeasonId;
  int? _currentEpisodeId;
  String? _offlineObjectUrl;
  Duration? _lastLoggedDuration;
  double _currentPlaybackSpeed = 1.0;
  bool _showResumeBanner = false;
  String? _resumedTimeText;
  Timer? _resumeBannerTimer;
  bool _showForwardIndicator = false;
  bool _showBackwardIndicator = false;
  Timer? _seekIndicatorTimer;
  bool _isMicMuted = false;

  void _changePlaybackSpeed(double speed) {
    if (!mounted || _isDisposed) return;
    setState(() {
      _currentPlaybackSpeed = speed;
    });

    final player = _player;
    if (player != null) {
      unawaited(player.setRate(speed));
    }
    final androidPlayer = _androidSecurePlayer;
    if (androidPlayer != null) {
      unawaited(androidPlayer.setPlaybackSpeed(speed));
    }
    final youtubeController = _youtubeController;
    if (youtubeController != null) {
      youtubeController.setPlaybackRate(speed);
    }
  }

  void _triggerResumeBanner(int seconds) {
    if (seconds <= 10) return;
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final formatted = duration.inHours > 0
        ? '${duration.inHours}:$minutes:$secs'
        : '$minutes:$secs';
    _resumeBannerTimer?.cancel();
    if (mounted) {
      setState(() {
        _resumedTimeText = formatted;
        _showResumeBanner = true;
      });
    }
    _resumeBannerTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showResumeBanner = false);
    });
  }

  bool get _isSeries =>
      (_currentEpisodeId != null && _currentEpisodeId! > 0) ||
      (widget.episodeIndex != null && widget.episodeIndex! > 0) ||
      ContentType.isSeries(widget.content?.type) ||
      ContentType.normalize(widget.content?.type) == ContentType.miniSeries ||
      ContentType.normalize(widget.content?.type) == 'MINI_SERIES';

  @override
  void initState() {
    super.initState();
    _currentSeasonId = widget.seasonIndex;
    _currentEpisodeId = widget.episodeIndex;
    SecurityDebugLog.event(
      'ROUTE',
      'PlayMediaPage.initState reached from the Watch Movie route.',
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(AntiPiracyService.instance.enableScreenProtection());
    unawaited(_startFullscreenPlayback());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _resumeAfterLifecyclePause = _loading ||
          (_player?.state.playing ?? false) ||
          (_androidSecurePlayer?.value.isPlaying ?? false) ||
          (_youtubeController?.value.isPlaying ?? false);
      unawaited(_player?.pause());
      unawaited(_androidSecurePlayer?.pause());
      _youtubeController?.pause();
      unawaited(_securePlaybackController?.onBackground());
      _saveProgress();
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_securePlaybackController?.onForeground());
      if (_resumeAfterLifecyclePause) {
        _resumeAfterLifecyclePause = false;
        unawaited(_resumeAfterLifecycleInterruption());
      }
    }
  }

  Future<void> _resumeAfterLifecycleInterruption() async {
    if (_isDisposed || !mounted || _hasPlaybackError) return;
    try {
      if (_youtubeController != null) {
        _youtubeController!.play();
      } else if (_androidSecurePlayer != null) {
        await _androidSecurePlayer!.play();
      } else {
        await _player?.play();
      }
    } catch (error, stackTrace) {
      if (_isBenignPlayInterruption(error)) return;
      SecurityDebugLog.exception(
        'LIFECYCLE_RESUME_PLAYBACK',
        error,
        stackTrace,
      );
      _showPlaybackError('Failed to resume video');
    }
  }

  Future<void> _enterLandscapePlayback() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _restorePortraitPlayback() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    await AntiPiracyService.instance.disableScreenProtection();
  }

  Future<void> _startFullscreenPlayback() async {
    SecurityDebugLog.event(
      'FLOW',
      'Fullscreen player startup began.',
    );
    try {
      await _enterLandscapePlayback();
      SecurityDebugLog.event(
        'PLAYER',
        'Landscape fullscreen mode was enabled.',
      );
    } catch (_) {
      SecurityDebugLog.event(
        'PLAYER',
        'Fullscreen/orientation setup is unavailable; continuing secure playback.',
      );
    }
    if (!mounted || _isDisposed) return;

    SecurityDebugLog.event(
      'FLOW',
      'Calling secure playback preparation.',
    );
    await _preparePlayback();
    if (!mounted || _isDisposed) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _addView();
      }
    });
  }

  void _addView() {
    final contentId = widget.content?.id;
    if (contentId == null || _isOfflinePlayback) return;

    final activeEpisodeId = _currentEpisodeId ?? widget.episodeIndex;
    context.read<PlayMediaProvider>().addView(
          mediaId: _isSeries && activeEpisodeId != null && activeEpisodeId > 0
              ? activeEpisodeId
              : contentId,
          isSeries: _isSeries,
        );
  }

  Future<void> _preparePlayback() async {
    SecurityDebugLog.event(
      'FLOW',
      'Resolving the media source before requesting signed access.',
    );
    String sourceUrl = await _resolveOfflineSourceUrl(widget.videoUrl.trim());
    if (sourceUrl.isEmpty) {
      SecurityDebugLog.event(
        'FLOW',
        'Secure playback stopped because the media source is empty.',
      );
      _showPlaybackError('Video unavailable');
      return;
    }

    final youtubeId = _extractYoutubeId(sourceUrl);

    if (youtubeId != null && youtubeId.isNotEmpty) {
      SecurityDebugLog.event(
        'FLOW',
        'External YouTube source identified; using the existing YouTube player path.',
      );
      await _setupYoutubePlayer(youtubeId);
      return;
    }

    if (_isOfflinePlayback) {
      SecurityDebugLog.event(
        'FLOW',
        'Signed API was not called because an existing offline file was selected.',
      );
      // Existing downloaded files are local media and do not have a CloudFront
      // URL to sign. Online protected content always follows the secure flow.
      await _setupPlayer(sourceUrl, playFromFile: true);
      return;
    }

    final isEpisode = _isSeries &&
        ((_currentEpisodeId != null && _currentEpisodeId! > 0) ||
            (widget.episodeIndex != null && widget.episodeIndex! > 0));
    final contentId = isEpisode
        ? ((_currentEpisodeId != null && _currentEpisodeId! > 0)
            ? _currentEpisodeId
            : widget.episodeIndex)
        : widget.content?.id;
    if (contentId == null) {
      SecurityDebugLog.event(
        'FLOW',
        'Signed API was not called because the content ID is missing.',
      );
      _showPlaybackError('The requested content was not found.');
      return;
    }
    SecurityDebugLog.event(
      'FLOW',
      'Online protected content identified; starting the anti-piracy API flow.',
    );
    await _startSecurePlayback(
      sourceUrl: sourceUrl,
      contentId: contentId.toString(),
    );
  }

  Future<String> _resolveOfflineSourceUrl(String sourceUrl) async {
    final content = widget.content;
    if (content == null) {
      _isOfflinePlayback = false;
      return sourceUrl;
    }

    if (!mounted) return sourceUrl;
    final offlinePath =
        await context.read<OfflineDownloadProvider>().getOfflinePath(content);
    if (offlinePath != null &&
        offlinePath.trim().isNotEmpty &&
        (kIsWeb || await _isExistingLocalFile(offlinePath))) {
      _isOfflinePlayback = true;
      if (kIsWeb) _offlineObjectUrl = offlinePath.trim();
      return offlinePath.trim();
    }

    _isOfflinePlayback = false;
    return sourceUrl;
  }

  Future<bool> _isExistingLocalFile(String value) async {
    if (kIsWeb || value.trim().isEmpty) return false;

    final fileUri = Uri.tryParse(value);
    final path = fileUri?.scheme == 'file' ? fileUri!.toFilePath() : value;

    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }

  Future<void> _startSecurePlayback({
    required String sourceUrl,
    required String contentId,
  }) async {
    SecurityDebugLog.event(
      'PLAYER',
      'Protected player route is calling SecurePlaybackController.start().',
    );
    final previous = _securePlaybackController;
    if (previous != null) {
      previous.removeListener(_onSecurePlaybackChanged);
      await previous.stop();
      previous.dispose();
    }
    _currentRemotePlaybackUrl = sourceUrl;
    final isEpisode = _isSeries &&
        ((_currentEpisodeId != null && _currentEpisodeId! > 0) ||
            (widget.episodeIndex != null && widget.episodeIndex! > 0));
    final resolvedType = isEpisode
        ? "EPISODE"
        : (ContentType.normalize(widget.content?.type).isNotEmpty
            ? ContentType.normalize(widget.content?.type)
            : "MOVIE");
    final controller = SecurePlaybackController(
        contentId: contentId,
        originalPlaybackUrl: sourceUrl,
        country: _resolvePlaybackCountryCode(),
        mediaLoader: _loadSecureMedia,
        pausePlayer: _pauseActivePlayer,
        type: resolvedType);
    _securePlaybackController = controller;
    controller.addListener(_onSecurePlaybackChanged);
    await controller.start();
  }

  void _onSecurePlaybackChanged() {
    if (!mounted || _isDisposed) return;
    final controller = _securePlaybackController;
    if (controller == null) return;
    if (controller.failure == SecurePlaybackFailure.unauthenticated &&
        !_handlingSecureAuthenticationFailure) {
      _handlingSecureAuthenticationFailure = true;
      unawaited(
        SessionManager.instance.handleSessionExpired(
            'Your session has expired. Please sign in again.'),
      );
    }
    setState(() {
      _playbackMessage = controller.errorMessage;
      _hasPlaybackError =
          controller.state == SecurePlaybackState.accessDenied ||
              controller.state == SecurePlaybackState.playbackError;
    });
  }

  Future<SecureMediaRestoreResult> _loadSecureMedia(
    SignedPlaybackResponse authorization, {
    required bool isRefresh,
  }) async {
    SecurityDebugLog.event(
      'PLAYER',
      isRefresh
          ? 'Received refreshed playback authorization; reinitializing the player.'
          : 'Received platform playback authorization; initializing the player now.',
    );
    final effectivePlaybackUrl = authorization.urlToPlay;
    final playbackUri = Uri.tryParse(effectivePlaybackUrl);
    _currentAuthorizedPlaybackUrl = effectivePlaybackUrl;
    _currentAuthorizedHttpHeaders = authorization.httpHeaders;
    SecurityDebugLog.diagnostic(
      'SIGNED_MEDIA_METADATA validUri=${playbackUri != null} '
      'scheme=${playbackUri?.scheme ?? '<missing>'} '
      'host=${playbackUri?.host ?? '<missing>'} '
      'authorizationType=${authorization.authorizationType} '
      'cookieHeaderPresent=${authorization.httpHeaders.containsKey('Cookie')} '
      'credentialValuesRedacted=true',
    );
    final previous = _player?.state;
    final androidPrevious = _androidSecurePlayer?.value;
    final position =
        androidPrevious?.position ?? previous?.position ?? Duration.zero;
    final wasPlaying = androidPrevious?.isPlaying ?? previous?.playing ?? true;
    final volume = androidPrevious == null
        ? previous?.volume ?? 100
        : androidPrevious.volume * 100;
    final rate = androidPrevious?.playbackSpeed ?? previous?.rate ?? 1;
    final audioTrack = previous?.track.audio;
    final subtitleTrack = previous?.track.subtitle;

    if (authorization.audioTracks.length > 1 ||
        authorization.subtitleTracks.length > 1) {
      SecurityDebugLog.event(
        'PLAYER',
        'Multiple supported external tracks were returned; only the selected content default or first track will be attached.',
      );
    }

    await _setupPlayer(
      effectivePlaybackUrl,
      httpHeaders: authorization.httpHeaders,
      diagnoseSignedHls: true,
      automaticAudioTrack: getAutomaticAudioTrack(authorization.audioTracks),
      automaticSubtitleTrack:
          getAutomaticSubtitleTrack(authorization.subtitleTracks),
    );
    final player = _player;
    final androidPlayer = _androidSecurePlayer;
    if ((player == null && androidPlayer == null) || _hasPlaybackError) {
      SecurityDebugLog.event(
        'PLAYER',
        'media_kit could not initialize the signed media source.',
      );
      throw StateError('Secure media initialization failed');
    }

    if (isRefresh) {
      if (androidPlayer != null) {
        if (position > Duration.zero) await androidPlayer.seekTo(position);
        await androidPlayer.setVolume((volume / 100).clamp(0.0, 1.0));
        await androidPlayer.setPlaybackSpeed(rate);
        if (wasPlaying) {
          await androidPlayer.play();
        } else {
          await androidPlayer.pause();
        }
      } else {
        if (position > Duration.zero) await player!.seek(position);
        await player!.setVolume(volume);
        await player.setRate(rate);
        if (audioTrack != null) await player.setAudioTrack(audioTrack);
        if (subtitleTrack != null) {
          await player.setSubtitleTrack(subtitleTrack);
        }
        if (wasPlaying) {
          await player.play();
        } else {
          await player.pause();
        }
      }
    }
    SecurityDebugLog.event(
      'PLAYER',
      'The player accepted the authorized source; credentials remain redacted.',
    );
    return SecureMediaRestoreResult(
      isPlaying: androidPlayer?.value.isPlaying ?? player!.state.playing,
    );
  }

  Future<void> _pauseActivePlayer() async {
    await _player?.pause();
    await _androidSecurePlayer?.pause();
    _youtubeController?.pause();
  }

  void _showPlaybackError([String message = 'Video unavailable']) {
    if (!mounted || _isDisposed) return;

    setState(() {
      _loading = false;
      _hasPlaybackError = true;
      _playbackMessage = message;
    });
  }

  Future<void> _setupYoutubePlayer(String videoId) async {
    final token = ++_setupToken;
    _controlsHideTimer?.cancel();

    final secureController = _securePlaybackController;
    if (secureController != null) {
      secureController.removeListener(_onSecurePlaybackChanged);
      await secureController.stop();
      secureController.dispose();
      _securePlaybackController = null;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _hasPlaybackError = false;
        _playbackMessage = null;
        _controlsVisible = true;
        _isSeeking = false;
      });
    }

    _progressTimer?.cancel();
    await _disposePlayer(saveProgress: false);
    if (_isDisposed || !mounted || token != _setupToken) return;

    final provider = context.read<PlayMediaProvider>();
    final activeEpisodeId = _currentEpisodeId ?? widget.episodeIndex;
    final activeSeasonId = _currentSeasonId ?? widget.seasonIndex;
    final contentId = widget.content?.id;
    final localResumeSeconds = contentId != null
        ? provider.getLocalResume(
            contentId: contentId,
            seasonId: _isSeries ? activeSeasonId : null,
            episodeId: _isSeries ? activeEpisodeId : null,
          )
        : 0;
    final backendResumeSeconds = widget.content?.watchedSeconds ?? 0;
    final resumeSeconds = localResumeSeconds > backendResumeSeconds
        ? localResumeSeconds
        : backendResumeSeconds;

    final controller = youtube.YoutubePlayerController(
      initialVideoId: videoId,
      flags: youtube.YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        loop: false,
        startAt: resumeSeconds > 5 ? resumeSeconds : 0,
      ),
    );

    controller.addListener(() {
      if (_isDisposed || !mounted || token != _setupToken) return;

      final value = controller.value;
      _handlePlayingChanged(value.isPlaying);

      if (value.hasError) {
        SecurityDebugLog.event(
          'PLAYER',
          'YouTube player reported a sanitized playback error.',
        );
        _showPlaybackError('Failed to load video');
      }

      if (value.playerState == youtube.PlayerState.ended) {
        _handlePlaybackCompleted();
      }

      setState(() {});
    });

    if (_isDisposed || !mounted || token != _setupToken) {
      controller.dispose();
      return;
    }

    _youtubeController = controller;
    SecurityDebugLog.event(
      'PLAYER',
      'YouTube player initialized without exposing the source URL.',
    );

    if (mounted && token == _setupToken) {
      setState(() => _loading = false);
    }

    _progressTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _saveProgress(),
    );
  }

  Future<void> _setupPlayer(
    String url, {
    bool playFromFile = false,
    bool diagnoseSignedHls = false,
    bool forceMediaKit = false,
    Map<String, String>? httpHeaders,
    SecureAudioTrack? automaticAudioTrack,
    SecureSubtitleTrack? automaticSubtitleTrack,
  }) async {
    final token = ++_setupToken;
    _controlsHideTimer?.cancel();

    if (mounted) {
      setState(() {
        _loading = true;
        _hasPlaybackError = false;
        _playbackMessage = null;
        _controlsVisible = true;
        _isSeeking = false;
        _firstFrameRendered = false;
      });
    }

    _progressTimer?.cancel();
    await _disposePlayer(saveProgress: false);
    if (_isDisposed || !mounted || token != _setupToken) return;

    await Future.delayed(const Duration(milliseconds: 250));
    if (_isDisposed || !mounted || token != _setupToken) return;

    if (kDebugMode && diagnoseSignedHls) {
      await _probeSignedHls(
        url,
        cookieHeader: httpHeaders?['Cookie'],
      );
      if (_isDisposed || !mounted || token != _setupToken) return;
    }

    if (!forceMediaKit &&
        (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await _setupNativeVideoPlayer(
        url,
        playFromFile: playFromFile,
        httpHeaders: httpHeaders ?? const {},
        token: token,
      );
      return;
    }

    final playerId = ++_nextPlayerId;
    final player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.debug,
        protocolWhitelist: [
          'udp',
          'rtp',
          'tcp',
          'tls',
          'data',
          'file',
          'http',
          'https',
          'crypto',
        ],
      ),
    );
    final controller = VideoController(player);
    SecurityDebugLog.diagnostic(
      'MEDIA_KIT_CREATE playerId=$playerId secure=$diagnoseSignedHls '
      'platform=${defaultTargetPlatform.name} native=${!kIsWeb}',
    );
    _bindNativePlayerLogs(player, playerId);

    try {
      // Media.httpHeaders is the supported media_kit API. Also configure the
      // underlying libmpv option because some native HLS paths do not retain
      // Media headers when opening child playlists and segments.
      if (!kIsWeb && !playFromFile && httpHeaders != null) {
        try {
          final nativeHeaderFields = httpHeaders.entries
              .map((entry) => '${entry.key}: ${entry.value}')
              .join('\n');
          await (player.platform as dynamic).setProperty(
            'http-header-fields',
            nativeHeaderFields,
          );
          final configuredHeaders = await (player.platform as dynamic)
              .getProperty('http-header-fields') as String;
          SecurityDebugLog.diagnostic(
            'MEDIA_KIT_NATIVE_PROPERTIES playerId=$playerId '
            'httpHeaderFieldsConfigured=${configuredHeaders.isNotEmpty} '
            'nativeCookiePresent=${configuredHeaders.contains('Cookie:')} '
            'protocolWhitelist=http,https,tls,tcp,crypto,data '
            'headers=${httpHeaders.keys.toList()} '
            'cookieHeaderPresent=${httpHeaders['Cookie']?.isNotEmpty == true} '
            'cookieValuesRedacted=true',
          );
        } catch (e) {
          SecurityDebugLog.event(
            'PLAYER',
            'Native property configuration skipped for platform compatibility.',
          );
        }
      }
      // media_kit is the underlying playback engine; the route keeps the
      // existing fullscreen, resume, continue-watching and auto-next behavior.
      final sanitizedHeaders = kIsWeb && httpHeaders != null
          ? Map<String, String>.fromEntries(
              httpHeaders.entries.where((e) => e.key.toLowerCase() != 'cookie'),
            )
          : httpHeaders;
      final media = Media(
        playFromFile && !kIsWeb ? _localFileMediaUri(url) : url,
        httpHeaders: sanitizedHeaders,
      );
      SecurityDebugLog.diagnostic(
        'MEDIA_KIT_MEDIA playerId=$playerId uri=${_safeMediaUrl(media.uri)} '
        'headers=${media.httpHeaders?.keys.toList() ?? const []} '
        'cookieHeaderPresent=${media.httpHeaders?['Cookie']?.isNotEmpty == true} '
        'cookieValuesRedacted=true openPlay=false',
      );
      await player.open(media, play: false);
      if (automaticAudioTrack != null) {
        try {
          await player.setAudioTrack(
            AudioTrack.uri(
              automaticAudioTrack.url,
              title: automaticAudioTrack.label,
              language: automaticAudioTrack.language,
            ),
          );
        } catch (_) {
          SecurityDebugLog.event(
            'PLAYER',
            'Automatic external audio is unsupported; continuing with audio embedded in the selected content manifest.',
          );
        }
      }
      if (automaticSubtitleTrack != null) {
        try {
          await player.setSubtitleTrack(
            SubtitleTrack.uri(
              automaticSubtitleTrack.url,
              title: automaticSubtitleTrack.label,
              language: automaticSubtitleTrack.language,
            ),
          );
        } catch (_) {
          SecurityDebugLog.event(
            'PLAYER',
            'Automatic external subtitle attachment is unsupported; playback will continue without it.',
          );
        }
      }
      SecurityDebugLog.event(
        'PLAYER',
        'Secure playback initialized; authorization type and automatic track presence were validated without logging media URLs.',
      );
      await player.setVolume(100);
    } catch (error, stackTrace) {
      SecurityDebugLog.exception(
        'MEDIA_KIT_OPEN',
        error,
        stackTrace,
      );
      SecurityDebugLog.event(
        'PLAYER',
        'media_kit initialization failed for playerId=$playerId; sanitized details are in HTTP_DIAGNOSTIC.',
      );
      SecurityDebugLog.diagnostic(
        'MEDIA_KIT_DISPOSE_BEGIN playerId=$playerId reason=open_exception',
      );
      await player.dispose();
      SecurityDebugLog.diagnostic(
        'MEDIA_KIT_DISPOSE_DONE playerId=$playerId reason=open_exception',
      );
      if (mounted && token == _setupToken) {
        if (playFromFile && widget.content?.id != null) {
          SecurityDebugLog.event(
            'PLAYER',
            'Local downloaded playback failed to initialize; falling back to online protected streaming.',
          );
          _isOfflinePlayback = false;
          await _startSecurePlayback(
            sourceUrl: _currentRemotePlaybackUrl ?? widget.videoUrl.trim(),
            contentId: widget.content!.id.toString(),
          );
          return;
        }
        _showPlaybackError('Failed to load video');
      }
      return;
    }

    if (_isDisposed || !mounted || token != _setupToken) {
      SecurityDebugLog.diagnostic(
        'MEDIA_KIT_DISPOSE_BEGIN playerId=$playerId reason=stale_setup',
      );
      await player.dispose();
      SecurityDebugLog.diagnostic(
        'MEDIA_KIT_DISPOSE_DONE playerId=$playerId reason=stale_setup',
      );
      return;
    }

    _player = player;
    _activePlayerId = playerId;
    _videoController = controller;
    _bindPlayerStreams(player);
    SecurityDebugLog.event(
      'PLAYER',
      'media_kit open completed for playerId=$playerId and player streams were attached.',
    );

    if (mounted && token == _setupToken) {
      setState(() => _loading = false);
    }

    await _resumeAndPlay(token);
  }

  Future<void> _setupNativeVideoPlayer(
    String url, {
    required Map<String, String> httpHeaders,
    required int token,
    bool playFromFile = false,
  }) async {
    final playerId = ++_nextPlayerId;
    final platformName = kIsWeb ? 'web' : defaultTargetPlatform.name;
    final uri = Uri.parse(url);
    SecurityDebugLog.diagnostic(
      'NATIVE_PLAYER_CREATE playerId=$playerId platform=$platformName '
      'playFromFile=$playFromFile uri=${_safeProbeUrl(uri)} '
      'headers=${httpHeaders.keys.toList()} '
      'cookieHeaderPresent=${httpHeaders['Cookie']?.isNotEmpty == true} '
      'cookieValuesRedacted=true',
    );
    final native_video.VideoPlayerController controller;
    if (playFromFile && !kIsWeb) {
      controller = native_video.VideoPlayerController.file(
        File(url),
        videoPlayerOptions: native_video.VideoPlayerOptions(
          mixWithOthers: false,
        ),
      );
    } else {
      final sanitizedHeaders = kIsWeb
          ? const <String, String>{}
          : Map<String, String>.unmodifiable(httpHeaders);
      controller = native_video.VideoPlayerController.networkUrl(
        uri,
        httpHeaders: sanitizedHeaders,
        videoPlayerOptions: native_video.VideoPlayerOptions(
          mixWithOthers: false,
        ),
      );
    }
    var lastPlaying = false;
    var lastBuffering = false;
    var lastError = '';
    controller.addListener(() {
      if (_isDisposed || token != _setupToken) return;
      final value = controller.value;
      _handlePositionChanged();
      if (value.isPlaying != lastPlaying ||
          value.isBuffering != lastBuffering) {
        lastPlaying = value.isPlaying;
        lastBuffering = value.isBuffering;
        SecurityDebugLog.diagnostic(
          'NATIVE_PLAYER_STATE playerId=$playerId '
          'initialized=${value.isInitialized} playing=${value.isPlaying} '
          'buffering=${value.isBuffering} '
          'positionMs=${value.position.inMilliseconds}',
        );
        _handlePlayingChanged(value.isPlaying);
      }
      final error = value.errorDescription ?? '';
      if (value.hasError && error != lastError) {
        lastError = error;
        SecurityDebugLog.exception(
          'NATIVE_PLAYER_ERROR playerId=$playerId',
          error,
          StackTrace.current,
        );
        if (error.contains('403') && _securePlaybackController != null) {
          unawaited(_securePlaybackController!.handlePlayerHttp403());
        } else {
          _showPlaybackError('Failed to load video');
        }
      }
      if (value.isCompleted) _handlePlaybackCompleted();
      if (mounted) setState(() {});
    });

    try {
      await controller.initialize();
      await controller.setVolume(1);
    } catch (error, stackTrace) {
      SecurityDebugLog.exception(
        'NATIVE_PLAYER_INITIALIZE playerId=$playerId fallback=${!kIsWeb}',
        error,
        stackTrace,
      );
      await controller.dispose();
      if (mounted && token == _setupToken) {
        if (!kIsWeb) {
          await _setupPlayer(
            url,
            playFromFile: playFromFile,
            httpHeaders: httpHeaders,
            forceMediaKit: true,
          );
        } else {
          _showPlaybackError('Failed to load video');
        }
      }
      return;
    }
    if (_isDisposed || !mounted || token != _setupToken) {
      await controller.dispose();
      return;
    }
    _androidSecurePlayer = controller;
    _activePlayerId = playerId;
    SecurityDebugLog.diagnostic(
      'NATIVE_PLAYER_INITIALIZED playerId=$playerId '
      'durationMs=${controller.value.duration.inMilliseconds} '
      'size=${controller.value.size.width}x${controller.value.size.height}',
    );
    setState(() => _loading = false);
    await _resumeAndPlay(token);
  }

  void _bindNativePlayerLogs(Player player, int playerId) {
    _playerSubscriptions.add(
      player.stream.log.listen(
        (log) {
          SecurityDebugLog.diagnostic(
            'MEDIA_KIT_NATIVE_LOG playerId=$playerId level=${log.level} '
            'prefix=${log.prefix} message=${log.text}',
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          SecurityDebugLog.exception(
            'MEDIA_KIT_NATIVE_LOG_STREAM playerId=$playerId',
            error,
            stackTrace,
          );
        },
      ),
    );
  }

  String _safeMediaUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return '<invalid-uri>';
    if (uri.scheme == 'file') return '<local-file>';
    return _safeProbeUrl(uri);
  }

  Future<void> _probeSignedHls(
    String playbackUrl, {
    required String? cookieHeader,
  }) async {
    final uri = Uri.tryParse(playbackUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      SecurityDebugLog.event(
        'HLS_PROBE',
        'Signed media URL is not a valid HTTPS URL.',
      );
      return;
    }

    if ((cookieHeader == null || cookieHeader.isEmpty) && !uri.hasQuery) {
      SecurityDebugLog.event(
        'HLS_PROBE',
        'CloudFront authorization is missing; the protected request was not sent.',
      );
      return;
    }
    try {
      final headers = {
        'Accept': 'application/vnd.apple.mpegurl, application/x-mpegURL, */*',
        'Range': 'bytes=0-65535',
        if (cookieHeader != null && cookieHeader.isNotEmpty && !kIsWeb)
          'Cookie': cookieHeader,
        if (!kIsWeb)
          'User-Agent': 'FilmyTell/1.0',
      };
      final master = await _getHlsProbeResource(
        stage: 'MASTER_PLAYLIST',
        uri: uri,
        headers: headers,
      );
      if (master == null) return;

      var mediaPlaylistUri = uri;
      var mediaPlaylist = master;
      final childReference = _firstPlaylistReference(master);
      if (childReference != null) {
        mediaPlaylistUri = uri.resolve(childReference);
        if (uri.hasQuery && !mediaPlaylistUri.hasQuery) {
          mediaPlaylistUri = mediaPlaylistUri.replace(query: uri.query);
        }
        final child = await _getHlsProbeResource(
          stage: 'CHILD_PLAYLIST',
          uri: mediaPlaylistUri,
          headers: headers,
        );
        if (child == null) return;
        mediaPlaylist = child;
      }

      final segmentReference = _firstSegmentReference(mediaPlaylist);
      if (segmentReference == null) {
        SecurityDebugLog.exception(
          'HLS_PROBE_SEGMENT_MISSING',
          'No .ts/.m4s segment or EXT-X-MAP URI was found.',
        );
        return;
      }
      var segmentUri = mediaPlaylistUri.resolve(segmentReference);
      if (uri.hasQuery && !segmentUri.hasQuery) {
        segmentUri = segmentUri.replace(query: uri.query);
      }
      final segment = await _getHlsProbeBytes(
        stage: 'FIRST_SEGMENT',
        uri: segmentUri,
        headers: headers,
      );
      if (segment == null) return;

      SecurityDebugLog.diagnostic(
        'HLS_PROBE_CHAIN_SUCCESS master=true child=${childReference != null} '
        'segment=true cookieAuthorizationApplied=true. If media_kit fails now, '
        'its native HLS requests are not retaining the supplied headers.',
      );
    } catch (error, stackTrace) {
      SecurityDebugLog.exception('HLS_PROBE_NETWORK', error, stackTrace);
    }
  }

  Future<String?> _getHlsProbeResource({
    required String stage,
    required Uri uri,
    required Map<String, String> headers,
  }) async {
    final bytes = await _getHlsProbeBytes(
      stage: stage,
      uri: uri,
      headers: headers,
    );
    if (bytes == null) return null;
    final playlist = utf8.decode(bytes, allowMalformed: true);
    final valid = playlist.trimLeft().startsWith('#EXTM3U');
    SecurityDebugLog.diagnostic(
      'HLS_PLAYLIST_CHECK stage=$stage validM3u8=$valid',
    );
    if (!valid) return null;
    return playlist;
  }

  Future<List<int>?> _getHlsProbeBytes({
    required String stage,
    required Uri uri,
    required Map<String, String> headers,
  }) async {
    SecurityDebugLog.diagnostic(
      'HLS_PROBE_REQUEST stage=$stage url=${_safeProbeUrl(uri)} '
      'headers=${headers.keys.toList()} Cookie=<redacted> '
      'cookieHeaderPresent=${headers['Cookie']?.isNotEmpty == true}',
    );
    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 10));
    SecurityDebugLog.diagnostic(
      'HLS_PROBE_RESPONSE stage=$stage url=${_safeProbeUrl(uri)} '
      'status=${response.statusCode} '
      'contentType=${response.headers['content-type'] ?? '<missing>'} '
      'bytes=${response.bodyBytes.length} '
      'cloudFrontXCache=${response.headers['x-cache'] ?? '<missing>'}',
    );
    if (response.statusCode != 200 && response.statusCode != 206) {
      final body = utf8.decode(
        response.bodyBytes.take(2048).toList(growable: false),
        allowMalformed: true,
      );
      SecurityDebugLog.exception(
        'HLS_PROBE_${stage}_HTTP_${response.statusCode}',
        body.isEmpty ? 'CloudFront returned an empty error body.' : body,
      );
      return null;
    }
    return response.bodyBytes;
  }

  String? _firstPlaylistReference(String playlist) {
    final lines = playlist.split(RegExp(r'\r?\n'));
    for (var index = 0; index < lines.length; index++) {
      if (!lines[index].trim().startsWith('#EXT-X-STREAM-INF')) continue;
      for (var next = index + 1; next < lines.length; next++) {
        final value = lines[next].trim();
        if (value.isEmpty) continue;
        if (!value.startsWith('#')) return value;
      }
    }
    return null;
  }

  String? _firstSegmentReference(String playlist) {
    final mapMatch =
        RegExp(r'''#EXT-X-MAP:.*URI=["']([^"']+)["']''').firstMatch(playlist);
    if (mapMatch != null) return mapMatch.group(1);
    for (final line in playlist.split(RegExp(r'\r?\n'))) {
      final value = line.trim();
      final path = Uri.tryParse(value)?.path.toLowerCase() ?? '';
      if (!value.startsWith('#') &&
          (path.endsWith('.ts') || path.endsWith('.m4s'))) {
        return value;
      }
    }
    return null;
  }

  String _safeProbeUrl(Uri uri) =>
      uri.replace(query: uri.hasQuery ? '<redacted>' : null).toString();

  void _bindPlayerStreams(Player player) {
    _playerSubscriptions
      ..add(player.stream.playing.listen((isPlaying) {
        SecurityDebugLog.diagnostic(
          'MEDIA_KIT_STATE playerId=$_activePlayerId playing=$isPlaying '
          'buffering=${player.state.buffering} '
          'positionMs=${player.state.position.inMilliseconds}',
        );
        _handlePlayingChanged(isPlaying);
        if (mounted) setState(() {});
      }))
      ..add(player.stream.position.listen((_) => _handlePositionChanged()))
      ..add(player.stream.duration.listen((_) {
        final duration = player.state.duration;
        if (duration != _lastLoggedDuration) {
          _lastLoggedDuration = duration;
          SecurityDebugLog.event(
            'PLAYER',
            'Media duration updated to ${duration.inMilliseconds} ms.',
          );
        }
        if (mounted) setState(() {});
      }))
      ..add(player.stream.buffering.listen((isBuffering) {
        SecurityDebugLog.event(
          'PLAYER',
          'media_kit playerId=$_activePlayerId buffering=$isBuffering '
              'playing=${player.state.playing} '
              'positionMs=${player.state.position.inMilliseconds}.',
        );
        if (isBuffering) {
          _showControls(persist: true);
        } else if (player.state.playing) {
          _scheduleControlsAutoHide();
        }
      }))
      ..add(player.stream.completed.listen((completed) {
        if (completed) {
          SecurityDebugLog.event('PLAYER', 'media_kit reported completion.');
          _handlePlaybackCompleted();
        }
      }))
      ..add(player.stream.error.listen((error) {
        if (_isBenignPlayInterruption(error)) {
          SecurityDebugLog.event(
            'PLAYER',
            'A pending browser play request was superseded by pause; playback state remains valid.',
          );
          return;
        }
        SecurityDebugLog.exception(
          'MEDIA_KIT_STREAM playerId=$_activePlayerId',
          error,
          StackTrace.current,
        );
        final isForbidden = error.toString().contains('403');
        if (isForbidden && _securePlaybackController != null) {
          unawaited(_securePlaybackController!.handlePlayerHttp403());
          return;
        }
        if (mounted) {
          _showPlaybackError('Failed to load video');
        }
      }));
  }

  Future<void> _resumeAndPlay(int token) async {
    if ((_player == null && _androidSecurePlayer == null) || !mounted) return;
    if (_isDisposed || token != _setupToken) return;

    final provider = context.read<PlayMediaProvider>();
    await _player?.setVolume(100);
    await _androidSecurePlayer?.setVolume(1);

    final activeEpisodeId = _currentEpisodeId ?? widget.episodeIndex;
    final activeSeasonId = _currentSeasonId ?? widget.seasonIndex;
    final contentId = widget.content?.id;
    final localResumeSeconds = contentId != null
        ? provider.getLocalResume(
            contentId: contentId,
            seasonId: _isSeries ? activeSeasonId : null,
            episodeId: _isSeries ? activeEpisodeId : null,
          )
        : 0;
    final backendResumeSeconds = widget.content?.watchedSeconds ?? 0;
    final resumeSeconds = localResumeSeconds > backendResumeSeconds
        ? localResumeSeconds
        : backendResumeSeconds;

    if (resumeSeconds > 5) {
      final resumePosition = Duration(seconds: resumeSeconds);
      if (_androidSecurePlayer != null) {
        await _androidSecurePlayer!.seekTo(resumePosition);
      } else {
        await _player!.seek(resumePosition);
      }
      _triggerResumeBanner(resumeSeconds);
    }

    try {
      final position = _androidSecurePlayer?.value.position ??
          _player?.state.position ??
          Duration.zero;
      SecurityDebugLog.event(
        'PLAYER',
        'Requesting secure engine play for playerId=$_activePlayerId '
            'at positionMs=${position.inMilliseconds}.',
      );
      if (_androidSecurePlayer != null) {
        await _androidSecurePlayer!.play();
      } else {
        await _player!.play();
      }
      final isPlaying = _androidSecurePlayer?.value.isPlaying ??
          _player?.state.playing ??
          false;
      final isBuffering = _androidSecurePlayer?.value.isBuffering ??
          _player?.state.buffering ??
          false;
      SecurityDebugLog.event(
        'PLAYER',
        'Secure engine play returned playerId=$_activePlayerId '
            'playing=$isPlaying buffering=$isBuffering.',
      );
    } catch (error, stackTrace) {
      if (_isBenignPlayInterruption(error)) {
        SecurityDebugLog.event(
          'PLAYER',
          'The initial browser play request was superseded by pause; waiting for foreground or user playback.',
        );
        return;
      }
      SecurityDebugLog.exception('MEDIA_KIT_PLAY', error, stackTrace);
      _showPlaybackError('Failed to load video');
      return;
    }
    if (_isDisposed || token != _setupToken) return;

    _progressTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _saveProgress(),
    );
  }

  bool _isBenignPlayInterruption(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('notallowederror') ||
        message.contains("user didn't interact") ||
        message.contains('interrupted by a call to pause') ||
        (message.contains('play() request was interrupted') &&
            (message.contains('call to pause()') ||
                message.contains('new load request')));
  }

  void _handlePlayingChanged(bool isPlaying) {
    if (_isDisposed || !mounted) return;

    if (isPlaying && !_firstFrameRendered) {
      _firstFrameRendered = true;
      SecurityDebugLog.event(
        'PLAYER',
        'First frame rendered; video and audio playback active for playerId=$_activePlayerId.',
      );
    }

    _securePlaybackController?.onPlayingChanged(isPlaying);

    if (isPlaying && !_wakelockEnabled) {
      WakelockPlus.enable();
      _wakelockEnabled = true;
    } else if (!isPlaying && _wakelockEnabled) {
      WakelockPlus.disable();
      _wakelockEnabled = false;
    }

    if (isPlaying && !_isPlaybackBuffering && !_isSeeking) {
      _scheduleControlsAutoHide();
    } else {
      _showControls(persist: true);
    }
  }

  void _handlePositionChanged() {
    if (_isDisposed || !mounted || _handlingEnd) return;

    final androidValue = _androidSecurePlayer?.value;
    if (androidValue != null) {
      if (androidValue.isPlaying &&
          (androidValue.position - _lastSavedPosition).inSeconds >= 15) {
        _saveProgress();
      }
      return;
    }
    if (_player == null) return;

    final state = _player!.state;

    if (state.playing &&
        (state.position - _lastSavedPosition).inSeconds >= 15) {
      _saveProgress();
    }

    if (!state.playing &&
        state.position > Duration.zero &&
        state.position != _lastSavedPosition) {
      _saveProgress();
    }

    if (mounted) setState(() {});
  }

  void _handlePlaybackCompleted() {
    unawaited(_securePlaybackController?.stop());
    if (_handlingEnd || !_isSeries) return;
    _handlingEnd = true;
    unawaited(_playNextEpisode());
  }

  void _saveProgress() {
    final contentId = widget.content?.id;
    if (contentId == null) return;

    final position = _youtubeController?.value.position ??
        _androidSecurePlayer?.value.position ??
        _player?.state.position;
    final duration = _youtubeController?.value.metaData.duration ??
        _androidSecurePlayer?.value.duration ??
        _player?.state.duration;

    if (position == null || duration == null) return;

    if (duration.inSeconds == 0) return;

    _lastSavedPosition = position;

    final activeEpisodeId = _currentEpisodeId ?? widget.episodeIndex;
    final activeSeasonId = _currentSeasonId ?? widget.seasonIndex;

    context.read<PlayMediaProvider>().saveLocalResume(
          contentId: contentId,
          seasonId: _isSeries ? activeSeasonId : null,
          episodeId: _isSeries ? activeEpisodeId : null,
          seconds: position.inSeconds,
        );

    // A validated local download must remain fully playable without a network
    // connection. Keep resume state on-device, but do not invoke authenticated
    // analytics/progress endpoints until playback is online again.
    if (_isOfflinePlayback) return;

    context.read<PlayMediaProvider>().saveContinueWatching(
          contentId: contentId,
          seasonId: _isSeries ? activeSeasonId : null,
          episodeId: _isSeries ? activeEpisodeId : null,
          position: position,
          duration: duration,
        );
  }

  Future<void> _playNextEpisode() async {
    if (!_isSeries ||
        widget.seasons == null ||
        widget.seasons!.isEmpty ||
        (_currentSeasonId == null && widget.seasonIndex == null) ||
        (_currentEpisodeId == null && widget.episodeIndex == null)) {
      return;
    }

    final provider = context.read<PlayMediaProvider>();

    final seasonId = _currentSeasonId ?? widget.seasonIndex!;
    final episodeId = _currentEpisodeId ?? widget.episodeIndex!;

    final next = provider.getNextEpisode(
      seasons: widget.seasons!,
      seasonId: seasonId,
      episodeId: episodeId,
    );

    if (next == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    _handlingEnd = false;
    final nextUrl = next.videoUrl?.trim() ?? "";
    if (nextUrl.isEmpty) {
      _showPlaybackError('Video unavailable');
      return;
    }

    int? nextSeasonId;
    for (final s in widget.seasons!) {
      if (s.episodes.any((e) => e.episodeId == next.episodeId)) {
        nextSeasonId = s.seasonId;
        break;
      }
    }
    _currentSeasonId = nextSeasonId ?? seasonId;
    _currentEpisodeId = next.episodeId;
    _currentRemotePlaybackUrl = nextUrl;

    final youtubeId = _extractYoutubeId(nextUrl);
    if (youtubeId != null && youtubeId.isNotEmpty) {
      await _setupYoutubePlayer(youtubeId);
    } else {
      await _startSecurePlayback(
        sourceUrl: nextUrl,
        contentId: next.episodeId.toString(),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _setupToken++;
    _controlsHideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    final secureController = _securePlaybackController;
    secureController?.removeListener(_onSecurePlaybackChanged);
    secureController?.dispose();
    _securePlaybackController = null;
    _disposePlayerSync(saveProgress: true);
    revokeWebOfflineMediaUrl(_offlineObjectUrl);
    _offlineObjectUrl = null;
    unawaited(_restorePortraitPlayback());
    super.dispose();
  }

  Future<void> _disposePlayer({bool saveProgress = true}) async {
    if (saveProgress) {
      _saveProgress();
    }
    _progressTimer?.cancel();
    _progressTimer = null;

    for (final subscription in _playerSubscriptions) {
      await subscription.cancel();
    }
    _playerSubscriptions.clear();

    final player = _player;
    final androidPlayer = _androidSecurePlayer;
    final playerId = _activePlayerId;
    final youtubeController = _youtubeController;
    _player = null;
    _androidSecurePlayer = null;
    _activePlayerId = null;
    _videoController = null;
    _youtubeController = null;

    if (player != null) {
      SecurityDebugLog.diagnostic(
        'MEDIA_KIT_DISPOSE_BEGIN playerId=$playerId reason=async_teardown',
      );
      try {
        await player.pause();
      } catch (_) {}
      try {
        await player.setVolume(0);
      } catch (_) {}
      await player.dispose();
      SecurityDebugLog.diagnostic(
        'MEDIA_KIT_DISPOSE_DONE playerId=$playerId reason=async_teardown',
      );
    }

    if (androidPlayer != null) {
      SecurityDebugLog.diagnostic(
        'ANDROID_EXOPLAYER_DISPOSE_BEGIN playerId=$playerId '
        'reason=async_teardown',
      );
      await androidPlayer.pause();
      await androidPlayer.dispose();
      SecurityDebugLog.diagnostic(
        'ANDROID_EXOPLAYER_DISPOSE_DONE playerId=$playerId '
        'reason=async_teardown',
      );
    }

    youtubeController?.pause();
    youtubeController?.dispose();

    if (_wakelockEnabled) {
      WakelockPlus.disable();
      _wakelockEnabled = false;
    }
  }

  void _disposePlayerSync({bool saveProgress = true}) {
    if (saveProgress) {
      _saveProgress();
    }
    _progressTimer?.cancel();
    _progressTimer = null;

    for (final subscription in _playerSubscriptions) {
      unawaited(subscription.cancel());
    }
    _playerSubscriptions.clear();

    final player = _player;
    final androidPlayer = _androidSecurePlayer;
    final playerId = _activePlayerId;
    final youtubeController = _youtubeController;
    _player = null;
    _androidSecurePlayer = null;
    _activePlayerId = null;
    _videoController = null;
    _youtubeController = null;

    if (player != null) {
      SecurityDebugLog.diagnostic(
        'MEDIA_KIT_DISPOSE_BEGIN playerId=$playerId reason=sync_teardown',
      );
      try {
        player.pause();
      } catch (_) {}
      try {
        player.setVolume(0);
      } catch (_) {}
      unawaited(
        player.dispose().then((_) {
          SecurityDebugLog.diagnostic(
            'MEDIA_KIT_DISPOSE_DONE playerId=$playerId reason=sync_teardown',
          );
        }),
      );
    }

    if (androidPlayer != null) {
      SecurityDebugLog.diagnostic(
        'ANDROID_EXOPLAYER_DISPOSE_BEGIN playerId=$playerId '
        'reason=sync_teardown',
      );
      unawaited(androidPlayer.dispose());
    }

    youtubeController?.pause();
    youtubeController?.dispose();

    if (_wakelockEnabled) {
      WakelockPlus.disable();
      _wakelockEnabled = false;
    }
  }

  Future<void> _handleExit() async {
    if (_isExiting) return;
    _isExiting = true;
    await _securePlaybackController?.stop();
    await _disposePlayer(saveProgress: true);
    await _restorePortraitPlayback();
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  KeyEventResult _handleRemoteKey(FocusNode node, KeyEvent event) {
    if (!ResponsiveWidget.isTabletOrTv(context) || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA) {
      _togglePlayback();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _seekBy(const Duration(seconds: 10));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _seekBy(const Duration(seconds: -10));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      unawaited(_handleExit());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _togglePlayback() {
    final youtubeController = _youtubeController;
    if (youtubeController != null) {
      if (youtubeController.value.isPlaying) {
        youtubeController.pause();
      } else {
        youtubeController.play();
      }
      return;
    }

    final player = _player;
    if (player != null) {
      unawaited(player.playOrPause());
      return;
    }
    final androidPlayer = _androidSecurePlayer;
    if (androidPlayer != null) {
      unawaited(
        androidPlayer.value.isPlaying
            ? androidPlayer.pause()
            : androidPlayer.play(),
      );
    }
  }

  bool get _isPlaybackPlaying =>
      _youtubeController?.value.isPlaying ??
      _androidSecurePlayer?.value.isPlaying ??
      _player?.state.playing ??
      false;

  bool get _isPlaybackBuffering =>
      _androidSecurePlayer?.value.isBuffering ??
      _player?.state.buffering ??
      false;

  void _toggleControlsVisibility() {
    if (_controlsVisible) {
      if (!_isPlaybackPlaying || _isPlaybackBuffering || _isSeeking) {
        _showControls(persist: true);
        return;
      }
      _controlsHideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  void _showControls({bool persist = false}) {
    _controlsHideTimer?.cancel();
    if (mounted && !_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    if (!persist &&
        _isPlaybackPlaying &&
        !_isPlaybackBuffering &&
        !_isSeeking) {
      _scheduleControlsAutoHide();
    }
  }

  void _scheduleControlsAutoHide({Duration? delay}) {
    _controlsHideTimer?.cancel();
    if (!_isPlaybackPlaying || _isPlaybackBuffering || _isSeeking) return;
    _controlsHideTimer = Timer(delay ?? const Duration(seconds: 4), () {
      if (!mounted ||
          !_isPlaybackPlaying ||
          _isPlaybackBuffering ||
          _isSeeking) {
        return;
      }
      setState(() => _controlsVisible = false);
    });
  }

  void _beginSeeking() {
    _controlsHideTimer?.cancel();
    setState(() {
      _isSeeking = true;
      _controlsVisible = true;
    });
  }

  void _finishSeeking(double value) {
    _seekTo(Duration(milliseconds: value.round()));
    setState(() => _isSeeking = false);
    if (_isPlaybackPlaying && !_isPlaybackBuffering) {
      _scheduleControlsAutoHide();
    }
  }

  void _seekBy(Duration delta) {
    _showControls();
    _seekIndicatorTimer?.cancel();
    setState(() {
      if (delta.inSeconds > 0) {
        _showForwardIndicator = true;
        _showBackwardIndicator = false;
      } else {
        _showBackwardIndicator = true;
        _showForwardIndicator = false;
      }
    });
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showForwardIndicator = false;
          _showBackwardIndicator = false;
        });
      }
    });

    final youtubeController = _youtubeController;
    if (youtubeController != null) {
      final duration = youtubeController.value.metaData.duration;
      youtubeController.seekTo(
        boundedSeekPosition(
          position: youtubeController.value.position,
          duration: duration,
          offset: delta,
        ),
      );
      _scheduleControlsAutoHide(delay: const Duration(milliseconds: 1200));
      return;
    }

    final player = _player;
    if (player != null) {
      final duration = player.state.duration;
      unawaited(
        player.seek(
          boundedSeekPosition(
            position: player.state.position,
            duration: duration,
            offset: delta,
          ),
        ),
      );
      _scheduleControlsAutoHide(delay: const Duration(milliseconds: 1200));
      return;
    }
    final androidPlayer = _androidSecurePlayer;
    if (androidPlayer != null) {
      unawaited(
        androidPlayer.seekTo(
          boundedSeekPosition(
            position: androidPlayer.value.position,
            duration: androidPlayer.value.duration,
            offset: delta,
          ),
        ),
      );
      _scheduleControlsAutoHide(delay: const Duration(milliseconds: 1200));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().getTheme;
    final secureState = _securePlaybackController?.state;
    final secureLoading =
        secureState == SecurePlaybackState.preparingSecurity ||
            secureState == SecurePlaybackState.requestingPlaybackAccess ||
            secureState == SecurePlaybackState.initializingPlayer ||
            secureState == SecurePlaybackState.refreshingUrl;
    final showLoading = _loading || secureLoading;
    final watermark = _securePlaybackController?.watermark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: null,
        body: Focus(
          autofocus: ResponsiveWidget.isTabletOrTv(context),
          onKeyEvent: _handleRemoteKey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: showLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: theme.primaryColor,
                        ),
                      )
                    : _hasPlaybackError
                        ? _secureErrorView()
                        : ResponsiveWidget.isDesktop(context)
                            ? _desktopPlayer()
                            : _mobilePlayer(),
              ),
              if (!showLoading && !_hasPlaybackError)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControlsVisibility,
                    child: const SizedBox.expand(),
                  ),
                ),
              if (_controlsVisible)
                Positioned(
                  top: 8,
                  left: 8,
                  child: SafeArea(child: _backButton()),
                ),
              if (!showLoading && !_hasPlaybackError && _controlsVisible)
                Positioned.fill(
                  child: Center(
                    child: _centerPlaybackControls(),
                  ),
                ),
              if (!showLoading && !_hasPlaybackError && _controlsVisible)
                Positioned(
                  top: 12,
                  right: 12,
                  child: SafeArea(child: _downloadButton()),
                ),
              if (!showLoading && !_hasPlaybackError && watermark != null)
                Positioned.fill(
                  child: PlaybackWatermarkOverlay(
                    watermark: watermark,
                  ),
                ),
              if (!showLoading && !_hasPlaybackError) _buildSeekIndicators(),
              if (!showLoading && !_hasPlaybackError && _showResumeBanner)
                _buildResumeBanner(theme),
              if (!showLoading && !_hasPlaybackError && _controlsVisible)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 12,
                  child: SafeArea(
                    top: false,
                    child: _videoProgressBar(theme),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _secureErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Colors.white70, size: 42),
            const SizedBox(height: 12),
            Text(
              _playbackMessage ?? 'Video unavailable',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            if (_securePlaybackController != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => unawaited(_securePlaybackController!.start()),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasNextEpisode {
    if (!_isSeries ||
        widget.seasons == null ||
        widget.seasons!.isEmpty ||
        (_currentSeasonId == null && widget.seasonIndex == null) ||
        (_currentEpisodeId == null && widget.episodeIndex == null)) {
      return false;
    }
    final seasonId = _currentSeasonId ?? widget.seasonIndex!;
    final episodeId = _currentEpisodeId ?? widget.episodeIndex!;
    final provider = context.read<PlayMediaProvider>();
    return provider.getNextEpisode(
          seasons: widget.seasons!,
          seasonId: seasonId,
          episodeId: episodeId,
        ) !=
        null;
  }

  Widget _centerPlaybackControls() {
    final compact = ResponsiveWidget.isMobile(context);
    final spacing = compact ? 18.0 : 32.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _roundPlaybackButton(
          icon: Icons.replay_10_rounded,
          semanticsLabel: 'Rewind 10 seconds',
          onPressed: () {
            _seekBy(const Duration(seconds: -10));
            _showControls();
          },
        ),
        SizedBox(width: spacing),
        _roundPlaybackButton(
          icon: _isPlaybackBuffering
              ? null
              : _isPlaybackPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
          semanticsLabel: _isPlaybackPlaying ? 'Pause' : 'Play',
          prominent: true,
          loading: _isPlaybackBuffering,
          onPressed: () {
            _togglePlayback();
            _showControls(persist: true);
          },
        ),
        SizedBox(width: spacing),
        _roundPlaybackButton(
          icon: Icons.forward_10_rounded,
          semanticsLabel: 'Forward 10 seconds',
          onPressed: () {
            _seekBy(const Duration(seconds: 10));
            _showControls();
          },
        ),
        if (_hasNextEpisode) ...[
          SizedBox(width: spacing),
          _roundPlaybackButton(
            icon: Icons.skip_next_rounded,
            semanticsLabel: 'Next Episode',
            onPressed: () {
              unawaited(_playNextEpisode());
              _showControls();
            },
          ),
        ],
      ],
    );
  }

  Widget _roundPlaybackButton({
    required IconData? icon,
    required String semanticsLabel,
    required VoidCallback onPressed,
    bool prominent = false,
    bool loading = false,
  }) {
    final compact = ResponsiveWidget.isMobile(context);
    final size = prominent
        ? (compact ? 40.0 : 46.0)
        : (compact ? 34.0 : 38.0);
    final iconSize = prominent
        ? (compact ? 24.0 : 28.0)
        : (compact ? 18.0 : 22.0);

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.black.withValues(alpha: prominent ? 0.65 : 0.50),
        shape: CircleBorder(
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: loading ? null : onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: compact ? 18 : 22,
                      height: compact ? 18 : 22,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      icon,
                      color: Colors.white,
                      size: iconSize,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _downloadButton() {
    final content = widget.content;
    final contentId = content?.id;
    final sourceUrl = _downloadSourceUrl(content);

    if (content == null ||
        contentId == null ||
        content.isDownloadable != true ||
        sourceUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.black.withValues(alpha: 0.48),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          final offlineProvider = context.read<OfflineDownloadProvider>();
          if (offlineProvider.isDownloading(contentId)) return;

          final result = offlineProvider.isDownloaded(contentId)
              ? <String, Object>{
                  'success': true,
                  'message': 'Movie is already downloaded.',
                }
              : await offlineProvider.downloadContent(
                  content,
                  sourceUrl: sourceUrl,
                  httpHeaders: _currentAuthorizedHttpHeaders,
                );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message']?.toString() ?? 'Download updated',
              ),
              backgroundColor: result['success'] == true
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            ),
          );
        },
        child: const SizedBox(
          height: 40,
          width: 40,
          child: Icon(
            Icons.download_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _videoProgressBar(ThemeData theme) {
    final position = _currentPlaybackPosition;
    final duration = _currentPlaybackDuration;
    final durationMs = duration.inMilliseconds;
    final positionMs = position.inMilliseconds.clamp(0, durationMs);
    final isLongDuration = duration.inHours > 0;
    final minLabelWidth = isLongDuration ? 68.0 : 50.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            _mikeOptionButton(theme),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: minLabelWidth),
              child: Text(
                _formatPlaybackTime(position),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: theme.primaryColor,
                  inactiveTrackColor: Colors.white38,
                  secondaryActiveTrackColor: Colors.white54,
                  thumbColor: theme.primaryColor,
                  overlayColor: theme.primaryColor.withValues(alpha: 0.2),
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                ),
                child: Slider(
                  value: durationMs > 0 ? positionMs.toDouble() : 0,
                  min: 0,
                  max: durationMs > 0 ? durationMs.toDouble() : 1,
                  onChanged: durationMs > 0
                      ? (value) => _seekTo(
                            Duration(milliseconds: value.round()),
                          )
                      : null,
                  onChangeStart: durationMs > 0 ? (_) => _beginSeeking() : null,
                  onChangeEnd: durationMs > 0 ? _finishSeeking : null,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: minLabelWidth),
              child: Text(
                _formatPlaybackTime(duration),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _speedSelectorButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _mikeOptionButton(ThemeData theme) {
    return Semantics(
      button: true,
      label: _isMicMuted ? 'Unmute Mic' : 'Mute Mic',
      child: Tooltip(
        message: _isMicMuted ? 'Unmute Mic' : 'Mute Mic',
        child: Material(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              _toggleMicOption();
              _showControls();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Icon(
                _isMicMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: _isMicMuted ? Colors.redAccent : Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleMicOption() {
    if (!mounted || _isDisposed) return;
    setState(() {
      _isMicMuted = !_isMicMuted;
    });

    final player = _player;
    if (player != null) {
      unawaited(player.setVolume(_isMicMuted ? 0 : 100));
    }
    final androidPlayer = _androidSecurePlayer;
    if (androidPlayer != null) {
      unawaited(androidPlayer.setVolume(_isMicMuted ? 0 : 1));
    }
    final youtubeController = _youtubeController;
    if (youtubeController != null) {
      if (_isMicMuted) {
        youtubeController.mute();
      } else {
        youtubeController.unMute();
      }
    }

    CustomToast.show(
      context,
      _isMicMuted ? 'Mic Muted' : 'Mic Enabled',
      isSuccess: !_isMicMuted,
    );
  }

  Widget _speedSelectorButton(ThemeData theme) {
    return PopupMenuButton<double>(
      tooltip: 'Playback speed',
      initialValue: _currentPlaybackSpeed,
      onSelected: (speed) {
        _changePlaybackSpeed(speed);
        _showControls();
      },
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${_currentPlaybackSpeed}x',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      itemBuilder: (context) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
        final isSelected = speed == _currentPlaybackSpeed;
        return PopupMenuItem<double>(
          value: speed,
          child: Row(
            children: [
              Text(
                '${speed}x',
                style: TextStyle(
                  color: isSelected ? theme.primaryColor : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check, size: 16, color: theme.primaryColor),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResumeBanner(ThemeData theme) {
    if (!_showResumeBanner || _resumedTimeText == null) {
      return const SizedBox.shrink();
    }

    final isMobile = ResponsiveWidget.isMobile(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: isMobile ? topPadding + 6 : 45,
      left: 12,
      right: 12,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _showResumeBanner ? 1.0 : 0.0,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 14,
              vertical: isMobile ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.primaryColor.withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_rounded,
                  color: theme.primaryColor,
                  size: isMobile ? 14 : 16,
                ),
                SizedBox(width: isMobile ? 4 : 6),
                Flexible(
                  child: Text(
                    'Resumed from $_resumedTimeText',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: isMobile ? 11 : 12,
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 6 : 10),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    _seekTo(Duration.zero);
                    setState(() => _showResumeBanner = false);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      'Start Over',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 10 : 11,
                        decoration: TextDecoration.underline,
                        decorationColor: theme.primaryColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 2 : 6),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() => _showResumeBanner = false);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: isMobile ? 14 : 16,
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

  Widget _buildSeekIndicators() {
    if (!_showBackwardIndicator && !_showForwardIndicator) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            if (_showBackwardIndicator)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(left: 40),
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.replay_10_rounded,
                          color: Colors.white, size: 36),
                      SizedBox(height: 2),
                      Text(
                        '-10s',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_showForwardIndicator)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(right: 40),
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.forward_10_rounded,
                          color: Colors.white, size: 36),
                      SizedBox(height: 2),
                      Text(
                        '+10s',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
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

  Duration get _currentPlaybackPosition =>
      _youtubeController?.value.position ??
      _androidSecurePlayer?.value.position ??
      _player?.state.position ??
      Duration.zero;

  Duration get _currentPlaybackDuration =>
      _youtubeController?.value.metaData.duration ??
      _androidSecurePlayer?.value.duration ??
      _player?.state.duration ??
      Duration.zero;

  void _seekTo(Duration position) {
    final youtubeController = _youtubeController;
    if (youtubeController != null) {
      youtubeController.seekTo(position);
      return;
    }
    final androidPlayer = _androidSecurePlayer;
    if (androidPlayer != null) {
      unawaited(androidPlayer.seekTo(position));
      return;
    }
    final player = _player;
    if (player != null) unawaited(player.seek(position));
  }

  String _formatPlaybackTime(Duration value) {
    final totalSeconds = value.inSeconds.clamp(0, 359999);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final twoMinutes = minutes.toString().padLeft(2, '0');
    final twoSeconds = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$twoMinutes:$twoSeconds';
    }
    return '$twoMinutes:$twoSeconds';
  }

  String _downloadSourceUrl(Content? content) {
    final authorizedUrl = _currentAuthorizedPlaybackUrl?.trim() ?? '';
    if (_isRemoteHttpUrl(authorizedUrl)) return authorizedUrl;

    final currentUrl = _currentRemotePlaybackUrl?.trim() ?? '';
    if (_isRemoteHttpUrl(currentUrl)) return currentUrl;

    final widgetUrl = widget.videoUrl.trim();
    if (_isRemoteHttpUrl(widgetUrl)) return widgetUrl;

    final contentUrl = content?.contentUrl?.trim() ?? '';
    return _isRemoteHttpUrl(contentUrl) ? contentUrl : '';
  }

  bool _isRemoteHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri?.scheme == 'https' || uri?.scheme == 'http';
  }

  Widget _backButton() {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _handleExit,
        child: const SizedBox(
          height: 36,
          width: 36,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _mobilePlayer() {
    return SizedBox.expand(
      child: _playerSurface(),
    );
  }

  Widget _desktopPlayer() {
    return SizedBox.expand(
      child: _playerSurface(),
    );
  }

  Widget _playerSurface() {
    final theme = Theme.of(context);

    if (_youtubeController != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          if (width <= 0 || height <= 0) return const SizedBox.expand();
          final aspectRatio = width / height;

          return SizedBox(
            width: width,
            height: height,
            child: youtube.YoutubePlayer(
              controller: _youtubeController!,
              width: width,
              aspectRatio: aspectRatio,
              showVideoProgressIndicator: false,
            ),
          );
        },
      );
    }

    final androidPlayer = _androidSecurePlayer;
    if (androidPlayer != null && androidPlayer.value.isInitialized) {
      final size = androidPlayer.value.size;
      final videoWidth = (size.width > 0) ? size.width : 16.0;
      final videoHeight = (size.height > 0) ? size.height : 9.0;
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: videoWidth,
            height: videoHeight,
            child: native_video.VideoPlayer(androidPlayer),
          ),
        ),
      );
    }

    if (_player == null || _videoController == null) {
      if (_hasPlaybackError) {
        return Center(
          child: Text(
            _playbackMessage ?? 'Video unavailable',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        );
      }
      return Center(
        child: CircularProgressIndicator(
          color: theme.primaryColor,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (width <= 0 || height <= 0) return const SizedBox.expand();

        return SizedBox(
          width: width,
          height: height,
          child: Video(
            controller: _videoController!,
            width: width,
            height: height,
            fit: BoxFit.cover,
            fill: Colors.black,
            controls: NoVideoControls,
          ),
        );
      },
    );
  }

  String _localFileMediaUri(String pathOrUri) {
    final uri = Uri.tryParse(pathOrUri);
    if (uri?.scheme == 'file') return pathOrUri;
    return File(pathOrUri).uri.toString();
  }
}
