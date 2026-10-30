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
import 'package:ott/app/widgets/customtextfield.dart';
import 'package:ott/app/widgets/responsive_poster_image.dart';
import 'package:ott/app/widgets/shimmer%20loader/search_shimmer.dart';
import 'package:ott/data/models/cast_member.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/repositories/demo.dart';
import 'package:ott/device/utils/ResponsiveWidget.dart';
import 'package:ott/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  bool isLoading = true;

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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final selectedThemeData = themeProvider.getTheme;
    final lang = AppLocalizations.of(context)!;

    final movies = featuredContent["movies"];
    final genreSet = {
      for (var movie in movies)
        ...List<String>.from([
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
          'Crime'
        ])
    };
    final languageSet = {
      for (var movie in movies) movie['language'].toString()
    };

    return Consumer<VideoProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: selectedThemeData.scaffoldBackgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading:
                !(kIsWeb || ResponsiveWidget.isTv(context)),
            toolbarHeight: 80,
            backgroundColor: ResponsiveWidget.isDesktop(context)
                ? selectedThemeData.scaffoldBackgroundColor
                : selectedThemeData.primaryColor,
            forceMaterialTransparency:
                ResponsiveWidget.isDesktop(context) ? true : false,
            title: SizedBox(
              width: ResponsiveWidget.isDesktop(context)
                  ? 500
                  : ResponsiveWidget.isTablet(context)
                      ? 400
                      : double.infinity,
              child: CustomTextField(
                controller: provider.searchContentController,
                hintText: lang.searchContent,
                prefixIcon: const Icon(Icons.search),
                textInputType: TextInputType.text,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: selectedThemeData.cardColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(
                      22,
                    ),
                  ),
                  child: Row(
                    children: [
                      ResponsiveWidget.isMobile(context)
                          ? SizedBox()
                          : Padding(
                              padding: EdgeInsets.only(
                                left: 10,
                              ),
                              child: Text(
                                lang.filter,
                                style: TextStyle(
                                  color: ResponsiveWidget.isDesktop(context)
                                      ? selectedThemeData.canvasColor
                                      : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                      PopupMenuButton(
                        color: selectedThemeData.cardColor,
                        tooltip: lang.filter,
                        icon: Icon(
                          Icons.filter_list,
                          color: ResponsiveWidget.isDesktop(context)
                              ? selectedThemeData.canvasColor
                              : Colors.white,
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: StatefulBuilder(
                              builder: (context, setState) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.filterOptions,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: selectedThemeData.primaryColor,
                                      ),
                                    ),
                                    const Divider(),
                                    Text(lang.genre),
                                    DropdownButton<String>(
                                      dropdownColor:
                                          selectedThemeData.cardColor,
                                      isExpanded: true,
                                      value: provider.selectedGenre,
                                      hint: Text(lang.selectGenre),
                                      onChanged: (value) {
                                        setState(() {
                                          provider.selectedGenre = value;
                                        });
                                        provider.applyFilter(
                                          value,
                                          provider.selectedLanguage,
                                          provider.selectedRating,
                                        );
                                      },
                                      items: genreSet
                                          .map((genre) =>
                                              DropdownMenuItem<String>(
                                                value: genre,
                                                child: Text(genre),
                                              ))
                                          .toList(),
                                    ),
                                    Text(lang.language),
                                    DropdownButton<String>(
                                      dropdownColor:
                                          selectedThemeData.cardColor,
                                      isExpanded: true,
                                      value: provider.selectedLanguage,
                                      hint: Text(lang.selectLanguage),
                                      onChanged: (value) {
                                        setState(() {
                                          provider.selectedLanguage = value;
                                        });
                                        provider.applyFilter(
                                          provider.selectedGenre,
                                          value,
                                          provider.selectedRating,
                                        );
                                      },
                                      items: languageSet
                                          .map((language) =>
                                              DropdownMenuItem<String>(
                                                value: language,
                                                child: Text(language),
                                              ))
                                          .toList(),
                                    ),
                                    Text(lang.minimumRating),
                                    DropdownButton<double>(
                                      dropdownColor:
                                          selectedThemeData.cardColor,
                                      isExpanded: true,
                                      value: provider.selectedRating,
                                      hint: Text(lang.selectRating),
                                      onChanged: (value) {
                                        setState(() {
                                          provider.selectedRating = value;
                                        });
                                        provider.applyFilter(
                                          provider.selectedGenre,
                                          provider.selectedLanguage,
                                          value,
                                        );
                                      },
                                      items: [3.0, 4.0, 4.5, 5.0]
                                          .map((rating) =>
                                              DropdownMenuItem<double>(
                                                value: rating,
                                                child: Text("$rating+"),
                                              ))
                                          .toList(),
                                    ),
                                    const SizedBox(height: 10),
                                    Center(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          provider.clearFilters();
                                          Navigator.pop(context);
                                        },
                                        child: Text(
                                          lang.clearFilter,
                                          style: TextStyle(
                                            color:
                                                selectedThemeData.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Inside _SearchPageState's build method where `body:` is assigned:
          body: isLoading
              ? SearchShimmer()
              : provider.filteredContentList.isEmpty
                  ? Center(
                      child: Text(
                        lang.noContentFound,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    )
                  : ResponsiveWidget.isMobile(context)
                      ? ListView.builder(
                          itemCount: provider.filteredContentList.length,
                          itemBuilder: (context, index) {
                            final movie = provider.filteredContentList[index];
                            return SearchMovieCard(movie: movie);
                          },
                        )
                      : CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.all(8.0),
                              sliver: SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final movie =
                                        provider.filteredContentList[index];
                                    return SearchMovieCard(movie: movie);
                                  },
                                  childCount:
                                      provider.filteredContentList.length,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent:
                                      ResponsiveWidget.isDesktop(context)
                                          ? 500
                                          : 550,
                                  mainAxisSpacing: 5,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 7 / 3,
                                ),
                              ),
                            ),
                          ],
                        ),
        );
      },
    );
  }
}

