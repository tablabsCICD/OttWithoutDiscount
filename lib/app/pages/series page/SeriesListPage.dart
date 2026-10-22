import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ott/app/core/constant/image_constant.dart';
import 'package:ott/app/core/utils/image_url_utils.dart';
import 'package:ott/app/core/utils/sharepreferences.dart';
import 'package:ott/app/pages/home%20page/category_content_page.dart';
import 'package:ott/app/pages/notification%20page/NotificationPage.dart';
import 'package:ott/app/pages/profile%20page/ProfilePage.dart';
import 'package:ott/app/pages/profile%20page/component/change_language.dart';
import 'package:ott/app/pages/search%20page/SearchPage.dart';
import 'package:ott/app/pages/wallet%20page/WalletPage.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/route/route_observer.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/provider/userProvider.dart';
import 'package:ott/app/provider/wallet_provider.dart';
import 'package:ott/app/widgets/movieCard.dart';
import 'package:ott/app/widgets/shimmer%20loader/home_shimmer.dart';
import 'package:ott/app/widgets/shimmer%20loader/shimmer_loader.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/models/response/get_dashboard_data.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class SeriesListPage extends StatelessWidget {
  const SeriesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardProvider(),
      child: const _SeriesListView(),
    );
  }
}

class _SeriesListView extends StatefulWidget {
  const _SeriesListView();

  @override
  State<_SeriesListView> createState() => _SeriesListViewState();
}

