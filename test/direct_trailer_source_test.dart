import 'package:flutter_test/flutter_test.dart';
import 'package:ott/app/core/utils/direct_trailer_source.dart';

void main() {
  test('returns the backend trailer URL without signing or rewriting it', () {
    const backendUrl =
        'https://trailers.example.com/movie/trailer.m3u8?token=backend-value';

    expect(DirectTrailerSource.fromBackend(backendUrl), same(backendUrl));
  });

  test('rejects missing and blank trailer values', () {
    expect(DirectTrailerSource.fromBackend(null), isNull);
    expect(DirectTrailerSource.fromBackend('   '), isNull);
  });

  group('DirectTrailerSource.hasValidTrailer', () {
    test('accepts valid http and https URLs', () {
      expect(
        DirectTrailerSource.hasValidTrailer('https://example.com/trailer.mp4'),
        isTrue,
      );
      expect(
        DirectTrailerSource.hasValidTrailer('http://cdn.filmytell.in/trailers/m.m3u8'),
        isTrue,
      );
    });

    test('rejects null, empty, and whitespace strings', () {
      expect(DirectTrailerSource.hasValidTrailer(null), isFalse);
      expect(DirectTrailerSource.hasValidTrailer(''), isFalse);
      expect(DirectTrailerSource.hasValidTrailer('   '), isFalse);
      expect(DirectTrailerSource.hasValidTrailer('\n\t '), isFalse);
    });

    test('rejects URLs without valid http/https scheme', () {
      expect(DirectTrailerSource.hasValidTrailer('invalid_url'), isFalse);
      expect(DirectTrailerSource.hasValidTrailer('ftp://example.com/video.mp4'), isFalse);
      expect(DirectTrailerSource.hasValidTrailer('javascript:void(0)'), isFalse);
      expect(DirectTrailerSource.hasValidTrailer('http://'), isFalse);
    });

    test('rejects youtube URLs since card preview requires direct streaming source', () {
      expect(
        DirectTrailerSource.hasValidTrailer('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        isFalse,
      );
      expect(
        DirectTrailerSource.hasValidTrailer('https://youtu.be/dQw4w9WgXcQ'),
        isFalse,
      );
    });
  });
}

