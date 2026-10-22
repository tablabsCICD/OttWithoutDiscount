import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ott/app/core/utils/release_date_formatter.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:ott/presentation/web_landing/utils/filmytell_theme.dart';
import 'package:ott/presentation/web_landing/widgets/filmytell_network_image.dart';
import 'package:ott/presentation/web_landing/widgets/landing_header.dart';

class HeroBanner extends StatefulWidget {
  const HeroBanner({
    super.key,
    required this.items,
    required this.onWatchNow,
    required this.onPlayTrailer,
  });

  final List<Content> items;
  final ValueChanged<Content> onWatchNow;
  final ValueChanged<Content> onPlayTrailer;

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  Timer? _timer;
  int _index = 0;
  bool _loggedFirstContentRender = false;

  @override
  void initState() {
    super.initState();
    _startRotation();
  }

  @override
  void didUpdateWidget(covariant HeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _index = 0;
      _startRotation();
    }
    _logFirstContentRender();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _logFirstContentRender();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRotation() {
    _timer?.cancel();
    if (widget.items.length < 2) return;
    _timer = Timer.periodic(FilmytellTheme.heroRotation, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.items.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 768;
    final isTablet = width >= 768 && width < 1100;
    final horizontalPadding = isMobile ? 18.0 : (isTablet ? 32.0 : 56.0);
    final headerHeight = LandingHeader.getHeaderHeight(context);
    final topBreathingSpace = isMobile ? 32.0 : (isTablet ? 48.0 : 64.0);
    final heroTopPadding = headerHeight + topBreathingSpace;
    final heroBottomPadding = isMobile ? 36.0 : (isTablet ? 44.0 : 54.0);

    final item = widget.items.isEmpty ? null : widget.items[_index];
    final poster = item == null ? null : _posterFor(item);

    return Container(
      decoration: const BoxDecoration(
        color: FilmytellTheme.background,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          heroTopPadding,
          horizontalPadding,
          heroBottomPadding,
        ),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      if (poster != null) ...[
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: _HeroPosterCard(
                              key: ValueKey(
                                  'hero_poster_${item?.id ?? item?.title}'),
                              posterUrl: poster,
                              posterUrls: item?.posterUrlList,
                              aspectRatio: 1.38,
                              onTap: item == null
                                  ? null
                                  : () => widget.onWatchNow(item),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOutCubic,
                        child: item == null
                            ? const _HeroCopySkeleton()
                            : _HeroContentBlock(
                                key: ValueKey(item.id ?? item.title),
                                item: item,
                                compact: true,
                                onWatchNow: () => widget.onWatchNow(item),
                                onPlayTrailer: () => widget.onPlayTrailer(item),
                              ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 50,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeOutCubic,
                          child: item == null
                              ? const _HeroCopySkeleton()
                              : _HeroContentBlock(
                                  key: ValueKey(item.id ?? item.title),
                                  item: item,
                                  compact: false,
                                  onWatchNow: () => widget.onWatchNow(item),
                                  onPlayTrailer: () =>
                                      widget.onPlayTrailer(item),
                                ),
                        ),
                      ),
                      const SizedBox(width: 36),
                      Expanded(
                        flex: 50,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            child: poster == null
                                ? const _HeroPosterFallback()
                                : ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isTablet
                                          ? 420
                                          : (width >= 1400 ? 580 : 500),
                                    ),
                                    child: _HeroPosterCard(
                                      key: ValueKey(
                                        'hero_poster_${item?.id ?? item?.title}',
                                      ),
                                      posterUrl: poster,
                                      posterUrls: item?.posterUrlList,
                                      aspectRatio: 1.38,
                                      onTap: item == null
                                          ? null
                                          : () => widget.onWatchNow(item),
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

  String? _posterFor(Content content) {
    final candidates = FilmytellNetworkImage.sanitizeAndPrioritizeUrls(
      content.posterUrlList ?? const <String>[],
    );
    if (candidates.isNotEmpty) return candidates.first;
    return null;
  }

  void _logFirstContentRender() {
    if (_loggedFirstContentRender || widget.items.isEmpty) return;
    _loggedFirstContentRender = true;
  }
}

class _HeroContentBlock extends StatelessWidget {
  const _HeroContentBlock({
    super.key,
    required this.item,
    required this.onWatchNow,
    required this.onPlayTrailer,
    required this.compact,
  });

  final Content item;
  final VoidCallback onWatchNow;
  final VoidCallback onPlayTrailer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final genres = (item.genreList ?? const <String>[]).take(4).toList();
    final releaseDate = formatReleaseDate(item.releaseDate);
    final lang = AppLocalizations.of(context)!;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Movie Title (Netflix-inspired bold, high-contrast, compact hierarchy)
          Text(
            item.title ?? lang.filmytellOriginals,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FilmytellTheme.heroHeading(
              isMobile: compact,
            ),
          ),
          const SizedBox(height: 14),
          // Metadata Badges (Rating, Age, Runtime, Release, Type)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _RatingBadge(rating: item.ratings ?? 0),
              _HeroMetaBadge(label: item.ageRating ?? 'U/A'),
              if ((item.runtime ?? 0) > 0)
                _HeroMetaBadge(label: '${item.runtime} min'),
              if (releaseDate.isNotEmpty) _HeroMetaBadge(label: releaseDate),
              _HeroMetaBadge(label: item.type ?? 'Movie'),
            ],
          ),
          const SizedBox(height: 16),
          // Synopsis / Description with Expandable "Read More"
          _HeroSynopsis(
            key: ValueKey(item.id ?? item.title ?? 'hero_synopsis'),
            description: item.description ?? lang.premiumStoriesDefault,
            compact: compact,
          ),
          // Genre Chips
          if (genres.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final genre in genres) _HeroGenreChip(label: genre),
              ],
            ),
          ],
          // Rental price tag if available
          if (item.price != null) ...[
            const SizedBox(height: 14),
            _HeroPriceBadge(price: item.price!),
          ],
          const SizedBox(height: 24),
          // Hero CTA Action Buttons
          Wrap(
            spacing: 14,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _HeroPrimaryButton(
                label: lang.watchNow,
                onPressed: onWatchNow,
              ),
              _HeroSecondaryButton(
                label: lang.playTrailer,
                onPressed: onPlayTrailer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF241A08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: FilmytellTheme.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: FilmytellTheme.gold, size: 14),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetaBadge extends StatelessWidget {
  const _HeroMetaBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: FilmytellTheme.textBody,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HeroSynopsis extends StatefulWidget {
  const _HeroSynopsis({
    super.key,
    required this.description,
    this.compact = false,
  });

  final String description;
  final bool compact;

  @override
  State<_HeroSynopsis> createState() => _HeroSynopsisState();
}

class _HeroSynopsisState extends State<_HeroSynopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.description.trim();
    final isLong = text.length > 130;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          alignment: Alignment.topLeft,
          child: Text(
            text,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: FilmytellTheme.bodyLarge(
              isMobile: widget.compact,
            ),
          ),
        ),
        if (isLong) ...[
          const SizedBox(height: 4),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _expanded
                          ? AppLocalizations.of(context)!.readLess
                          : AppLocalizations.of(context)!.readMore,
                      style: FilmytellTheme.font(
                        color: FilmytellTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: FilmytellTheme.primary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HeroGenreChip extends StatelessWidget {
  const _HeroGenreChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF18181D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: FilmytellTheme.font(
          color: Colors.white.withValues(alpha: 0.88),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeroPriceBadge extends StatelessWidget {
  const _HeroPriceBadge({required this.price});
  final double price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1416),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: FilmytellTheme.primary.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: FilmytellTheme.primary.withValues(alpha: 0.20),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_offer_rounded,
            color: FilmytellTheme.primary,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            AppLocalizations.of(context)!.rent,
            style: FilmytellTheme.font(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Rs ${price.toStringAsFixed(0)}',
            style: FilmytellTheme.font(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPrimaryButton extends StatefulWidget {
  const _HeroPrimaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_HeroPrimaryButton> createState() => _HeroPrimaryButtonState();
}

class _HeroPrimaryButtonState extends State<_HeroPrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: _hovered
                ? const LinearGradient(
                    colors: [Color(0xFFFF2432), Color(0xFFE50914)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFFE50914), Color(0xFFB8050F)],
                  ),
            boxShadow: [
              BoxShadow(
                color: FilmytellTheme.primary
                    .withValues(alpha: _hovered ? 0.50 : 0.25),
                blurRadius: _hovered ? 20 : 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: widget.onPressed,
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: Text(widget.label),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              textStyle: FilmytellTheme.buttonText(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSecondaryButton extends StatefulWidget {
  const _HeroSecondaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_HeroSecondaryButton> createState() => _HeroSecondaryButtonState();
}

class _HeroSecondaryButtonState extends State<_HeroSecondaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: OutlinedButton.icon(
          onPressed: widget.onPressed,
          icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
          label: Text(widget.label),
          style: OutlinedButton.styleFrom(
            backgroundColor: _hovered
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.06),
            foregroundColor: Colors.white,
            side: BorderSide(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.25),
              width: 1.2,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            textStyle: FilmytellTheme.buttonText(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPosterCard extends StatelessWidget {
  const _HeroPosterCard({
    super.key,
    required this.posterUrl,
    this.posterUrls,
    this.aspectRatio = 1.38,
    this.onTap,
  });

  final String posterUrl;
  final List<String>? posterUrls;
  final double aspectRatio;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.70),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Container(
            color: const Color(0xFF0D0D12),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: FilmytellNetworkImage(
                imageUrl: posterUrl,
                imageUrls: posterUrls,
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCopySkeleton extends StatelessWidget {
  const _HeroCopySkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 240);
  }
}

class _HeroPosterFallback extends StatelessWidget {
  const _HeroPosterFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FilmytellTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FilmytellTheme.borderSubtle),
      ),
      child: const AspectRatio(
        aspectRatio: 1.38,
        child: Center(
          child: Icon(Icons.movie_filter_outlined,
              color: Colors.white38, size: 38),
        ),
      ),
    );
  }
}
