/// Defines the source boundary for trailer playback.
///
/// Trailer URLs come directly from the backend and must never be routed
/// through the protected movie signed-URL workflow.
abstract final class DirectTrailerSource {
  static String? fromBackend(String? backendUrl) {
    if (backendUrl == null || backendUrl.trim().isEmpty) return null;
    return backendUrl.trim();
  }

  /// Checks whether a movie trailer URL is present, non-empty, and valid for playback.
  static bool hasValidTrailer(String? rawUrl) {
    final value = fromBackend(rawUrl);
    if (value == null) return false;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return false;

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    if (uri.host.trim().isEmpty) return false;

    final host = uri.host.toLowerCase();
    final isYoutube = host.contains('youtube.com') || host == 'youtu.be';
    if (isYoutube) return false;

    return true;
  }
}

