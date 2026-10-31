import 'package:ott/app/core/utils/direct_trailer_source.dart';

class Content {
  int? id;
  String? title;
  String? description;
  int? runtime;
  dynamic releaseDate;

  double? ratings;
  double? price;

  List<LanguageList>? languageList;
  List<String>? castList;
  List<String>? genreList;
  List<String>? directorList;

  int? views;
  double? totalRevenue;

  String? ageRating;
  List<String>? posterUrlList;
  String? teaserUrl;
  String? trailerUrl;
  String? contentUrl;
  String? approvalStatus;
  String? type;
  String? sensorCertificate;
  bool? isFeatured;

  Availability? availability;

  List<String>? audioFormatList;
  List<String>? subtitleLanguageList;
  bool? isDownloadable;

  int? uploadDateTime;
  int? approvedDateTime;

  String? mediaHouseName;
  int? mediaHouseId;

  int? ratingCount;
  String? rentlDuration;
  bool? isRental;

  int? watchedSeconds;
  int? watchedPercentage;

  int? seasonId;
  int? episodeId;

  int? seriesId;
  String? seriesTitle;
  int? seasonNumber;
  int? episodeNumber;
  String? episodeTitle;
  String? episodePosterUrl;

  Content({
    this.id,
    this.title,
    this.description,
    this.runtime,
    this.releaseDate,
    this.ratings,
    this.price,
    this.languageList,
    this.castList,
    this.genreList,
    this.directorList,
    this.views,
    this.totalRevenue,
    this.ageRating,
    this.posterUrlList,
    this.teaserUrl,
    this.trailerUrl,
    this.contentUrl,
    this.approvalStatus,
    this.type,
    this.sensorCertificate,
    this.isFeatured,
    this.availability,
    this.audioFormatList,
    this.subtitleLanguageList,
    this.isDownloadable,
    this.uploadDateTime,
    this.approvedDateTime,
    this.mediaHouseName,
    this.mediaHouseId,
    this.ratingCount,
    this.rentlDuration,
    this.isRental,
    this.watchedSeconds,
    this.watchedPercentage,
    this.seasonId,
    this.episodeId,
    this.seriesId,
    this.seriesTitle,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeTitle,
    this.episodePosterUrl,
  });

  /// Formatted display title for UI (e.g. Continue Watching card/banner).
  /// For series episodes, displays the episode information.
  String get displayTitle {
    final isSeries = (type?.trim().toLowerCase() == 'series') ||
        (episodeId != null && episodeId! > 0) ||
        (episodeTitle != null && episodeTitle!.trim().isNotEmpty);

    if (isSeries && (episodeTitle != null || episodeNumber != null)) {
      final epNum = episodeNumber != null ? 'E$episodeNumber' : '';
      final sNum = seasonNumber != null ? 'S$seasonNumber' : '';
      final epPrefix = (sNum.isNotEmpty && epNum.isNotEmpty)
          ? '$sNum:$epNum'
          : (epNum.isNotEmpty ? epNum : sNum);

      final hasExplicitTitle =
          episodeTitle != null && episodeTitle!.trim().isNotEmpty;
      final epName = hasExplicitTitle ? episodeTitle!.trim() : '';

      final parentTitle = (seriesTitle != null && seriesTitle!.trim().isNotEmpty)
          ? seriesTitle!.trim()
          : ((title != null && title != episodeTitle) ? title!.trim() : '');

      if (parentTitle.isNotEmpty && epPrefix.isNotEmpty && epName.isNotEmpty) {
        return '$parentTitle • $epPrefix - $epName';
      } else if (parentTitle.isNotEmpty && epPrefix.isNotEmpty) {
        return '$parentTitle • $epPrefix';
      } else if (epPrefix.isNotEmpty && epName.isNotEmpty) {
        return '$epPrefix • $epName';
      } else if (epPrefix.isNotEmpty) {
        return epPrefix;
      } else if (epName.isNotEmpty) {
        return parentTitle.isNotEmpty ? '$parentTitle • $epName' : epName;
      }
    }
    return title ?? '';
  }

