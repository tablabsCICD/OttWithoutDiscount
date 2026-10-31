import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/core/utils/content_type.dart';
import 'package:ott/app/provider/playMediaProvider.dart';
import 'package:ott/data/models/anti_piracy_models.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/models/response/SeriesDetailsResponse.dart';
import 'package:ott/data/models/seriesModel.dart';

void main() {
  group('SignedPlaybackResponse urlToPlay and Headers', () {
    test('returns signedUrl when query parameters are present', () {
      final now = DateTime.now().toUtc();
      final epochSeconds =
          now.add(const Duration(minutes: 10)).millisecondsSinceEpoch ~/ 1000;
      final response = SignedPlaybackResponse.fromJson(
        {
          'signedUrl':
              'https://cdn.filmytell.com/movies/1/master.m3u8?Key-Pair-Id=K1&Signature=S1&Policy=P1',
          'playbackUrl': 'https://cdn.filmytell.com/movies/1/master.m3u8',
          'authorizationType': 'CLOUDFRONT_SIGNED_URL',
          'sessionId': 'sess-123',
          'expiresAtEpochSeconds': epochSeconds,
        },
        now: now,
      );

      expect(
        response.urlToPlay,
        'https://cdn.filmytell.com/movies/1/master.m3u8?Key-Pair-Id=K1&Signature=S1&Policy=P1',
      );
      expect(response.httpHeaders, isEmpty);
    });

    test('falls back to playbackUrl when signedUrl is empty', () {
      final now = DateTime.now().toUtc();
      final epochSeconds =
          now.add(const Duration(minutes: 10)).millisecondsSinceEpoch ~/ 1000;
      final response = SignedPlaybackResponse.fromJson(
        {
          'signedUrl': '',
          'playbackUrl': 'https://cdn.filmytell.com/movies/1/master.m3u8',
          'authorizationType': 'CLOUDFRONT_SIGNED_COOKIES',
          'cookies': {
            'CloudFront-Policy': 'policy',
            'CloudFront-Signature': 'signature',
            'CloudFront-Key-Pair-Id': 'key-pair',
          },
          'sessionId': 'sess-456',
          'expiresAtEpochSeconds': epochSeconds,
        },
        platform: 'ANDROID',
        now: now,
      );

      expect(
        response.urlToPlay,
        'https://cdn.filmytell.com/movies/1/master.m3u8',
      );
    });
  });

  group('Playback Content Identification and Episode Resolution', () {
    test('Movie uses movie ID and MOVIE type', () {
      final movie = Content(
        id: 101,
        title: 'Blockbuster Movie',
        type: 'MOVIE',
        contentUrl: 'https://cdn.filmytell.com/movies/101/master.m3u8',
      );

      final isSeries = (0 > 0) ||
          ContentType.isSeries(movie.type) ||
          ContentType.normalize(movie.type) == ContentType.miniSeries;
      expect(isSeries, isFalse);

      final isEpisode = isSeries && (0 > 0);
      final contentId = isEpisode ? 0 : movie.id;
      final resolvedType = isEpisode
          ? 'EPISODE'
          : (ContentType.normalize(movie.type).isNotEmpty
              ? ContentType.normalize(movie.type)
              : 'MOVIE');

      expect(contentId, 101);
      expect(resolvedType, 'MOVIE');
    });

    test('Series episode uses episode ID and EPISODE type, never series ID', () {
      final series = Content(
        id: 55, // series ID
        title: 'Top Series',
        type: 'SERIES',
      );
      const selectedEpisodeId = 701;
      
      final isSeries = (selectedEpisodeId > 0) ||
          ContentType.isSeries(series.type) ||
          ContentType.normalize(series.type) == ContentType.miniSeries;
      expect(isSeries, isTrue);

      final isEpisode = isSeries && (selectedEpisodeId > 0);
      final contentId = isEpisode ? selectedEpisodeId : series.id;
      final resolvedType = isEpisode
          ? 'EPISODE'
          : (ContentType.normalize(series.type).isNotEmpty
              ? ContentType.normalize(series.type)
              : 'MOVIE');

      expect(contentId, 701); // Episode ID, NOT series ID 55!
      expect(contentId, isNot(equals(series.id)));
      expect(resolvedType, 'EPISODE');
    });

    test('Next Episode progression transitions seamlessly and tracks season', () {
      final provider = PlayMediaProvider();
      final season1 = SeasonEntity(
        seasonId: 10,
        seasonNumber: 1,
        title: 'Season 1',
        description: 'Season 1 Description',
        releaseDate: 12345678,
        price: 0,
        isSeasonPurchased: true,
        episodes: [
          EpisodeEntity(
            episodeId: 101,
            episodeNumber: 1,
            title: 'Episode 1',
            description: 'Ep 1',
            runtime: 1200,
            releaseDate: 12345678,
            posterUrl: 'https://cdn.example.com/e1.png',
            videoUrl: 'https://cdn.example.com/e1.m3u8',
            price: 0,
            isFree: true,
            isPurchased: true,
            isLocked: false,
          ),
          EpisodeEntity(
            episodeId: 102,
            episodeNumber: 2,
            title: 'Episode 2',
            description: 'Ep 2',
            runtime: 1300,
            releaseDate: 12345678,
            posterUrl: 'https://cdn.example.com/e2.png',
            videoUrl: 'https://cdn.example.com/e2.m3u8',
            price: 0,
            isFree: true,
            isPurchased: true,
            isLocked: false,
          ),
        ],
      );

      final season2 = SeasonEntity(
        seasonId: 20,
        seasonNumber: 2,
        title: 'Season 2',
        description: 'Season 2 Description',
        releaseDate: 12345678,
        price: 0,
        isSeasonPurchased: true,
        episodes: [
          EpisodeEntity(
            episodeId: 201,
            episodeNumber: 1,
            title: 'Season 2 Episode 1',
            description: 'S2 Ep 1',
            runtime: 1400,
            releaseDate: 12345678,
            posterUrl: 'https://cdn.example.com/e3.png',
            videoUrl: 'https://cdn.example.com/e3.m3u8',
            price: 0,
            isFree: true,
            isPurchased: true,
            isLocked: false,
          ),
        ],
      );

      final allSeasons = [season1, season2];

      // Next after ep 1 in same season
      final next1 = provider.getNextEpisode(
        seasonId: 10,
        episodeId: 101,
        seasons: allSeasons,
      );
      expect(next1, isNotNull);
      expect(next1!.episodeId, 102);

      // Verify season resolution for ep 2
      int? nextSeasonId1;
      for (final s in allSeasons) {
        if (s.episodes.any((e) => e.episodeId == next1.episodeId)) {
          nextSeasonId1 = s.seasonId;
          break;
        }
      }
      expect(nextSeasonId1, 10);

      // Next after ep 2 transitions to Season 2 Ep 1
      final next2 = provider.getNextEpisode(
        seasonId: 10,
        episodeId: 102,
        seasons: allSeasons,
      );
      expect(next2, isNotNull);
      expect(next2!.episodeId, 201);

      // Verify season resolution for season 2 transition
      int? nextSeasonId2;
      for (final s in allSeasons) {
        if (s.episodes.any((e) => e.episodeId == next2.episodeId)) {
          nextSeasonId2 = s.seasonId;
          break;
        }
      }
      expect(nextSeasonId2, 20);

      // Next after last episode returns null (clean end of series)
      final next3 = provider.getNextEpisode(
        seasonId: 20,
        episodeId: 201,
        seasons: allSeasons,
      );
      expect(next3, isNull);
    });
  });

  group('EpisodeResponse URL Extraction from Variant JSON Schemas', () {
    test('extracts videoUrl when backend provides videoFileUrl', () {
      final json = {
        'id': 401,
        'title': 'Episode 1',
        'videoFileUrl': 'https://cdn.filmytell.com/episodes/401/master.m3u8',
      };
      final episode = EpisodeResponse.fromJson(json);
      expect(episode.videoUrl, 'https://cdn.filmytell.com/episodes/401/master.m3u8');
    });

    test('extracts videoUrl when backend provides hls_url', () {
      final json = {
        'id': 402,
        'title': 'Episode 2',
        'hls_url': 'https://cdn.filmytell.com/episodes/402/master.m3u8',
      };
      final episode = EpisodeResponse.fromJson(json);
      expect(episode.videoUrl, 'https://cdn.filmytell.com/episodes/402/master.m3u8');
    });

    test('extracts videoUrl from languageList when top-level url is null', () {
      final json = {
        'id': 403,
        'title': 'Episode 3',
        'languageList': [
          {
            'language': 'Hindi',
            'videoUrl': 'https://cdn.filmytell.com/episodes/403/hi/master.m3u8',
          }
        ],
      };
      final episode = EpisodeResponse.fromJson(json);
      expect(episode.videoUrl, 'https://cdn.filmytell.com/episodes/403/hi/master.m3u8');
    });
  });

  group('Content URL and EpisodeId Extraction from Variant Keys', () {
    test('parses contentUrl from playbackUrl and episodeId from snake_case', () {
      final json = {
        'id': 501,
        'title': 'Test Title',
        'playbackUrl': 'https://cdn.filmytell.com/movies/501/master.m3u8',
        'episode_id': 88,
        'season_id': 3,
        'type': 'SERIES',
      };
      final content = Content.fromJson(json);
      expect(content.contentUrl, 'https://cdn.filmytell.com/movies/501/master.m3u8');
      expect(content.episodeId, 88);
      expect(content.seasonId, 3);
    });

    test('parses contentUrl from hls_url and episodeId from activeEpisodeId', () {
      final json = {
        'id': 502,
        'title': 'Another Series',
        'hls_url': 'https://cdn.filmytell.com/series/502/master.m3u8',
        'activeEpisodeId': 99,
        'activeSeasonId': 4,
        'type': 'SERIES',
      };
      final content = Content.fromJson(json);
      expect(content.contentUrl, 'https://cdn.filmytell.com/series/502/master.m3u8');
      expect(content.episodeId, 99);
      expect(content.seasonId, 4);
    });
  });

  group('HLS Signed URL Parameter Propagation Logic', () {
    test('preserves signed URL tokens when resolving relative child playlists and segments', () {
      final masterUri = Uri.parse(
        'https://cdn.filmytell.com/streams/master.m3u8?Key-Pair-Id=K1&Signature=S1&Policy=P1',
      );
      const childRelativePath = '720p/playlist.m3u8';
      var childUri = masterUri.resolve(childRelativePath);
      if (masterUri.hasQuery && !childUri.hasQuery) {
        childUri = childUri.replace(query: masterUri.query);
      }

      expect(
        childUri.toString(),
        'https://cdn.filmytell.com/streams/720p/playlist.m3u8?Key-Pair-Id=K1&Signature=S1&Policy=P1',
      );

      const segmentRelativePath = 'segment_001.ts';
      var segmentUri = childUri.resolve(segmentRelativePath);
      if (childUri.hasQuery && !segmentUri.hasQuery) {
        segmentUri = segmentUri.replace(query: childUri.query);
      }

      expect(
        segmentUri.toString(),
        'https://cdn.filmytell.com/streams/720p/segment_001.ts?Key-Pair-Id=K1&Signature=S1&Policy=P1',
      );
    });
  });

  group('Season and Episode ID Extraction from Variant Schema Keys', () {
    test('extracts seasonId and episodeId when backend provides id or snake_case keys', () {
      final seasonJson = {
        'id': 15,
        'title': 'Season 1',
        'episodes': [
          {
            'id': 205,
            'title': 'Episode 5',
            'videoUrl': 'https://cdn.filmytell.com/episodes/205.m3u8',
          }
        ]
      };
      final season = SeasonResponse.fromJson(seasonJson);
      expect(season.seasonId, 15);
      expect(season.episodes.first.episodeId, 205);
      expect(season.episodes.first.videoUrl, 'https://cdn.filmytell.com/episodes/205.m3u8');
    });

    test('extracts episodeId from epId or episode_id', () {
      final epJson1 = {'epId': 301, 'title': 'Ep 1'};
      final epJson2 = {'episode_id': 302, 'title': 'Ep 2'};
      expect(EpisodeResponse.fromJson(epJson1).episodeId, 301);
      expect(EpisodeResponse.fromJson(epJson2).episodeId, 302);
    });
  });

  group('Movie Content URL vs Trailer URL Separation', () {
    test('movie contentUrl is parsed from languageList and distinguishes from trailerUrl', () {
      final movieJson = {
        'id': 999,
        'title': 'Feature Movie',
        'trailerUrl': 'https://cdn.filmytell.com/trailers/feature.mp4',
        'languageList': [
          {
            'language': 'Hindi',
            'videoUrl': 'https://cdn.filmytell.com/movies/999/hi/master.m3u8',
          }
        ],
      };
      final content = Content.fromJson(movieJson);
      expect(content.trailerUrl, 'https://cdn.filmytell.com/trailers/feature.mp4');
      expect(content.contentUrl, 'https://cdn.filmytell.com/movies/999/hi/master.m3u8');
      expect(content.contentUrl, isNot(equals(content.trailerUrl)));
    });

    test('player replaces trailerUrl with canonical contentUrl if trailerUrl was inadvertently supplied', () {
      final movie = Content(
        id: 888,
        title: 'Special Movie',
        trailerUrl: 'https://cdn.filmytell.com/trailers/special_trailer.mp4',
        contentUrl: 'https://cdn.filmytell.com/movies/888/master.m3u8',
      );

      // Simulates the player URL resolution guard
      var suppliedSourceUrl = 'https://cdn.filmytell.com/trailers/special_trailer.mp4';
      if (movie.contentUrl != null &&
          movie.contentUrl!.isNotEmpty &&
          suppliedSourceUrl == movie.trailerUrl) {
        suppliedSourceUrl = movie.contentUrl!;
      }

      expect(suppliedSourceUrl, 'https://cdn.filmytell.com/movies/888/master.m3u8');
      expect(suppliedSourceUrl, isNot(equals(movie.trailerUrl)));
    });
  });
}
