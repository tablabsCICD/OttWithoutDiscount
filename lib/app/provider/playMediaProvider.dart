import 'dart:convert';
import 'dart:developer';

import 'package:ott/app/core/constant/api_constant.dart';
import 'package:ott/data/models/seriesModel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/sharepreferences.dart';
import '../core/network/api_helper.dart';
import 'baseProvider.dart';

class PlayMediaProvider extends BaseProvider {
  /// ================= LOCAL RESUME CACHE =================

  /// key examples:
  /// movie_3
  /// series_1_2_5  (contentId_seasonId_episodeId)
  final Map<String, int> _resumeSecondsMap = {};

  final Map<String, int> _lastSavedSecondsMap = {};

  final Map<String, int> _resumeCache = {};
  String _movieKey(int contentId) => "movie_$contentId";

  String _episodeKey({
    required int contentId,
    required int seasonId,
    required int episodeId,
  }) =>
      "series_${contentId}_${seasonId}_$episodeId";

  // ================= ADD VIEW =================

  Future<void> addView({
    required int mediaId,
    required bool isSeries,
  }) async {
    try {
      final prefs = LocalSharePreferences();
      final user = await prefs.getUser();
      if (user?.id == null) return;

      final url = isSeries
          ? ApiConstant.addViewForEpisode(mediaId, user!.id!)
          : ApiConstant.addViewForMovie(mediaId, user!.id!);

      // This endpoint is protected. Going through ApiHelper keeps the view
      // request consistent with the rest of the authenticated API calls by
      // attaching the stored bearer token and handling an expired session.
      final response = await ApiHelper().postApi(url);
      if (response.statusCode < 200 || response.statusCode >= 300) {

      }
    } catch (e) {
      log("Add view error: $e");
    }
  }

  // ================= SAVE RESUME (LOCAL + BACKEND) =================

