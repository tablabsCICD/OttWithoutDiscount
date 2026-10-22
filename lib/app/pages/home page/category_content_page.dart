import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ott/app/widgets/movieCard.dart';
import 'package:ott/app/route/route_observer.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';

class CategoryContentPage extends StatefulWidget {
  final String categoryTitle;
  final List<Content> contents;

  const CategoryContentPage({
    super.key,
    required this.categoryTitle,
    required this.contents,
  });

  @override
  State<CategoryContentPage> createState() => _CategoryContentPageState();
}

class _CategoryContentPageState extends State<CategoryContentPage>
    with RouteAware, WidgetsBindingObserver {
  static const double _autoPlayVisibilityThreshold = 0.70;
  static const double _cardHeight = MovieCard.standardHeight;
  static const double _gap = 16;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int?> _activeIndex = ValueNotifier<int?>(null);
  late List<Content> _contents;
  int _crossAxisCount = 1;
  PageRoute<dynamic>? _route;
  bool _routeIsActive = true;
  bool _appIsActive = true;
  bool get _pageIsActive => _routeIsActive && _appIsActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _contents = List<Content>.from(widget.contents);
    _scrollController.addListener(_updateActiveIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateActiveIndex();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      if (_route != null) routeObserver.unsubscribe(this);
      _route = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _routeIsActive = false;
    _activeIndex.value = null;
  }

  @override
  void didPopNext() {
    _routeIsActive = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateActiveIndex();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsActive = state == AppLifecycleState.resumed;
    if (!_pageIsActive) {
      _activeIndex.value = null;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateActiveIndex();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CategoryContentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contents != widget.contents) {
      _contents = List<Content>.from(widget.contents);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateActiveIndex();
      });
    }
  }

  void _updateActiveIndex() {
    if (!_pageIsActive || !_scrollController.hasClients || _contents.isEmpty) {
      if (_activeIndex.value != null) {
        _activeIndex.value = null;
      }
      return;
    }

    final viewport = _scrollController.position.viewportDimension;
    if (viewport <= 0) return;

    final rowExtent = _cardHeight + _gap;
    final viewStart = _scrollController.offset;
    final viewEnd = viewStart + viewport;
    final crossCount = _crossAxisCount < 1 ? 1 : _crossAxisCount;
    final totalRows = (_contents.length / crossCount).ceil();
    final firstRow =
        (viewStart / rowExtent).floor().clamp(0, totalRows - 1).toInt();
    final lastRow =
        ((viewEnd - 0.001) / rowExtent).floor().clamp(0, totalRows - 1).toInt();
    final first = (firstRow * crossCount).clamp(0, _contents.length - 1).toInt();
    final last =
        (((lastRow + 1) * crossCount) - 1).clamp(0, _contents.length - 1).toInt();
    int? index;
    double bestVisibility = 0;
    for (var candidate = first; candidate <= last; candidate++) {
      if (!(_contents[candidate].trailerUrl?.trim().isNotEmpty ?? false)) {
        continue;
      }
      final candidateRow = (candidate / crossCount).floor();
      final itemStart = candidateRow * rowExtent;
      final itemEnd = itemStart + _cardHeight;
      final overlap = (itemEnd.clamp(viewStart, viewEnd) -
              itemStart.clamp(viewStart, viewEnd))
          .clamp(0.0, _cardHeight);
      final visibility = overlap / _cardHeight;
      if (visibility >= _autoPlayVisibilityThreshold &&
          visibility > bestVisibility) {
        index = candidate;
        bestVisibility = visibility;
      }
    }

    if (_activeIndex.value != index) {
      _activeIndex.value = index;
    }
  }

  void _replaceContent(Content updatedContent) {
    final contentId = updatedContent.id;
    if (contentId == null || !mounted) return;

    final index = _contents.indexWhere((content) => content.id == contentId);
    if (index == -1) return;

    setState(() {
      _contents[index] = updatedContent;
    });
    _updateActiveIndex();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _activeIndex.value = null;
    _scrollController.dispose();
    _activeIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: !(kIsWeb || ResponsiveWidget.isTv(context)),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          widget.categoryTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _contents.isEmpty
          ? const Center(
              child: Text('No content available'),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = ResponsiveWidget.isDesktop(context);
                  final isTablet = ResponsiveWidget.isTablet(context);
                  final isMobile = ResponsiveWidget.isMobile(context);
                  final horizontalPadding = isDesktop
                      ? 18.0
                      : ResponsiveWidget.isTablet(context)
                          ? 14.0
                          : 10.0;
                  final availableWidth =
                      constraints.maxWidth - (horizontalPadding * 2);

                  /*   final header = Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.primaryColor.withValues(alpha: 0.12),
                          theme.cardColor,
                        ],
                      ),
                      border: Border.all(
                        color: theme.canvasColor.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: theme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.categoryTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.canvasColor,
                                  fontSize: isMobile ? 17 : 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Browse the full collection',
                                style: TextStyle(
                                  color:
                                      theme.canvasColor.withValues(alpha: 0.64),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
             */

                  // Standardized card dimensions per platform & responsive breakpoint
                  final double cardWidth;
                  const double cardHeight = MovieCard.standardHeight; // 235.0
                  const double gap = 16.0;

                  if (availableWidth >= 1800) {
                    cardWidth = MovieCard.desktopCardWidth; // 300.0
                  } else if (availableWidth >= 1024) {
                    cardWidth = MovieCard.laptopCardWidth; // 300.0
                  } else if (availableWidth >= 600) {
                    cardWidth = MovieCard.tabletCardWidth; // 300.0
                  } else {
                    cardWidth = MovieCard.mobileCardWidth; // 300.0
                  }

                  int crossAxisCount =
                      ((availableWidth + gap) / (cardWidth + gap)).floor();
                  if (crossAxisCount < 1) crossAxisCount = 1;
                  _crossAxisCount = crossAxisCount;

                  // Keep card dimensions stable within each breakpoint:
                  // Center the grid of consistently sized cards, absorbing remaining space into side padding
                  final totalGridWidth =
                      (crossAxisCount * cardWidth) + ((crossAxisCount - 1) * gap);
                  final centeringPadding =
                      math.max(0.0, (availableWidth - totalGridWidth) / 2);
                  final effectiveHorizontalPadding =
                      horizontalPadding + centeringPadding;

                  return CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          effectiveHorizontalPadding,
                          12,
                          effectiveHorizontalPadding,
                          24,
                        ),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final content = _contents[index];
                              return SizedBox(
                                width: cardWidth,
                                height: cardHeight,
                                child: Center(
                                  child: MovieCard(
                                    movie: content,
                                    index: index,
                                    activeIndexListenable: _activeIndex,
                                    cardWidth: cardWidth,
                                    cardMargin: 0,
                                    onContentUpdated: _replaceContent,
                                  ),
                                ),
                              );
                            },
                            childCount: _contents.length,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: gap,
                            crossAxisSpacing: gap,
                            mainAxisExtent: cardHeight,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}
