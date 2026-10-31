class CastMember {
  final int? castId;
  final String? name;
  final String? role;
  final String? image;
  final String? description;
  final int? contentId;
  final int? seasonId;

  CastMember({
    this.castId,
    this.name,
    this.role,
    this.image,
    this.description,
    this.contentId,
    this.seasonId,
  });

  factory CastMember.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    return CastMember(
      castId: _asInt(json['castId'] ?? json['id'] ?? json['crewId'] ?? json['personId']),
      name: _firstString(
        json,
        const [
          'name',
          'mname',
          'memberName',
          'castName',
          'personName',
          'actorName',
          'artistName',
          'fullName',
        ],
      ),
      role: _firstString(
        json,
        const [
          'role',
          'character',
          'designation',
          'roleName',
          'type',
          'profession',
          'job',
          'department',
        ],
      ),
      image: _normalizeImageUrl(
        _firstString(
          json,
          const [
            'image',
            'mimage',
            'imageUrl',
            'image_url',
            'profilePicture',
            'profilePhoto',
            'profileImage',
            'photo',
            'avatar',
            'url',
            'posterUrl',
            'img',
          ],
        ),
      ),
      description: _firstString(
        json,
        const ['description', 'bio', 'about'],
      ),
      contentId: _asInt(json['contentId'] ?? json['movieId'] ?? json['seriesId']),
      seasonId: _asInt(json['seasonId']),
    );
  }
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;

    final text = value.toString().trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') {
      return text;
    }
  }

  return null;
}

String? _normalizeImageUrl(String? value) {
  if (value == null) return null;

  final normalized = value.trim().replaceAll('\\', '/');
  if (normalized.isEmpty) return null;

  if (normalized.startsWith('//')) {
    return 'https:$normalized';
  }

  return normalized;
}
