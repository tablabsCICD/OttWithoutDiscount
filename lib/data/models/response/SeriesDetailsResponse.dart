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
      videoUrl: (json['videoUrl'] ?? json['contentUrl'] ?? json['url'])?.toString(),
      isPurchased: purchased,
      isLocked: locked,
      price: json['price'] is num
          ? json['price'] as num
          : num.tryParse(json['price']?.toString() ?? ''),
    );
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
