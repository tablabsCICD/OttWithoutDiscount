import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ott/app/core/utils/direct_trailer_source.dart';
import 'package:ott/app/core/utils/security_debug_log.dart';
import 'package:video_player/video_player.dart' as native_video;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:ott/app/widgets/video_skip_controls.dart';

import '../../../../data/models/content.dart';
import '../../../core/constant/api_constant.dart';
import '../../../core/network/api_helper.dart';
import '../../../core/utils/sharepreferences.dart';

String? _extractYoutubeId(String urlOrId) {
  final value = urlOrId.trim();
  if (value.isEmpty) return null;

  final converted = YoutubePlayer.convertUrlToId(value);
  if (converted != null && converted.isNotEmpty) return converted;

  final uri = Uri.tryParse(value);
  if (uri != null) {
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if ((uri.host.contains('youtube.com') || uri.host == 'youtu.be') &&
        segments.isNotEmpty) {
      final candidate = uri.host == 'youtu.be'
          ? segments.first
          : segments.first == 'shorts' && segments.length > 1
              ? segments[1]
              : null;
      if (candidate != null &&
          RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(candidate)) {
        return candidate;
      }
    }
  }

  final looksLikeVideoId = RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(value);
  return looksLikeVideoId ? value : null;
}

class TrailerPage extends StatefulWidget {
  final String? trailerUrl;
  final bool isTrailerUrl;
  final Content content;

  const TrailerPage({
    super.key,
    required this.trailerUrl,
    required this.isTrailerUrl,
    required this.content,
  });

  @override
  State<TrailerPage> createState() => _TrailerPageState();
}

class _TrailerPageState extends State<TrailerPage> with WidgetsBindingObserver {
  Player? _player;
  VideoController? _videoController;
  YoutubePlayerController? _youtubeController;
  native_video.VideoPlayerController? _androidController;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool _initialized = false;
  bool _historySaved = false;
  bool _hasError = false;
  bool _controlsVisible = true;
  bool _isSeeking = false;
  Timer? _controlsTimer;

