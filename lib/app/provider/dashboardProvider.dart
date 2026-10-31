import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:ott/app/core/utils/content_type.dart';
import 'package:ott/app/core/utils/sharepreferences.dart';
import 'package:ott/data/models/cast_member.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/models/response/continueWatchedResponse.dart';
import 'package:ott/data/models/response/getContentResponse.dart';
import 'package:ott/data/models/response/SeriesDetailsResponse.dart';
import 'package:ott/data/models/seriesModel.dart';
import 'package:ott/data/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/response/get_dashboard_data.dart';
import '../core/constant/api_constant.dart';
import '../core/network/api_helper.dart';
import 'baseProvider.dart';

class DashboardProvider extends BaseProvider {
  DashboardProvider() : super('Ideal');

  List<DashboardData> _dashboardData = [];
  List<DashboardData> get dashboardData => _dashboardData;

  Content _content = Content();
  Content get content => _content;
  List<CastMember> _castList = [];
  List<CastMember> get castList => _castList;

  TextEditingController searchContentController = TextEditingController();

  bool _isLoadingDashboard = false;
  bool get isLoading => _isLoadingDashboard;
  bool _isLoadingCast = false;
  bool get isLoadingCast => _isLoadingCast;

  List<Content> _continueWatchedMovies = [];
  List<Content> get continueWatchedMovies => _continueWatchedMovies;

  int _activeDashboardRequestId = 0;
  String? _activeDashboardType;
  int _activeContinueWatchRequestId = 0;
  String? _activeContinueWatchType;

  // ==================== DASHBOARD LOAD ====================

  Future<void> getDashboardData(
    String type,
    List<String> languages,
    int userId,
  ) async {
    final requestId = ++_activeDashboardRequestId;
    _activeDashboardType = type;

    _dashboardData = [];
    _isLoadingDashboard = true;
    notifyListeners();

    List<DashboardData> finalDashboardData = [];

    for (final lang in languages) {
      if (requestId != _activeDashboardRequestId) return;
      try {
        final latest = await getDashboardLatestData(type, [lang], userId);
        final trending = await getDashboardTrendingData(type, [lang], userId);
        final upcoming = await getDashboardUpcomingData(type, [lang], userId);

        if (requestId != _activeDashboardRequestId) return;

        _filterContentByType(latest, type);
        _filterContentByType(trending, type);
        _filterContentByType(upcoming, type);

        _initRowLoadingState(latest);
        _initRowLoadingState(trending);
        _initRowLoadingState(upcoming);

        finalDashboardData.addAll(latest);
        finalDashboardData.addAll(trending);
        finalDashboardData.addAll(upcoming);
      } catch (e) {}
    }

    if (requestId != _activeDashboardRequestId) return;

    _dashboardData = finalDashboardData;
    _isLoadingDashboard = false;
    notifyListeners();
  }

  /// Ensure all items in rows strictly match the requested content type
  void _filterContentByType(List<DashboardData> rows, String expectedType) {
    final normalizedExpected = expectedType.trim().toUpperCase();
    for (final row in rows) {
      if (row.movies != null) {
        row.movies = row.movies!.where((item) {
          final itemType = item.type?.trim().toUpperCase();
          return itemType == normalizedExpected;
        }).toList();
      }
    }
  }

  /// Only reset UI loading state — pagination comes from backend
  void _initRowLoadingState(List<DashboardData> rows) {
    for (final row in rows) {
      row.isRowLoading = false;
    }
  }

  // ==================== HORIZONTAL PAGINATION ====================

  Future<void> loadMoreRowData(
    DashboardData row,
    String type,
    int userId,
  ) async {
    if (row.isRowLoading || !row.hasMore) return;
    if (_activeDashboardType != null &&
        _activeDashboardType!.trim().toUpperCase() !=
            type.trim().toUpperCase()) {
      return;
    }

    row.isRowLoading = true;
    notifyListeners();

    final nextPage = row.currentPage + 1;

    try {
      List<DashboardData> newData = [];

      final cat = row.category?.toLowerCase() ?? "";

      if (cat.contains("latest")) {
        newData = await getDashboardLatestPaged(
            type, [row.language!], userId, nextPage);
      } else if (cat.contains("trending")) {
        newData = await getDashboardTrendingPaged(
            type, [row.language!], userId, nextPage);
      } else if (cat.contains("upcoming")) {
        newData = await getDashboardUpcomingPaged(
            type, [row.language!], userId, nextPage);
      }

      if (_activeDashboardType != null &&
          _activeDashboardType!.trim().toUpperCase() !=
              type.trim().toUpperCase()) {
        return;
      }

      _filterContentByType(newData, type);

      if (newData.isNotEmpty &&
          newData.first.movies != null &&
          newData.first.movies!.isNotEmpty) {
        row.movies!.addAll(newData.first.movies!);
        row.pagination = newData.first.pagination;
      }
    } catch (e) {}

    row.isRowLoading = false;
    notifyListeners();
  }

