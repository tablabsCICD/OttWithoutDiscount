// To parse this JSON data, do
//
//     final contentResponse = contentResponseFromJson(jsonString);

import 'package:ott/data/models/content.dart';

class GetContentResponse {
  String? message;
  Data? data;
  int? statusCode;
  bool? success;

  GetContentResponse({
    this.message,
    this.data,
    this.statusCode,
    this.success,
  });

  factory GetContentResponse.fromJson(Map<String, dynamic> json) =>
      GetContentResponse(
        message: json["message"],
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
        statusCode: json["statusCode"],
        success: json["success"],
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": data?.toJson(),
        "statusCode": statusCode,
        "success": success,
      };
}

class Data {
  Content? contentList;

  Data({
    this.contentList,
  });

  factory Data.fromJson(Map<String, dynamic> json) {
    final raw = json["ContentList"] ??
        json["contentList"] ??
        json["content"] ??
        json["Content"] ??
        json["movie"] ??
        json["Movie"] ??
        ((json.containsKey("contentUrl") || json.containsKey("videoUrl") || json.containsKey("title")) ? json : null);
    return Data(
      contentList: raw is Map<String, dynamic>
          ? Content.fromJson(raw)
          : raw is Map
              ? Content.fromJson(Map<String, dynamic>.from(raw))
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
        "ContentList": contentList?.toJson(),
      };
}