  String get _trailerUrl =>
      DirectTrailerSource.fromBackend(widget.trailerUrl) ?? '';
  bool get _hasUrl => _trailerUrl.isNotEmpty;
  String? get _youtubeId => _extractYoutubeId(_trailerUrl);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (_hasUrl) _initPlayer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_player?.pause());
      unawaited(_androidController?.pause());
      _youtubeController?.pause();
    }
  }

  Future<void> _initPlayer() async {
    if (kDebugMode) {
      debugPrint(_youtubeId == null
          ? 'TRAILER_FLOW: Opening direct trailer player'
          : 'TRAILER_FLOW: Opening YouTube trailer player');
    }
    SecurityDebugLog.event(
      'TRAILER',
      'Initializing trailer from the direct backend URL; signed playback API is intentionally bypassed.',
    );
    final youtubeId = _youtubeId;
    if (youtubeId != null && youtubeId.isNotEmpty) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: youtubeId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          loop: false,
          hideControls: true,
        ),
      )..addListener(() {
          if (!mounted) return;
          _youtubeController!.value.isPlaying
              ? WakelockPlus.enable()
              : WakelockPlus.disable();
          setState(() {});
          if (_youtubeController!.value.isPlaying) _scheduleControlsHide();
        });

      if (mounted) {
        setState(() => _initialized = true);
        if (kDebugMode) {
          debugPrint('TRAILER_FLOW: Trailer player initialized');
        }
      }
      return;
    }

    final uri = Uri.tryParse(_trailerUrl);
    if (uri == null || !uri.hasScheme) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final controller = native_video.VideoPlayerController.networkUrl(uri);
      try {
        await controller.initialize();
        await controller.setVolume(1);
        if (!mounted) {
          await controller.dispose();
          return;
        }
        _androidController = controller;
        controller.addListener(_onAndroidValueChanged);
        await controller.play();
        WakelockPlus.enable();
        setState(() => _initialized = true);
        if (kDebugMode) {
          debugPrint('TRAILER_FLOW: Trailer player initialized');
        }
        return;
      } catch (error) {

        await controller.dispose();
        if (mounted) setState(() => _hasError = true);
        return;
      }
    }

    final player = Player();
    final controller = VideoController(player);

    try {
      // media_kit powers direct trailer URLs while YouTube URLs keep their
      // existing YouTube-specific controller.
      _subscriptions
        ..add(player.stream.playing.listen((isPlaying) {
          isPlaying ? WakelockPlus.enable() : WakelockPlus.disable();
          if (isPlaying && !_historySaved && !widget.isTrailerUrl) {
            _historySaved = true;
            _saveHistory();
          }
          if (mounted) setState(() {});
        }))
        ..add(player.stream.position.listen((_) {
          if (mounted) setState(() {});
        }))
        ..add(player.stream.duration.listen((_) {
          if (mounted) setState(() {});
        }))
        ..add(player.stream.error.listen((error) {

          if (mounted) setState(() => _hasError = true);
        }));

      SecurityDebugLog.event(
        'TRAILER',
        'Passing the direct backend trailer URL to media_kit.',
      );
      await player.open(Media(_trailerUrl), play: true);
      await player.setVolume(100);

      if (!mounted) {
        await player.dispose();
        return;
      }

      setState(() {
        _player = player;
        _videoController = controller;
        _initialized = true;
      });
      if (kDebugMode) {
        debugPrint('TRAILER_FLOW: Trailer player initialized');
      }
      _scheduleControlsHide();
    } catch (error) {

      await player.dispose();
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onAndroidValueChanged() {
    if (!mounted) return;
    setState(() {});
    if (_androidController?.value.isPlaying == true) _scheduleControlsHide();
  }

  Duration get _position {
    if (_youtubeController != null) return _youtubeController!.value.position;
    if (_androidController != null) return _androidController!.value.position;
    return _player?.state.position ?? Duration.zero;
  }

  Duration get _duration {
    if (_youtubeController != null) {
      return _youtubeController!.value.metaData.duration;
    }
    if (_androidController != null) return _androidController!.value.duration;
    return _player?.state.duration ?? Duration.zero;
  }

  bool get _isPlaying {
    if (_youtubeController != null) return _youtubeController!.value.isPlaying;
    if (_androidController != null) {
      return _androidController!.value.isPlaying;
    }
    return _player?.state.playing ?? false;
  }

  bool get _isBuffering {
    if (_youtubeController != null) {
      return _youtubeController!.value.playerState == PlayerState.buffering;
    }
    if (_androidController != null) {
      return _androidController!.value.isBuffering;
    }
    return _player?.state.buffering ?? false;
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    if (!_isPlaying || _isBuffering || _isSeeking) return;
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying && !_isBuffering && !_isSeeking) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      _scheduleControlsHide();
    } else if (_isPlaying && !_isBuffering) {
      _controlsTimer?.cancel();
      setState(() => _controlsVisible = false);
    }
  }

  void _togglePlayback() {
    final youtube = _youtubeController;
    if (youtube != null) {
      youtube.value.isPlaying ? youtube.pause() : youtube.play();
    } else if (_androidController != null) {
      _androidController!.value.isPlaying
          ? unawaited(_androidController!.pause())
          : unawaited(_androidController!.play());
    } else if (_player != null) {
      _player!.state.playing
          ? unawaited(_player!.pause())
          : unawaited(_player!.play());
    }
    setState(() => _controlsVisible = true);
    _scheduleControlsHide();
  }

  void _seekTo(Duration position) {
    final bounded = position < Duration.zero
        ? Duration.zero
        : position > _duration
            ? _duration
            : position;
    if (_youtubeController != null) {
      _youtubeController!.seekTo(bounded);
    } else if (_androidController != null) {
      unawaited(_androidController!.seekTo(bounded));
    } else {
      unawaited(_player?.seek(bounded));
    }
  }

  String _formatDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Future<void> _saveHistory() async {
    try {
      final user = await LocalSharePreferences.localSharePreferences.getUser();
      if (user == null) return;

      final body = {
        "contentId": widget.content.id,
        "resumeTime": _player?.state.position.toString() ?? "0:00",
        "selectedLanguage":
            widget.content.languageList?.first.language ?? "Unknown",
        "userId": user.id,
        "viewDate": DateTime.now().toUtc().toIso8601String(),
      };

      await ApiHelper().postApiWithBody(ApiConstant.saveViewHistory, body);
    } catch (_) {}
  }

  void _seekBy(Duration offset) {
    final youtube = _youtubeController;
    if (youtube != null) {
      youtube.seekTo(
        boundedSeekPosition(
          position: youtube.value.position,
          duration: youtube.value.metaData.duration,
          offset: offset,
        ),
      );
      return;
    }
    final player = _player;
    final androidController = _androidController;
    if (androidController != null) {
      unawaited(androidController.seekTo(boundedSeekPosition(
        position: androidController.value.position,
        duration: androidController.value.duration,
        offset: offset,
      )));
      return;
    }
    if (player == null) return;
    unawaited(
      player.seek(
        boundedSeekPosition(
          position: player.state.position,
          duration: player.state.duration,
          offset: offset,
        ),
      ),
    );
  }

  Future<void> _disposePlayer() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    final player = _player;
    final androidController = _androidController;
    _player = null;
    _videoController = null;
    _androidController = null;
    if (player != null) {
      try {
        await player.pause();
      } catch (_) {}
      await player.dispose();
    }
    if (androidController != null) {
      androidController.removeListener(_onAndroidValueChanged);
      await androidController.pause();
      await androidController.dispose();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    unawaited(_disposePlayer());
    _youtubeController?.dispose();
    WakelockPlus.disable();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (kDebugMode) {
      debugPrint('TRAILER_FLOW: Trailer player disposed');
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _initialized ? _toggleControls : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_initialized)
              Center(child: _playerSurface())
            else
              Center(
                child: _hasError || !_hasUrl
                    ? const Text('Unable to play this trailer.',
                        style: TextStyle(color: Colors.white))
                    : CircularProgressIndicator(
                        color: Theme.of(context).primaryColor),
              ),
            if (_initialized && _controlsVisible) _buildControls(),
            if (_initialized) _buildBottomProgressBar(),
            if (!_initialized || _hasError)
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return ColoredBox(
      color: Colors.black38,
      child: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    iconSize: 38,
                    onPressed: () => _seekBy(const Duration(seconds: -10)),
                    icon: const Icon(Icons.replay_10, color: Colors.white),
                  ),
                  const SizedBox(width: 28),
                  if (_isBuffering)
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  else
                    IconButton(
                      iconSize: 52,
                      onPressed: _togglePlayback,
                      icon: Icon(
                        _isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: Colors.white,
                      ),
                    ),
                  const SizedBox(width: 28),
                  IconButton(
                    iconSize: 38,
                    onPressed: () => _seekBy(const Duration(seconds: 10)),
                    icon: const Icon(Icons.forward_10, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomProgressBar() {
    final durationMs = _duration.inMilliseconds;
    final positionMs = _position.inMilliseconds.clamp(0, durationMs);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black87],
            ),
          ),
          child: Row(
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: positionMs.toDouble(),
                  max: durationMs > 0 ? durationMs.toDouble() : 1,
                  onChangeStart: (_) {
                    _controlsTimer?.cancel();
                    setState(() {
                      _isSeeking = true;
                      _controlsVisible = true;
                    });
                  },
                  onChanged: (value) =>
                      _seekTo(Duration(milliseconds: value.round())),
                  onChangeEnd: (_) {
                    setState(() => _isSeeking = false);
                    _scheduleControlsHide();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playerSurface() {
    if (_youtubeController != null) {
      return YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: false,
        ),
        builder: (context, player) {
          return AspectRatio(
            aspectRatio: 16 / 9,
            child: player,
          );
        },
      );
    }

    final androidController = _androidController;
    if (androidController != null && androidController.value.isInitialized) {
      return AspectRatio(
        aspectRatio: androidController.value.aspectRatio == 0
            ? 16 / 9
            : androidController.value.aspectRatio,
        child: native_video.VideoPlayer(androidController),
      );
    }

    final player = _player;
    final controller = _videoController;
    if (player == null || controller == null) {
      return const SizedBox.shrink();
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          Positioned.fill(
            child: Video(
              controller: controller,
              fit: BoxFit.contain,
              controls: null,
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTapDown: (details) async {
                final box = context.findRenderObject() as RenderBox;
                final local = box.globalToLocal(details.globalPosition);
                final isLeft = local.dx < box.size.width / 2;

                final current = player.state.position;
                final duration = player.state.duration;

                final target = isLeft
                    ? current - const Duration(seconds: 10)
                    : current + const Duration(seconds: 10);

                await player.seek(
                  target < Duration.zero
                      ? Duration.zero
                      : target > duration
                          ? duration
                          : target,
                );
              },
              onLongPressStart: (_) {
                player.setRate(2.0);
              },
              onLongPressEnd: (_) {
                player.setRate(1.0);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TrailerPreview extends StatefulWidget {
  final String? trailerUrl;
  final Content content;
  final TrailerPreviewController controller;
  final bool autoPlay;
  final bool muted;

  const TrailerPreview({
    super.key,
    required this.trailerUrl,
    required this.content,
    required this.controller,
    this.autoPlay = true,
    this.muted = false,
  });

  @override
  State<TrailerPreview> createState() => _TrailerPreviewState();
}

class _TrailerPreviewState extends State<TrailerPreview>
    with WidgetsBindingObserver {
  Player? _player;
  VideoController? _videoController;
  native_video.VideoPlayerController? _androidController;
  YoutubePlayerController? _youtubeController;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _showControls = false;
  bool _isDisposed = false;
  bool _hasError = false;
  int _initToken = 0;
  Future<void>? _initializationFuture;
  bool _manuallyPaused = false;
  bool _appIsActive = true;
  bool _isMuted = false;

  String get _trailerUrl =>
      DirectTrailerSource.fromBackend(widget.trailerUrl) ?? '';
  String? get _youtubeId => _extractYoutubeId(_trailerUrl);

  bool get _isPlaying {
    final android = _androidController;
    if (android != null && android.value.isInitialized) {
      return android.value.isPlaying;
    }
    final player = _player;
    if (player != null) {
      return player.state.playing;
    }
    final youtube = _youtubeController;
    if (youtube != null) {
      return youtube.value.isPlaying;
    }
    return false;
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _stopAudio() {
    unawaited(_player?.setVolume(0));
    unawaited(_androidController?.setVolume(0));
    _youtubeController?.mute();
  }

  void _pauseTrailer() {
    _manuallyPaused = true;
    _stopAudio();
    unawaited(_player?.pause());
    unawaited(_androidController?.pause());
    _youtubeController?.pause();
    if (mounted) {
      setState(() {});
    }
  }

  void _playTrailer() {
    _manuallyPaused = false;
    if (!_appIsActive) return;

    final androidVol = _isMuted ? 0.0 : 1.0;
    unawaited(_androidController?.setVolume(androidVol));
    unawaited(_androidController?.play());

    final mediaKitVol = _isMuted ? 0.0 : 100.0;
    unawaited(_player?.setVolume(mediaKitVol));
    unawaited(_player?.play());

    if (_youtubeController != null) {
      if (_isMuted) {
        _youtubeController!.mute();
      } else {
        _youtubeController!.unMute();
      }
      _youtubeController!.play();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pauseTrailer();
    } else {
      _playTrailer();
    }
  }

  @override
  void initState() {
    super.initState();
    _isMuted = widget.muted;
    WidgetsBinding.instance.addObserver(this);
    _appIsActive = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    widget.controller.pause = _pauseTrailer;
    widget.controller.play = _playTrailer;
    widget.controller.stopAudio = _stopAudio;

    widget.controller.mute = () {
      if (mounted) setState(() => _isMuted = true);
      _stopAudio();
    };

    widget.controller.unmute = () {
      if (mounted) setState(() => _isMuted = false);
      if (_isPlaying) {
        unawaited(_player?.setVolume(100));
        unawaited(_androidController?.setVolume(1));
        _youtubeController?.unMute();
      }
    };
    widget.controller.disposePlayer = _disposeControllerAsync;
    widget.controller.isPlaying = () => _isPlaying;

    if (widget.trailerUrl?.isNotEmpty == true) {
      _initializationFuture = _init();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsActive = state == AppLifecycleState.resumed;
    if (!_appIsActive) {
      _stopAudio();
      unawaited(_player?.pause());
      unawaited(_androidController?.pause());
      _youtubeController?.pause();
    } else if (widget.autoPlay && !_manuallyPaused) {
      _playTrailer();
    }
  }

  Future<void> _init() async {
    if (_trailerUrl.isEmpty) return;

    SecurityDebugLog.event(
      'TRAILER',
      'Initializing embedded trailer directly; no signed URL is requested.',
    );
    final currentToken = ++_initToken;
    final youtubeId = _youtubeId;
    if (youtubeId != null && youtubeId.isNotEmpty) {
      _youtubeController?.removeListener(_onControllerUpdate);
      _youtubeController?.dispose();
      final controller = YoutubePlayerController(
        initialVideoId: youtubeId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: true,
          loop: true,
        ),
      );

      if (!_isMuted && !_manuallyPaused) {
        controller.unMute();
      } else {
        controller.mute();
      }
      if (!widget.autoPlay || _manuallyPaused || !_appIsActive) {
        controller.pause();
      }

      if (_isDisposed || currentToken != _initToken) {
        controller.dispose();
        return;
      }

      controller.addListener(_onControllerUpdate);
      if (mounted) {
        setState(() {
          _hasError = false;
          _youtubeController = controller;
        });
      }
      return;
    }

    final uri = Uri.tryParse(_trailerUrl);
    if (uri == null || !uri.hasScheme) {
      if (mounted && !_isDisposed) {
        setState(() => _hasError = true);
      }
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final controller = native_video.VideoPlayerController.networkUrl(uri);
      try {
        await controller.initialize();
        if (_isDisposed || currentToken != _initToken || _manuallyPaused) {
          await controller.setVolume(0);
          await controller.pause();
          if (_isDisposed || currentToken != _initToken) {
            await controller.dispose();
            return;
          }
        }
        await controller.setLooping(true);
        final vol = (_isMuted || _manuallyPaused) ? 0.0 : 1.0;
        await controller.setVolume(vol);
        if (widget.autoPlay && !_manuallyPaused && _appIsActive) {
          await controller.play();
        } else {
          await controller.pause();
        }
        if (_isDisposed || currentToken != _initToken) {
          await controller.setVolume(0);
          await controller.pause();
          await controller.dispose();
          return;
        }
        controller.addListener(_onControllerUpdate);
        if (mounted) {
          setState(() {
            _hasError = false;
            _androidController = controller;
          });
        }
      } catch (error) {
        await controller.dispose();
        if (mounted && !_isDisposed) setState(() => _hasError = true);
      }
      return;
    }

    final player = Player();
    final controller = VideoController(player);

    try {
      _subscriptions
        ..add(player.stream.position.listen((_) {
          if (mounted) setState(() {});
        }))
        ..add(player.stream.duration.listen((_) {
          if (mounted) setState(() {});
        }))
        ..add(player.stream.playing.listen((_) {
          if (mounted) setState(() {});
        }))
        ..add(player.stream.volume.listen((_) {
          if (mounted) setState(() {});
        }))
        ..add(player.stream.completed.listen((completed) {
          if (completed &&
              !_isDisposed &&
              currentToken == _initToken &&
              widget.autoPlay &&
              !_manuallyPaused &&
              _appIsActive) {
            player.seek(Duration.zero);
            player.play();
          }
        }))
        ..add(player.stream.error.listen((error) {
          if (mounted && !_isDisposed) {
            setState(() => _hasError = true);
          }
        }));

      SecurityDebugLog.event(
        'TRAILER',
        'Passing the direct backend trailer URL to the embedded media_kit player.',
      );
      await player.open(Media(_trailerUrl), play: false);
      if (_isDisposed || currentToken != _initToken || _manuallyPaused) {
        await player.setVolume(0);
        await player.pause();
        if (_isDisposed || currentToken != _initToken) {
          await player.dispose();
          return;
        }
      }
      final vol = (_isMuted || _manuallyPaused) ? 0.0 : 100.0;
      await player.setVolume(vol);
      if (widget.autoPlay && !_manuallyPaused && _appIsActive) {
        await player.play();
      } else {
        await player.pause();
      }

      if (_isDisposed || currentToken != _initToken) {
        await player.setVolume(0);
        await player.pause();
        await player.dispose();
        return;
      }

      if (mounted) {
        setState(() {
          _hasError = false;
          _player = player;
          _videoController = controller;
        });
      }
    } catch (error) {
      await player.dispose();
      if (mounted && !_isDisposed) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void didUpdateWidget(covariant TrailerPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trailerUrl != widget.trailerUrl) {
      _manuallyPaused = false;
      _disposeController();
      _hasError = false;
      if (widget.trailerUrl?.isNotEmpty == true) {
        _initializationFuture = _init();
      }
      return;
    }
    if (oldWidget.muted != widget.muted) {
      _isMuted = widget.muted;
      final vol = _isMuted ? 0.0 : 1.0;
      unawaited(_player?.setVolume(_isMuted ? 0 : 100));
      unawaited(_androidController?.setVolume(vol));
      widget.muted ? _youtubeController?.mute() : _youtubeController?.unMute();
    }
    if (oldWidget.autoPlay != widget.autoPlay) {
      if (widget.autoPlay && !_manuallyPaused && _appIsActive) {
        _playTrailer();
      } else {
        _pauseTrailer();
      }
    }
  }

  void _disposeController() {
    _initToken++;
    _stopAudio();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();

    _androidController?.removeListener(_onControllerUpdate);
    _youtubeController?.removeListener(_onControllerUpdate);

    final player = _player;
    final androidController = _androidController;
    _player = null;
    _videoController = null;
    _androidController = null;
    if (player != null) {
      unawaited(player.pause());
      unawaited(player.dispose());
    }
    if (androidController != null) {
      unawaited(androidController.pause());
      unawaited(androidController.dispose());
    }

    _youtubeController?.pause();
    _youtubeController?.dispose();
    _youtubeController = null;
  }

  Future<void> _disposeControllerAsync() async {
    _manuallyPaused = true;
    _initToken++;
    _stopAudio();
    unawaited(_player?.pause());
    unawaited(_androidController?.pause());
    _youtubeController?.pause();

    await _initializationFuture;
    _initializationFuture = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    _androidController?.removeListener(_onControllerUpdate);
    _youtubeController?.removeListener(_onControllerUpdate);

    final player = _player;
    final androidController = _androidController;
    _player = null;
    _videoController = null;
    _androidController = null;
    if (player != null) {
      SecurityDebugLog.event(
        'TRAILER',
        'Awaiting embedded trailer disposal before secure playback.',
      );
      await player.dispose();
      SecurityDebugLog.event(
        'TRAILER',
        'Embedded trailer disposal completed before secure playback.',
      );
    }
    if (androidController != null) {
      await androidController.pause();
      await androidController.dispose();
    }
    _youtubeController?.pause();
    _youtubeController?.dispose();
    _youtubeController = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.pause = null;
    widget.controller.play = null;
    widget.controller.mute = null;
    widget.controller.unmute = null;
    widget.controller.stopAudio = null;
    widget.controller.disposePlayer = null;
    widget.controller.isPlaying = null;
    _disposeController();
    super.dispose();
  }

  String _format(Duration d) {
    if (d == Duration.zero) return "00:00";
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}";
  }

  void _seekPreviewBy(Duration offset) {
    final youtube = _youtubeController;
    if (youtube != null) {
      youtube.seekTo(
        boundedSeekPosition(
          position: youtube.value.position,
          duration: youtube.value.metaData.duration,
          offset: offset,
        ),
      );
      return;
    }
    final player = _player;
    final androidController = _androidController;
    if (androidController != null) {
      unawaited(androidController.seekTo(boundedSeekPosition(
        position: androidController.value.position,
        duration: androidController.value.duration,
        offset: offset,
      )));
      return;
    }
    if (player == null) return;
    unawaited(
      player.seek(
        boundedSeekPosition(
          position: player.state.position,
          duration: player.state.duration,
          offset: offset,
        ),
      ),
    );
  }

  Future<void> _openFullscreenTrailer() async {
    final trailerUrl = _trailerUrl;
    if (trailerUrl.isEmpty) return;

    await _disposeControllerAsync();
    if (!mounted || _isDisposed) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrailerPage(
          trailerUrl: trailerUrl,
          isTrailerUrl: true,
          content: widget.content,
        ),
      ),
    );

    if (mounted && !_isDisposed) {
      _initializationFuture = _init();
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });

    if (_isPlaying) {
      if (_player != null) {
        unawaited(_player!.setVolume(_isMuted ? 0 : 100));
      }
      if (_androidController != null) {
        unawaited(_androidController!.setVolume(_isMuted ? 0 : 1));
      }
      if (_youtubeController != null) {
        if (_isMuted) {
          _youtubeController!.mute();
        } else {
          _youtubeController!.unMute();
        }
      }
    }
  }

  Widget _volumeButton({double rightOffset = 56, double bottomOffset = 8}) {
    return Positioned(
      right: rightOffset,
      bottom: bottomOffset,
      child: Semantics(
        button: true,
        label: _isMuted ? 'Unmute trailer' : 'Mute trailer',
        child: Material(
          color: Colors.black54,
          shape: const CircleBorder(),
          child: IconButton(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            iconSize: 16,
            tooltip: _isMuted ? 'Unmute trailer' : 'Mute trailer',
            onPressed: _toggleMute,
            icon: Icon(
              _isMuted ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _fullscreenButton() {
    return Positioned(
      right: 8,
      bottom: 8,
      child: Semantics(
        button: true,
        label: 'Play trailer fullscreen',
        child: Material(
          color: Colors.black54,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: 'Fullscreen trailer',
            onPressed: _openFullscreenTrailer,
            icon: const Icon(Icons.fullscreen, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _centerPlayPauseOverlay() {
    final playing = _isPlaying;
    return Center(
      child: Semantics(
        button: true,
        label: playing ? 'Pause trailer' : 'Play trailer',
        child: Material(
          color: Colors.black.withOpacity(0.45),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _togglePlayPause,
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              child: Icon(
                playing ? Icons.pause : Icons.play_arrow,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(
                "Trailer unavailable",
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ),
            if (_trailerUrl.isNotEmpty) _fullscreenButton(),
          ],
        ),
      );
    }

    final androidController = _androidController;
    if (androidController != null && androidController.value.isInitialized) {
      return AspectRatio(
        aspectRatio: androidController.value.aspectRatio == 0
            ? 16 / 9
            : androidController.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            native_video.VideoPlayer(androidController),
            _centerPlayPauseOverlay(),
            _volumeButton(),
            _fullscreenButton(),
          ],
        ),
      );
    }

    if (_player == null || _videoController == null) {
      if (_youtubeController != null) {
        return _buildYoutubePreview();
      }

      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            ),
            if (_trailerUrl.isNotEmpty) ...[
              _volumeButton(),
              _fullscreenButton(),
            ],
          ],
        ),
      );
    }

    final player = _player!;
    return MouseRegion(
      onEnter: (_) => setState(() => _showControls = true),
      onExit: (_) => setState(() => _showControls = false),
      child: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              Positioned.fill(
                child: Video(
                  controller: _videoController!,
                  fit: BoxFit.cover,
                  controls: null,
                ),
              ),
              _centerPlayPauseOverlay(),
              if (_showControls) ...[
                Positioned.fill(
                  child: Container(color: Colors.black.withOpacity(0.35)),
                ),
                _centerPlayPauseOverlay(),
                Center(
                  child: VideoSkipControls(
                    onBackward: () =>
                        _seekPreviewBy(const Duration(seconds: -10)),
                    onForward: () =>
                        _seekPreviewBy(const Duration(seconds: 10)),
                    gap: 72,
                    compact: true,
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 104,
                  bottom: 8,
                  child: Row(
                    children: [
                      Text(
                        _format(player.state.position),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: _progressSlider(player)),
                      const SizedBox(width: 6),
                      Text(
                        _format(player.state.duration),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
              _volumeButton(),
              _fullscreenButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressSlider(Player player) {
    final durationMs = player.state.duration.inMilliseconds;
    final positionMs = player.state.position.inMilliseconds;
    if (durationMs <= 0) {
      return const LinearProgressIndicator(
        value: 0,
        color: Colors.red,
        backgroundColor: Colors.white24,
      );
    }

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
      ),
      child: Slider(
        min: 0,
        max: durationMs.toDouble(),
        value: positionMs.clamp(0, durationMs).toDouble(),
        activeColor: Colors.red,
        inactiveColor: Colors.white24,
        onChanged: (value) {
          player.seek(Duration(milliseconds: value.round()));
        },
      ),
    );
  }

  Widget _buildYoutubePreview() {
    return MouseRegion(
      onEnter: (_) => setState(() => _showControls = true),
      onExit: (_) => setState(() => _showControls = false),
      child: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              Positioned.fill(
                child: YoutubePlayer(
                  controller: _youtubeController!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: Colors.red,
                  progressColors: const ProgressBarColors(
                    playedColor: Colors.red,
                    handleColor: Colors.red,
                    bufferedColor: Colors.white54,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
              _centerPlayPauseOverlay(),
              _volumeButton(),
              _fullscreenButton(),
              if (_showControls)
                Center(
                  child: VideoSkipControls(
                    onBackward: () =>
                        _seekPreviewBy(const Duration(seconds: -10)),
                    onForward: () =>
                        _seekPreviewBy(const Duration(seconds: 10)),
                    gap: 72,
                    compact: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrailerPreviewController {
  VoidCallback? pause;
  VoidCallback? play;
  VoidCallback? mute;
  VoidCallback? unmute;
  VoidCallback? stopAudio;
  Future<void> Function()? disposePlayer;
  bool Function()? isPlaying;
}