class SearchMovieCard extends StatefulWidget {
  final Content movie;

  const SearchMovieCard({
    super.key,
    required this.movie,
  });

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

    return LayoutBuilder(
      builder: (context, constraints) {
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

        final card = Card(
          color: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  height: 140,
                  child: ResponsivePosterImage(
                    imageUrl: movie.posterUrlList != null &&
                            movie.posterUrlList!.isNotEmpty
                        ? movie.posterUrlList![0]
                        : null,
                    imageUrls: movie.posterUrlList,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    backgroundColor: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    fallbackBuilder: () => Container(
                      width: 100,
                      height: 140,
                      color: theme.cardColor,
                      child: const Center(
                        child: Icon(
                          Icons.movie,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          TextSpan(
                              style: TextStyle(
                                color: theme.canvasColor.withOpacity(0.7),
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(
                                  text: ' ${movie.ratings ?? '-'}',
                                  style: TextStyle(
                                      color: Colors.amberAccent,
                                      fontWeight: FontWeight.w600),
                                ),
                                TextSpan(
                                  text: ' | ',
                                  style: TextStyle(
                                    color: theme.canvasColor.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                TextSpan(
                                  text: (movie.genreList != null &&
                                          movie.genreList!.isNotEmpty)
                                      ? movie.genreList!.join(', ')
                                      : 'N/A',
                                )
                              ]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          movie.title ?? 'No Title',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.canvasColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text.rich(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          TextSpan(
                              style: TextStyle(
                                color: theme.canvasColor.withOpacity(0.7),
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Director: ',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(text: _memberNames(_crewList))
                              ]),
                        ),
                        const SizedBox(height: 1),
                        Text.rich(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          TextSpan(
                              style: TextStyle(
                                color: theme.canvasColor.withOpacity(0.7),
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Cast: ',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(text: _memberNames(_castList))
                              ]),
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          TextSpan(
                              style: TextStyle(
                                color: theme.canvasColor.withOpacity(0.7),
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(
                                  text: formatReleaseDate(movie.releaseDate),
                                  style: TextStyle(
                                    color: theme.canvasColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: ' | ',
                                  style: TextStyle(
                                    color: theme.canvasColor.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                TextSpan(
                                  text: movie.description ?? '',
                                  style: TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                    fontSize: 12,
                                    color: theme.canvasColor.withOpacity(0.7),
                                  ),
                                )
                              ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (ResponsiveWidget.isMobile(context)) {
          return GestureDetector(onTap: openDetails, child: card);
        }

        return OttTvFocus(
          onTap: openDetails,
          borderRadius: 12,
          scale: 1.025,
          child: card,
        );
      },
    );
  }

  String _memberNames(List<CastMember> members) {
    final names = members
        .map((member) => member.name?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    return names.isEmpty ? 'N/A' : names.join(', ');
  }

  Widget _buildPeopleSection(BuildContext context) {
    final cast = _castList;
    final crew = _crewList;

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
        if (cast.isNotEmpty) _buildPeopleChips(context, 'Cast', cast),
        if (cast.isNotEmpty && crew.isNotEmpty) const SizedBox(height: 4),
        if (crew.isNotEmpty) _buildPeopleChips(context, 'Crew', crew),
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
    final name = member.name?.trim() ?? 'N/A';
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