  Content copyWith({
    int? id,
    String? title,
    String? description,
    int? runtime,
    dynamic releaseDate,
    double? ratings,
    double? price,
    List<LanguageList>? languageList,
    List<String>? castList,
    List<String>? genreList,
    List<String>? directorList,
    int? views,
    double? totalRevenue,
    String? ageRating,
    List<String>? posterUrlList,
    String? teaserUrl,
    String? trailerUrl,
    String? contentUrl,
    String? approvalStatus,
    String? type,
    String? sensorCertificate,
    bool? isFeatured,
    Availability? availability,
    List<String>? audioFormatList,
    List<String>? subtitleLanguageList,
    bool? isDownloadable,
    int? uploadDateTime,
    int? approvedDateTime,
    String? mediaHouseName,
    int? mediaHouseId,
    int? ratingCount,
    String? rentlDuration,
    bool? isRental,
    int? watchedSeconds,
    int? watchedPercentage,
    int? seasonId,
    int? episodeId,
    int? seriesId,
    String? seriesTitle,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeTitle,
    String? episodePosterUrl,
  }) =>
      Content(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        runtime: runtime ?? this.runtime,
        releaseDate: releaseDate ?? this.releaseDate,
        ratings: ratings ?? this.ratings,
        price: price ?? this.price,
        languageList: languageList ?? this.languageList,
        castList: castList ?? this.castList,
        genreList: genreList ?? this.genreList,
        directorList: directorList ?? this.directorList,
        views: views ?? this.views,
        totalRevenue: totalRevenue ?? this.totalRevenue,
        ageRating: ageRating ?? this.ageRating,
        posterUrlList: posterUrlList ?? this.posterUrlList,
        teaserUrl: teaserUrl ?? this.teaserUrl,
        trailerUrl: trailerUrl ?? this.trailerUrl,
        contentUrl: contentUrl ?? this.contentUrl,
        approvalStatus: approvalStatus ?? this.approvalStatus,
        type: type ?? this.type,
        sensorCertificate: sensorCertificate ?? this.sensorCertificate,
        isFeatured: isFeatured ?? this.isFeatured,
        availability: availability ?? this.availability,
        audioFormatList: audioFormatList ?? this.audioFormatList,
        subtitleLanguageList: subtitleLanguageList ?? this.subtitleLanguageList,
        isDownloadable: isDownloadable ?? this.isDownloadable,
        uploadDateTime: uploadDateTime ?? this.uploadDateTime,
        approvedDateTime: approvedDateTime ?? this.approvedDateTime,
        mediaHouseName: mediaHouseName ?? this.mediaHouseName,
        mediaHouseId: mediaHouseId ?? this.mediaHouseId,
        ratingCount: ratingCount ?? this.ratingCount,
        rentlDuration: rentlDuration ?? this.rentlDuration,
        isRental: isRental ?? this.isRental,
        watchedSeconds: watchedSeconds ?? this.watchedSeconds,
        watchedPercentage: watchedPercentage ?? this.watchedPercentage,
        seasonId: seasonId ?? this.seasonId,
        episodeId: episodeId ?? this.episodeId,
        seriesId: seriesId ?? this.seriesId,
        seriesTitle: seriesTitle ?? this.seriesTitle,
        seasonNumber: seasonNumber ?? this.seasonNumber,
        episodeNumber: episodeNumber ?? this.episodeNumber,
        episodeTitle: episodeTitle ?? this.episodeTitle,
        episodePosterUrl: episodePosterUrl ?? this.episodePosterUrl,
      );

  String? get teaserOrTrailerUrl {
    final teaser = teaserUrl?.trim();
    if (teaser != null && teaser.isNotEmpty) return teaser;
    return trailerUrl;
  }

  /// Returns whether this content has a valid, non-empty, playable trailer URL.
  bool get hasValidTrailer => DirectTrailerSource.hasValidTrailer(trailerUrl);

