import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';

/// The app bar shared by the four content detail pages (Movie, Short Film,
/// Series, Mini Series):
///
///   [ ← ]  [ Content title… ]                 [ ★ 4.5 ]
///
/// Compact Filmytell red bar ([FilmytellAppBarMetrics.compact]) with a white
/// back button, the white content title next to it and the content's star
/// rating on the right. The title is single-line and ellipsized, so it never
/// overlaps the back button or the rating. A missing / zero rating is not
/// shown. Age rating is shown in the page content, not here.
class ContentDetailAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ContentDetailAppBar({
    super.key,
    this.title,
    this.rating,
    this.onBack,
  });

  final String? title;

  /// Average rating out of 5 from the content API. Hidden when null or not
  /// positive.
  final double? rating;

  /// Overrides the default back behavior (Navigator.maybePop).
  final VoidCallback? onBack;

  static const double ratingIconSize = 16;
  static const double ratingFontSize = 14;

  @override
  Size get preferredSize =>
      const Size.fromHeight(FilmytellAppBarMetrics.compact);

  String? get _titleText {
    final value = title?.trim();
    if (value == null || value.isEmpty || value == 'null') return null;
    return value;
  }

  /// 5 -> "5.0", 3.5 -> "3.5", 4.25 -> "4.3".
  String? get _ratingText {
    final value = rating;
    if (value == null || value.isNaN || value <= 0) return null;
    return value.clamp(0, 5).toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    const implyBack = !kIsWeb;
    final hasBack = onBack != null ||
        (implyBack &&
            (ModalRoute.of(context)?.impliesAppBarDismissal ?? false));
    final ratingText = _ratingText;

    return FilmytellAppBar(
      title: _titleText,
      automaticallyImplyLeading: implyBack,
      leading: onBack == null ? null : BackButton(onPressed: onBack),
      centerTitle: false,
      // Title sits right after the back button (standard 16pt inset when
      // there is none).
      titleSpacing: hasBack ? 0 : 16,
      actions: [
        if (ratingText != null) ...[
          const SizedBox(width: 12),
          Center(
            child: Semantics(
              label: 'Rating $ratingText out of 5',
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: ratingIconSize,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    ratingText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: ratingFontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(width: 16),
      ],
    );
  }
}
