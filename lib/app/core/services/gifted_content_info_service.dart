import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:ott/app/core/constant/api_constant.dart';
import 'package:ott/app/core/network/api_helper.dart';
import 'package:ott/data/models/response/purchesContentListResponse.dart';

/// Gift state shown on "Gifted To You" cards.
enum GiftStatus { active, expiringSoon, expired }

/// Gift details for one content item, taken from the existing gifted-content
/// endpoint (`api/filter/remainingDays/{userId}?isGifted=true`). Any value the
/// API does not provide (or that cannot be parsed) is null and is not shown.
@immutable
class GiftedContentInfo {
  const GiftedContentInfo({this.giftedOn, this.expiresOn, this.active});

  final DateTime? giftedOn;
  final DateTime? expiresOn;

  /// The API's `active` flag; `false` means the gift can no longer be played.
  final bool? active;

  /// Days before expiry that count as "expiring soon".
  static const int expiringSoonDays = 3;

  /// Null when neither an expiry date nor an inactive flag is available
  /// (status can't be determined).
  GiftStatus? statusAt(DateTime now) {
    if (active == false) return GiftStatus.expired;
    final expiry = expiresOn;
    if (expiry == null) return null;
    if (!expiry.isAfter(now)) return GiftStatus.expired;
    if (expiry.difference(now) <= const Duration(days: expiringSoonDays)) {
      return GiftStatus.expiringSoon;
    }
    return GiftStatus.active;
  }

  bool get hasDetails =>
      giftedOn != null || expiresOn != null || active == false;

  factory GiftedContentInfo.fromUserContent(UserContent item) =>
      GiftedContentInfo(
        giftedOn: parseApiDate(item.dateFrom),
        expiresOn: parseApiDate(item.dateTo),
        active: item.active,
      );
}

/// Parses the date shapes this backend uses: epoch seconds/milliseconds (int
/// or numeric string), ISO-8601 / `yyyy-MM-dd[ HH:mm:ss]` strings and Java
/// `LocalDate(Time)` arrays (`[y, m, d, h, min, s]`). Returns null otherwise.
DateTime? parseApiDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is num) return _fromEpoch(value.toInt());
  if (value is List) {
    final parts = value.map((e) => e is num ? e.toInt() : null).toList();
    if (parts.length < 3 || parts.take(3).any((e) => e == null)) return null;
    int at(int i) => i < parts.length ? (parts[i] ?? 0) : 0;
    return DateTime(at(0), at(1), at(2), at(3), at(4), at(5));
  }
  final text = value.toString().trim();
  if (text.isEmpty || text == 'null') return null;
  final numeric = int.tryParse(text);
  if (numeric != null) return _fromEpoch(numeric);
  // Date-only values are local calendar dates, not UTC midnight.
  final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (dateOnly != null) {
    return DateTime(int.parse(dateOnly.group(1)!),
        int.parse(dateOnly.group(2)!), int.parse(dateOnly.group(3)!));
  }
  final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
  return parsed?.toLocal();
}

DateTime? _fromEpoch(int value) {
  if (value <= 0) return null;
  return value > 100000000000
      ? DateTime.fromMillisecondsSinceEpoch(value)
      : DateTime.fromMillisecondsSinceEpoch(value * 1000);
}

/// Read-only cache of gift details keyed by content id, for the Home
/// "Gifted To You" row. Uses its own copy of the data so the Watchlist's
/// [PurchaseContentProvider] list is never replaced.
class GiftedContentInfoService {
  GiftedContentInfoService._();
  static final GiftedContentInfoService instance =
      GiftedContentInfoService._();

  final ValueNotifier<Map<int, GiftedContentInfo>> infoByContentId =
      ValueNotifier(const {});

  int? _loadedForUser;
  bool _loading = false;

  /// Loads once per user per app session (call again with [force] to
  /// refresh, e.g. on pull-to-refresh). Failures leave the cache unchanged;
  /// cards then show only the GIFTED badge.
  Future<void> load(int userId, {bool force = false}) async {
    if (_loading || (!force && _loadedForUser == userId)) return;
    _loading = true;
    try {
      final response = await ApiHelper().getApi(
        ApiConstant.getUserContent(userId, isGifted: true),
      );
      if (response.statusCode != 200) return;
      final parsed = PurchaseContentListResponse.fromJson(
          json.decode(response.body) as Map<String, dynamic>);
      final map = <int, GiftedContentInfo>{};
      for (final item in parsed.data?.userContent ?? const <UserContent>[]) {
        final id = item.movie?.id;
        if (id == null || item.isGifted == false) continue;
        final info = GiftedContentInfo.fromUserContent(item);
        final existing = map[id];
        // Several gifts of the same title: keep the latest expiry.
        if (existing == null ||
            (info.expiresOn != null &&
                (existing.expiresOn == null ||
                    info.expiresOn!.isAfter(existing.expiresOn!)))) {
          map[id] = info;
        }
      }
      infoByContentId.value = Map.unmodifiable(map);
      _loadedForUser = userId;
    } catch (error) {
      log('Gifted content info load failed: $error');
    } finally {
      _loading = false;
    }
  }

  /// "Gifted To You" rows are identified by their dashboard category.
  static bool isGiftedCategory(String? category) =>
      (category ?? '').toLowerCase().contains('gift');
}
