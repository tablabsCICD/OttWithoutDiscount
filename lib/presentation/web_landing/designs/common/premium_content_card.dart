import 'package:flutter/material.dart';
import 'package:ott/app/widgets/responsive_poster_image.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/presentation/web_landing/designs/theme/landing_theme.dart';

/// Premium interactive OTT content card supporting desktop hover scaling,
/// glowing borders, metadata badges, trailer trigger, and tap actions.
class PremiumContentCard extends StatefulWidget {
  const PremiumContentCard({
    super.key,
    required this.content,
    this.width = 200,
    this.height = 300,
    this.rankNumber,
    this.onTap,
    this.onPlayTrailer,
    this.showMetaOnHover = true,
  });

  final Content content;
  final double width;
  final double height;
  final int? rankNumber;
  final VoidCallback? onTap;
  final VoidCallback? onPlayTrailer;
  final bool showMetaOnHover;

  @override
  State<PremiumContentCard> createState() => _PremiumContentCardState();
}

class _PremiumContentCardState extends State<PremiumContentCard> {
  bool _hovered = false;

  String? get _posterUrl {
    final list = widget.content.posterUrlList;
    if (list != null && list.isNotEmpty) {
      for (final url in list) {
        if (url.trim().isNotEmpty) return url.trim();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = LandingThemeColors.of(context);
    final isDark = colors.isDark;
    final title = widget.content.title ?? 'Featured Title';
    final releaseDate = widget.content.releaseDate?.toString() ?? '';
    final year = releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
    final type = (widget.content.type ?? 'MOVIE').toUpperCase().replaceAll('_', ' ');
    final poster = _posterUrl;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: widget.width,
          height: widget.height,
          transform: Matrix4.identity()
            ..translate(0.0, _hovered ? -8.0 : 0.0)
            ..scale(_hovered ? 1.04 : 1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: colors.cardBackground,
            border: Border.all(
              color: _hovered
                  ? colors.primaryAccent.withOpacity(0.85)
                  : colors.border.withOpacity(isDark ? 0.6 : 0.9),
              width: _hovered ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? colors.primaryAccent.withOpacity(isDark ? 0.35 : 0.20)
                    : Colors.black.withOpacity(isDark ? 0.35 : 0.06),
                blurRadius: _hovered ? 24 : 10,
                offset: Offset(0, _hovered ? 12 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Responsive Poster Image (handles multi-candidate failover, preserves aspect ratio, contain fit)
                ResponsivePosterImage(
                  imageUrl: poster,
                  imageUrls: widget.content.posterUrlList,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  backgroundColor: colors.surface,
                  borderRadius: BorderRadius.circular(13),
                  fallbackBuilder: () => Container(
                    color: colors.surface,
                    child: Center(
                      child: Icon(
                        Icons.movie_filter_rounded,
                        size: 40,
                        color: colors.textMuted.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),

                // Ambient Gradient Overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(_hovered ? 0.4 : 0.1),
                          Colors.black.withOpacity(_hovered ? 0.92 : 0.75),
                        ],
                        stops: const [0.35, 0.65, 1.0],
                      ),
                    ),
                  ),
                ),

                // Top Badges (Rank or Content Type)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.rankNumber != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE50914), Color(0xFFFF334B)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE50914).withOpacity(0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            'TOP ${widget.rankNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Text(
                            type,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Quality Badges Top Right (4K / Ultra HD)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.6)),
                    ),
                    child: const Text(
                      '4K ULTRA HD',
                      style: TextStyle(
                        color: Color(0xFFFFB800),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),

                // Hover Play Button (Centered)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  top: _hovered ? (widget.height * 0.35) : (widget.height * 0.4),
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _hovered ? 1.0 : 0.0,
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primaryAccent,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primaryAccent.withOpacity(0.6),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Content Details
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (year.isNotEmpty) ...[
                            Text(
                              year,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            'U/A 13+',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (widget.onPlayTrailer != null && _hovered)
                            GestureDetector(
                              onTap: widget.onPlayTrailer,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.videocam_rounded,
                                      color: Colors.white,
                                      size: 11,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'Trailer',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
