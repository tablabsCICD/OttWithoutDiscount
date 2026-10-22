import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:ott/app/core/constant/api_constant.dart';

/// A reusable, responsive image widget that automatically fits any movie poster
/// or backdrop within its designated card constraints across Android, iOS, and Web.
///
/// Features:
/// - Smart poster display strategy:
///   * Foreground poster renders with [BoxFit.contain] so corners, embedded text,
///     and key artwork are never cropped, stretched, or distorted.
///   * Centers the foreground poster and scales it to the largest size that fits
///     within the existing container.
///   * When the poster's aspect ratio differs from the card's image area,
///     a subtle, blurred ([ui.ImageFilter.blur]) and darkened [BoxFit.cover]
///     ambient background layer fills all unused space without distracting.
///   * When the poster already matches the container's aspect ratio, it displays
///     normally without unnecessary background effects.
/// - In-memory dimensions and aspect ratio caching ([dimensionCache], [aspectRatioCache]).
/// - Multi-candidate URL fallback (retries with next candidate in [imageUrls] on error).
/// - Memory & network efficient: background and foreground layers reuse the exact same
///   image provider cache key, eliminating redundant network requests.
/// - Silent loaders on background layer prevent duplicate spinners or error callbacks.
/// - Supports [isDecorativeBackdrop] for banners where decorative cover cropping is permitted.
class ResponsivePosterImage extends StatefulWidget {
  final String? imageUrl;
  final List<String>? imageUrls;
  final BoxFit fit;
  final Alignment alignment;
  final Color backgroundColor;
  final Color? loadingProgressColor;
  final Color? errorIconColor;
  final BorderRadius borderRadius;
  final Widget Function()? fallbackBuilder;
  final Widget? overlay;
  final bool isDecorativeBackdrop;
  final bool enableAmbientBackdrop;
  final ValueChanged<Size>? onDimensionResolved;

  const ResponsivePosterImage({
    super.key,
    this.imageUrl,
    this.imageUrls,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.backgroundColor = Colors.black,
    this.loadingProgressColor,
    this.errorIconColor,
    this.borderRadius = BorderRadius.zero,
    this.fallbackBuilder,
    this.overlay,
    this.isDecorativeBackdrop = false,
    this.enableAmbientBackdrop = true,
    this.onDimensionResolved,
  });

  /// In-memory cache of resolved image dimensions (width, height)
  static final Map<String, Size> dimensionCache = {};

  /// In-memory cache of resolved aspect ratios (width / height)
  static final Map<String, double> aspectRatioCache = {};

  /// Returns cached dimensions for [url] if already resolved, else null.
  static Size? getDimensions(String? url) {
    if (url == null || url.isEmpty) return null;
    return dimensionCache[url];
  }

  /// Returns cached aspect ratio for [url] if already resolved, else null.
  static double? getAspectRatio(String? url) {
    if (url == null || url.isEmpty) return null;
    if (aspectRatioCache.containsKey(url)) {
      return aspectRatioCache[url];
    }
    final dim = dimensionCache[url];
    if (dim != null && dim.height > 0) {
      final ratio = dim.width / dim.height;
      aspectRatioCache[url] = ratio;
      return ratio;
    }
    return null;
  }

  /// Whether the cached image has a landscape aspect ratio (> 1.05).
  static bool isLandscape(String? url) {
    final ratio = getAspectRatio(url);
    return ratio != null && ratio > 1.05;
  }

  /// Whether the cached image has a portrait aspect ratio (< 0.95).
  static bool isPortrait(String? url) {
    final ratio = getAspectRatio(url);
    return ratio != null && ratio < 0.95;
  }

  /// Whether the cached image has an approximately square aspect ratio (0.95 - 1.05).
  static bool isSquare(String? url) {
    final ratio = getAspectRatio(url);
    return ratio != null && ratio >= 0.95 && ratio <= 1.05;
  }

  /// Sanitizes any raw image URL (handles relative paths, protocol upgrades, whitespace).
  static String? sanitizeUrl(String? raw) {
    if (raw == null) return null;
    var url = raw.trim();
    if (url.isEmpty) return null;

    if (url.startsWith('//')) {
      url = 'https:$url';
    } else if (url.startsWith('http://')) {
      url = 'https://${url.substring(7)}';
    } else if (!url.startsWith('https://')) {
      final base = ApiConstant.baseUrl.endsWith('/')
          ? ApiConstant.baseUrl.substring(0, ApiConstant.baseUrl.length - 1)
          : ApiConstant.baseUrl;

      if (url.startsWith('/')) {
        url = '$base$url';
      } else {
        url = '$base/$url';
      }
    }

    return Uri.tryParse(url)?.toString() ?? Uri.encodeFull(url);
  }

  /// Sanitizes and sorts URLs so valid, working domains (S3, Filmytell CDN) take priority.
  static List<String> sanitizeAndPrioritizeUrls(List<String?> rawUrls) {
    final results = <String>[];
    for (final raw in rawUrls) {
      final sanitized = sanitizeUrl(raw);
      if (sanitized != null && sanitized.isNotEmpty && !results.contains(sanitized)) {
        results.add(sanitized);
      }
    }

    results.sort((a, b) {
      final aIsS3 = a.contains('amazonaws.com') || a.contains('filmytell.com');
      final bIsS3 = b.contains('amazonaws.com') || b.contains('filmytell.com');
      if (aIsS3 && !bIsS3) return -1;
      if (!aIsS3 && bIsS3) return 1;
      return 0;
    });

    return results;
  }

  @override
  State<ResponsivePosterImage> createState() => _ResponsivePosterImageState();
}

