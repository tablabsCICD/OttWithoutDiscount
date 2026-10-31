import 'package:ott/data/models/seriesModel.dart';

class SeriesDetailsResponse {
  final SeriesUserData data;

  SeriesDetailsResponse({required this.data});

  factory SeriesDetailsResponse.fromJson(Map<String, dynamic> json) {
    final dataMap = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json['data'] is Map
            ? Map<String, dynamic>.from(json['data'] as Map)
            : <String, dynamic>{};
    return SeriesDetailsResponse(
      data: SeriesUserData.fromJson(dataMap),
    );
  }

  SeriesEntity toEntity() => data.toEntity();
}

class SeriesUserData {
  final int seriesId;
  final String title;
  final String description;
  final String posterUrl;
  final List<SeasonResponse> seasons;

  SeriesUserData({
    required this.seriesId,
    required this.title,
    required this.description,
    required this.posterUrl,
    required this.seasons,
  });

  factory SeriesUserData.fromJson(Map<String, dynamic> json) {
    return SeriesUserData(
      seriesId: json['seriesId'] is int
          ? json['seriesId'] as int
          : int.tryParse(json['seriesId']?.toString() ?? '') ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      posterUrl: json['posterUrl'] ?? '',
      seasons: (json['seasons'] as List?)
              ?.map((e) => SeasonResponse.fromJson(
                  e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <SeasonResponse>[],
    );
  }

  SeriesEntity toEntity() {
    return SeriesEntity(
      id: seriesId,
      title: title,
      description: description,
      posterUrl: posterUrl,
      seasons: seasons.map((e) => e.toEntity()).toList(),
    );
  }
}

class SeasonResponse {
  final int seasonId;
  final int seasonNumber;
  final String title;
  final String description;
  final int releaseDate;
  final bool isSeasonPurchased;
  final num? price;
  final List<EpisodeResponse> episodes;

  SeasonResponse({
    required this.seasonId,
    required this.seasonNumber,
    required this.title,
    required this.description,
    required this.releaseDate,
    required this.isSeasonPurchased,
    required this.price,
    required this.episodes,
  });

  factory SeasonResponse.fromJson(Map<String, dynamic> json) {
    final rawDate = json['releaseDate'];
    final parsedDate = rawDate is int
        ? rawDate
        : int.tryParse(rawDate?.toString() ?? '') ?? 0;

    return SeasonResponse(
      seasonId: json['seasonId'] is int
          ? json['seasonId'] as int
          : int.tryParse(json['seasonId']?.toString() ?? '') ?? 0,
      seasonNumber: json['seasonNumber'] is int
          ? json['seasonNumber'] as int
          : int.tryParse(json['seasonNumber']?.toString() ?? '') ?? 1,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      releaseDate: parsedDate,
      isSeasonPurchased: json['isSeasonPurchased'] == true ||
          json['seasonPurchased'] == true,
      price: json['price'] is num
          ? json['price'] as num
          : num.tryParse(json['price']?.toString() ?? ''),
      episodes: (json['episodes'] as List?)
              ?.map((e) => EpisodeResponse.fromJson(
                  e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <EpisodeResponse>[],
    );
  }

  SeasonEntity toEntity() {
    return SeasonEntity(
      seasonId: seasonId,
      seasonNumber: seasonNumber,
      title: title,
      description: description,
      releaseDate: releaseDate,
      price: (price ?? 0).toDouble(),
      isSeasonPurchased: isSeasonPurchased,
      episodes: episodes.map((e) => e.toEntity()).toList(),
    );
  }
}

class EpisodeResponse {
  final int episodeId;
  final int episodeNumber;
  final String title;
  final String description;
  final int runtime;
  final int releaseDate;
  final bool isFree;
  final String posterUrl;
  final String? videoUrl;
  final bool isPurchased;
  final bool isLocked;
  final num? price;

  EpisodeResponse({
    required this.episodeId,
    required this.episodeNumber,
    required this.title,
    required this.description,
    required this.runtime,
    required this.releaseDate,
    required this.isFree,
    required this.posterUrl,
    required this.videoUrl,
    required this.isPurchased,
    required this.isLocked,
    required this.price,
  });

  factory EpisodeResponse.fromJson(Map<String, dynamic> json) {
    final rawRuntime = json['runtime'];
    final parsedRuntime = rawRuntime is int
        ? rawRuntime
        : int.tryParse(rawRuntime?.toString() ?? '') ?? 0;

    final rawDate = json['releaseDate'];
    final parsedDate = rawDate is int
        ? rawDate
        : int.tryParse(rawDate?.toString() ?? '') ?? 0;

    final purchased = json['isPurchased'] == true ||
        json['episodePurchased'] == true;
    final free = json['isFree'] == true || json['free'] == true;
    final locked = json['isLocked'] == true ||
        json['locked'] == true ||
        (!purchased && !free);

    return EpisodeResponse(
      episodeId: json['episodeId'] is int
          ? json['episodeId'] as int
          : int.tryParse(json['episodeId']?.toString() ?? '') ?? 0,
      episodeNumber: json['episodeNumber'] is int
          ? json['episodeNumber'] as int
          : int.tryParse(json['episodeNumber']?.toString() ?? '') ?? 1,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      runtime: parsedRuntime,
      releaseDate: parsedDate,
      isFree: free,
      posterUrl: json['posterUrl'] ?? '',
      videoUrl: _extractEpisodeVideoUrl(json),
      isPurchased: purchased,
      isLocked: locked,
      price: json['price'] is num
          ? json['price'] as num
          : num.tryParse(json['price']?.toString() ?? ''),
    );
  }

  static String? _extractEpisodeVideoUrl(Map<String, dynamic> json) {
    const candidateKeys = [
      'videoUrl',
      'videoFile',
      'videoFileUrl',
      'video_url',
      'video_file',
      'video_file_url',
      'contentUrl',
      'contentFile',
      'contentFileUrl',
      'content_url',
      'content_file',
      'content_file_url',
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
    ];

    for (final key in candidateKeys) {
      final value = json[key];
      if (value != null) {
        if (value is Map) {
          for (final subKey in const ['url', 'fileUrl', 'file_url', 'path']) {
            final subVal = value[subKey]?.toString().trim();
            if (subVal != null && subVal.isNotEmpty) return subVal;
          }
        } else {
          final s = value.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }
    }

    final languages = json['languageList'];
    if (languages is List) {
      for (final item in languages) {
        if (item is Map) {
          final raw = item['fileUrl'] ??
              item['file_url'] ??
              item['videoUrl'] ??
              item['video_url'] ??
              item['contentUrl'] ??
              item['content_url'] ??
              item['playbackUrl'] ??
              item['url'];
          final s = raw?.toString().trim();
          if (s != null && s.isNotEmpty) return s;
        }
      }
    }

    return null;
  }

  EpisodeEntity toEntity() {
    return EpisodeEntity(
      episodeId: episodeId,
      episodeNumber: episodeNumber,
      title: title,
      description: description,
      runtime: runtime,
      releaseDate: releaseDate,
      posterUrl: posterUrl,
      videoUrl: videoUrl,
      price: (price ?? 0).toDouble(),
      isFree: isFree,
      isPurchased: isPurchased,
      isLocked: isLocked,
    );
  }
}
