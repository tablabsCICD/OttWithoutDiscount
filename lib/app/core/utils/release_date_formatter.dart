/// Formats content release dates without parsing date-only values as UTC.
String formatReleaseDate(dynamic releaseDate) {
  if (releaseDate == null) return '';
  if (releaseDate is DateTime) {
    return '${releaseDate.day.toString().padLeft(2, '0')}-'
        '${releaseDate.month.toString().padLeft(2, '0')}-${releaseDate.year}';
  }

  if (releaseDate is int) {
    if (releaseDate <= 0) return '';
    final dt = releaseDate > 100000000000
        ? DateTime.fromMillisecondsSinceEpoch(releaseDate)
        : DateTime.fromMillisecondsSinceEpoch(releaseDate * 1000);
    return '${dt.day.toString().padLeft(2, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-${dt.year}';
  }

  final value = releaseDate.toString().trim();
  if (value.isEmpty) return '';

  final numeric = int.tryParse(value);
  if (numeric != null) {
    if (numeric <= 0) return '';
    if (numeric > 1000000000) {
      final dt = numeric > 100000000000
          ? DateTime.fromMillisecondsSinceEpoch(numeric)
          : DateTime.fromMillisecondsSinceEpoch(numeric * 1000);
      return '${dt.day.toString().padLeft(2, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-${dt.year}';
    }
  }

  final match =
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:$|[T\s])').firstMatch(value);
  if (match == null) return value;
  return '${match.group(3)}-${match.group(2)}-${match.group(1)}';
}