class _SeriesListViewState extends State<_SeriesListView>
    with RouteAware, WidgetsBindingObserver {
  static const String _seriesType = 'SERIES';
  static const double _autoPlayVisibilityThreshold = 0.70;

  final ScrollController _verticalController = ScrollController();
  final Map<int, ScrollController> _rowControllers = {};
  final Map<int, ValueNotifier<int?>> _rowActiveIndexes = {};
  final Map<int, int> _rowItemCounts = {};
  final Map<int, List<Content>> _rowItems = {};
  final Map<int, GlobalKey> _rowKeys = {};

  bool _isLoading = true;
  bool _visibleUpdateScheduled = false;
  int? _userId;
  PageRoute<dynamic>? _route;
  bool _routeIsActive = true;
  bool _appIsActive = true;
  bool get _pageIsActive => _routeIsActive && _appIsActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verticalController.addListener(_updateVisibleRows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadSeries();
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

  void _clearAutoPlay() {
    for (final notifier in _rowActiveIndexes.values) {
      notifier.value = null;
    }
  }

  @override
  void didPushNext() {
    _routeIsActive = false;
    _clearAutoPlay();
  }

  @override
  void didPopNext() {
    _routeIsActive = true;
    _scheduleVisibleUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsActive = state == AppLifecycleState.resumed;
    _pageIsActive ? _scheduleVisibleUpdate() : _clearAutoPlay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _clearAutoPlay();
    for (final controller in _rowControllers.values) {
      controller.dispose();
    }
    for (final notifier in _rowActiveIndexes.values) {
      notifier.dispose();
    }
    _verticalController.dispose();
    super.dispose();
  }

  Future<void> _loadSeries() async {
    final localSharePreferences = LocalSharePreferences();
    final user = await localSharePreferences.getUser();
    if (user == null || !mounted) return;

    _userId = user.id;
    await context.read<UserProvider>().getUserById(user.id!);
    if (!mounted) return;

    final selectedLanguages =
        context.read<UserProvider>().userObject.selectedLanguages ?? [];
    final languages =
        selectedLanguages.isEmpty ? <String>['English'] : selectedLanguages;

    final dashboardProvider = context.read<DashboardProvider>();
    await dashboardProvider.getContinueWatchedMovieList(_seriesType);
    await dashboardProvider.getDashboardData(_seriesType, languages, user.id!);

    if (!mounted) return;
    setState(() => _isLoading = false);
    _scheduleVisibleUpdate();
  }

  void _updateActiveIndex(
    ValueNotifier<int?> notifier,
    ScrollController controller,
    int itemCount,
    List<Content>? items,
  ) {
    if (!controller.hasClients || itemCount <= 0) {
      if (notifier.value != null) notifier.value = null;
      return;
    }

    final viewport = controller.position.viewportDimension;
    if (viewport <= 0) {
      if (notifier.value != null) notifier.value = null;
      return;
    }

    final viewStart = controller.offset;
    final viewEnd = viewStart + viewport;
    final cardExtent = MovieCard.cardExtentFor(context);
    final firstCandidate = math.max(
      0,
      (viewStart / cardExtent).floor(),
    );
    final lastCandidate = math.min(
      itemCount - 1,
      ((viewEnd - 0.001) / cardExtent).floor(),
    );

    int? bestIndex;
    double bestOverlap = 0;

    for (int candidate = firstCandidate;
        candidate <= lastCandidate;
        candidate++) {
      final overlap = _visibleOverlap(
        viewStart,
        viewEnd,
        candidate,
        cardExtent: cardExtent,
      );
      if (overlap <= 0) continue;

      final hasTrailer = items != null &&
          candidate < items.length &&
          (items[candidate].trailerUrl?.trim().isNotEmpty ?? false);
      if (!hasTrailer) continue;

      final visibility = overlap / cardExtent;
      if (visibility < _autoPlayVisibilityThreshold) continue;

      if (bestIndex == null ||
          overlap > bestOverlap ||
          (overlap == bestOverlap && candidate > bestIndex)) {
        bestOverlap = overlap;
        bestIndex = candidate;
      }
    }

    if (notifier.value != bestIndex) notifier.value = bestIndex;
  }

  double _visibleOverlap(
    double viewStart,
    double viewEnd,
    int index, {
    double? cardExtent,
  }) {
    final extent = cardExtent ?? MovieCard.cardExtentFor(context);
    final itemStart = index * extent;
    final itemEnd = itemStart + extent;
    final overlap = math.min(viewEnd, itemEnd) - math.max(viewStart, itemStart);
    return overlap <= 0 ? 0 : overlap;
  }

  Rect? _rowRect(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    final position = renderObject.localToGlobal(Offset.zero);
    return position & renderObject.size;
  }

  void _updateVisibleRows() {
    if (!mounted || !_pageIsActive) {
      _clearAutoPlay();
      return;
    }

    final screenHeight = MediaQuery.of(context).size.height;
    for (final entry in _rowActiveIndexes.entries) {
      final rowIndex = entry.key;
      final notifier = entry.value;
      final controller = _rowControllers[rowIndex];
      final itemCount = _rowItemCounts[rowIndex] ?? 0;
      final items = _rowItems[rowIndex];
      final key = _rowKeys[rowIndex];
      final rect = key == null ? null : _rowRect(key);
      final visibleHeight = rect == null
          ? 0.0
          : (math.min(rect.bottom, screenHeight) - math.max(rect.top, 0.0))
              .clamp(0.0, rect.height);
      final visibility =
          rect == null || rect.height <= 0 ? 0.0 : visibleHeight / rect.height;
      final isVisible = visibility >= _autoPlayVisibilityThreshold;

      if (!isVisible || controller == null) {
        if (notifier.value != null) notifier.value = null;
        continue;
      }

      _updateActiveIndex(notifier, controller, itemCount, items);
    }
  }

  void _scheduleVisibleUpdate() {
    if (_visibleUpdateScheduled) return;
    _visibleUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _visibleUpdateScheduled = false;
      _updateVisibleRows();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedThemeData = context.watch<ThemeProvider>().getTheme;

    return Scaffold(
      backgroundColor: selectedThemeData.scaffoldBackgroundColor,
      body: _isLoading
          ? const HomeShimmer()
          : CustomScrollView(
              controller: _verticalController,
              slivers: [
                _buildSliverAppBar(context, selectedThemeData),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Consumer<DashboardProvider>(
                      builder: (context, dashboardProvider, child) {
                        if (dashboardProvider.isLoading) {
                          return _buildDashboardSectionLoader(
                            context,
                            selectedThemeData,
                          );
                        }

                        if (dashboardProvider.dashboardData.isEmpty) {
                          return SizedBox(
                            height: MediaQuery.of(context).size.height * 0.65,
                            child: Center(
                              child: Text(
                                'No series available',
                                style: TextStyle(
                                  color: selectedThemeData.canvasColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: dashboardProvider.dashboardData.length,
                          itemBuilder: (context, index) {
                            final dashboardData =
                                dashboardProvider.dashboardData[index];
                            return _buildDashboardRow(
                              context,
                              dashboardProvider,
                              dashboardData,
                              index,
                              selectedThemeData,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  SliverAppBar _buildSliverAppBar(
    BuildContext context,
    ThemeData selectedThemeData,
  ) {
    final lang = AppLocalizations.of(context)!;
    final useTransparentAppBar = !ResponsiveWidget.isMobile(context);

    return SliverAppBar(
      automaticallyImplyLeading: false,
      forceMaterialTransparency: useTransparentAppBar,
      floating: false,
      pinned: true,
      stretch: true,
      surfaceTintColor: Colors.transparent,
      backgroundColor: useTransparentAppBar
          ? selectedThemeData.scaffoldBackgroundColor
          : selectedThemeData.primaryColor,
      titleSpacing: 10,
      title: useTransparentAppBar
          ? Text(
              lang.series,
              style: TextStyle(
                color: selectedThemeData.canvasColor,
                fontWeight: FontWeight.bold,
              ),
            )
          : SizedBox(
              width: 70,
              height: 70,
              child: Hero(
                tag: 'series_logo',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    ImageConstant.logo,
                    width: 75,
                    height: 75,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.search,
            color: useTransparentAppBar
                ? selectedThemeData.canvasColor
                : Colors.white,
          ),
          tooltip: lang.search,
          style: _appBarIconStyle(context),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchPage()),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(
            Icons.notifications_active,
            color: useTransparentAppBar
                ? selectedThemeData.canvasColor
                : Colors.white,
          ),
          tooltip: lang.notification,
          style: _appBarIconStyle(context),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotificationPage()),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: lang.selectPreferredLanguage,
          style: _appBarIconStyle(context),
          icon: Icon(
            Icons.language_sharp,
            color: useTransparentAppBar
                ? selectedThemeData.canvasColor
                : Colors.white,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ChangeLanguage()),
          ),
        ),
        const SizedBox(width: 4),
        Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            final walletProvider =
                Provider.of<WalletProvider>(context, listen: false);
            return Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.account_balance_wallet,
                    color: useTransparentAppBar
                        ? selectedThemeData.canvasColor
                        : Colors.white,
                  ),
                  tooltip: '₹ ${walletProvider.walletBalance.toStringAsFixed(2)}',
                  style: _appBarIconStyle(context),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => WalletPage()),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  textStyle: TextStyle(
                    fontSize: 10,
                    color: selectedThemeData.scaffoldBackgroundColor,
                  ),
                  message:
                      '${userProvider.userObj.firstName} ${userProvider.userObj.lastName}',
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfilePage()),
                    ),
                    child: Hero(
                      tag: 'series_profile',
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: selectedThemeData.canvasColor,
                          child: ClipOval(
                            child: Builder(
                              builder: (_) {
                                final profilePhotoUrl =
                                    normalizeNetworkImageUrl(
                                  userProvider.userObj.profilePhoto,
                                );
                                if (profilePhotoUrl.isEmpty) {
                                  return Image.asset(
                                    ImageConstant.profile,
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                  );
                                }
                                return Image.network(
                                  profilePhotoUrl,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    ImageConstant.profile,
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            );
          },
        ),
      ],
    );
  }

  ButtonStyle _appBarIconStyle(BuildContext context) {
    final useTransparentAppBar = !ResponsiveWidget.isMobile(context);

    return IconButton.styleFrom(
      backgroundColor: useTransparentAppBar
          ? Colors.white.withOpacity(0.3)
          : Colors.black.withOpacity(0.2),
    );
  }

  Widget _buildDashboardRow(
    BuildContext context,
    DashboardProvider dashboardProvider,
    DashboardData dashboardData,
    int index,
    ThemeData selectedThemeData,
  ) {
    if (dashboardData.movies == null || dashboardData.movies!.isEmpty) {
      return const SizedBox.shrink();
    }

    _rowControllers.putIfAbsent(index, () => ScrollController());
    _rowActiveIndexes.putIfAbsent(index, () => ValueNotifier<int?>(0));
    _rowItemCounts[index] = dashboardData.movies?.length ?? 0;
    _rowItems[index] = dashboardData.movies ?? const <Content>[];
    _rowKeys.putIfAbsent(index, () => GlobalKey());

    final controller = _rowControllers[index]!;
    final activeIndex = _rowActiveIndexes[index]!;
    final rowKey = _rowKeys[index]!;

    if (!controller.hasListeners) {
      controller.addListener(() {
        _updateActiveIndex(
          activeIndex,
          controller,
          _rowItemCounts[index] ?? 0,
          _rowItems[index],
        );
        _scheduleVisibleUpdate();

        if (controller.position.pixels >=
            controller.position.maxScrollExtent - 200) {
          if (_userId != null) {
            dashboardProvider.loadMoreRowData(
              dashboardData,
              _seriesType,
              _userId!,
            );
          }
        }
      });
    }

    _scheduleVisibleUpdate();

    final title = '${dashboardData.language} - ${dashboardData.category}';

    return KeyedSubtree(
      key: rowKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            splashColor: Colors.transparent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryContentPage(
                    categoryTitle: title,
                    contents: dashboardData.movies ?? [],
                  ),
                ),
              );
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: ResponsiveWidget.isMobile(context) ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: selectedThemeData.canvasColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: selectedThemeData.primaryColor,
                ),
                const SizedBox(width: 3),
              ],
            ),
          ),
          SizedBox(
            height: MovieCard.standardHeight,
            child: ListView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              itemCount: dashboardData.movies!.length +
                  (dashboardData.isRowLoading ? 1 : 0),
              itemBuilder: (context, i) {
                if (i < dashboardData.movies!.length) {
                  return MovieCard(
                    movie: dashboardData.movies![i],
                    index: i,
                    activeIndexListenable: activeIndex,
                  );
                }

                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDashboardSectionLoader(
    BuildContext context,
    ThemeData selectedThemeData,
  ) {
    final cardCount = ResponsiveWidget.isMobile(context)
        ? 1
        : ResponsiveWidget.isDesktop(context)
            ? 4
            : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (sectionIndex) {
        return Padding(
          padding: EdgeInsets.only(bottom: sectionIndex == 2 ? 0 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ShimmerLoader(
                  width: ResponsiveWidget.isMobile(context) ? 170 : 220,
                  height: 18,
                  borderRadius: 8,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cardCount,
                  itemBuilder: (context, index) {
                    return Container(
                      width: MovieCard.itemWidth,
                      margin: const EdgeInsets.all(MovieCard.itemMargin),
                      decoration: BoxDecoration(
                        color:
                            selectedThemeData.cardColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        children: [
                          Expanded(
                            flex: 8,
                            child: ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: ShimmerLoader(
                                width: double.infinity,
                                height: double.infinity,
                                borderRadius: 0,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShimmerLoader(
                                    width: 80,
                                    height: 10,
                                    borderRadius: 6,
                                  ),
                                  SizedBox(height: 8),
                                  ShimmerLoader(
                                    width: double.infinity,
                                    height: 14,
                                  ),
                                  SizedBox(height: 6),
                                  ShimmerLoader(
                                    width: 110,
                                    height: 10,
                                    borderRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