  // ==================== PAGED APIs ====================

  Future<List<DashboardData>> getDashboardLatestPaged(
    String type,
    List<String> languages,
    int userId,
    int page,
  ) async {
    return _getPagedApi("latest", type, languages, userId, page);
  }

  Future<List<DashboardData>> getDashboardTrendingPaged(
    String type,
    List<String> languages,
    int userId,
    int page,
  ) async {
    return _getPagedApi("trending", type, languages, userId, page);
  }

  Future<List<DashboardData>> getDashboardUpcomingPaged(
    String type,
    List<String> languages,
    int userId,
    int page,
  ) async {
    return _getPagedApi("upcoming", type, languages, userId, page);
  }

  Future<List<DashboardData>> _getPagedApi(
    String endpoint,
    String type,
    List<String> languages,
    int userId,
    int page,
  ) async {
    String languagesParam = languages.map((lang) => "lang=$lang").join('&');

    String apiUrl =
        "${ApiConstant.getNewDashboardData}$endpoint?type=$type&$languagesParam&userId=$userId&page=$page&size=10";

    ApiHelper apiHelper = ApiHelper();
    var response = await apiHelper.getApi(apiUrl);

    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      return DashboardResponse.fromJson(responseBody).data ?? [];
    } else {
      throw Exception('$endpoint paged API Failed');
    }
  }

  // ==================== ORIGINAL APIs ====================

  Future<List<DashboardData>> getDashboardLatestData(
      String type, List<String> languages, int userId) async {
    return getDashboardLatestPaged(type, languages, userId, 0);
  }

  Future<List<DashboardData>> getDashboardTrendingData(
      String type, List<String> languages, int userId) async {
    return getDashboardTrendingPaged(type, languages, userId, 0);
  }

  Future<List<DashboardData>> getDashboardUpcomingData(
      String type, List<String> languages, int userId) async {
    return getDashboardUpcomingPaged(type, languages, userId, 0);
  }

  // ==================== CONTENT DETAILS ====================

  Future<Content?> getContentById(int id) async {
    User? user = await LocalSharePreferences.localSharePreferences.getUser();
    String apiUrl = ApiConstant.getVideoById(id, user?.id ?? 1);
    ApiHelper apiHelper = ApiHelper();

    try {
      var response = await apiHelper.getApi(apiUrl);
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        GetContentResponse addUserResponse =
            GetContentResponse.fromJson(responseBody);

        if (addUserResponse.success == true &&
            addUserResponse.data?.contentList != null) {
          _content = addUserResponse.data!.contentList!;
          notifyListeners();
          return _content;
        }
      }
    } catch (error) {}
    return null;
  }

  Future<void> getCastByContentId(int contentId) async {
    _isLoadingCast = true;
    notifyListeners();

    final apiUrl = ApiConstant.getCastByContentId(contentId);
    final apiHelper = ApiHelper();

    try {
      final response = await apiHelper.getApi(apiUrl);
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final castData = responseBody['data']?['cast'] as List?;

        _castList = castData == null
            ? []
            : castData.map((item) => CastMember.fromJson(item)).toList();
      } else {
        _castList = [];
      }
    } catch (error) {
      _castList = [];
    } finally {
      _isLoadingCast = false;
      notifyListeners();
    }
  }

  Future<void> getContinueWatchedMovieList(String type) async {
    final cwRequestId = ++_activeContinueWatchRequestId;
    _activeContinueWatchType = type;

    _continueWatchedMovies.clear();
    notifyListeners();

    final localSharePreferences = LocalSharePreferences();
    final user = await localSharePreferences.getUser();
    if (user?.id == null) {
      if (cwRequestId == _activeContinueWatchRequestId) {
        _continueWatchedMovies.clear();
        notifyListeners();
      }
      return;
    }
    String apiUrl = ApiConstant.continueWatchedMoviesByUser(user!.id, type);
    ApiHelper apiHelper = ApiHelper();

    try {
      var response = await apiHelper.getApi1(apiUrl);

      if (cwRequestId != _activeContinueWatchRequestId ||
          type.trim().toUpperCase() !=
              (_activeContinueWatchType ?? '').trim().toUpperCase()) {
        return;
      }

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);

        ContinueWatchedResponse continueWatchedResponse =
            ContinueWatchedResponse.fromJson(responseBody);

        if (continueWatchedResponse.isSuccess == true &&
            continueWatchedResponse.data != null) {
          final normalizedType = type.trim().toUpperCase();
          final rawItems = continueWatchedResponse.data!.where((item) {
            final itemType = item.type?.trim().toUpperCase();
            return itemType == normalizedType;
          }).toList();

          final enrichedItems = <Content>[];
          final seenSeriesIds = <int>{};

          for (final item in rawItems) {
            final isSeries =
                ContentType.isSeries(item.type) || item.episodeId != null;

            if (isSeries) {
              final seriesId = item.seriesId ?? item.id;
              if (seriesId != null && seenSeriesIds.contains(seriesId)) {
                continue;
              }
              if (seriesId != null) seenSeriesIds.add(seriesId);

              // 1. Enrich from local SharedPreferences cache if episode metadata is missing
              if (item.episodeTitle == null || item.episodeNumber == null) {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  Map<String, dynamic>? meta;
                  if (item.episodeId != null && item.episodeId! > 0) {
                    final metaStr = prefs.getString(
                      "episode_meta_${seriesId}_${item.seasonId ?? 0}_${item.episodeId}",
                    );
                    if (metaStr != null) {
                      meta = jsonDecode(metaStr) as Map<String, dynamic>;
                    }
                  }
                  if (meta == null && seriesId != null) {
                    final seriesLastStr =
                        prefs.getString("series_last_episode_$seriesId");
                    if (seriesLastStr != null) {
                      meta = jsonDecode(seriesLastStr) as Map<String, dynamic>;
                    }
                  }

                  if (meta != null) {
                    item.episodeId ??= meta['episodeId'];
                    item.seasonId ??= meta['seasonId'];
                    item.episodeTitle ??= meta['episodeTitle'];
                    item.episodeNumber ??= meta['episodeNumber'];
                    item.seasonNumber ??= meta['seasonNumber'];
                    item.episodePosterUrl ??= meta['episodePosterUrl'];
                    item.seriesTitle ??= meta['seriesTitle'] ?? item.title;
                    if (meta['watchedSeconds'] != null &&
                        (item.watchedSeconds == null ||
                            item.watchedSeconds == 0)) {
                      item.watchedSeconds = meta['watchedSeconds'];
                    }
                    if (meta['watchedPercentage'] != null &&
                        (item.watchedPercentage == null ||
                            item.watchedPercentage == 0)) {
                      item.watchedPercentage = meta['watchedPercentage'];
                    }
                  }
                } catch (_) {}
              }

              // 2. If still missing episode metadata, resolve from series details
              if ((item.episodeTitle == null || item.episodeNumber == null) &&
                  seriesId != null &&
                  seriesId > 0) {
                try {
                  final detailsUrl =
                      ApiConstant.seriesDetails(seriesId, user.id);
                  final detailsRes = await apiHelper.getApi(detailsUrl);
                  if (detailsRes.statusCode == 200) {
                    final detailsBody = jsonDecode(detailsRes.body);
                    final seriesData =
                        SeriesDetailsResponse.fromJson(detailsBody);
                    final entity = seriesData.toEntity();

                    SeasonEntity? matchedSeason;
                    EpisodeEntity? matchedEpisode;

                    for (final s in entity.seasons) {
                      if (item.seasonId == null ||
                          s.seasonId == item.seasonId) {
                        for (final ep in s.episodes) {
                          if (item.episodeId == null ||
                              ep.episodeId == item.episodeId) {
                            matchedSeason = s;
                            matchedEpisode = ep;
                            break;
                          }
                        }
                      }
                      if (matchedEpisode != null) break;
                    }

                    if (matchedEpisode == null && entity.seasons.isNotEmpty) {
                      for (final s in entity.seasons) {
                        for (final ep in s.episodes) {
                          if (item.episodeId == ep.episodeId) {
                            matchedSeason = s;
                            matchedEpisode = ep;
                            break;
                          }
                        }
                        if (matchedEpisode != null) break;
                      }
                    }

                    if (matchedEpisode != null) {
                      item.episodeTitle = matchedEpisode.title;
                      item.episodeNumber = matchedEpisode.episodeNumber;
                      item.seasonNumber = matchedSeason?.seasonNumber;
                      item.episodePosterUrl = matchedEpisode.posterUrl;
                      item.seriesTitle = entity.title.isNotEmpty
                          ? entity.title
                          : item.title;
                      item.contentUrl = matchedEpisode.videoUrl;
                      item.seasonId ??= matchedSeason?.seasonId;
                      item.episodeId ??= matchedEpisode.episodeId;
                    }
                  }
                } catch (_) {}
              }

              enrichedItems.add(item);
            } else {
              enrichedItems.add(item);
            }
          }

          _continueWatchedMovies = enrichedItems;
        } else {
          _continueWatchedMovies.clear();
        }
      } else {
        _continueWatchedMovies.clear();
      }
    } catch (error) {
      if (cwRequestId == _activeContinueWatchRequestId) {
        _continueWatchedMovies.clear();
      }
    } finally {
      if (cwRequestId == _activeContinueWatchRequestId) {
        notifyListeners();
      }
    }
  }

  void clear() {
    _activeDashboardRequestId++;
    _activeContinueWatchRequestId++;
    _activeDashboardType = null;
    _activeContinueWatchType = null;
    _isLoadingDashboard = false;
    _dashboardData.clear();
    _continueWatchedMovies.clear();
    _castList.clear();
    notifyListeners();
  }
}
