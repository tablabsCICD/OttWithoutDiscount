import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ott/data/models/response/getRatingsAndReview.dart';
import 'package:ott/l10n/app_localizations.dart';

/// A single user review on the movie details page.
///
/// Layout: avatar + name/date on the left, star rating on the right, the
/// review text underneath (collapsed to a few lines with Read more / less).
/// Renders only what the API returned: no rating row without a rating, no
/// date without `createdAt`, no body without review text.
class ReviewListCard extends StatefulWidget {
  const ReviewListCard({super.key, required this.review});

  final Review review;

  @override
  State<ReviewListCard> createState() => _ReviewListCardState();
}

class _ReviewListCardState extends State<ReviewListCard> {
  static const int _collapsedLines = 4;
  static const double _avatarSize = 42;

  bool _expanded = false;

  String? get _displayName {
    final name = widget.review.username?.trim();
    if (name == null || name.isEmpty || name == 'null null') return null;
    return name;
  }

  String? get _reviewText {
    for (final value in [widget.review.title, widget.review.comment]) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty && text != 'null') return text;
    }
    return null;
  }

  String? get _formattedDate {
    final createdAt = widget.review.createdAt;
    if (createdAt == null) return null;
    return DateFormat('d MMM yyyy, h:mm a')
        .format(DateTime.fromMillisecondsSinceEpoch(createdAt));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = AppLocalizations.of(context)!;
    final onSurface = theme.canvasColor;
    final name = _displayName;
    final date = _formattedDate;
    final text = _reviewText;
    final rating = widget.review.rating;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(theme, name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? lang.detailsAnonymousUser,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (date != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.55),
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (rating != null) ...[
                const SizedBox(width: 8),
                _buildRating(rating, onSurface),
              ],
            ],
          ),
          if (text != null) ...[
            const SizedBox(height: 12),
            _buildReviewText(text, theme, lang),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, String? name) {
    final imageUrl = widget.review.userProfile?.trim();
    final placeholder = Container(
      width: _avatarSize,
      height: _avatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.primaryColor.withValues(alpha: 0.16),
      ),
      child: name != null
          ? Text(
              name.characters.first.toUpperCase(),
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            )
          : Icon(Icons.person_rounded, size: 24, color: theme.primaryColor),
    );

    if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null') {
      return placeholder;
    }
    return ClipOval(
      child: Image.network(
        imageUrl,
        width: _avatarSize,
        height: _avatarSize,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder,
      ),
    );
  }

  Widget _buildRating(int rating, Color onSurface) {
    final value = rating.clamp(0, 5);
    return Semantics(
      label: '$value out of 5 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final filled = index < value;
          return Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 16,
            color: filled ? Colors.amber : onSurface.withValues(alpha: 0.3),
          );
        }),
      ),
    );
  }

  Widget _buildReviewText(String text, ThemeData theme, AppLocalizations lang) {
    final style = TextStyle(
      color: theme.canvasColor.withValues(alpha: 0.82),
      fontSize: 14,
      height: 1.45,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: _collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final isLong = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: style,
              maxLines: _expanded || !isLong ? null : _collapsedLines,
              overflow: _expanded || !isLong
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            if (isLong)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _expanded ? lang.readLess : lang.readMore,
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
