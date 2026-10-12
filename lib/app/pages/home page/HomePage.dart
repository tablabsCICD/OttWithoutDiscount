import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ott/app/core/constant/image_constant.dart';
import 'package:ott/app/core/utils/image_url_utils.dart';
import 'package:ott/app/core/utils/content_type.dart';
import 'package:ott/app/core/utils/release_date_formatter.dart';
import 'package:ott/app/pages/NavigationPage.dart';
import 'package:ott/app/pages/home%20page/category_content_page.dart';
import 'package:ott/app/pages/madioo%20page/MadiooPage.dart';
import 'package:ott/app/pages/movie%20details%20page/MovieDetailsPage.dart';
import 'package:ott/app/pages/profile%20page/component/change_language.dart';
import 'package:ott/app/pages/series%20details%20page/seriesdetailspage.dart';
import 'package:ott/app/pages/shorts%20page/component/shortsLibraryPage.dart';
import 'package:ott/app/pages/profile%20page/ProfilePage.dart';
import 'package:ott/app/pages/search%20page/SearchPage.dart';
import 'package:ott/app/pages/wallet%20page/WalletPage.dart';
import 'package:ott/app/provider/dashboardProvider.dart';
import 'package:ott/app/route/route_observer.dart';
import 'package:ott/app/provider/wallet_provider.dart';
import 'package:ott/app/widgets/continueWatchMovieCard.dart';
import 'package:ott/app/widgets/customtextfield.dart';
import 'package:ott/app/widgets/feature_tour.dart';
import 'package:ott/app/widgets/ott_tv_focus.dart';
import 'package:ott/app/widgets/shimmer%20loader/home_shimmer.dart';
import 'package:ott/app/widgets/shimmer%20loader/shimmer_loader.dart';
import 'package:ott/app/widgets/show_toast.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/models/response/get_dashboard_data.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:ott/app/pages/notification%20page/NotificationPage.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/widgets/movieCard.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/referral_service.dart';
import '../../core/utils/sharepreferences.dart';
import '../../provider/onboarding_tour_provider.dart';
import '../../provider/userProvider.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.initialSelectedType = "MOVIE",
    this.lockContentType = false,
  });

  final String initialSelectedType;
  final bool lockContentType;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with RouteAware, WidgetsBindingObserver {
  static const double _autoPlayVisibilityThreshold = 0.70;

  late String selectedType;
  bool isLoading = true;

//// upcoming movie posters
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<Content> trendingMovieList = [];

  bool _dataLoaded = false;
  int? _userId;

  /// Scroll controllers for each horizontal row.
  final Map<int, ScrollController> _rowControllers = {};
  final Map<int, ValueNotifier<int?>> _rowActiveIndexes = {};
  final Map<int, int> _rowItemCounts = {};
  final Map<int, List<Content>> _rowItems = {};
  final Map<int, GlobalKey> _rowKeys = {};
  final ScrollController _verticalController = ScrollController();
  final ScrollController _continueWatchController = ScrollController();
  final ValueNotifier<int?> _continueWatchActiveIndex = ValueNotifier<int?>(0);
  int _continueWatchItemCount = 0;
  List<Content> _continueWatchItems = const <Content>[];
  bool _continueWatchListenerAttached = false;
  final GlobalKey _continueWatchKey = GlobalKey();
  bool _visibleUpdateScheduled = false;
  bool _isOffline = false;
  bool _continueWatchRefreshInFlight = false;
  PageRoute<dynamic>? _route;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selectedType = widget.initialSelectedType;

    _verticalController.addListener(_updateVisibleRows);
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_setConnectionStatus);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_dataLoaded) {
        _dataLoaded = true;
        await _initializeData();
      }
      if (mounted) {
        _updateVisibleRows();
      }
    });
  }

  void _resetRowState() {
    _clearHomeAutoPlay('category changed');
    for (final controller in _rowControllers.values) {
      controller.dispose();
    }
    for (final notifier in _rowActiveIndexes.values) {
      notifier.dispose();
    }
    _rowControllers.clear();
    _rowActiveIndexes.clear();
    _rowItemCounts.clear();
    _rowItems.clear();
    _rowKeys.clear();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSelectedType != widget.initialSelectedType &&
        selectedType != widget.initialSelectedType) {
      selectedType = widget.initialSelectedType;
      _resetRowState();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_initializeData());
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      if (_route != null) {
        routeObserver.unsubscribe(this);
      }
      _route = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _refreshContinueWatching();
    _scheduleVisibleUpdate();
  }

  @override
  void didPushNext() {
    _clearHomeAutoPlay('navigating away from home');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _clearHomeAutoPlay('app lifecycle $state');
    } else if (state == AppLifecycleState.resumed) {
      _scheduleVisibleUpdate();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearHomeAutoPlay('home disposed');
    routeObserver.unsubscribe(this);
    for (final controller in _rowControllers.values) {
      controller.dispose();
    }
    for (final notifier in _rowActiveIndexes.values) {
      notifier.dispose();
    }
    _rowControllers.clear();
    _rowActiveIndexes.clear();
    _rowItemCounts.clear();
    _rowItems.clear();
    _rowKeys.clear();

    _verticalController.dispose();
    _pageController.dispose();
    _continueWatchController.dispose();
    _continueWatchActiveIndex.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshContinueWatching() async {
    if (!mounted ||
        _continueWatchRefreshInFlight ||
        _isOffline ||
        selectedType == 'MINI SERIES' ||
        selectedType == 'MADIOO') {
      return;
    }

    _continueWatchRefreshInFlight = true;
    try {
      await context
          .read<DashboardProvider>()
          .getContinueWatchedMovieList(selectedType);
    } finally {
      _continueWatchRefreshInFlight = false;
    }
  }

  Future<void> _initializeData() async {
    await _updateConnectionStatus();
    await _fetchUserData();
    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
    confirmDetails(context);
  }

  Future<void> _updateConnectionStatus() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    _setConnectionStatus(connectivityResults);
  }

  void _setConnectionStatus(List<ConnectivityResult> connectivityResults) {
    final isOffline = !connectivityResults.any(
      (result) => result != ConnectivityResult.none,
    );

    if (!mounted) return;
    if (_isOffline == isOffline) return;
    setState(() {
      _isOffline = isOffline;
    });
    if (isOffline) {
      _clearHomeAutoPlay('network offline');
    } else {
      _scheduleVisibleUpdate();
    }
  }

  void _startAutoScroll() {
    if (trendingMovieList.isEmpty) return;

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 10));
      if (!mounted || trendingMovieList.isEmpty) return false;

      _currentPage = (_currentPage + 1) % trendingMovieList.length;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
      return true;
    });
  }

  void confirmDetails(BuildContext context) {
    final userProvider =
        Provider.of<UserProvider>(context, listen: false).userObject;

    // Stage 1: Email ID & Date of Birth
    final hasEmail =
        userProvider.emailId != null && userProvider.emailId!.trim().isNotEmpty;
    final hasDob =
        userProvider.dob != null && userProvider.dob!.trim().isNotEmpty;
    if (!hasEmail || !hasDob) {
      stage1ProfilePopUp(context);
      return;
    }

    // Stage 2: Personal Profile (Single Name field)
    final hasFirstName = userProvider.firstName != null &&
        userProvider.firstName!.trim().isNotEmpty;
    if (!hasFirstName) {
      stage2ProfilePopUp(context);
      return;
    }

    // Stage 3: Address / Location (Country, State, District)
    final loc = userProvider.location;
    final hasCountry = loc?.country != null && loc!.country!.trim().isNotEmpty;
    final hasState = loc?.state != null && loc!.state!.trim().isNotEmpty;
    final hasDistrict =
        loc?.district != null && loc!.district!.trim().isNotEmpty;
    if (!hasCountry || !hasState || !hasDistrict) {
      userLocationPopUp(context);
      return;
    }
  }

  Future<void> _fetchUserData() async {
    final localSharePreferences = LocalSharePreferences();
    final user = await localSharePreferences.getUser();
    if (user != null && mounted) {
      _userId = user.id;
      await Provider.of<UserProvider>(context, listen: false)
          .getUserById(user.id!);
    }
    final dashBoardProvider =
        Provider.of<DashboardProvider>(context, listen: false);
    final selectedLanguages = Provider.of<UserProvider>(context, listen: false)
            .userObject
            .selectedLanguages ??
        [];

    if (selectedLanguages.isEmpty || selectedLanguages == []) {
      await getMovieList(dashBoardProvider, selectedType, ["English"]);
    } else {
      await getMovieList(dashBoardProvider, selectedType, selectedLanguages);
    }
  }

  /// Horizontal pagination trigger.
  void _onRowScroll(
    ScrollController controller,
    DashboardProvider provider,
    DashboardData row,
  ) {
    if (controller.position.pixels >=
        controller.position.maxScrollExtent - 200) {
      if (_userId != null) {
        provider.loadMoreRowData(row, selectedType, _userId!);
      }
    }
  }

  int? _primaryVisibleIndexForRow(
    ScrollController controller,
    int itemCount,
    List<Content>? items,
  ) {
    if (!controller.hasClients || itemCount <= 0) {
      return null;
    }

    final viewport = controller.position.viewportDimension;
    if (viewport <= 0) {
      return null;
    }

    final realItemCount = items?.length ?? itemCount;
    if (realItemCount <= 0) return null;

    final viewStart = controller.offset;
    final viewEnd = viewStart + viewport;
    final firstCandidate = math.max(
      0,
      (viewStart / MovieCard.itemExtent).floor(),
    );
    final lastCandidate = math.min(
      realItemCount - 1,
      math.max(
        firstCandidate,
        ((viewEnd - 0.001) / MovieCard.itemExtent).floor(),
      ),
    );
    final isAtEnd =
        controller.position.maxScrollExtent - controller.offset <= 1;

    int? bestIndex;
    double bestVisibility = 0;

    for (int candidate = firstCandidate;
        candidate <= lastCandidate;
        candidate++) {
      final overlap = _visibleOverlap(viewStart, viewEnd, candidate);
      if (overlap <= 0) continue;

      final hasTrailer = items != null &&
          candidate < items.length &&
          (items[candidate].trailerUrl?.trim().isNotEmpty ?? false);
      if (!hasTrailer) {
        continue;
      }

      final visibility =
          (overlap / MovieCard.itemWidth).clamp(0.0, 1.0).toDouble();
      _logHomeAutoPlay(
        'Visibility Percentage index=$candidate '
        '${(visibility * 100).toStringAsFixed(0)}%',
      );
      if (visibility < _autoPlayVisibilityThreshold) {
        continue;
      }

      if (bestIndex == null ||
          visibility > bestVisibility ||
          (visibility == bestVisibility &&
              bestIndex != null &&
              candidate > bestIndex)) {
        bestVisibility = visibility;
        bestIndex = candidate;
      }
    }

    if (bestIndex == null && isAtEnd) {
      final lastPlayableIndex = _lastPlayableIndex(items);
      if (lastPlayableIndex != null) {
        final overlap = _visibleOverlap(viewStart, viewEnd, lastPlayableIndex);
        final visibility =
            (overlap / MovieCard.itemWidth).clamp(0.0, 1.0).toDouble();
        _logHomeAutoPlay(
          'End-of-list visibility index=$lastPlayableIndex '
          '${(visibility * 100).toStringAsFixed(0)}%',
        );
        if (visibility >= _autoPlayVisibilityThreshold) {
          bestIndex = lastPlayableIndex;
        }
      }
    }

    return bestIndex;
  }

  int? _lastPlayableIndex(List<Content>? items) {
    if (items == null || items.isEmpty) return null;
    for (int index = items.length - 1; index >= 0; index--) {
      if (items[index].trailerUrl?.trim().isNotEmpty ?? false) {
        return index;
      }
    }
    return null;
  }

  double _visibleOverlap(double viewStart, double viewEnd, int index) {
    final itemStart = index * MovieCard.itemExtent;
    final itemEnd = itemStart + MovieCard.itemExtent;
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
    if (!mounted) return;

    final screenSize = MediaQuery.of(context).size;
    final screenRect = Offset.zero & screenSize;
    int? activeRowIndex;
    int? activeCardIndex;
    double bestVerticalVisibility = 0;

    for (final entry in _rowActiveIndexes.entries) {
      final rowIndex = entry.key;
      final controller = _rowControllers[rowIndex];
      final itemCount = _rowItemCounts[rowIndex] ?? 0;
      final items = _rowItems[rowIndex];
      final key = _rowKeys[rowIndex];
      final rowRect = key == null ? null : _rowRect(key);

      if (rowRect == null || controller == null || rowRect.height <= 0) {
        continue;
      }

      final visibleTop = math.max(rowRect.top, screenRect.top);
      final visibleBottom = math.min(rowRect.bottom, screenRect.bottom);
      final visibleHeight = math.max(0.0, visibleBottom - visibleTop);
      final verticalVisibility =
          (visibleHeight / rowRect.height).clamp(0.0, 1.0).toDouble();
      if (verticalVisibility < _autoPlayVisibilityThreshold) {
        continue;
      }

      final rowPrimaryIndex = _primaryVisibleIndexForRow(
        controller,
        itemCount,
        items,
      );
      if (rowPrimaryIndex == null) continue;

      if (activeRowIndex == null ||
          verticalVisibility > bestVerticalVisibility) {
        activeRowIndex = rowIndex;
        activeCardIndex = rowPrimaryIndex;
        bestVerticalVisibility = verticalVisibility;
      }
    }

    for (final entry in _rowActiveIndexes.entries) {
      final rowIndex = entry.key;
      final notifier = entry.value;
      final nextValue = rowIndex == activeRowIndex ? activeCardIndex : null;
      if (notifier.value != nextValue) {
        notifier.value = nextValue;
        if (nextValue != null) {
          final activeItems = _rowItems[rowIndex];
          final activeVideoId =
              activeItems != null && nextValue < activeItems.length
                  ? activeItems[nextValue].id
                  : null;
          _logHomeAutoPlay(
            'Auto-play Triggered row=$rowIndex index=$nextValue '
            'Current Active Video ID=$activeVideoId '
            'vertical=${(bestVerticalVisibility * 100).toStringAsFixed(0)}%',
          );
        }
      }
    }
  }

  void _clearHomeAutoPlay(String reason) {
    for (final notifier in _rowActiveIndexes.values) {
      if (notifier.value != null) {
        notifier.value = null;
      }
    }
    _logHomeAutoPlay('Video Stopped: $reason');
  }

  void _logHomeAutoPlay(String message) {}

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
    var themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    var selectedThemeData = themeProvider.getTheme;

    return Scaffold(
      body: isLoading
          ? HomeShimmer()
          : CustomScrollView(
              controller: _verticalController,
              slivers: [
                _buildSliverAppBar(context, selectedThemeData),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Consumer<DashboardProvider>(
                        builder: (context, dashboardProvider, child) {
                      final showContentLoader = dashboardProvider.isLoading &&
                          (ContentType.isMovieLike(selectedType) ||
                              ContentType.isSeries(selectedType));

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 5,
                          ),
                          if (ResponsiveWidget.isTabletOrTv(context) &&
                              selectedType != 'MINI SERIES' &&
                              selectedType != 'MADIOO')
                            _buildTvHeroSlider(
                              context,
                              selectedThemeData,
                              dashboardProvider,
                            ),
                          if (!widget.lockContentType)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _buildFilterButtons(
                                  context, dashboardProvider),
                            ),
                          SizedBox(
                            height: 20,
                          ),
                          showContentLoader
                              ? _buildDashboardSectionLoader(
                                  context,
                                  selectedThemeData,
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    selectedType == 'MINI SERIES' ||
                                            selectedType == 'MADIOO'
                                        ? SizedBox.shrink()
                                        : _isOffline
                                            ? _continueWatchShimmerWidget()
                                            : continueWatchWidget(
                                                continueWatchList:
                                                    dashboardProvider
                                                        .continueWatchedMovies),
                                    selectedType == 'MINI SERIES'
                                        ? ShortsLibraryPage(
                                            useParentScroll: true)
                                        : selectedType == 'MADIOO'
                                            ? MadiooPage(useParentScroll: true)
                                            : ListView.builder(
                                                shrinkWrap: true,
                                                physics:
                                                    NeverScrollableScrollPhysics(),
                                                padding: EdgeInsets.zero,
                                                scrollDirection: Axis.vertical,
                                                itemCount: dashboardProvider
                                                    .dashboardData.length,
                                                itemBuilder: (context, index) {
                                                  DashboardData dashboardData =
                                                      dashboardProvider
                                                          .dashboardData[index];

                                                  _rowControllers.putIfAbsent(
                                                      index,
                                                      () => ScrollController());
                                                  _rowActiveIndexes.putIfAbsent(
                                                      index,
                                                      () => ValueNotifier<int?>(
                                                          null));
                                                  _rowItemCounts[index] =
                                                      dashboardData
                                                              .movies?.length ??
                                                          0;
                                                  _rowItems[index] =
                                                      dashboardData.movies ??
                                                          const <Content>[];
                                                  _scheduleVisibleUpdate();
                                                  _rowKeys.putIfAbsent(
                                                      index, () => GlobalKey());

                                                  final controller =
                                                      _rowControllers[index]!;
                                                  final activeIndex =
                                                      _rowActiveIndexes[index]!;
                                                  final rowKey =
                                                      _rowKeys[index]!;
                                                  final rowIndex = index;

                                                  // Attach listener only once.
                                                  if (!controller
                                                      .hasListeners) {
                                                    controller.addListener(() {
                                                      _scheduleVisibleUpdate();

                                                      if (controller.position
                                                              .pixels >=
                                                          controller.position
                                                                  .maxScrollExtent -
                                                              200) {
                                                        if (_userId != null) {
                                                          dashboardProvider
                                                              .loadMoreRowData(
                                                                  dashboardData,
                                                                  selectedType,
                                                                  _userId!)
                                                              .whenComplete(
                                                                  _scheduleVisibleUpdate);
                                                        }
                                                      }
                                                    });
                                                  }

                                                  return KeyedSubtree(
                                                    key: rowKey,
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        (dashboardData.movies ==
                                                                    null ||
                                                                dashboardData
                                                                    .movies!
                                                                    .isEmpty)
                                                            ? SizedBox.shrink()
                                                            : InkWell(
                                                                splashColor: Colors
                                                                    .transparent,
                                                                onTap: () {
                                                                  Navigator
                                                                      .push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                      builder:
                                                                          (_) =>
                                                                              CategoryContentPage(
                                                                        categoryTitle:
                                                                            "${dashboardData.language} - ${dashboardData.category}",
                                                                        contents:
                                                                            dashboardData.movies ??
                                                                                [],
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                                child: Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child:
                                                                          Text(
                                                                        "${dashboardData.language} - ${dashboardData.category}",
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                        style: GoogleFonts
                                                                            .inter(
                                                                          fontSize: ResponsiveWidget.isMobile(context)
                                                                              ? 18
                                                                              : 20,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color:
                                                                              selectedThemeData.canvasColor,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    Icon(
                                                                      Icons
                                                                          .arrow_forward_ios,
                                                                      size: 18,
                                                                      color: selectedThemeData
                                                                          .primaryColor,
                                                                    ),
                                                                    SizedBox(
                                                                      width: 3,
                                                                    )
                                                                  ],
                                                                ),
                                                              ),
                                                        (dashboardData.movies ==
                                                                    null ||
                                                                dashboardData
                                                                    .movies!
                                                                    .isEmpty)
                                                            ? SizedBox.shrink()
                                                            : SizedBox(
                                                                height: 270,
                                                                child: ListView
                                                                    .builder(
                                                                  controller:
                                                                      controller,
                                                                  scrollDirection:
                                                                      Axis.horizontal,
                                                                  //padding: EdgeInsets.zero,
                                                                  itemCount: dashboardData
                                                                          .movies!
                                                                          .length +
                                                                      (dashboardData
                                                                              .isRowLoading
                                                                          ? 1
                                                                          : 0),
                                                                  itemBuilder:
                                                                      (context,
                                                                          i) {
                                                                    if (i <
                                                                        dashboardData
                                                                            .movies!
                                                                            .length) {
                                                                      return MovieCard(
                                                                          movie: dashboardData.movies![
                                                                              i],
                                                                          index:
                                                                              i,
                                                                          isShortFilmTab: ContentType.normalize(selectedType) ==
                                                                              ContentType
                                                                                  .shortFilm,
                                                                          activeIndexListenable:
                                                                              activeIndex);
                                                                    } else if (dashboardData
                                                                        .isRowLoading) {
                                                                      return Padding(
                                                                        padding: const EdgeInsets
                                                                            .all(
                                                                            12),
                                                                        child:
                                                                            SizedBox(
                                                                          width:
                                                                              40,
                                                                          height:
                                                                              40,
                                                                          child:
                                                                              CircularProgressIndicator(strokeWidth: 2),
                                                                        ),
                                                                      );
                                                                    } else {
                                                                      return const SizedBox
                                                                          .shrink();
                                                                    }
                                                                  },
                                                                ),
                                                              ),
                                                        (dashboardData.movies ==
                                                                    null ||
                                                                dashboardData
                                                                    .movies!
                                                                    .isEmpty)
                                                            ? SizedBox.shrink()
                                                            : SizedBox(
                                                                height: 20),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                  ],
                                ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTvHeroSlider(
    BuildContext context,
    ThemeData theme,
    DashboardProvider dashboardProvider,
  ) {
    final normalizedSelectedType = selectedType.trim().toUpperCase();
    final heroItems = dashboardProvider.dashboardData
        .expand((row) => row.movies ?? const <Content>[])
        .where((item) =>
            item.id != null &&
            (item.type?.trim().toUpperCase() == normalizedSelectedType) &&
            (item.posterUrlList?.isNotEmpty ?? false) &&
            (item.title?.trim().isNotEmpty ?? false))
        .toList();

    if (heroItems.isEmpty) return const SizedBox.shrink();

    final height = ResponsiveWidget.isDesktop(context) ? 520.0 : 410.0;
    final horizontalMargin = ResponsiveWidget.isDesktop(context) ? 24.0 : 14.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalMargin, 8, horizontalMargin, 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _moveHeroSlider(heroItems.length, -1);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _moveHeroSlider(heroItems.length, 1);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                _openContentDetails(heroItems[_currentPage % heroItems.length]);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: heroItems.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final item = heroItems[index];
                    final imageUrl = item.posterUrlList?.first ?? '';
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (_, __, ___) => Container(
                            color: theme.cardColor,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.movie_creation_outlined,
                              color: theme.canvasColor.withOpacity(0.5),
                              size: 72,
                            ),
                          ),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black,
                                Colors.black87,
                                Colors.black26,
                                Colors.black87,
                              ],
                              stops: [0, 0.26, 0.72, 1],
                            ),
                          ),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black38,
                                Colors.transparent,
                                Colors.black87,
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: ResponsiveWidget.isDesktop(context) ? 70 : 36,
                          bottom: ResponsiveWidget.isDesktop(context) ? 58 : 34,
                          width:
                              ResponsiveWidget.isDesktop(context) ? 560 : 430,
                          child: _buildTvHeroCopy(context, theme, item, index),
                        ),
                      ],
                    );
                  },
                ),
                Positioned(
                  left: 18,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildHeroArrowButton(
                      theme: theme,
                      icon: Icons.chevron_left_rounded,
                      onTap: () => _moveHeroSlider(heroItems.length, -1),
                    ),
                  ),
                ),
                Positioned(
                  right: 18,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildHeroArrowButton(
                      theme: theme,
                      icon: Icons.chevron_right_rounded,
                      onTap: () => _moveHeroSlider(heroItems.length, 1),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 18,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      math.min(heroItems.length, 9),
                      (index) {
                        final active =
                            index == (_currentPage % heroItems.length);
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 26 : 8,
                          height: 7,
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white
                                : Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroArrowButton({
    required ThemeData theme,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OttTvFocus(
      onTap: onTap,
      borderRadius: 999,
      scale: 1.1,
      child: Material(
        color: Colors.black.withOpacity(0.42),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 54,
            height: 54,
            child: Icon(
              icon,
              color: Colors.white,
              size: 38,
            ),
          ),
        ),
      ),
    );
  }

  void _moveHeroSlider(int itemCount, int delta) {
    if (itemCount <= 0) return;
    final next = (_currentPage + delta) % itemCount;
    final normalized = next < 0 ? itemCount - 1 : next;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        normalized,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
    setState(() => _currentPage = normalized);
  }

  Widget _buildTvHeroCopy(
    BuildContext context,
    ThemeData theme,
    Content item,
    int index,
  ) {
    final genres =
        item.genreList?.where((e) => e.trim().isNotEmpty).join('  -  ');
    final meta = [
      if (formatReleaseDate(item.releaseDate).isNotEmpty)
        formatReleaseDate(item.releaseDate),
      if (genres != null && genres.isNotEmpty) genres,
      if (item.ratings != null) '${item.ratings!.toStringAsFixed(0)} star',
    ].join('  -  ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: theme.primaryColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '#${index + 1} Trending',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          item.title ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: ResponsiveWidget.isDesktop(context) ? 46 : 34,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
        if ((item.description ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            item.description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(142, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _openContentDetails(item),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'Watch Now',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.14),
                foregroundColor: Colors.white,
                minimumSize: const Size(118, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _openContentDetails(item),
              icon: const Icon(Icons.movie_filter_rounded),
              label: const Text(
                'Trailer',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openContentDetails(Content item) {
    final type = item.type?.toLowerCase();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => type == 'series'
            ? SeriesDetailsPage(
                seriesId: item.id ?? 0,
                content: item,
              )
            : MovieDetailsPage(
                movieId: item.id!,
                contentType: item.type,
              ),
      ),
    );
  }

  Widget continueWatchWidget({
    required List<Content> continueWatchList,
  }) {
    final items = continueWatchList
        .where((item) => (item.watchedPercentage ?? 0) < 95)
        .toList();

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    var theme = Theme.of(context);

    _continueWatchItemCount = items.length;
    _continueWatchItems = items;
    if (!_continueWatchListenerAttached) {
      _continueWatchListenerAttached = true;
      _continueWatchController.addListener(() {
        _scheduleVisibleUpdate();
      });
    }

    _scheduleVisibleUpdate();

    return KeyedSubtree(
      key: _continueWatchKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
            child: Text(
              "Continue Watching",
              style: GoogleFonts.inter(
                fontSize: ResponsiveWidget.isMobile(context) ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: theme.canvasColor,
              ),
            ),
          ),

          // Horizontal list
          SizedBox(
            height: 220, //270,
            child: ListView.builder(
              controller: _continueWatchController,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                // return SizedBox(
                //   width: MovieCard.itemExtent,
                //   child: MovieCard(
                //     movie: item,
                //     index: index,
                //     activeIndexListenable: _continueWatchActiveIndex,
                //   ),
                // );
                return SizedBox(
                  width: ContinueWatchMovieCard.itemExtent,
                  child: ContinueWatchMovieCard(
                    movie: item,
                    index: index,
                    isShortFilmTab: ContentType.normalize(selectedType) ==
                        ContentType.shortFilm,
                    enableTrailerPreview: false,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _continueWatchShimmerWidget() {
    final theme = Theme.of(context);
    final itemCount = ResponsiveWidget.isMobile(context)
        ? 2
        : ResponsiveWidget.isDesktop(context)
            ? 5
            : 3;

    _continueWatchItemCount = 0;
    _continueWatchItems = const <Content>[];
    if (_continueWatchActiveIndex.value != null) {
      _continueWatchActiveIndex.value = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          child: ShimmerLoader(
            width: ResponsiveWidget.isMobile(context) ? 170 : 220,
            height: ResponsiveWidget.isMobile(context) ? 18 : 20,
            borderRadius: 8,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              return Container(
                width: ContinueWatchMovieCard.itemExtent,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: theme.cardColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
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
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ShimmerLoader(
                            width: double.infinity,
                            height: 6,
                            borderRadius: 6,
                          ),
                          const SizedBox(height: 10),
                          ShimmerLoader(
                            width: ContinueWatchMovieCard.itemExtent * 0.62,
                            height: 14,
                            borderRadius: 6,
                          ),
                          const SizedBox(height: 8),
                          ShimmerLoader(
                            width: ContinueWatchMovieCard.itemExtent * 0.4,
                            height: 10,
                            borderRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

// double bannerHeight(BuildContext context) {
  //   final width = MediaQuery.of(context).size.width;

  //   const posterRatio = 16 / 8;
  //   return width / posterRatio;
  // }

  SliverAppBar _buildSliverAppBar(
      BuildContext context, ThemeData selectedThemeData) {
    final lang = AppLocalizations.of(context)!;
    final useTransparentAppBar = !ResponsiveWidget.isMobile(context);

    return SliverAppBar(
      automaticallyImplyLeading: false,
      forceMaterialTransparency: useTransparentAppBar,
      // expandedHeight: bannerHeight(context),
      floating: false,
      pinned: true,
      stretch: true,
      surfaceTintColor: Colors.transparent,
      backgroundColor: useTransparentAppBar
          ? selectedThemeData.scaffoldBackgroundColor
          : selectedThemeData.primaryColor,
      title: useTransparentAppBar
          ? Text(
              "",
              style: TextStyle(
                color: selectedThemeData.canvasColor,
                fontWeight: FontWeight.bold,
              ),
            )
          : SizedBox(
              width: 70,
              height: 70,
              /*   decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white),
              ), */
              child: Hero(
                tag: "logo",
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            NavigationPage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  },
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
            ),

      titleSpacing: 10,
      actions: [
        //LanguageDropdown(),
        FeatureTourTarget(
          id: FeatureTourStepId.search,
          child: IconButton(
            icon: Icon(Icons.search,
                color: useTransparentAppBar
                    ? selectedThemeData.canvasColor
                    : Colors.white),
            tooltip: lang.search,
            style: IconButton.styleFrom(
                backgroundColor: useTransparentAppBar
                    ? Colors.white.withOpacity(0.3)
                    : Colors.black.withOpacity(0.2)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SearchPage()),
            ),
          ),
        ),
        SizedBox(
          width: 4,
        ),
        FeatureTourTarget(
          id: FeatureTourStepId.notifications,
          child: IconButton(
            icon: Icon(Icons.notifications_active,
                color: useTransparentAppBar
                    ? selectedThemeData.canvasColor
                    : Colors.white),
            tooltip: lang.notification,
            style: IconButton.styleFrom(
                backgroundColor: useTransparentAppBar
                    ? Colors.white.withOpacity(0.3)
                    : Colors.black.withOpacity(0.2)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => NotificationPage()),
            ),
          ),
        ),
        SizedBox(
          width: 4,
        ),
        FeatureTourTarget(
          id: FeatureTourStepId.language,
          child: IconButton(
            tooltip: lang.selectPreferredLanguage,
            style: IconButton.styleFrom(
              backgroundColor: useTransparentAppBar
                  ? Colors.white.withOpacity(0.3)
                  : Colors.black.withOpacity(0.2),
            ),
            icon: Icon(Icons.language_sharp,
                color: useTransparentAppBar
                    ? selectedThemeData.canvasColor
                    : Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChangeLanguage(),
              ),
            ),
          ),
        ),

        SizedBox(
          width: 4,
        ),
        Consumer<UserProvider>(builder: (context, userProvider, child) {
          final walletProvider =
              Provider.of<WalletProvider>(context, listen: false);

          final user = userProvider.userObject;
          return Row(
            children: [
              FeatureTourTarget(
                id: FeatureTourStepId.wallet,
                child: IconButton(
                  icon: Icon(Icons.account_balance_wallet,
                      color: useTransparentAppBar
                          ? selectedThemeData.canvasColor
                          : Colors.white),
                  tooltip: "₹ ${walletProvider.walletBalance.toStringAsFixed(2)}",
                  style: IconButton.styleFrom(
                      backgroundColor: useTransparentAppBar
                          ? Colors.white.withOpacity(0.3)
                          : Colors.black.withOpacity(0.2)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => WalletPage()),
                  ),
                ),
              ),
              SizedBox(
                width: 4,
              ),
              FeatureTourTarget(
                id: FeatureTourStepId.profile,
                child: Tooltip(
                  textStyle: TextStyle(
                    fontSize: 10,
                    color: selectedThemeData.scaffoldBackgroundColor,
                  ),
                  message:
                      "${userProvider.userObj.firstName} ${userProvider.userObj.lastName}",
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ProfilePage()));
                    },
                    child: Hero(
                      tag: "profile",
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1,
                          ),
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
              ),
            ],
          );
        }),
        const SizedBox(width: 16),
      ],
      // flexibleSpace: FlexibleSpaceBar(
      //   stretchModes: const [
      //     StretchMode.zoomBackground,
      //     StretchMode.fadeTitle,
      //   ],
      //   background: Stack(
      //     children: [
      //       // Base fallback
      //       Positioned.fill(
      //         child: Container(
      //           color: selectedThemeData.scaffoldBackgroundColor,
      //         ),
      //       ),

      //       // Banner carousel
      //       Positioned.fill(
      //         child: trendingMovieList.isEmpty
      //             ? const SizedBox.shrink()
      //             : PageView.builder(
      //                 controller: _pageController,
      //                 itemCount: trendingMovieList.length,
      //                 onPageChanged: (i) {
      //                   setState(() => _currentPage = i);
      //                 },
      //                 itemBuilder: (context, index) {
      //                   final poster = trendingMovieList[index].posterUrlList;
      //                   return poster != null && poster.isNotEmpty
      //                       ? Image.network(
      //                           poster.first,
      //                           fit: BoxFit.cover,
      //                           errorBuilder: (_, __, ___) => Container(
      //                             color: Colors.black12,
      //                             child: const Icon(Icons.broken_image),
      //                           ),
      //                         )
      //                       : const SizedBox.shrink();
      //                 },
      //               ),
      //       ),

      //       // Hotstar-style dark gradient
      //       Positioned.fill(
      //         child: Container(
      //           decoration: const BoxDecoration(
      //             gradient: LinearGradient(
      //               begin: Alignment.topCenter,
      //               end: Alignment.bottomCenter,
      //               colors: [
      //                 Color.fromARGB(120, 0, 0, 0),
      //                 Color.fromARGB(60, 0, 0, 0),
      //                 Colors.transparent,
      //                 Color.fromARGB(180, 0, 0, 0),
      //               ],
      //             ),
      //           ),
      //         ),
      //       ),

      //       if (trendingMovieList.isNotEmpty) ...[
      //         // Bottom-left content
      //         Positioned(
      //           left: 16,
      //           right: ResponsiveWidget.isMobile(context) ? 150 : 360,
      //           bottom: 16,
      //           child: Column(
      //             crossAxisAlignment: CrossAxisAlignment.start,
      //             children: [
      //               Text(
      //                 trendingMovieList[_currentPage].title ?? '',
      //                 maxLines: 1,
      //                 overflow: TextOverflow.ellipsis,
      //                 style: TextStyle(
      //                   color: Colors.white,
      //                   fontSize: ResponsiveWidget.isMobile(context) ? 20 : 24,
      //                   fontWeight: FontWeight.w700,
      //                 ),
      //               ),
      //               const SizedBox(height: 4),
      //               Row(
      //                 children: [
      //                   StarRatingWidget(
      //                     rating: double.parse(
      //                       (trendingMovieList[_currentPage].ratings ?? 0)
      //                           .toStringAsFixed(1),
      //                     ),
      //                   ),
      //                   const SizedBox(width: 8),
      //                   Text(
      //                     (trendingMovieList[_currentPage]
      //                                 .genreList
      //                                 ?.isNotEmpty ??
      //                             false)
      //                         ? trendingMovieList[_currentPage]
      //                             .genreList!
      //                             .join(', ')
      //                         : 'N/A',
      //                     style: const TextStyle(
      //                       color: Colors.white70,
      //                       fontWeight: FontWeight.bold,
      //                       fontSize: 11,
      //                     ),
      //                     maxLines: 1,
      //                     overflow: TextOverflow.ellipsis,
      //                   ),
      //                 ],
      //               ),
      //               const SizedBox(height: 4),
      //               Row(
      //                 crossAxisAlignment: CrossAxisAlignment.center,
      //                 children: [
      //                   Text(
      //                     (trendingMovieList[_currentPage]
      //                                 .languageList
      //                                 ?.isNotEmpty ??
      //                             false)
      //                         ? trendingMovieList[_currentPage]
      //                             .languageList!
      //                             .map((e) => e.language)
      //                             .join(', ')
      //                         : 'N/A',
      //                     style: const TextStyle(
      //                       color: Colors.white,
      //                       fontSize: 11,
      //                       fontWeight: FontWeight.bold,
      //                     ),
      //                     maxLines: 1,
      //                     overflow: TextOverflow.ellipsis,
      //                   ),
      //                   Text(
      //                     ' | ',
      //                     style: TextStyle(
      //                       color: selectedThemeData.primaryColor,
      //                       fontSize: 14,
      //                       fontWeight: FontWeight.bold,
      //                     ),
      //                     maxLines: 1,
      //                     overflow: TextOverflow.ellipsis,
      //                   ),
      //                   Text(
      //                     "${trendingMovieList[_currentPage].runtime ?? 'xx min'} min",
      //                     style: const TextStyle(
      //                       color: Colors.white,
      //                       fontSize: 11,
      //                       fontWeight: FontWeight.bold,
      //                     ),
      //                     maxLines: 1,
      //                     overflow: TextOverflow.ellipsis,
      //                   ),
      //                   Text(
      //                     ' | ',
      //                     style: TextStyle(
      //                       color: selectedThemeData.primaryColor,
      //                       fontSize: 14,
      //                       fontWeight: FontWeight.bold,
      //                     ),
      //                     maxLines: 1,
      //                     overflow: TextOverflow.ellipsis,
      //                   ),
      //                   Text(
      //                     "${trendingMovieList[_currentPage].releaseDate ?? 'NA'}",
      //                     style: const TextStyle(
      //                       color: Colors.white,
      //                       fontSize: 11,
      //                       fontWeight: FontWeight.bold,
      //                     ),
      //                     maxLines: 1,
      //                     overflow: TextOverflow.ellipsis,
      //                   ),
      //                 ],
      //               ),
      //               const SizedBox(height: 4),
      //               Text(
      //                 trendingMovieList[_currentPage].description ?? '',
      //                 maxLines: 2,
      //                 overflow: TextOverflow.ellipsis,
      //                 style: const TextStyle(
      //                   color: Colors.white70,
      //                   fontSize: 11,
      //                 ),
      //               ),
      //             ],
      //           ),
      //         ),

      //         // Bottom-right button
      //         Positioned(
      //           right: 16,
      //           bottom: 48,
      //           child: GestureDetector(
      //             onTap: () => Navigator.push(
      //               context,
      //               MaterialPageRoute(
      //                 builder: (context) => trendingMovieList[_currentPage]
      //                             .type!
      //                             .toLowerCase() ==
      //                         'movie'
      //                     ? MovieDetailsPage(
      //                         movieId: trendingMovieList[_currentPage].id!,
      //                       )
      //                     : SeriesDetailsPage(
      //                         seriesId: trendingMovieList[_currentPage].id ?? 0,
      //                         content: trendingMovieList[_currentPage],
      //                       ),
      //               ),
      //             ),
      //             child: Container(
      //               decoration: BoxDecoration(
      //                 borderRadius: BorderRadius.circular(
      //                   10,
      //                 ),
      //                 color: selectedThemeData.primaryColor.withOpacity(0.9),
      //               ),
      //               child: Padding(
      //                 padding: EdgeInsets.symmetric(
      //                   vertical: 8.0,
      //                   horizontal: 16,
      //                 ),
      //                 child: Text(
      //                   "Watch",
      //                   style: TextStyle(
      //                     fontSize: 14,
      //                     fontWeight: FontWeight.bold,
      //                     color: Colors.white,
      //                   ),
      //                 ),
      //               ),
      //             ),
      //           ),
      //           // child: GestureDetector(
      //           //   onTap: () {},
      //           //   child: Container(
      //           //     padding:
      //           //         const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      //           //     decoration: BoxDecoration(
      //           //       color: selectedThemeData.primaryColor,
      //           //       borderRadius: BorderRadius.circular(6),
      //           //     ),
      //           //     child: Text(
      //           //       trendingMovieList[_currentPage].isRental == true
      //           //           ? (trendingMovieList[_currentPage]
      //           //                       .type
      //           //                       ?.toLowerCase() ==
      //           //                   "movie"
      //           //               ? lang.watchMovie
      //           //               : lang.watchSeries)
      //           //           : "Rs ${trendingMovieList[_currentPage].price}",
      //           //       style: const TextStyle(
      //           //         color: Colors.white,
      //           //         fontSize: 14,
      //           //         fontWeight: FontWeight.w600,
      //           //       ),
      //           //     ),
      //           //   ),
      //           // ),
      //         ),
      //       ],
      //     ],
      //   ),
      // ),
    );
  }

  Widget _buildFilterButtons(
      BuildContext context, DashboardProvider dashboardProvider) {
    final lang = AppLocalizations.of(context)!;
    var themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    var selectedThemeData = themeProvider.getTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        ...ContentType.homeTypes,
      ].map((type) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: GestureDetector(
            onTap: () async {
              if (selectedType == type) return;
              setState(() {
                selectedType = type;
                _resetRowState();
              });
              final selectedLanguages =
                  Provider.of<UserProvider>(context, listen: false)
                          .userObject
                          .selectedLanguages ??
                      []; // Ensure it doesn't throw null

              if (selectedType == 'MINI SERIES') {
                return;
              }
              if (selectedType == 'MADIOO') {
                return;
              }
              if (selectedLanguages.isEmpty || selectedLanguages == []) {
                await getMovieList(
                    dashboardProvider, selectedType, ["Hindi", "English"]);
              } else {
                await getMovieList(
                    dashboardProvider, selectedType, selectedLanguages);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: selectedType == type
                    ? selectedThemeData.primaryColor
                    : Colors.transparent,
                border: Border.all(
                  color: selectedType == type
                      ? selectedThemeData.primaryColor
                      : selectedThemeData.canvasColor.withOpacity(0.6),
                ),
                borderRadius: BorderRadius.circular(
                  10,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Text(
                  type == ContentType.movie
                      ? lang.movie
                      : type == ContentType.series
                          ? lang.series
                          : ContentType.displayLabel(type),
                  style: TextStyle(
                    color: selectedType == type
                        ? Colors.white
                        : selectedThemeData.primaryColor,
                    fontWeight: selectedType == type
                        ? FontWeight.bold
                        : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          //
        );
      }).toList(),
    );
  }

  Widget _buildDashboardSectionLoader(
      BuildContext context, ThemeData selectedThemeData) {
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
                      child: Column(
                        children: [
                          Expanded(
                            flex: 8,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: const ShimmerLoader(
                                width: double.infinity,
                                height: double.infinity,
                                borderRadius: 0,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShimmerLoader(
                                    width: 80,
                                    height: 10,
                                    borderRadius: 6,
                                  ),
                                  const SizedBox(height: 8),
                                  const ShimmerLoader(
                                    width: double.infinity,
                                    height: 14,
                                  ),
                                  const SizedBox(height: 6),
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

  Future<void> getMovieList(DashboardProvider dashBoardProvider,
      String selectedType, List<String> langList) async {
    final localSharePreferences = LocalSharePreferences();
    final user = await localSharePreferences.getUser();
    log('User in getMovieList method ${user!.firstName} ');
    await dashBoardProvider.getContinueWatchedMovieList(selectedType);

    await dashBoardProvider.getDashboardData(selectedType, langList, user.id!);
  }
// Compatibility alias
  Future<void> userDetailsPopUp(BuildContext context) async {
    confirmDetails(context);
  }

  // STAGE 1: First Login / Minimum Information Popup (Email, DOB, Referral Code)
  Future<void> stage1ProfilePopUp(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final lang = AppLocalizations.of(context)!;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (userProvider.emailController.text.trim().isEmpty) {
      userProvider.emailController.text =
          userProvider.userObject.emailId ?? "";
    }
    if (userProvider.dobController.text.trim().isEmpty) {
      userProvider.dobController.text = userProvider.userObject.dob ?? "";
    }
    if (userProvider.refferedByController.text.trim().isEmpty) {
      final pendingReferral =
          await ReferralService.instance.getPendingReferralCode();
      if (pendingReferral != null && pendingReferral.isNotEmpty) {
        userProvider.refferedByController.text = pendingReferral;
      }
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        UserProvider provider =
            Provider.of<UserProvider>(context, listen: true);
        var selectedThemeData =
            Provider.of<ThemeProvider>(context, listen: true).getTheme;
        return AlertDialog(
          backgroundColor: selectedThemeData.scaffoldBackgroundColor,
          title: Text(
            lang.enterDetails,
            style: TextStyle(
              color: selectedThemeData.canvasColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    controller: provider.emailController,
                    isEmail: true,
                    isValidator: true,
                    label: lang.email,
                    hintText: lang.enterEmail,
                    textInputType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      lang.birthDate,
                      style: TextStyle(
                        color: selectedThemeData.canvasColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextFormField(
                    cursorColor: selectedThemeData.primaryColor,
                    controller: provider.dobController,
                    readOnly: true,
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: ctx,
                        initialDate:
                            DateTime.tryParse(provider.dobController.text) ??
                                DateTime(2000, 1, 1),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        provider.setDate(pickedDate);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '${lang.enterBirthDate} is required';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: selectedThemeData.cardColor,
                      hintText: lang.enterBirthDate,
                      hintStyle: TextStyle(
                        color: selectedThemeData.canvasColor,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.transparent),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.transparent),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: selectedThemeData.primaryColor,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    controller: provider.refferedByController,
                    hintText: lang.referralCodeOptional,
                    label: lang.enterReferralCode,
                    textInputType: TextInputType.text,
                    capitalization: TextCapitalization.characters,
                    isValidator: false,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedThemeData.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                var result = await provider.updateUserDetails();
                if (!ctx.mounted) return;
                if (result['success'] == true) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isLoggedIn', true);

                  if (provider.userObject.id != null) {
                    await provider.getUserById(provider.userObject.id!);
                  }

                  CustomToast.show(
                    context,
                    lang.profileUpdatedSuccessfully,
                    isSuccess: true,
                  );

                  Navigator.of(ctx).pop();
                  // Re-evaluate next stage
                  if (context.mounted) {
                    confirmDetails(context);
                  }
                } else {
                  CustomToast.show(
                    context,
                    'Failure: ${result['message']}',
                    isSuccess: false,
                  );
                }
              },
              child: const Center(
                child: Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // STAGE 2: Second App Open / Remaining Profile Information Popup (Single Name Field)
  Future<void> stage2ProfilePopUp(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final lang = AppLocalizations.of(context)!;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final initialFirst = userProvider.userObject.firstName ??
        userProvider.firstNameController.text;
    final initialLast =
        userProvider.userObject.lastName ?? userProvider.lastNameController.text;
    final initialFullName = '$initialFirst $initialLast'.trim();
    final nameController = TextEditingController(text: initialFullName);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        UserProvider provider =
            Provider.of<UserProvider>(context, listen: true);
        var selectedThemeData =
            Provider.of<ThemeProvider>(context, listen: true).getTheme;
        return AlertDialog(
          backgroundColor: selectedThemeData.scaffoldBackgroundColor,
          title: Text(
            lang.enterDetails,
            style: TextStyle(
              color: selectedThemeData.canvasColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    controller: nameController,
                    isName: true,
                    label: 'Name',
                    hintText: 'Enter your name',
                    isValidator: true,
                    textInputType: TextInputType.name,
                    capitalization: TextCapitalization.words,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Name cannot be empty';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedThemeData.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final fullName = nameController.text.trim();
                final parts = fullName.split(RegExp(r'\s+'));
                final firstName = parts.first;
                final lastName =
                    parts.length > 1 ? parts.sublist(1).join(' ') : '';

                provider.firstNameController.text = firstName;
                provider.lastNameController.text = lastName;

                var result = await provider.updateUserDetails();
                if (!ctx.mounted) return;
                if (result['success'] == true) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isLoggedIn', true);

                  if (provider.userObject.id != null) {
                    await provider.getUserById(provider.userObject.id!);
                  }

                  CustomToast.show(
                    context,
                    lang.profileUpdatedSuccessfully,
                    isSuccess: true,
                  );

                  Navigator.of(ctx).pop();
                  // Re-evaluate next stage
                  if (context.mounted) {
                    confirmDetails(context);
                  }
                } else {
                  CustomToast.show(
                    context,
                    'Failure: ${result['message']}',
                    isSuccess: false,
                  );
                }
              },
              child: const Center(
                child: Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // STAGE 3: Third App Open / Address Popup with Location Detection & Cascading Dropdowns
  Future<void> userLocationPopUp(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final lang = AppLocalizations.of(context)!;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.loadCountryOptions();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        UserProvider provider =
            Provider.of<UserProvider>(context, listen: true);
        var selectedThemeData =
            Provider.of<ThemeProvider>(context, listen: true).getTheme;
        return AlertDialog(
          backgroundColor: selectedThemeData.scaffoldBackgroundColor,
          title: Text(
            lang.enterLocationDetails,
            style: TextStyle(
              color: selectedThemeData.canvasColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selectedThemeData.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selectedThemeData.primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How would you like to add your address?',
                          style: TextStyle(
                            color: selectedThemeData.canvasColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: provider.isFetchingCurrentLocation
                                    ? null
                                    : () async {
                                        final filled = await provider
                                            .useCurrentLocationFromGoogle();
                                        if (!ctx.mounted) return;
                                        if (filled) {
                                          CustomToast.show(
                                            ctx,
                                            'Current address detected & filled',
                                            isSuccess: true,
                                          );
                                        } else {
                                          CustomToast.show(
                                            ctx,
                                            'Unable to fetch location. Please enter address manually.',
                                            isSuccess: false,
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      selectedThemeData.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                icon: provider.isFetchingCurrentLocation
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.my_location, size: 16),
                                label: Text(
                                  provider.isFetchingCurrentLocation
                                      ? 'Detecting...'
                                      : 'Use Current Address',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: provider.officeBuildingController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [CapitalizeWordsTextInputFormatter()],
                    cursorColor: selectedThemeData.primaryColor,
                    onChanged: (value) {
                      provider.searchAddressSuggestions(value);
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: selectedThemeData.cardColor,
                      labelText: 'Address',
                      hintText: 'Search or enter your address',
                      labelStyle:
                          TextStyle(color: selectedThemeData.canvasColor),
                      hintStyle: TextStyle(
                        color: selectedThemeData.canvasColor,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.transparent),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.transparent),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: selectedThemeData.primaryColor,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      prefixIcon: Icon(
                        Icons.location_on_outlined,
                        color: selectedThemeData.canvasColor,
                      ),
                      suffixIcon: provider.isSearchingAddress
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: selectedThemeData.primaryColor,
                                ),
                              ),
                            )
                          : null,
                    ),
                    style: TextStyle(color: selectedThemeData.canvasColor),
                  ),
                  if (provider.addressSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6, bottom: 8),
                      decoration: BoxDecoration(
                        color: selectedThemeData.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selectedThemeData.primaryColor
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: provider.addressSuggestions.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: selectedThemeData.canvasColor
                              .withValues(alpha: 0.08),
                        ),
                        itemBuilder: (context, index) {
                          final suggestion =
                              provider.addressSuggestions[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.place_outlined,
                              color: selectedThemeData.primaryColor,
                            ),
                            title: Text(
                              suggestion['description'] ?? '',
                              style: TextStyle(
                                color: selectedThemeData.canvasColor,
                                fontSize: 13,
                              ),
                            ),
                            onTap: () {
                              provider.selectAddressSuggestion(suggestion);
                            },
                          );
                        },
                      ),
                    ),
                  _buildEditableLocationDropdown(
                    context: context,
                    selectedThemeData: selectedThemeData,
                    controller: provider.countryController,
                    label: lang.country,
                    hintText: lang.enterCountry,
                    options: provider.countryOptions,
                    onChanged: (value) {
                      if (value.trim().isEmpty) {
                        provider.loadStateOptionsByCountry('');
                      }
                    },
                    onFieldSubmitted: (value) {
                      provider.loadStateOptionsByCountry(value);
                    },
                    onOptionSelected: (value) {
                      provider.loadStateOptionsByCountry(value);
                    },
                  ),
                  _buildEditableLocationDropdown(
                    context: context,
                    selectedThemeData: selectedThemeData,
                    controller: provider.stateController,
                    label: lang.state,
                    hintText: lang.enterState,
                    options: provider.stateOptions,
                    onChanged: (value) {
                      if (value.trim().isEmpty) {
                        provider.loadDistrictOptionsByState('');
                      }
                    },
                    onFieldSubmitted: (value) {
                      provider.loadDistrictOptionsByState(value);
                    },
                    onOptionSelected: (value) {
                      provider.loadDistrictOptionsByState(value);
                    },
                  ),
                  _buildEditableLocationDropdown(
                    context: context,
                    selectedThemeData: selectedThemeData,
                    controller: provider.districtController,
                    label: lang.district,
                    hintText: lang.enterDistrict,
                    options: provider.districtOptions,
                    onChanged: (value) {
                      if (value.trim().isEmpty) {
                        provider.loadTalukaOptionsByDistrict('');
                      }
                    },
                    onFieldSubmitted: (value) {
                      provider.loadTalukaOptionsByDistrict(value);
                    },
                    onOptionSelected: (value) {
                      provider.loadTalukaOptionsByDistrict(value);
                    },
                  ),
                  _buildEditableLocationDropdown(
                    context: context,
                    selectedThemeData: selectedThemeData,
                    controller: provider.talukaController.text.isNotEmpty
                        ? provider.talukaController
                        : provider.cityController,
                    label: lang.taluka,
                    hintText: lang.enterTaluka,
                    options: provider.talukaOptions,
                  ),
                  _buildEditableLocationDropdown(
                    context: context,
                    selectedThemeData: selectedThemeData,
                    controller: provider.pinCodeDateController,
                    label: 'Pincode',
                    hintText: 'Enter pincode',
                    options: provider.pincodeOptions,
                    keyboardType: TextInputType.number,
                    isRequired: false,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedThemeData.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                var result = await provider.updateUserLocation();
                if (!ctx.mounted) return;
                if (result['success'] == true) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isLoggedIn', true);

                  if (provider.userObject.id != null) {
                    await provider.getUserById(provider.userObject.id!);
                  }

                  CustomToast.show(
                    context,
                    lang.profileUpdatedSuccessfully,
                    isSuccess: true,
                  );

                  Navigator.of(ctx).pop();
                } else {
                  CustomToast.show(
                    context,
                    'Failure: ${result['message']}',
                    isSuccess: false,
                  );
                }
              },
              child: const Center(
                child: Text(
                  'Save Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditableLocationDropdown({
    required BuildContext context,
    required ThemeData selectedThemeData,
    required TextEditingController controller,
    required String label,
    required String hintText,
    required List<String> options,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = true,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onFieldSubmitted,
    ValueChanged<String>? onOptionSelected,
  }) {
    final cleanOptions =
        options.where((option) => option.trim().isNotEmpty).toSet().toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selectedThemeData.canvasColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: keyboardType == TextInputType.number
                ? TextCapitalization.none
                : TextCapitalization.words,
            inputFormatters: keyboardType == TextInputType.number
                ? [FilteringTextInputFormatter.digitsOnly]
                : [CapitalizeWordsTextInputFormatter()],
            cursorColor: selectedThemeData.primaryColor,
            onChanged: onChanged,
            onFieldSubmitted: onFieldSubmitted,
            validator: isRequired
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '$hintText is required';
                    }
                    return null;
                  }
                : null,
            style: TextStyle(
              color: selectedThemeData.canvasColor,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: selectedThemeData.cardColor,
              hintText: hintText,
              hintStyle: TextStyle(
                color: selectedThemeData.canvasColor,
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.transparent),
                borderRadius: BorderRadius.circular(6),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.transparent),
                borderRadius: BorderRadius.circular(6),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: selectedThemeData.primaryColor),
                borderRadius: BorderRadius.circular(6),
              ),
              suffixIcon: cleanOptions.isEmpty
                  ? PopupMenuButton<String>(
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: selectedThemeData.primaryColor,
                      ),
                      color: selectedThemeData.cardColor,
                      enabled: false,
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          enabled: false,
                          child: Text(
                            'No options available',
                            style: TextStyle(
                              color: selectedThemeData.canvasColor
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    )
                  : PopupMenuButton<String>(
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: selectedThemeData.primaryColor,
                      ),
                      color: selectedThemeData.cardColor,
                      onSelected: (value) {
                        controller.text = value;
                        if (onOptionSelected != null) {
                          onOptionSelected(value);
                        }
                      },
                      itemBuilder: (context) {
                        return cleanOptions
                            .map(
                              (option) => PopupMenuItem<String>(
                                value: option,
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    color: selectedThemeData.canvasColor,
                                  ),
                                ),
                              ),
                            )
                            .toList();
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
