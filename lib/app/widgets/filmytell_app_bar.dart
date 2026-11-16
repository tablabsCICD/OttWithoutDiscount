import 'package:flutter/material.dart';

/// Shared app bar sizes and styles for Filmytell.
///
/// * [main] (56): top-level screens reached from the bottom navigation or
///   the side menu (Home, Shorts, Search, Watchlist, Purchase History,
///   Profile, Wallet, Upcoming, Help). Matches the Home header height.
/// * [compact] (48): secondary / nested screens (details, notifications,
///   billing, settings sub-pages). Still a full 48pt touch target.
///
/// Collapsing hero headers (`SliverAppBar` with an `expandedHeight`) keep
/// their hero and use these values for their pinned toolbar height.
class FilmytellAppBarMetrics {
  FilmytellAppBarMetrics._();

  static const double main = kToolbarHeight; // 56
  static const double compact = 48;

  static const double mainTitleSize = 20;
  static const double compactTitleSize = 18;
  static const double iconSize = 22;

  static double heightFor(FilmytellAppBarVariant variant) =>
      variant == FilmytellAppBarVariant.main ? main : compact;
}

enum FilmytellAppBarVariant { main, compact }

/// Standard Filmytell app bar: brand-coloured bar, white bold title,
/// consistent height per [variant], no Material 3 scroll tint / elevation.
///
/// Wraps [AppBar], so safe-area / status-bar insets, the platform back
/// button and `automaticallyImplyLeading` behave exactly as before.
class FilmytellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FilmytellAppBar({
    super.key,
    this.variant = FilmytellAppBarVariant.compact,
    this.title,
    this.titleWidget,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions,
    this.centerTitle = true,
    this.backgroundColor,
    this.foregroundColor,
    this.bottom,
    this.titleSpacing,
  });

  /// Top-level screen app bar (56pt).
  const FilmytellAppBar.main({
    Key? key,
    String? title,
    Widget? titleWidget,
    Widget? leading,
    bool automaticallyImplyLeading = true,
    List<Widget>? actions,
    bool centerTitle = true,
    Color? backgroundColor,
    Color? foregroundColor,
    PreferredSizeWidget? bottom,
    double? titleSpacing,
  }) : this(
          key: key,
          variant: FilmytellAppBarVariant.main,
          title: title,
          titleWidget: titleWidget,
          leading: leading,
          automaticallyImplyLeading: automaticallyImplyLeading,
          actions: actions,
          centerTitle: centerTitle,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          bottom: bottom,
          titleSpacing: titleSpacing,
        );

  final FilmytellAppBarVariant variant;

  /// Plain text title (single line, ellipsized). Ignored if [titleWidget]
  /// is given.
  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final List<Widget>? actions;
  final bool centerTitle;

  /// Defaults to the theme's brand colour (`primaryColor`).
  final Color? backgroundColor;

  /// Defaults to white.
  final Color? foregroundColor;
  final PreferredSizeWidget? bottom;
  final double? titleSpacing;

  double get _toolbarHeight => FilmytellAppBarMetrics.heightFor(variant);

  @override
  Size get preferredSize =>
      Size.fromHeight(_toolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = foregroundColor ?? Colors.white;
    final iconTheme =
        IconThemeData(color: fg, size: FilmytellAppBarMetrics.iconSize);

    return AppBar(
      toolbarHeight: _toolbarHeight,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      title: titleWidget ??
          (title == null
              ? null
              : Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis)),
      // Based on the theme so the app font family is kept.
      titleTextStyle: (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
        color: fg,
        fontSize: variant == FilmytellAppBarVariant.main
            ? FilmytellAppBarMetrics.mainTitleSize
            : FilmytellAppBarMetrics.compactTitleSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      titleSpacing: titleSpacing,
      centerTitle: centerTitle,
      actions: actions,
      bottom: bottom,
      backgroundColor: backgroundColor ?? theme.primaryColor,
      foregroundColor: fg,
      iconTheme: iconTheme,
      actionsIconTheme: iconTheme,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
    );
  }
}
