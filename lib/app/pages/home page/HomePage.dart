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
import 'package:ott/app/widgets/continue_watching_banner.dart';
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
import 'package:geolocator/geolocator.dart';
import '../../core/services/referral_service.dart';
import '../../core/services/staged_registration_service.dart';
import '../../widgets/month_year_picker_dialog.dart';
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
    try {
      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen(_setConnectionStatus);
    } catch (_) {}

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
    try {
      await _updateConnectionStatus();
      await _fetchUserData();
    } catch (e) {
      log('HomePage initialization warning: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        confirmDetails(context);
      }
    }
  }

  Future<void> _updateConnectionStatus() async {
    try {
      final connectivityResults =
          await Connectivity().checkConnectivity().timeout(
                const Duration(milliseconds: 500),
                onTimeout: () => [ConnectivityResult.wifi],
              );
      _setConnectionStatus(connectivityResults);
    } catch (e) {
      _setConnectionStatus([ConnectivityResult.wifi]);
    }
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
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.userObject;

    final stagedService = StagedRegistrationService.instance;
    final nextStep = stagedService.getNextIncompleteStep(user);

    if (!stagedService.shouldShowStepInCurrentLaunch(
      step: nextStep,
      user: user,
    )) {
      return;
    }

    switch (nextStep) {
      case StagedRegistrationStep.dobAndEmail:
        stage1ProfilePopUp(context);
        break;
      case StagedRegistrationStep.name:
        stage2ProfilePopUp(context);
        break;
      case StagedRegistrationStep.location:
        userLocationPopUp(context);
        break;
      case StagedRegistrationStep.none:
        break;
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
    final extent = MovieCard.cardExtentFor(context);
    final cardW = MovieCard.cardWidthFor(context);
    final viewEnd = viewStart + viewport;
    final firstCandidate = math.max(
      0,
      (viewStart / extent).floor(),
    );
    final lastCandidate = math.min(
      realItemCount - 1,
      math.max(
        firstCandidate,
        ((viewEnd - 0.001) / extent).floor(),
      ),
    );
    final isAtEnd =
        controller.position.maxScrollExtent - controller.offset <= 1;

    int? bestIndex;
    double bestVisibility = 0;

    for (int candidate = firstCandidate;
        candidate <= lastCandidate;
        candidate++) {
      final overlap = _visibleOverlap(viewStart, viewEnd, candidate, extent);
      if (overlap <= 0) continue;

      final hasTrailer = items != null &&
          candidate < items.length &&
          (items[candidate].trailerUrl?.trim().isNotEmpty ?? false);
      if (!hasTrailer) {
        continue;
      }

      final visibility = (overlap / cardW).clamp(0.0, 1.0).toDouble();
      _logHomeAutoPlay(
        'Visibility Percentage index=$candidate '
        '${(visibility * 100).toStringAsFixed(0)}%',
      );
      if (visibility < _autoPlayVisibilityThreshold) {
        continue;
      }

      if (bestIndex == null ||
          visibility > bestVisibility ||
          (visibility == bestVisibility && candidate > bestIndex)) {
        bestVisibility = visibility;
        bestIndex = candidate;
      }
    }

    if (bestIndex == null && isAtEnd) {
      final lastPlayableIndex = _lastPlayableIndex(items);
      if (lastPlayableIndex != null) {
        final overlap =
            _visibleOverlap(viewStart, viewEnd, lastPlayableIndex, extent);
        final visibility = (overlap / cardW).clamp(0.0, 1.0).toDouble();
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

  double _visibleOverlap(double viewStart, double viewEnd, int index,
      [double? extent]) {
    final itemExtent = extent ?? MovieCard.cardExtentFor(context);
    final itemStart = index * itemExtent;
    final itemEnd = itemStart + itemExtent;
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
      backgroundColor: selectedThemeData.scaffoldBackgroundColor,
      body: isLoading
          ? HomeShimmer()
          : CustomScrollView(
              controller: _verticalController,
              slivers: [
                _buildSliverAppBar(context, selectedThemeData),
                SliverToBoxAdapter(
                  child: Consumer<DashboardProvider>(
                    builder: (context, dashboardProvider, child) {
                      final showContentLoader = dashboardProvider.isLoading &&
                          (ContentType.isMovieLike(selectedType) ||
                              ContentType.isSeries(selectedType));

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!widget.lockContentType)
                            Container(
                              color: selectedThemeData.scaffoldBackgroundColor,
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10.0),
                                child: _buildFilterButtons(
                                    context, dashboardProvider),
                              ),
                            ),
                          const SizedBox(height: 6),
                          if (selectedType != 'MINI SERIES' &&
                              selectedType != 'MADIOO')
                            _isOffline
                                ? _continueWatchShimmerWidget()
                                : continueWatchWidget(
                                    continueWatchList: dashboardProvider
                                        .continueWatchedMovies),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (ResponsiveWidget.isTabletOrTv(context) &&
                                    selectedType != 'MINI SERIES' &&
                                    selectedType != 'MADIOO')
                                  _buildTvHeroSlider(
                                    context,
                                    selectedThemeData,
                                    dashboardProvider,
                                  ),
                                const SizedBox(height: 8),
                                showContentLoader
                                    ? _buildDashboardSectionLoader(
                                        context,
                                        selectedThemeData,
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          selectedType == 'MINI SERIES'
                                              ? ShortsLibraryPage(
                                                  useParentScroll: true)
                                              : selectedType == 'MADIOO'
                                                  ? MadiooPage(
                                                      useParentScroll: true)
                                                  : ListView.builder(
                                                      shrinkWrap: true,
                                                      physics:
                                                          NeverScrollableScrollPhysics(),
                                                      padding: EdgeInsets.zero,
                                                      scrollDirection:
                                                          Axis.vertical,
                                                      itemCount:
                                                          dashboardProvider
                                                              .dashboardData
                                                              .length,
                                                      itemBuilder:
                                                          (context, index) {
                                                        DashboardData
                                                            dashboardData =
                                                            dashboardProvider
                                                                    .dashboardData[
                                                                index];

                                                        _rowControllers.putIfAbsent(
                                                            index,
                                                            () =>
                                                                ScrollController());
                                                        _rowActiveIndexes
                                                            .putIfAbsent(
                                                                index,
                                                                () => ValueNotifier<
                                                                        int?>(
                                                                    null));
                                                        _rowItemCounts[index] =
                                                            dashboardData.movies
                                                                    ?.length ??
                                                                0;
                                                        _rowItems[index] =
                                                            dashboardData
                                                                    .movies ??
                                                                const <Content>[];
                                                        _scheduleVisibleUpdate();
                                                        _rowKeys.putIfAbsent(
                                                            index,
                                                            () => GlobalKey());

                                                        final controller =
                                                            _rowControllers[
                                                                index]!;
                                                        final activeIndex =
                                                            _rowActiveIndexes[
                                                                index]!;
                                                        final rowKey =
                                                            _rowKeys[index]!;

                                                        // Attach listener only once.
                                                        if (!controller
                                                            .hasListeners) {
                                                          controller
                                                              .addListener(() {
                                                            _scheduleVisibleUpdate();

                                                            if (controller
                                                                    .position
                                                                    .pixels >=
                                                                controller
                                                                        .position
                                                                        .maxScrollExtent -
                                                                    200) {
                                                              if (_userId !=
                                                                  null) {
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
                                                                  ? SizedBox
                                                                      .shrink()
                                                                  : InkWell(
                                                                      splashColor:
                                                                          Colors
                                                                              .transparent,
                                                                      onTap:
                                                                          () {
                                                                        Navigator
                                                                            .push(
                                                                          context,
                                                                          MaterialPageRoute(
                                                                            builder: (_) =>
                                                                                CategoryContentPage(
                                                                              categoryTitle: "${dashboardData.language} - ${dashboardData.category}",
                                                                              contents: dashboardData.movies ?? [],
                                                                            ),
                                                                          ),
                                                                        );
                                                                      },
                                                                      child:
                                                                          Padding(
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            horizontal:
                                                                                4.0,
                                                                            vertical:
                                                                                8.0),
                                                                        child:
                                                                            Row(
                                                                          children: [
                                                                            Expanded(
                                                                              child: Text(
                                                                                "${dashboardData.language} - ${dashboardData.category}",
                                                                                overflow: TextOverflow.ellipsis,
                                                                                style: GoogleFonts.inter(
                                                                                  fontSize: ResponsiveWidget.isMobile(context) ? 18 : 20,
                                                                                  fontWeight: FontWeight.bold,
                                                                                  color: selectedThemeData.canvasColor,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                Text(
                                                                                  "See All",
                                                                                  style: GoogleFonts.inter(
                                                                                    fontSize: 14,
                                                                                    fontWeight: FontWeight.bold,
                                                                                    color: const Color(0xFFE50914),
                                                                                  ),
                                                                                ),
                                                                                const SizedBox(width: 4),
                                                                                const Icon(
                                                                                  Icons.arrow_forward_ios_rounded,
                                                                                  size: 12,
                                                                                  color: Color(0xFFE50914),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                              (dashboardData.movies ==
                                                                          null ||
                                                                      dashboardData
                                                                          .movies!
                                                                          .isEmpty)
                                                                  ? SizedBox
                                                                      .shrink()
                                                                  : SizedBox(
                                                                      height: MovieCard
                                                                          .standardHeight,
                                                                      child: ListView
                                                                          .builder(
                                                                        controller:
                                                                            controller,
                                                                        scrollDirection:
                                                                            Axis.horizontal,
                                                                        //padding: EdgeInsets.zero,
                                                                        itemCount: dashboardData.movies!.length +
                                                                            (dashboardData.isRowLoading
                                                                                ? 1
                                                                                : 0),
                                                                        itemBuilder:
                                                                            (context,
                                                                                i) {
                                                                          if (i <
                                                                              dashboardData.movies!.length) {
                                                                            return MovieCard(
                                                                                movie: dashboardData.movies![i],
                                                                                index: i,
                                                                                isShortFilmTab: ContentType.normalize(selectedType) == ContentType.shortFilm,
                                                                                activeIndexListenable: activeIndex);
                                                                          } else if (dashboardData.isRowLoading) {
                                                                            return Padding(
                                                                              padding: const EdgeInsets.all(12),
                                                                              child: SizedBox(
                                                                                width: 40,
                                                                                height: 40,
                                                                                child: CircularProgressIndicator(strokeWidth: 2),
                                                                              ),
                                                                            );
                                                                          } else {
                                                                            return const SizedBox.shrink();
                                                                          }
                                                                        },
                                                                      ),
                                                                    ),
                                                              (dashboardData.movies ==
                                                                          null ||
                                                                      dashboardData
                                                                          .movies!
                                                                          .isEmpty)
                                                                  ? SizedBox
                                                                      .shrink()
                                                                  : SizedBox(
                                                                      height:
                                                                          20),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                    ),
                                        ],
                                      ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
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

    return KeyedSubtree(
      key: _continueWatchKey,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: ContinueWatchingBanner(
          items: items,
          selectedType: selectedType,
          onPlaybackFinished: () {
            if (mounted) {
              setState(() {});
            }
          },
        ),
      ),
    );
  }

  Widget _continueWatchShimmerWidget() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 20.0),
      child: ContinueWatchingBannerShimmer(),
    );
  }

// double bannerHeight(BuildContext context) {
  //   final width = MediaQuery.of(context).size.width;

  //   const posterRatio = 16 / 8;
  //   return width / posterRatio;
  // }

  Widget _buildCircleGlassButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    FeatureTourStepId? tourStepId,
  }) {
    Widget button = Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.15),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );

    if (tourStepId != null) {
      return FeatureTourTarget(id: tourStepId, child: button);
    }
    return button;
  }

  SliverAppBar _buildSliverAppBar(
      BuildContext context, ThemeData selectedThemeData) {
    final lang = AppLocalizations.of(context)!;

    return SliverAppBar(
      automaticallyImplyLeading: false,
      forceMaterialTransparency: false,
      floating: false,
      pinned: true,
      stretch: true,
      surfaceTintColor: Colors.transparent,
      backgroundColor: selectedThemeData.primaryColor,
      title: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 0),
            child: Image.asset(
              ImageConstant.logo,
              height: 70.0,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
          ),
        ),
      ),
      titleSpacing: 12,
      actions: [
        _buildCircleGlassButton(
          icon: Icons.search,
          tooltip: lang.search,
          tourStepId: FeatureTourStepId.search,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SearchPage()),
          ),
        ),
        const SizedBox(width: 6),
        _buildCircleGlassButton(
          icon: Icons.notifications_none,
          tooltip: lang.notification,
          tourStepId: FeatureTourStepId.notifications,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NotificationPage()),
          ),
        ),
        const SizedBox(width: 6),
        _buildCircleGlassButton(
          icon: Icons.language,
          tooltip: lang.selectPreferredLanguage,
          tourStepId: FeatureTourStepId.language,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChangeLanguage(),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Consumer<UserProvider>(builder: (context, userProvider, child) {
          final walletProvider =
              Provider.of<WalletProvider>(context, listen: false);

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCircleGlassButton(
                icon: Icons.account_balance_wallet_outlined,
                tooltip: "₹ ${walletProvider.walletBalance.toStringAsFixed(2)}",
                tourStepId: FeatureTourStepId.wallet,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => WalletPage()),
                ),
              ),
              const SizedBox(width: 6),
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
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: Builder(
                          builder: (_) {
                            final profilePhotoUrl = normalizeNetworkImageUrl(
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
            ],
          );
        }),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildFilterButtons(
      BuildContext context, DashboardProvider dashboardProvider) {
    final lang = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ...ContentType.homeTypes,
        ].map((type) {
          final isSelected = selectedType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
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
                        [];

                if (selectedType == 'MINI SERIES' || selectedType == 'MADIOO') {
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.primaryColor
                      : theme.cardColor,
                  border: Border.all(
                    color: isSelected
                        ? theme.primaryColor
                        : theme.dividerColor.withOpacity(0.2),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 18),
                child: Text(
                  type == ContentType.movie
                      ? lang.movie
                      : type == ContentType.series
                          ? lang.series
                          : ContentType.displayLabel(type),
                  style: GoogleFonts.inter(
                    color: isSelected
                        ? Colors.white
                        : theme.canvasColor,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
                height: MovieCard.standardHeight,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cardCount,
                  itemBuilder: (context, index) {
                    return Container(
                      width: MovieCard.cardWidthFor(context),
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
    log('User in getMovieList method ${user?.firstName} ');
    await dashBoardProvider.getContinueWatchedMovieList(selectedType);

    if (user?.id != null) {
      await dashBoardProvider.getDashboardData(
          selectedType, langList, user!.id!);
    }
  }

// Compatibility alias
  Future<void> userDetailsPopUp(BuildContext context) async {
    confirmDetails(context);
  }

  // STAGE 1: First Login / Minimum Information Popup (Email, Age based on Birth Year, Optional Referral Code)
  Future<void> stage1ProfilePopUp(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final lang = AppLocalizations.of(context)!;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (userProvider.emailController.text.trim().isEmpty) {
      userProvider.emailController.text = userProvider.userObject.emailId ?? "";
    }
    // Set age from userObject.age if present, or infer from dob if existing user has dob
    if (userProvider.ageController.text.trim().isEmpty) {
      final existingAge = userProvider.userObject.age?.trim();
      if (existingAge != null && existingAge.isNotEmpty) {
        userProvider.ageController.text = existingAge;
      } else {
        final existingDob = userProvider.userObject.dob?.trim();
        if (existingDob != null && existingDob.isNotEmpty) {
          final parsed = parseBirthMonthAndYear(existingDob);
          if (parsed['year'] != null) {
            final calculated = DateTime.now().year - (parsed['year'] as int);
            userProvider.ageController.text = '$calculated';
          }
        }
      }
    }
    if (userProvider.refferedByController.text.trim().isEmpty) {
      final userRefferedBy = userProvider.userObject.refferedBy?.trim();
      if (userRefferedBy != null && userRefferedBy.isNotEmpty) {
        userProvider.refferedByController.text = userRefferedBy;
      } else {
        final pendingReferral =
            await ReferralService.instance.getPendingReferralCode();
        if (pendingReferral != null && pendingReferral.isNotEmpty) {
          userProvider.refferedByController.text = pendingReferral;
        }
      }
    }

    final initialDob = userProvider.dobController.text.trim().isNotEmpty
        ? userProvider.dobController.text.trim()
        : (userProvider.userObject.dob?.trim() ?? '');
    final initialParsed = parseBirthMonthAndYear(initialDob);
    String? selectedMonth = initialParsed['month'];
    int? selectedYear = initialParsed['year'];

    if (selectedYear == null &&
        userProvider.ageController.text.trim().isNotEmpty) {
      final ageVal = int.tryParse(userProvider.ageController.text.trim());
      if (ageVal != null && ageVal > 0 && ageVal < 130) {
        selectedYear = DateTime.now().year - ageVal;
      }
    }
    if (selectedMonth != null && selectedYear != null) {
      userProvider.setBirthMonthAndYear(selectedMonth, selectedYear);
    }

    if (!context.mounted) return;

    StagedRegistrationService.instance.setDialogActive(true);
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final provider = Provider.of<UserProvider>(context, listen: true);
            final selectedThemeData =
                Provider.of<ThemeProvider>(context, listen: true).getTheme;

            final currentYear = DateTime.now().year;
            final currentMonth = DateTime.now().month;
            final birthYears = getBirthYears();

            return AlertDialog(
              backgroundColor: selectedThemeData.scaffoldBackgroundColor,
              title: Text(
                lang.enterDetails,
                style: TextStyle(
                  color: selectedThemeData.canvasColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Field 1: Birth Month and Year (Month & Year Only, No Day Field)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Month Dropdown
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: selectedMonth,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Birth Month *',
                                hintText: 'Month',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Icon(
                                  Icons.calendar_month_outlined,
                                  size: 18,
                                  color: selectedThemeData.canvasColor
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              dropdownColor:
                                  selectedThemeData.scaffoldBackgroundColor,
                              items: kBirthMonths
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(
                                        m,
                                        style: TextStyle(
                                          color: selectedThemeData.canvasColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: isSubmitting
                                  ? null
                                  : (val) {
                                      setDialogState(() {
                                        selectedMonth = val;
                                        if (selectedMonth != null &&
                                            selectedYear != null) {
                                          provider.setBirthMonthAndYear(
                                            selectedMonth!,
                                            selectedYear!,
                                          );
                                        }
                                      });
                                    },
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Select month';
                                }
                                if (selectedYear == currentYear &&
                                    val.isNotEmpty) {
                                  final monthIndex =
                                      kBirthMonths.indexOf(val) + 1;
                                  if (monthIndex > currentMonth) {
                                    return 'Invalid month';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Year Dropdown
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              value: selectedYear,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Birth Year *',
                                hintText: 'Year',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              dropdownColor:
                                  selectedThemeData.scaffoldBackgroundColor,
                              items: birthYears
                                  .map(
                                    (y) => DropdownMenuItem(
                                      value: y,
                                      child: Text(
                                        '$y',
                                        style: TextStyle(
                                          color: selectedThemeData.canvasColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: isSubmitting
                                  ? null
                                  : (val) {
                                      setDialogState(() {
                                        selectedYear = val;
                                        if (selectedMonth != null &&
                                            selectedYear != null) {
                                          provider.setBirthMonthAndYear(
                                            selectedMonth!,
                                            selectedYear!,
                                          );
                                        }
                                      });
                                    },
                              validator: (val) {
                                if (val == null) {
                                  return 'Select year';
                                }
                                if (val > currentYear) {
                                  return 'Invalid year';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      if (selectedMonth != null && selectedYear != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selectedThemeData.cardColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: selectedThemeData.primaryColor
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.cake_outlined,
                                size: 16,
                                color: selectedThemeData.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Birth Date: $selectedMonth $selectedYear',
                                style: TextStyle(
                                  color: selectedThemeData.canvasColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Field 2: Email (Completely Optional)
                      CustomTextField(
                        controller: provider.emailController,
                        isEmail: false,
                        isValidator: false,
                        label: '${lang.email} (Optional)',
                        hintText: lang.enterEmail,
                        textInputType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final emailRegex =
                                RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(val.trim())) {
                              return lang.enterEmail;
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Field 3: Referral Code (Optional)
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
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          if (selectedMonth != null && selectedYear != null) {
                            provider.setBirthMonthAndYear(
                              selectedMonth!,
                              selectedYear!,
                            );
                          }
                          setDialogState(() {
                            isSubmitting = true;
                          });

                          print(
                              "[DOB POPUP] Submitting birth month and year popup...");
                          var result = await provider.updateUserDetails();
                          print("[DOB POPUP] Update API result: $result");
                          if (!dialogCtx.mounted) return;

                          if (result['success'] == true) {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('isLoggedIn', true);

                            if (provider.userObject.id != null) {
                              await provider
                                  .getUserById(provider.userObject.id!);
                            }

                            await StagedRegistrationService.instance
                                .markStepCompleted(
                              step: StagedRegistrationStep.dobAndEmail,
                              userId: provider.userObject.id,
                            );

                            if (provider.refferedByController.text
                                .trim()
                                .isNotEmpty) {
                              await ReferralService.instance
                                  .clearReferralCode();
                            }

                            if (context.mounted) {
                              CustomToast.show(
                                context,
                                lang.profileUpdatedSuccessfully,
                                isSuccess: true,
                              );
                            }

                            Navigator.of(dialogCtx).pop();
                          } else {
                            setDialogState(() {
                              isSubmitting = false;
                            });
                            if (context.mounted) {
                              CustomToast.show(
                                context,
                                'Failure: ${result['message']}',
                                isSuccess: false,
                              );
                            }
                          }
                        },
                  child: Center(
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
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
      },
    );
    StagedRegistrationService.instance.setDialogActive(false);
  }

  // STAGE 2: Second App Open / Remaining Profile Information Popup (Single Optional Name Field)
  Future<void> stage2ProfilePopUp(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final lang = AppLocalizations.of(context)!;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final initialFirst = userProvider.userObject.firstName ??
        userProvider.firstNameController.text;
    final initialLast = userProvider.userObject.lastName ??
        userProvider.lastNameController.text;
    final initialFullName = '$initialFirst $initialLast'.trim();
    final nameController = TextEditingController(text: initialFullName);

    StagedRegistrationService.instance.setDialogActive(true);
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final provider = Provider.of<UserProvider>(context, listen: true);
            final selectedThemeData =
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                        label: 'Name (Optional)',
                        hintText: 'Enter your name',
                        isValidator: false,
                        textInputType: TextInputType.name,
                        capitalization: TextCapitalization.words,
                        validator: (val) {
                          if (val != null &&
                              val.trim().isNotEmpty &&
                              val.trim().length < 2) {
                            return 'Please enter a valid name';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: selectedThemeData.canvasColor
                                .withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                await StagedRegistrationService.instance
                                    .markStepSkipped(
                                  step: StagedRegistrationStep.name,
                                  userId: provider.userObject.id,
                                );
                                Navigator.of(dialogCtx).pop();
                              },
                        child: Text(
                          lang.skip,
                          style: TextStyle(
                            color: selectedThemeData.canvasColor
                                .withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedThemeData.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                final fullName = nameController.text.trim();

                                if (fullName.isEmpty) {
                                  await StagedRegistrationService.instance
                                      .markStepSkipped(
                                    step: StagedRegistrationStep.name,
                                    userId: provider.userObject.id,
                                  );
                                  Navigator.of(dialogCtx).pop();
                                  return;
                                }

                                setDialogState(() {
                                  isSubmitting = true;
                                });

                                final parts = fullName.split(RegExp(r'\s+'));
                                final firstName = parts.first;
                                final lastName = parts.length > 1
                                    ? parts.sublist(1).join(' ')
                                    : '';

                                provider.firstNameController.text = firstName;
                                provider.lastNameController.text = lastName;

                                var result = await provider.updateUserDetails();
                                if (!dialogCtx.mounted) return;

                                if (result['success'] == true) {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setBool('isLoggedIn', true);

                                  if (provider.userObject.id != null) {
                                    await provider
                                        .getUserById(provider.userObject.id!);
                                  }

                                  await StagedRegistrationService.instance
                                      .markStepCompleted(
                                    step: StagedRegistrationStep.name,
                                    userId: provider.userObject.id,
                                  );

                                  if (context.mounted) {
                                    CustomToast.show(
                                      context,
                                      lang.profileUpdatedSuccessfully,
                                      isSuccess: true,
                                    );
                                  }

                                  Navigator.of(dialogCtx).pop();
                                } else {
                                  setDialogState(() {
                                    isSubmitting = false;
                                  });
                                  if (context.mounted) {
                                    CustomToast.show(
                                      context,
                                      'Failure: ${result['message']}',
                                      isSuccess: false,
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
    StagedRegistrationService.instance.setDialogActive(false);
  }

  // STAGE 3: Third App Open / Location Popup (Current Location Only with Cancel)
  Future<void> userLocationPopUp(BuildContext context) async {
    final lang = AppLocalizations.of(context)!;

    if (!context.mounted) return;

    StagedRegistrationService.instance.setDialogActive(true);

    bool isFetching = false;
    bool isSaving = false;
    String? locationError;
    bool isPermanentlyDenied = false;
    bool locationDetected = false;
    String detectedSummary = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final provider = Provider.of<UserProvider>(context, listen: true);
            final selectedThemeData =
                Provider.of<ThemeProvider>(context, listen: true).getTheme;

            return AlertDialog(
              backgroundColor: selectedThemeData.scaffoldBackgroundColor,
              title: Row(
                children: [
                  Icon(
                    Icons.my_location,
                    color: selectedThemeData.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang.enterLocationDetails,
                      style: TextStyle(
                        color: selectedThemeData.canvasColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Share your current location to get regional content and personalized recommendations.',
                      style: TextStyle(
                        fontSize: 14,
                        color: selectedThemeData.canvasColor
                            .withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (locationDetected) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedThemeData.cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedThemeData.primaryColor
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Location Detected',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: selectedThemeData.canvasColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    detectedSummary,
                                    style: TextStyle(
                                      color: selectedThemeData.canvasColor
                                          .withValues(alpha: 0.9),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (locationError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          locationError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (isPermanentlyDenied) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Geolocator.openAppSettings();
                          },
                          icon: const Icon(Icons.settings, size: 16),
                          label: const Text('Open App Settings'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: selectedThemeData.primaryColor,
                            side: BorderSide(
                              color: selectedThemeData.primaryColor,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                Row(
                  children: [
                    // CANCEL BUTTON
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isFetching || isSaving
                            ? null
                            : () {
                                // Close dialog without requesting or saving location.
                                // Does not mark location as completed; prevents repeating in current session.
                                StagedRegistrationService.instance
                                    .markStepHandledForLaunch();
                                Navigator.of(dialogCtx).pop();
                              },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: selectedThemeData.dividerColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: selectedThemeData.canvasColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // USE CURRENT LOCATION / SAVE LOCATION BUTTON
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedThemeData.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: isFetching || isSaving
                            ? null
                            : () async {
                                if (locationDetected) {
                                  // Save already detected location
                                  setDialogState(() {
                                    isSaving = true;
                                  });
                                  final saveResult =
                                      await provider.updateUserLocation();
                                  setDialogState(() {
                                    isSaving = false;
                                  });

                                  if (saveResult['success'] == true) {
                                    await StagedRegistrationService.instance
                                        .markStepCompleted(
                                      step: StagedRegistrationStep.location,
                                      userId: provider.userObject.id,
                                    );
                                    if (context.mounted) {
                                      CustomToast.show(
                                        context,
                                        lang.profileUpdatedSuccessfully,
                                        isSuccess: true,
                                      );
                                    }
                                    Navigator.of(dialogCtx).pop();
                                  } else {
                                    setDialogState(() {
                                      locationError =
                                          saveResult['message']?.toString() ??
                                              'Failed to save location';
                                    });
                                  }
                                } else {
                                  // Fetch current location via device GPS + Google Geocoding
                                  setDialogState(() {
                                    isFetching = true;
                                    locationError = null;
                                    isPermanentlyDenied = false;
                                  });

                                  final fetchResult = await provider
                                      .fetchAndApplyCurrentDeviceLocation();

                                  if (fetchResult['success'] == true) {
                                    final city =
                                        fetchResult['city']?.toString() ?? '';
                                    final state =
                                        fetchResult['state']?.toString() ?? '';
                                    final country =
                                        fetchResult['country']?.toString() ??
                                            '';
                                    final summary = [city, state, country]
                                        .where((s) => s.isNotEmpty)
                                        .join(', ');

                                    setDialogState(() {
                                      isFetching = false;
                                      locationDetected = true;
                                      detectedSummary = summary.isNotEmpty
                                          ? summary
                                          : (fetchResult['formattedAddress']
                                                  ?.toString() ??
                                              'Current Location');
                                      isSaving = true;
                                    });

                                    // Save the resolved location using existing API
                                    final saveResult =
                                        await provider.updateUserLocation();
                                    setDialogState(() {
                                      isSaving = false;
                                    });

                                    if (saveResult['success'] == true) {
                                      await StagedRegistrationService.instance
                                          .markStepCompleted(
                                        step: StagedRegistrationStep.location,
                                        userId: provider.userObject.id,
                                      );
                                      if (context.mounted) {
                                        CustomToast.show(
                                          context,
                                          lang.profileUpdatedSuccessfully,
                                          isSuccess: true,
                                        );
                                      }
                                      Navigator.of(dialogCtx).pop();
                                    } else {
                                      setDialogState(() {
                                        locationError = saveResult['message']
                                                ?.toString() ??
                                            'Failed to save location to profile';
                                      });
                                    }
                                  } else {
                                    setDialogState(() {
                                      isFetching = false;
                                      locationError = fetchResult['error']
                                              ?.toString() ??
                                          'Could not determine your location';
                                      isPermanentlyDenied =
                                          fetchResult['isPermanentlyDenied'] ==
                                              true;
                                    });
                                  }
                                }
                              },
                        child: isFetching || isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                locationDetected
                                    ? 'Save Location'
                                    : 'Use Current Location',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
    StagedRegistrationService.instance.setDialogActive(false);
  }
}
