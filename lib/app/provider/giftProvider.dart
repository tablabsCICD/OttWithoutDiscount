import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:ott/app/core/constant/api_constant.dart';
import 'package:ott/app/core/network/api_helper.dart';
import 'package:ott/app/core/utils/sharepreferences.dart';
import 'package:ott/data/models/content.dart';
import 'package:ott/data/models/giftMasterModel.dart' hide User;
import 'package:ott/data/models/giftRecordModel.dart';
import 'package:ott/data/models/user.dart';
import 'baseProvider.dart';

class GiftProvider extends BaseProvider {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSavingGift = false;
  bool get isSavingGift => _isSavingGift;

  bool _isClaimingGift = false;
  bool get isClaimingGift => _isClaimingGift;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<GiftRecordModel> _giftRecords = [];
  List<GiftRecordModel> get giftRecords => _giftRecords;
  GiftMasterModel? giftMaster;
  // GiftMaster? _giftMaster;
  // GiftMaster? get giftMaster => _giftMaster;

  /// Save user gift (send gift purchase request to API)
  Future<Map<String, dynamic>> saveUserGift(
      Content content, int giftCount) async {
    if (_isSavingGift) {
      return {
        "success": false,
        "message": "Gift purchase already in progress. Please wait."
      };
    }

    _isSavingGift = true;
    notifyListeners();

    final String apiUrl = ApiConstant.saveUserGift;
    log("API URL => $apiUrl");

    try {
      User? user = await LocalSharePreferences.localSharePreferences.getUser();
      if (user == null) {
        return {"success": false, "message": "User not logged in"};
      }

      double totalPaid = (content.price ?? 0) * giftCount;
      Map<String, dynamic> requestBody = {
        "giftOwnerId": user.id,
        "movieId": content.id,
        "totalGiftCount": giftCount,
        "totalPaid": totalPaid,
      };

      log("Request Body => $requestBody");

      ApiHelper apiHelper = ApiHelper();
      final response = await apiHelper.postApiWithBody(apiUrl, requestBody);

      log("API Response => ${response.statusCode} | ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);

        if (responseBody["success"] == true) {
          return {
            "success": true,
            "message": responseBody["message"] ?? "Gift saved successfully"
          };
        } else {
          return {
            "success": false,
            "message": responseBody["message"] ?? "Failed to save gift"
          };
        }
      } else {
        return {
          "success": false,
          "message": "Server error: ${response.statusCode}"
        };
      }
    } catch (error, stack) {
      log("Error in saveUserGift => $error", stackTrace: stack);
      return {"success": false, "message": "Something went wrong: $error"};
    } finally {
      _isSavingGift = false;
      notifyListeners();
    }
  }

  /// Fetch gift history for a gift owner
  Future<void> fetchGiftHistory() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      User? user = await LocalSharePreferences.localSharePreferences.getUser();
      if (user == null) {
        _errorMessage = "User not logged in";
        _isLoading = false;
        notifyListeners();
        return;
      }

      final String apiUrl = ApiConstant.getByGiftOwner(user.id);
      log("Fetching gift history from => $apiUrl");

      ApiHelper apiHelper = ApiHelper();
      final response = await apiHelper.getApi(apiUrl);

      log("Gift history response => ${response.statusCode} | ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);

        if (responseBody["success"] == true) {
          final dynamic data = responseBody["data"];
          List<dynamic> records = [];

          if (data is List) {
            // Shape: { success:true, data:[...] }
            records = data;
          } else if (data is Map<String, dynamic>) {
            // Shape: { success:true, data:{ giftRecords:[...] } }
            final nested = data["giftRecords"];
            if (nested is List) {
              records = nested;
            }
          } else if (responseBody["giftRecords"] is List) {
            // Shape: { success:true, giftRecords:[...] }
            records = responseBody["giftRecords"] as List<dynamic>;
          }

          _giftRecords =
              records.map((e) => GiftRecordModel.fromJson(e)).toList();
        } else {
          _errorMessage =
              responseBody["message"] ?? "Failed to load gift history";
        }
      } else {
        _errorMessage = "Server error: ${response.statusCode}";
      }
    } catch (e, stack) {
      log("Error in fetchGiftHistory => $e", stackTrace: stack);
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch gift master by ID (parse inline instead of using GiftUsageResponse)
  Future<void> getByMasterId(int giftMasterId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final String apiUrl = ApiConstant.getByGiftMasterId(giftMasterId);
      log("Fetching Gift Usage from => $apiUrl");

      ApiHelper apiHelper = ApiHelper();
      final response = await apiHelper.getApi(apiUrl);
      log("Gift Usage response => ${response.statusCode} | ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);

        if (responseBody["data"]?["giftUsage"] != null) {
          giftMaster =
              GiftMasterModel.fromJson(responseBody["data"]["giftUsage"]);
        } else {
          _errorMessage = responseBody["message"] ?? "Gift details not found";
        }
      } else {
        _errorMessage = "Error: ${response.statusCode}";
      }
    } catch (e, stack) {
      log("Error in getByMasterId => $e", stackTrace: stack);
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// use gift by coupon
  Future<Map<String, dynamic>> useGiftByCoupon(String couponCode) async {
    if (_isClaimingGift) {
      return {
        "success": false,
        "message": "Gift claim already in progress. Please wait."
      };
    }

    _isClaimingGift = true;
    notifyListeners();

    try {
      User? user = await LocalSharePreferences.localSharePreferences.getUser();

      if (user == null) {
        return {"success": false, "message": "User not logged in"};
      }
      final String apiUrl = ApiConstant.useGiftByCoupon(user.id, couponCode);
      log("API URL => $apiUrl");

      ApiHelper apiHelper = ApiHelper();
      final response = await apiHelper.postApi(apiUrl);

      log(
        "Gift Claim API Response Received => "
        "${response.statusCode} | ${response.body}",
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);

        if (responseBody["success"] == true || responseBody["status"] == true) {
          return {
            "success": true,
            "message": responseBody["message"] ?? "Gift card claimed successfully!"
          };
        } else {
          final rawMsg = responseBody["message"]?.toString() ?? "";
          log(
            "Gift Claim Error Response Received => "
            "${rawMsg.isNotEmpty ? rawMsg : 'Failed to save gift'}",
          );
          return {
            "success": false,
            "message": rawMsg.isNotEmpty ? rawMsg : "Failed to save gift",
            "statusCode": 200,
          };
        }
      } else {
        log("Gift Claim Error Response Received => ${response.statusCode}");
        return {
          "success": false,
          "message": response.statusCode >= 500
              ? "Something went wrong while claiming the gift card. Please try again later."
              : "Server error: ${response.statusCode}",
          "statusCode": response.statusCode,
        };
      }
    } catch (error, stack) {
      log("Gift Claim Error Response Received => $error", stackTrace: stack);
      final errStr = error.toString().toLowerCase();
      final isNetwork = errStr.contains('socket') ||
          errStr.contains('network') ||
          errStr.contains('connection') ||
          errStr.contains('host lookup') ||
          errStr.contains('timed out') ||
          errStr.contains('clientexception');
      return {
        "success": false,
        "message": isNetwork
            ? "Unable to claim the gift card. Please check your internet connection and try again."
            : "Something went wrong while claiming the gift card. Please try again later.",
        "error": error,
      };
    } finally {
      _isClaimingGift = false;
      notifyListeners();
    }
  }
}