  factory Content.fromJson(Map<String, dynamic> json) => Content(
        id: _asInt(json['id']),
        title: json['title'],
        description: json['description'],
        runtime: _asInt(json['runtime']),
        releaseDate: json['releaseDate'],

        ratings: _asDouble(json['ratings']),
        price: _asDouble(json['price']),
        totalRevenue: _asDouble(json['totalRevenue']),

        languageList: (json['languageList'] as List?)
            ?.map((e) => e is Map
                ? LanguageList.fromJson(Map<String, dynamic>.from(e))
                : LanguageList(language: e.toString()))
            .toList(),

        castList:
            (json['castList'] as List?)?.map((e) => e.toString()).toList(),

        genreList:
            (json['genreList'] as List?)?.map((e) => e.toString()).toList(),

        directorList:
            (json['directorList'] as List?)?.map((e) => e.toString()).toList(),

        views: _asInt(json['views']),
        ageRating: json['ageRating'],

        posterUrlList: _posterUrlsFromJson(json),

        teaserUrl: _firstStringValue(json, const [
              'teaserUrl',
              'teaserFile',
              'teaserFileUrl',
              'teaser_url',
              'teaser_file',
              'teasurUrl',
              'teasurFile',
              'teasurFileUrl',
              'teasur_url',
              'teasur_file',
            ]) ??
            _firstMediaListValue(json, const [
              'teaserAudioUrlList',
              'teaserUrlList',
              'teaser_url_list',
            ]),
        trailerUrl: _firstStringValue(json, const [
              'trailerUrl',
              'trailerFile',
              'trailerFileUrl',
              'trailer_url',
              'trailer_file',
              'trailer_file_url',
            ]) ??
            _firstMediaListValue(json, const [
              'trailerAudioUrlList',
              'trailerUrlList',
              'trailer_url_list',
            ]),
        contentUrl: _contentUrlFromJson(json),
        approvalStatus: json['approvalStatus'],
        // Newer APIs use contentType while existing dashboard responses use type.
        // Keep the backend value intact so activity, playback, and caching can
        // distinguish SHORT_FILM from MOVIE.
        type: (json['contentType'] ?? json['content_type'] ?? json['type'])
            ?.toString(),
        sensorCertificate: json['sensorCertificate'],
        isFeatured: json['isFeatured'] == true,

        availability: json['availability'] != null
            ? Availability.fromJson(json['availability'])
            : null,

        audioFormatList: (json['audioFormatList'] as List?)
            ?.map((e) => e.toString())
            .toList(),

        subtitleLanguageList: (json['subtitleLanguageList'] as List?)
            ?.map((e) => e.toString())
            .toList(),

        isDownloadable: json['isDownloadable'] == true,

        uploadDateTime: _asInt(json['uploadDateTime']),
        approvedDateTime: _asInt(json['approvedDateTime']),

        mediaHouseName: json['mediaHouseName'],
        mediaHouseId: _asInt(json['mediaHouseId']),

        ratingCount: _asInt(json['ratingCount']),
        rentlDuration: json['rentlDuration'],
        isRental: json['isRental'] == true,

        watchedSeconds: _asInt(json['watchedSeconds']),
        watchedPercentage: _asInt(json['watchedPercentage']),

        seasonId: _asInt(
          json['seasonId'] ??
              json['season_id'] ??
              json['activeSeasonId'] ??
              json['season']?['id'] ??
              json['season']?['seasonId'],
        ),
        episodeId: _asInt(
          json['episodeId'] ??
              json['episode_id'] ??
              json['activeEpisodeId'] ??
              json['epId'] ??
              json['episode']?['id'] ??
              json['episode']?['episodeId'],
        ),
        seriesId: _asInt(
          json['seriesId'] ??
              json['series_id'] ??
              json['contentId'] ??
              json['seriesContentId'] ??
              (json['type']?.toString().toLowerCase() == 'series'
                  ? json['id']
                  : null),
        ),
        seriesTitle: _stringFromField(
          json['seriesTitle'] ??
              json['series_title'] ??
              json['seriesName'] ??
              json['series_name'] ??
              json['series']?['title'] ??
              json['series']?['name'],
        ),
        seasonNumber: _asInt(
          json['seasonNumber'] ??
              json['season_number'] ??
              json['seasonIndex'] ??
              json['season_index'] ??
              json['season']?['seasonNumber'] ??
              json['season']?['season_number'],
        ),
        episodeNumber: _asInt(
          json['episodeNumber'] ??
              json['episode_number'] ??
              json['episodeIndex'] ??
              json['episode_index'] ??
              json['episode']?['episodeNumber'] ??
              json['episode']?['episode_number'],
        ),
        episodeTitle: _stringFromField(
          json['episodeTitle'] ??
              json['episode_title'] ??
              json['episodeName'] ??
              json['episode_name'] ??
              json['episode']?['title'] ??
              json['episode']?['name'],
        ),
        episodePosterUrl: _stringFromField(
          json['episodePosterUrl'] ??
              json['episode_poster_url'] ??
              json['episodePoster'] ??
              json['episode_poster'] ??
              json['episodeThumbnail'] ??
              json['episode_thumbnail'] ??
              json['thumbnailUrl'] ??
              json['thumbnail_url'] ??
              json['episode']?['posterUrl'] ??
              json['episode']?['poster_url'] ??
              json['episode']?['thumbnail'],
        ),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "description": description,
        "runtime": runtime,
        "releaseDate": releaseDate,
        "ratings": ratings,
        "price": price,
        "languageList": languageList?.map((x) => x.toJson()).toList() ?? [],
        "castList": castList ?? [],
        "genreList": genreList ?? [],
        "directorList": directorList ?? [],
        "views": views,
        "totalRevenue": totalRevenue,
        "ageRating": ageRating,
        "posterUrlList": posterUrlList ?? [],
        "teaserUrl": teaserUrl,
        "trailerUrl": trailerUrl,
        "contentUrl": contentUrl,
        "approvalStatus": approvalStatus,
        "type": type,
        "sensorCertificate": sensorCertificate,
        "isFeatured": isFeatured,
        "availability": availability?.toJson(),
        "audioFormatList": audioFormatList ?? [],
        "subtitleLanguageList": subtitleLanguageList ?? [],
        "isDownloadable": isDownloadable,
        "uploadDateTime": uploadDateTime,
        "approvedDateTime": approvedDateTime,
        "mediaHouseName": mediaHouseName,
        "mediaHouseId": mediaHouseId,
        "ratingCount": ratingCount,
        "rentlDuration": rentlDuration,
        "isRental": isRental,
        "watchedSeconds": watchedSeconds,
        "watchedPercentage": watchedPercentage,
        "seasonId": seasonId,
        "episodeId": episodeId,
        "seriesId": seriesId,
        "seriesTitle": seriesTitle,
        "seasonNumber": seasonNumber,
        "episodeNumber": episodeNumber,
        "episodeTitle": episodeTitle,
        "episodePosterUrl": episodePosterUrl,
      };
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

String? _firstStringValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _stringFromField(json[key]);
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

String? _firstMediaListValue(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final values = json[key];
    if (values is! List) continue;
    for (final item in values) {
      if (item is Map) {
        final mapped = Map<String, dynamic>.from(item);
        final nested = _firstStringValue(mapped, const [
          'url',
          'fileUrl',
          'mediaUrl',
          'trailerUrl',
          'teaserUrl',
        ]);
        if (nested != null) return nested;
      } else {
        final value = item?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
  }
  return null;
}

String? _contentUrlFromJson(Map<String, dynamic> json) {
  final directUrl = _firstStringValue(json, const [
    'contentUrl',
    'contentFile',
    'contentFileUrl',
    'content_url',
    'content_file',
    'content_file_url',
    'videoUrl',
    'videoFile',
    'videoFileUrl',
    'video_url',
    'video_file',
    'video_file_url',
    'movieUrl',
    'movieFile',
    'movieFileUrl',
    'movie_url',
    'movie_file',
    'movie_file_url',
    'playbackUrl',
    'playback_url',
    'hlsUrl',
    'hls_url',
    'streamUrl',
    'stream_url',
    'mediaUrl',
    'media_url',
    'masterUrl',
    'master_url',
    'manifestUrl',
    'manifest_url',
    'fileUrl',
    'file_url',
    'url',
  ]);
  if (directUrl != null && directUrl.isNotEmpty) return directUrl;

  final languages = json['languageList'];
  if (languages is List) {
    for (final item in languages) {
      if (item is Map) {
        final languageUrl = _stringFromField(item['fileUrl']) ??
            _stringFromField(item['file_url']) ??
            _stringFromField(item['videoUrl']) ??
            _stringFromField(item['video_url']) ??
            _stringFromField(item['contentUrl']) ??
            _stringFromField(item['content_url']) ??
            _stringFromField(item['playbackUrl']) ??
            _stringFromField(item['playback_url']) ??
            _stringFromField(item['hlsUrl']) ??
            _stringFromField(item['hls_url']) ??
            _stringFromField(item['url']);
        if (languageUrl != null && languageUrl.isNotEmpty) return languageUrl;
      }
    }
  }

  return null;
}

String? _stringFromField(dynamic field) {
  if (field == null) return null;
  if (field is Map) {
    for (final key in const [
      'url',
      'fileUrl',
      'file_url',
      'videoUrl',
      'video_url',
      'contentUrl',
      'content_url',
      'playbackUrl',
      'playback_url',
      'hlsUrl',
      'hls_url',
      'path',
    ]) {
      final value = field[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  final value = field.toString().trim();
  return value.isEmpty ? null : value;
}

List<String> _posterUrlsFromJson(Map<String, dynamic> json) {
  final posters = <String>[];
  final posterList = json['posterUrlList'] ??
      json['poster_url_list'] ??
      json['backdropUrlList'] ??
      json['backdrop_url_list'] ??
      json['backdrops'] ??
      json['posters'] ??
      json['posterList'] ??
      json['images'] ??
      json['thumbnails'];

  if (posterList is List) {
    for (final item in posterList) {
      final s = _sanitizeUrl(_stringFromField(item));
      if (s != null && s.isNotEmpty && !posters.contains(s)) {
        posters.add(s);
      }
    }
  }

  for (final key in const [
    'backdropUrl',
    'backdrop_url',
    'backdrop',
    'landscapePoster',
    'landscape_poster',
    'landscapeUrl',
    'landscape_url',
    'landscape',
    'horizontalPoster',
    'horizontal_poster',
    'horizontalUrl',
    'horizontal_url',
    'widePoster',
    'wide_poster',
    'wideUrl',
    'wide_url',
    'posterUrl',
    'poster',
    'thumbnail',
    'thumbnailUrl',
    'imageUrl',
    'bannerUrl',
    'coverUrl',
    'poster_url',
    'thumbnail_url',
    'image_url',
    'banner_url',
    'cover_url',
  ]) {
    final s = _sanitizeUrl(json[key]?.toString());
    if (s != null && s.isNotEmpty && !posters.contains(s)) {
      posters.add(s);
    }
  }

  // Also check nested media/movie/series objects if present
  for (final subKey in const ['movie', 'series', 'video', 'media', 'details']) {
    final sub = json[subKey];
    if (sub is Map<String, dynamic>) {
      final subPosters = _posterUrlsFromJson(sub);
      for (final s in subPosters) {
        if (!posters.contains(s)) {
          posters.add(s);
        }
      }
    }
  }

  return posters;
}

String? _sanitizeUrl(String? raw) {
  if (raw == null) return null;
  var url = raw.trim();
  if (url.isEmpty) return null;
  if (url.startsWith('//')) {
    url = 'https:$url';
  } else if (url.startsWith('http://')) {
    url = 'https://${url.substring(7)}';
  }
  return url;
}

class Availability {
  List<String>? regions;
  List<String>? platforms;

  Availability({
    this.regions,
    this.platforms,
  });

  factory Availability.fromJson(Map<String, dynamic> json) => Availability(
        regions: json["regions"] == null
            ? []
            : List<String>.from(json["regions"]!.map((x) => x)),
        platforms: json["platforms"] == null
            ? []
            : List<String>.from(json["platforms"]!.map((x) => x)),
      );

  Map<String, dynamic> toJson() => {
        "regions":
            regions == null ? [] : List<dynamic>.from(regions!.map((x) => x)),
        "platforms": platforms == null
            ? []
            : List<dynamic>.from(platforms!.map((x) => x)),
      };
}

class LanguageList {
  String? language;
  String? fileUrl;

  LanguageList({
    this.language,
    this.fileUrl,
  });

  factory LanguageList.fromJson(Map<String, dynamic> json) => LanguageList(
        language: json["language"],
        fileUrl: json["fileUrl"],
      );

  Map<String, dynamic> toJson() => {
        "language": language,
        "fileUrl": fileUrl,
      };
}