class _ResponsivePosterImageState extends State<ResponsivePosterImage> {
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
  void didUpdateWidget(covariant ResponsivePosterImage oldWidget) {
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
    _candidates = ResponsivePosterImage.sanitizeAndPrioritizeUrls(rawList);
    _currentIndex = 0;

    if (_candidates.isNotEmpty) {
      _listenToActiveImageDimensions(_candidates[_currentIndex]);
    }
  }

  void _listenToActiveImageDimensions(String url) {
    if (ResponsivePosterImage.dimensionCache.containsKey(url)) {
      final cachedSize = ResponsivePosterImage.dimensionCache[url]!;
      widget.onDimensionResolved?.call(cachedSize);
      return;
    }

    try {
      _cleanStream();
      final stream = NetworkImage(url).resolve(const ImageConfiguration());
      _imageStream = stream;
      _streamListener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          final int width = info.image.width;
          final int height = info.image.height;
          if (width > 0 && height > 0) {
            final size = Size(width.toDouble(), height.toDouble());
            ResponsivePosterImage.dimensionCache[url] = size;
            ResponsivePosterImage.aspectRatioCache[url] = width / height;
            if (mounted) {
              setState(() {});
              widget.onDimensionResolved?.call(size);
            }
          }
        },
        onError: (dynamic _, StackTrace? __) {
          // Handled by errorBuilder in widget build
        },
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

  /// Builds a subtly blurred and darkened background layer using [BoxFit.cover]
  /// to seamlessly fill letterboxed/pillarboxed areas when poster aspect ratio
  /// differs from the card container.
  Widget _buildAmbientBackground(String activeUrl) {
    return Positioned.fill(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Scaled and blurred background image (scale 1.15 prevents edge blur bleed)
            Transform.scale(
              scale: 1.15,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Image.network(
                  activeUrl,
                  key: ValueKey('ambient_$activeUrl'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.low,
                  // Silent loaders to avoid duplicate spinners or multiple error calls
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox.shrink();
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            // Darkening scrim overlay so the background complements the foreground poster
            Container(
              color: Colors.black.withValues(alpha: 0.52),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the crisp foreground poster image using [foregroundFit] ([BoxFit.contain] by default).
  Widget _buildForegroundImage(
    String activeUrl,
    BoxFit foregroundFit,
    ThemeData theme,
  ) {
    return Image.network(
      activeUrl,
      key: ValueKey(activeUrl),
      fit: foregroundFit,
      alignment: widget.alignment,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
            color: widget.loadingProgressColor ?? theme.primaryColor,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        if (_currentIndex + 1 < _candidates.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _handleError());
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.loadingProgressColor ?? theme.primaryColor,
            ),
          );
        }
        return _buildFallback(theme);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_candidates.isEmpty || _currentIndex >= _candidates.length) {
      return _buildFallback(theme);
    }

    final activeUrl = _candidates[_currentIndex];

    // If marked as decorative backdrop (e.g. Continue Watching banner artwork),
    // cover fit is used directly and ambient background is bypassed.
    if (widget.isDecorativeBackdrop) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: widget.backgroundColor,
        alignment: widget.alignment,
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildForegroundImage(activeUrl, BoxFit.cover, theme),
              if (widget.overlay != null) widget.overlay!,
            ],
          ),
        ),
      );
    }

    // Smart poster display strategy:
    // - Foreground: original poster with BoxFit.contain so corners, text, and artwork are never cropped.
    // - Ambient background: if aspect ratio differs from card image area, blurred & darkened layer fills unused space.
    // - If aspect ratio matches container, displays normally without background layer.
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: widget.backgroundColor,
      alignment: widget.alignment,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double? containerRatio = (constraints.maxWidth > 0 &&
                    constraints.maxHeight > 0 &&
                    constraints.maxWidth.isFinite &&
                    constraints.maxHeight.isFinite)
                ? (constraints.maxWidth / constraints.maxHeight)
                : null;

            final double? imageRatio =
                ResponsivePosterImage.getAspectRatio(activeUrl);

            // Confirmed 16:9 landscape image (~1.70 to 1.85, 1600x900 = 1.777)
            final bool is16x9Image = imageRatio != null &&
                (imageRatio - (16 / 9)).abs() < 0.08;

            final bool is16x9Container = containerRatio != null &&
                (containerRatio - (16 / 9)).abs() < 0.08;

            // If the poster already matches the container's aspect ratio (within 5% tolerance),
            // display it normally without unnecessary background effects.
            final bool isAspectMatching = (containerRatio != null &&
                imageRatio != null &&
                (containerRatio - imageRatio).abs() < 0.08);

            final bool showAmbientBackground =
                widget.enableAmbientBackdrop && !isAspectMatching;

            // For confirmed 16:9 images inside matching 16:9 containers, use BoxFit.cover
            // to eliminate subpixel rounding seams and ensure edge-to-edge coverage.
            // For portrait posters (< 0.95), preserve widget.fit (BoxFit.contain) to prevent cropping.
            final effectiveFit = (widget.enableAmbientBackdrop &&
                    ((is16x9Image && is16x9Container) || isAspectMatching))
                ? BoxFit.cover
                : widget.fit;

            return Stack(
              fit: StackFit.expand,
              children: [
                if (showAmbientBackground)
                  _buildAmbientBackground(activeUrl),
                _buildForegroundImage(activeUrl, effectiveFit, theme),
                if (widget.overlay != null) widget.overlay!,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFallback(ThemeData theme) {
    if (widget.fallbackBuilder != null) {
      return widget.fallbackBuilder!();
    }

    final color = widget.errorIconColor ??
        theme.canvasColor.withValues(alpha: 0.3);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: widget.backgroundColor,
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Center(
          child: Icon(
            Icons.broken_image,
            color: color,
            size: 44,
          ),
        ),
      ),
    );
  }
}
