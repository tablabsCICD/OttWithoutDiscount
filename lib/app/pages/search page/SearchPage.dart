import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ott/app/core/constant/api_constant.dart';
import 'package:ott/app/core/network/api_helper.dart';
import 'package:ott/app/core/utils/content_type.dart';
import 'package:ott/app/core/utils/release_date_formatter.dart';
import 'package:ott/app/pages/movie%20details%20page/MovieDetailsPage.dart';
import 'package:ott/app/pages/series%20details%20page/seriesdetailspage.dart';
import 'package:ott/app/provider/themeProvider.dart';
import 'package:ott/app/provider/videoProvider.dart';
import 'package:ott/app/widgets/ott_tv_focus.dart';
import 'package:ott/app/widgets/responsive_poster_image.dart';
import 'package:ott/app/widgets/shimmer%20loader/search_shimmer.dart';
import 'package:ott/data/models/cast_member.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/repositories/demo.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:ott/app/widgets/filmytell_app_bar.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  bool isLoading = true;

  static const List<String> _genres = <String>[
    'Action',
    'Drama',
    'Comedy',
    'Thriller',
    'Horror',
    'Romance',
    'Sci-Fi',
    'Fantasy',
    'Mystery',
    'Documentary',
    'Animation',
    'Adventure',
    'Musical',
    'Historical',
    'Crime',
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      Provider.of<VideoProvider>(context, listen: false).searchContent();
      setState(() {
        isLoading = false;
      });
    });
  }

  Set<String> get _languages => {
        for (final movie in featuredContent["movies"])
          movie['language'].toString()
      };

  bool _hasActiveFilter(VideoProvider provider) =>
      provider.selectedGenre != null ||
      provider.selectedLanguage != null ||
      provider.selectedRating != null;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final theme = themeProvider.getTheme;
    final lang = AppLocalizations.of(context)!;
    final isDesktop = ResponsiveWidget.isDesktop(context);

    return Consumer<VideoProvider>(
      builder: (context, provider, child) {
        final results = provider.filteredContentList;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading:
                !(kIsWeb || ResponsiveWidget.isTv(context)),
            toolbarHeight: FilmytellAppBarMetrics.main,
            titleSpacing: 12,
            backgroundColor:
                isDesktop ? theme.scaffoldBackgroundColor : theme.primaryColor,
            foregroundColor: isDesktop ? theme.canvasColor : Colors.white,
            forceMaterialTransparency: isDesktop,
            title: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchField(
                        controller: provider.searchContentController,
                        hintText: lang.searchContent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FilterButton(
                      tooltip: lang.filter,
                      active: _hasActiveFilter(provider),
                      onPressed: () => _openFilters(context, provider),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: isLoading
              ? const SearchShimmer()
              : results.isEmpty
                  ? _SearchEmptyState(
                      title: lang.noContentFound,
                      subtitle: lang.searchNoResultsHint,
                    )
                  : _buildResults(context, theme, lang, results),
        );
      },
    );
  }

  Widget _buildResults(
    BuildContext context,
    ThemeData theme,
    AppLocalizations lang,
    List<Content> results,
  ) {
    final isMobile = ResponsiveWidget.isMobile(context);
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              lang.searchResultsCount(results.length),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: theme.canvasColor,
              ),
            ),
          ),
          Icon(Icons.swap_vert_rounded,
              size: 16, color: theme.canvasColor.withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Text(
            lang.newestFirst,
            style: TextStyle(
              fontSize: 12,
              color: theme.canvasColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: header),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          sliver: isMobile
              ? SliverList.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => SizedBox(
                    height: SearchMovieCard.cardHeight,
                    child: SearchMovieCard(movie: results[index]),
                  ),
                )
              : SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => SearchMovieCard(movie: results[index]),
                    childCount: results.length,
                  ),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent:
                        ResponsiveWidget.isDesktop(context) ? 560 : 520,
                    mainAxisExtent: SearchMovieCard.cardHeight,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _openFilters(BuildContext context, VideoProvider provider) {
    final lang = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final languages = _languages;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Widget label(String text) => Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 6),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.canvasColor,
                    ),
                  ),
                );

            InputDecoration fieldDecoration(String hint) => InputDecoration(
                  hintText: hint,
                  isDense: true,
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.4)),
                  ),
                );

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: theme.dividerColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          lang.filterOptions,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: theme.primaryColor,
                          ),
                        ),
                        label(lang.genre),
                        DropdownButtonFormField<String>(
                          initialValue: provider.selectedGenre,
                          isExpanded: true,
                          dropdownColor: theme.cardColor,
                          decoration: fieldDecoration(lang.selectGenre),
                          items: _genres
                              .map((genre) => DropdownMenuItem<String>(
                                    value: genre,
                                    child: Text(_genreLabel(lang, genre)),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setSheetState(() => provider.selectedGenre = value);
                            provider.applyFilter(
                              value,
                              provider.selectedLanguage,
                              provider.selectedRating,
                            );
                          },
                        ),
                        label(lang.language),
                        DropdownButtonFormField<String>(
                          initialValue: provider.selectedLanguage,
                          isExpanded: true,
                          dropdownColor: theme.cardColor,
                          decoration: fieldDecoration(lang.selectLanguage),
                          items: languages
                              .map((language) => DropdownMenuItem<String>(
                                    value: language,
                                    child: Text(language),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setSheetState(
                                () => provider.selectedLanguage = value);
                            provider.applyFilter(
                              provider.selectedGenre,
                              value,
                              provider.selectedRating,
                            );
                          },
                        ),
                        label(lang.minimumRating),
                        DropdownButtonFormField<double>(
                          initialValue: provider.selectedRating,
                          isExpanded: true,
                          dropdownColor: theme.cardColor,
                          decoration: fieldDecoration(lang.selectRating),
                          items: const [3.0, 4.0, 4.5, 5.0]
                              .map((rating) => DropdownMenuItem<double>(
                                    value: rating,
                                    child: Text("$rating+"),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setSheetState(
                                () => provider.selectedRating = value);
                            provider.applyFilter(
                              provider.selectedGenre,
                              provider.selectedLanguage,
                              value,
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(46),
                                  side: BorderSide(color: theme.primaryColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  provider.clearFilters();
                                  Navigator.pop(sheetContext);
                                },
                                child: Text(
                                  lang.clearFilter,
                                  style: TextStyle(color: theme.primaryColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(46),
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(sheetContext),
                                child: Text(lang.done),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Localized display name for a genre filter value. The value itself (sent
/// to the filter API) stays in English.
String _genreLabel(AppLocalizations lang, String genre) {
  switch (genre) {
    case 'Action':
      return lang.genreAction;
    case 'Drama':
      return lang.cardDefaultGenre;
    case 'Comedy':
      return lang.genreComedy;
    case 'Thriller':
      return lang.genreThriller;
    case 'Horror':
      return lang.genreHorror;
    case 'Romance':
      return lang.genreRomance;
    case 'Sci-Fi':
      return lang.genreSciFi;
    case 'Fantasy':
      return lang.genreFantasy;
    case 'Mystery':
      return lang.genreMystery;
    case 'Documentary':
      return lang.genreDocumentary;
    case 'Animation':
      return lang.genreAnimation;
    case 'Adventure':
      return lang.genreAdventure;
    case 'Musical':
      return lang.genreMusical;
    case 'Historical':
      return lang.genreHistorical;
    case 'Crime':
      return lang.genreCrime;
    default:
      return genre;
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hintText});

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = theme.scaffoldBackgroundColor;
    final iconColor = theme.canvasColor.withValues(alpha: 0.7);

    return SizedBox(
      height: 46,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: theme.canvasColor, fontSize: 15),
            cursorColor: theme.primaryColor,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: theme.canvasColor.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              filled: true,
              fillColor: fill,
              contentPadding: EdgeInsets.zero,
              prefixIcon: Icon(Icons.search_rounded, color: iconColor),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close_rounded, color: iconColor),
                      onPressed: controller.clear,
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });

  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Badge(
          isLabelVisible: active,
          smallSize: 8,
          backgroundColor: theme.primaryColor,
          child: Icon(Icons.tune_rounded, color: theme.canvasColor),
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded,
                  size: 46, color: theme.primaryColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: theme.canvasColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.canvasColor.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchMovieCard extends StatefulWidget {
  final Content movie;

  const SearchMovieCard({
    super.key,
    required this.movie,
  });

  /// Fixed card height so list and grid rows line up and never overflow.
  static const double cardHeight = 176;

  @override
  State<SearchMovieCard> createState() => _SearchMovieCardState();
}

class _SearchMovieCardState extends State<SearchMovieCard> {
  bool _isLoadingCast = false;
  List<CastMember> _apiCastAndCrew = [];

  Content get movie => widget.movie;

  @override
  void initState() {
    super.initState();
    _loadCastAndCrew();
  }

  @override
  void didUpdateWidget(covariant SearchMovieCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movie.id != widget.movie.id) {
      _loadCastAndCrew();
    }
  }

  Future<void> _loadCastAndCrew() async {
    final contentId = widget.movie.id;
    if (contentId == null) return;

    setState(() {
      _isLoadingCast = true;
      _apiCastAndCrew = [];
    });

    try {
      final response =
          await ApiHelper().getApi(ApiConstant.getCastByContentId(contentId));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final responseData =
            responseBody is Map<String, dynamic> ? responseBody['data'] : null;
        final castData =
            responseData is Map<String, dynamic> ? responseData['cast'] : null;

        setState(() {
          _apiCastAndCrew = castData is! List
              ? []
              : castData
                  .whereType<Map<String, dynamic>>()
                  .map(CastMember.fromJson)
                  .toList();
        });
      }
    } catch (error) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingCast = false);
      }
    }
  }

  List<CastMember> get _castList {
    final apiCast = _apiCastAndCrew.where(_isCastMember).toList();
    if (apiCast.isNotEmpty) return apiCast;

    return (movie.castList ?? const [])
        .where((name) => name.trim().isNotEmpty)
        .map((name) => CastMember(name: name.trim(), role: 'Cast'))
        .toList();
  }

  List<CastMember> get _crewList {
    final apiCrew =
        _apiCastAndCrew.where((member) => !_isCastMember(member)).toList();
    if (apiCrew.isNotEmpty) return apiCrew;

    return (movie.directorList ?? const [])
        .where((name) => name.trim().isNotEmpty)
        .map((name) => CastMember(name: name.trim(), role: 'Director'))
        .toList();
  }

  bool _isCastMember(CastMember member) {
    final role = member.role?.toLowerCase().trim() ?? '';
    if (role.isEmpty) return true;

    const castRoles = {
      'actor',
      'actress',
      'cast',
      'lead actor',
      'lead actress',
      'supporting actor',
      'supporting actress',
      'artist',
      'character',
    };

    return castRoles.any(role.contains);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final theme = themeProvider.getTheme;
    final lang = AppLocalizations.of(context)!;
    final muted = theme.canvasColor.withValues(alpha: 0.7);
    final releaseText = formatReleaseDate(movie.releaseDate);
    final genres = (movie.genreList ?? const <String>[])
        .where((g) => g.trim().isNotEmpty)
        .join(' • ');

    void openDetails() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ContentType.isMovieLike(movie.type)
              ? MovieDetailsPage(
                  movieId: movie.id!,
                  contentType: movie.type,
                )
              : SeriesDetailsPage(
                  seriesId: movie.id!,
                  content: movie,
                ),
        ),
      );
    }

    Widget peopleLine(String label, List<CastMember> members) {
      return Text.rich(
        TextSpan(
          style: TextStyle(color: muted, fontSize: 12),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: _memberNames(members)),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final card = Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: ResponsivePosterImage(
              imageUrl:
                  movie.posterUrlList != null && movie.posterUrlList!.isNotEmpty
                      ? movie.posterUrlList![0]
                      : null,
              imageUrls: movie.posterUrlList,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              backgroundColor: Colors.black,
              borderRadius: BorderRadius.circular(10),
              enableAmbientBackdrop: false,
              fallbackBuilder: () => Container(
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.movie, size: 40, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title ?? lang.noTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.canvasColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if ((movie.type ?? '').trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _localizedTypeLabel(lang, movie.type),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    if (movie.ratings != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            '${movie.ratings}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.canvasColor,
                            ),
                          ),
                        ],
                      ),
                    if (releaseText.isNotEmpty)
                      Text(
                        releaseText,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                  ],
                ),
                if (genres.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    genres,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
                const SizedBox(height: 4),
                peopleLine(lang.director, _crewList),
                peopleLine(lang.cast, _castList),
                const Spacer(),
                Text(
                  movie.description ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: muted, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (ResponsiveWidget.isMobile(context)) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: openDetails,
          child: card,
        ),
      );
    }

    return OttTvFocus(
      onTap: openDetails,
      borderRadius: 14,
      scale: 1.025,
      child: card,
    );
  }

  String _localizedTypeLabel(AppLocalizations lang, String? type) =>
      ContentType.localizedLabel(lang, type);

  String _memberNames(List<CastMember> members) {
    final names = members
        .map((member) => member.name?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    return names.isEmpty
        ? AppLocalizations.of(context)!.searchNotAvailable
        : names.join(', ');
  }

  Widget _buildPeopleSection(BuildContext context) {
    final cast = _castList;
    final crew = _crewList;
    final lang = AppLocalizations.of(context)!;

    if (_isLoadingCast && cast.isEmpty && crew.isEmpty) {
      return const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (cast.isEmpty && crew.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cast.isNotEmpty) _buildPeopleChips(context, lang.cast, cast),
        if (cast.isNotEmpty && crew.isNotEmpty) const SizedBox(height: 4),
        if (crew.isNotEmpty) _buildPeopleChips(context, lang.searchCrew, crew),
      ],
    );
  }

  Widget _buildPeopleChips(
    BuildContext context,
    String label,
    List<CastMember> members,
  ) {
    final theme = Theme.of(context);
    final visibleMembers = members.take(4).toList();

    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: theme.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visibleMembers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                return _buildPersonChip(context, visibleMembers[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonChip(BuildContext context, CastMember member) {
    final theme = Theme.of(context);
    final name =
        member.name?.trim() ?? AppLocalizations.of(context)!.searchNotAvailable;
    final role = member.role?.trim() ?? '';

    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.canvasColor.withOpacity(0.12)),
      ),
      child: Text(
        role.isEmpty ? name : '$name ($role)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: theme.canvasColor.withOpacity(0.78),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
