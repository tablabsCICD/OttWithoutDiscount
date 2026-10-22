import 'package:flutter/material.dart';
import 'package:ott/app/widgets/responsive_poster_image.dart';
import 'package:ott/presentation/web_landing/utils/filmytell_theme.dart';

/// Reusable, CORS-safe, multi-candidate Network Image Loader for Filmytell Web.
class FilmytellNetworkImage extends StatefulWidget {
  const FilmytellNetworkImage({
    super.key,
    this.imageUrl,
    this.imageUrls,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.borderRadius = BorderRadius.zero,
    this.fallbackIcon = Icons.movie_outlined,
    this.showShimmer = true,
  });

  final String? imageUrl;
  final List<String>? imageUrls;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius borderRadius;
  final IconData fallbackIcon;
  final bool showShimmer;

  /// Sanitizes any raw image URL (handles relative paths, protocol upgrades, whitespace).
  static String? sanitizeUrl(String? raw) =>
      ResponsivePosterImage.sanitizeUrl(raw);

  /// Extracts and prioritizes valid candidate URLs.
  /// Prioritizes working S3 / direct HTTPS storage domains.
  static List<String> sanitizeAndPrioritizeUrls(List<String?> rawUrls) =>
      ResponsivePosterImage.sanitizeAndPrioritizeUrls(rawUrls);

  @override
  State<FilmytellNetworkImage> createState() => _FilmytellNetworkImageState();
}

class _FilmytellNetworkImageState extends State<FilmytellNetworkImage> {
  late List<String> _candidates;
  int _currentIndex = 0;
  ImageStream? _imageStream;
  ImageStreamListener? _streamListener;

  @override
  void initState() {
    super.initState();
    _resolveCandidates();
  }

  @override
  void didUpdateWidget(covariant FilmytellNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.imageUrls != widget.imageUrls) {
      _resolveCandidates();
    }
  }

  @override
  void dispose() {
    _cleanStream();
    super.dispose();
  }

  void _cleanStream() {
    if (_imageStream != null && _streamListener != null) {
      _imageStream!.removeListener(_streamListener!);
    }
    _imageStream = null;
    _streamListener = null;
  }

  void _resolveCandidates() {
    _cleanStream();
    final rawList = <String?>[
      if (widget.imageUrl != null) widget.imageUrl,
      if (widget.imageUrls != null) ...widget.imageUrls!,
    ];
    _candidates = FilmytellNetworkImage.sanitizeAndPrioritizeUrls(rawList);
    _currentIndex = 0;

    if (_candidates.isNotEmpty) {
      _listenToActiveImageDimensions(_candidates[_currentIndex]);
    }
  }

  void _listenToActiveImageDimensions(String url) {
    if (ResponsivePosterImage.dimensionCache.containsKey(url)) return;

    try {
      _cleanStream();
      final stream = NetworkImage(url).resolve(const ImageConfiguration());
      _imageStream = stream;
      _streamListener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          final int width = info.image.width;
          final int height = info.image.height;
          if (width > 0 && height > 0) {
            ResponsivePosterImage.dimensionCache[url] =
                Size(width.toDouble(), height.toDouble());
            ResponsivePosterImage.aspectRatioCache[url] = width / height;
          }
        },
        onError: (_, __) {},
      );
      stream.addListener(_streamListener!);
    } catch (_) {}
  }

  void _handleError() {
    if (_currentIndex + 1 < _candidates.length) {
      if (mounted) {
        setState(() {
          _currentIndex++;
          _listenToActiveImageDimensions(_candidates[_currentIndex]);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_candidates.isEmpty || _currentIndex >= _candidates.length) {
      return _buildFallback();
    }

    final activeUrl = _candidates[_currentIndex];

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: FilmytellTheme.surfaceDark,
        alignment: widget.alignment,
        child: Image.network(
          activeUrl,
          key: ValueKey(activeUrl),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
          filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return widget.showShimmer ? _buildShimmer() : _buildFallback();
        },
        errorBuilder: (context, error, stackTrace) {
          // If more candidates exist, trigger fallback transition
          if (_currentIndex + 1 < _candidates.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _handleError());
            return widget.showShimmer ? _buildShimmer() : _buildFallback();
          }
          return _buildFallback();
        },
      ),
    ),
  );
}

  Widget _buildShimmer() {
    return _ShimmerBox(
      width: widget.width,
      height: widget.height,
      borderRadius: widget.borderRadius,
    );
  }

  Widget _buildFallback() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: FilmytellTheme.surfaceDark,
        borderRadius: widget.borderRadius,
        border: Border.all(color: FilmytellTheme.borderSubtle),
      ),
      child: Center(
        child: Icon(
          widget.fallbackIcon,
          color: FilmytellTheme.textSubtle,
          size: (widget.height != null && widget.height! < 120) ? 20 : 28,
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    this.width,
    this.height,
    required this.borderRadius,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [
                  (_controller.value - 0.3).clamp(0.0, 1.0),
                  _controller.value.clamp(0.0, 1.0),
                  (_controller.value + 0.3).clamp(0.0, 1.0),
                ],
                colors: const [
                  Color(0xFF121216),
                  Color(0xFF1F1F26),
                  Color(0xFF121216),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