  Future<void> saveContinueWatching({
    required int contentId,
    int? seasonId,
    int? episodeId,
    String? episodeTitle,
    int? episodeNumber,
    int? seasonNumber,
    String? episodePosterUrl,
    String? seriesTitle,
    required Duration position,
    required Duration duration,
    bool force = false,
  }) async {
    try {
      if (duration.inSeconds == 0) {
        return;
      }

      final key = episodeId != null && seasonId != null
          ? _episodeKey(
              contentId: contentId,
              seasonId: seasonId,
              episodeId: episodeId,
            )
          : _movieKey(contentId);

      final currentSeconds = position.inSeconds;
      final lastSaved = _lastSavedSecondsMap[key] ?? 0;

      /// ❌ DO NOT SPAM API unless forced or first time saving
      if (!force && (currentSeconds - lastSaved).abs() < 5 && lastSaved > 0) {
        return;
      }

      // 🔥 SAVE LOCALLY
      _resumeSecondsMap[key] = currentSeconds;
      _lastSavedSecondsMap[key] = currentSeconds;

      final prefs = LocalSharePreferences();
      final user = await prefs.getUser();
      if (user?.id == null) {
        return;
      }

      final watchedPercentage =
          ((currentSeconds / duration.inSeconds) * 100).clamp(0, 100).toInt();

      final queryParams = <String, String>{
        "userId": user!.id.toString(),
        "contentId": contentId.toString(),
        "watchedSeconds": currentSeconds.toString(),
        "watchedPercentage": watchedPercentage.toString(),
        if (seasonId != null) "seasonId": seasonId.toString(),
        if (episodeId != null) "episodeId": episodeId.toString(),
        if (episodeTitle != null && episodeTitle.trim().isNotEmpty)
          "episodeTitle": episodeTitle.trim(),
        if (episodeNumber != null) "episodeNumber": episodeNumber.toString(),
        if (seasonNumber != null) "seasonNumber": seasonNumber.toString(),
        if (episodePosterUrl != null && episodePosterUrl.trim().isNotEmpty)
          "episodePosterUrl": episodePosterUrl.trim(),
        if (seriesTitle != null && seriesTitle.trim().isNotEmpty)
          "seriesTitle": seriesTitle.trim(),
      };

      final uri = Uri.parse(
        "${ApiConstant.baseUrl}continue-watching/save",
      ).replace(queryParameters: queryParams);

      final response = await ApiHelper().postApi(uri.toString());
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }
    } catch (e, stackTrace) {
      log('Continue watching save error: $e', stackTrace: stackTrace);
    }
  }

  // ================= GET RESUME TIME =================

  int getResumeSeconds({
    required int contentId,
    int? seasonId,
    int? episodeId,
  }) {
    final key = episodeId != null && seasonId != null
        ? _episodeKey(
            contentId: contentId,
            seasonId: seasonId,
            episodeId: episodeId,
          )
        : _movieKey(contentId);

    return _resumeSecondsMap[key] ?? 0;
  }

  // ================= AUTO NEXT EPISODE (FIXED) =================

  EpisodeEntity? getNextEpisode({
    required int seasonId,
    required int episodeId,
    required List<SeasonEntity> seasons,
  }) {
    for (int s = 0; s < seasons.length; s++) {
      final season = seasons[s];

      if (season.seasonId != seasonId) continue;

      for (int e = 0; e < season.episodes.length; e++) {
        if (season.episodes[e].episodeId == episodeId) {
          // next episode in same season
          if (e + 1 < season.episodes.length) {
            return season.episodes[e + 1];
          }

          // first episode of next season
          if (s + 1 < seasons.length && seasons[s + 1].episodes.isNotEmpty) {
            return seasons[s + 1].episodes.first;
          }

          return null;
        }
      }
    }
    return null;
  }

  Future<void> saveLocalResume({
    required int contentId,
    int? seasonId,
    int? episodeId,
    String? episodeTitle,
    int? episodeNumber,
    int? seasonNumber,
    String? episodePosterUrl,
    String? seriesTitle,
    required int seconds,
    int? totalDuration,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final key = _resumeKey(
      contentId: contentId,
      seasonId: seasonId,
      episodeId: episodeId,
    );

    _resumeCache[key] = seconds;
    await prefs.setInt(key, seconds);

    if (episodeId != null && episodeId > 0) {
      final episodeMetaKey =
          "episode_meta_${contentId}_${seasonId ?? 0}_$episodeId";
      final metaData = {
        'contentId': contentId,
        'seriesId': contentId,
        'seasonId': seasonId,
        'episodeId': episodeId,
        'episodeTitle': episodeTitle,
        'episodeNumber': episodeNumber,
        'seasonNumber': seasonNumber,
        'episodePosterUrl': episodePosterUrl,
        'seriesTitle': seriesTitle,
        'watchedSeconds': seconds,
        'totalDuration': totalDuration,
        'watchedPercentage': (totalDuration != null && totalDuration > 0)
            ? ((seconds / totalDuration) * 100).clamp(0, 100).toInt()
            : 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(episodeMetaKey, jsonEncode(metaData));

      // Also save as the latest watched episode for this series
      final seriesLastKey = "series_last_episode_$contentId";
      await prefs.setString(seriesLastKey, jsonEncode(metaData));
    }

    notifyListeners(); // 🔥 IMMEDIATE UI UPDATE
  }

  Future<Map<String, dynamic>?> getSavedEpisodeMeta({
    required int contentId,
    int? seasonId,
    int? episodeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (episodeId != null && episodeId > 0) {
      final key = "episode_meta_${contentId}_${seasonId ?? 0}_$episodeId";
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        try {
          return jsonDecode(jsonStr) as Map<String, dynamic>;
        } catch (_) {}
      }
    }
    // Check series last watched episode
    final seriesLastKey = "series_last_episode_$contentId";
    final lastStr = prefs.getString(seriesLastKey);
    if (lastStr != null) {
      try {
        return jsonDecode(lastStr) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  int getLocalResume({
    required int contentId,
    int? seasonId,
    int? episodeId,
  }) {
    final key = _resumeKey(
      contentId: contentId,
      seasonId: seasonId,
      episodeId: episodeId,
    );

    return _resumeCache[key] ?? 0;
  }

  String _resumeKey({
    required int contentId,
    int? seasonId,
    int? episodeId,
  }) {
    return "resume_${contentId}_${seasonId ?? 0}_${episodeId ?? 0}";
  }

  Future<void> loadLocalResumes() async {
    final prefs = await SharedPreferences.getInstance();

    for (final key in prefs.getKeys()) {
      if (key.startsWith("resume_")) {
        _resumeCache[key] = prefs.getInt(key) ?? 0;
      }
    }

    notifyListeners();
  }
}
