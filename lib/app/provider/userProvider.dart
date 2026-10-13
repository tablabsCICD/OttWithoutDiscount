import 'dart:convert';
import 'dart:developer';
import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:universal_html/html.dart' as html;

import 'package:image_picker/image_picker.dart'; // For web-specific file handling

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ott/app/core/constant/app_constant.dart';
import 'package:ott/app/core/constant/prefrense_constant.dart';
import 'package:ott/data/models/response/errorResponse.dart';
import 'package:ott/data/models/response/getUserResponse.dart';
import 'package:ott/data/models/response/updateUserResponse.dart';
import 'package:ott/data/repositories/country_name.dart';

import '../../data/models/request/user_request.dart';
import '../../data/models/response/addUserResponse.dart';
import '../../data/models/user.dart';
import '../core/constant/api_constant.dart';
import '../core/network/api_helper.dart';
import '../core/repositories/secure_playback_repository.dart';
import '../core/services/device_type_helper.dart';
import '../core/services/notification_service.dart';
import '../core/services/session_manager.dart';
import '../core/services/referral_service.dart';
import '../core/utils/sharepreferences.dart';
import 'baseProvider.dart';

class UserProvider extends BaseProvider {
  UserProvider() : super('Ideal');

  TextEditingController firstNameController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController mobileController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController countryController = TextEditingController();
  TextEditingController stateController = TextEditingController();
  TextEditingController districtController = TextEditingController();
  TextEditingController talukaController = TextEditingController();
  TextEditingController dobController = TextEditingController();
  TextEditingController ageController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  TextEditingController officeBuildingController = TextEditingController();
  TextEditingController registrationDateController = TextEditingController();
  TextEditingController profileController = TextEditingController();
  TextEditingController pinCodeDateController = TextEditingController();
  TextEditingController refferedByController = TextEditingController();
  TextEditingController roleController = TextEditingController();
  String? selectedGender;
  List<String> selectedLanguages = [];
  List<Map<String, String>> addressSuggestions = [];
  bool isSearchingAddress = false;
  bool isFetchingCurrentLocation = false;
  List<String> countryOptions = [];
  List<String> stateOptions = [];
  List<String> districtOptions = [];
  List<String> talukaOptions = [];
  List<String> pincodeOptions = [];

  bool isEnbale = false;
  final CountryService _countryService = CountryService();
  final Map<String, List<String>> _stateOptionsCache = {};

  setValue() async {
    User? user = await LocalSharePreferences.localSharePreferences.getUser();
    final currentUser = user!;

    firstNameController.text = currentUser.firstName ?? "";
    lastNameController.text = currentUser.lastName ?? "";
    final currentFirst = (currentUser.firstName ?? "").trim();
    final currentLast = (currentUser.lastName ?? "").trim();
    nameController.text = '$currentFirst $currentLast'.trim();
    mobileController.text = currentUser.mobileNumber ?? "";
    emailController.text = currentUser.emailId ?? "";
    dobController.text = currentUser.dob ?? "";
    ageController.text = currentUser.age ?? "";
    profileController.text = currentUser.profilePhoto ?? "";
    notifyListeners();
  }

  checkValidation() {
    if (firstNameController.text.isNotEmpty &&
        lastNameController.text.isNotEmpty &&
        emailController.text.isNotEmpty &&
        mobileController.text.isNotEmpty &&
        passwordController.text.isNotEmpty &&
        confirmPasswordController.text.isNotEmpty &&
        dobController.text.isNotEmpty) {
      isEnbale = true;
    } else {
      isEnbale = false;
    }
    notifyListeners();
  }

  User userObject = User();

  User get userObj => userObject;

  Future<void> hydrateFromCache() async {
    final cachedUser =
        await LocalSharePreferences.localSharePreferences.getUser();
    if (cachedUser == null) return;

    userObject = cachedUser;
    firstNameController.text = cachedUser.firstName ?? "";
    lastNameController.text = cachedUser.lastName ?? "";
    final cachedFirst = (cachedUser.firstName ?? "").trim();
    final cachedLast = (cachedUser.lastName ?? "").trim();
    nameController.text = '$cachedFirst $cachedLast'.trim();
    mobileController.text = cachedUser.mobileNumber ?? "";
    emailController.text = cachedUser.emailId ?? "";
    dobController.text = cachedUser.dob ?? "";
    ageController.text = cachedUser.age ?? "";
    profileController.text = cachedUser.profilePhoto ?? "";
    notifyListeners();
  }

  // Create a new user
  Future<Map<String, dynamic>> createUser() async {
    String apiUrl = ApiConstant.registration;
    UserRequest userRequest = UserRequest();
    userRequest.admin = false;
    userRequest.age = '';
    userRequest.area = officeBuildingController.text;
    userRequest.city = cityController.text;
    userRequest.country = countryController.text;
    userRequest.deviceId = '';
    userRequest.deviceName = '';
    userRequest.deviceToken = '';
    userRequest.district = districtController.text;
    userRequest.dob = dobController.text;
    userRequest.emailId = emailController.text.trim().isNotEmpty
        ? emailController.text.trim()
        : null;
    userRequest.firstName = firstNameController.text;
    userRequest.gender = selectedGender;
    userRequest.joinDate = '';
    userRequest.mobileNumber = mobileController.text;
    userRequest.lastName = lastNameController.text;
    userRequest.locationId = 0;
    userRequest.officeBuilding = officeBuildingController.text;
    userRequest.osName = "Web";
    userRequest.password = passwordController.text;
    userRequest.pincode = pinCodeDateController.text.trim().isNotEmpty
        ? pinCodeDateController.text.trim()
        : "411017";
    userRequest.profilePhoto = profileController.text;
    final pendingReferral =
        await ReferralService.instance.getPendingReferralCode();
    userRequest.refferedBy = refferedByController.text.trim().isNotEmpty
        ? refferedByController.text.trim()
        : (pendingReferral ?? '');
    userRequest.taluka = cityController.text;
    userRequest.state = stateController.text;
    userRequest.languages = selectedLanguages;
    userRequest.verified = true;

    ApiHelper apiHelper = ApiHelper();

    try {
      var response =
          await apiHelper.postApiWithBody(apiUrl, userRequest.toJson());
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        GetUserResponse addUserResponse =
            GetUserResponse.fromJson(responseBody);
        if (addUserResponse.success == true) {
          if (addUserResponse.data != null) {
            userObject = addUserResponse.data!.user!;
            //log("before SEtData ${userObject.firstName}");
            LocalSharePreferences localSharePreferences =
                LocalSharePreferences();
            localSharePreferences.setBool(
                SharedPreferencesConstant.isUserLoggedIn, true);
            localSharePreferences.setString(
                SharedPreferencesConstant.currentUser,
                jsonEncode(addUserResponse.data!.user));

            // log("after SEtData ${await localSharePreferences.getString(SharedPreferencesConstant.currentUser)}");
            disposeData();
            await ReferralService.instance.clearReferralCode();
            notifyListeners();

            return {'success': true, 'message': 'User created successfully'};
          } else {
            return {
              'success': false,
              'message': addUserResponse.message ?? 'No data returned'
            };
          }
        } else {
          return {
            'success': false,
            'message': addUserResponse.message ?? 'Error in response'
          };
        }
      } else if (response.statusCode == 500) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        ErrorResposne addUserResponse = ErrorResposne.fromJson(responseBody);
        return {'success': false, 'message': addUserResponse.message};
        // throw Exception('Failed to add user. Status code: ${response.statusCode}');
      } else {
        return {'success': false, 'message': 'Something went wrong!'};
      }
    } catch (error) {
      return {
        'success': false,
        'message': 'An error occurred while adding user: $error'
      };
    }
  }

  // Update user data
  Future<Map<String, Object>> updateUser() async {
    User? user = await LocalSharePreferences.localSharePreferences.getUser();
    if (user == null || user.id == null) {
      print("UPDATE USER: User not found");
      return {'success': false, 'message': 'User not found'};
    }
    final userId = user.id!;
    String apiUrl = ApiConstant.editUserById(userId);

    final fullName = nameController.text.trim();
    if (fullName.isNotEmpty) {
      final parts = fullName.split(RegExp(r'\s+'));
      firstNameController.text = parts.first;
      lastNameController.text =
          parts.length > 1 ? parts.sublist(1).join(' ') : '';
    } else if (firstNameController.text.trim().isEmpty &&
        lastNameController.text.trim().isEmpty) {
      firstNameController.text = '';
      lastNameController.text = '';
    }

    final trimmedEmail = emailController.text.trim();
    final String? emailToSend = trimmedEmail.isNotEmpty
        ? trimmedEmail
        : (user.emailId != null && user.emailId!.trim().isNotEmpty
            ? user.emailId!.trim()
            : null);

    ApiHelper apiHelper = ApiHelper();
    Map<String, dynamic> data = {
      "id": userId,
      "emailId": emailToSend,
      "firstName": firstNameController.text.trim(),
      "lastName": lastNameController.text.trim(),
      "dob": dobController.text.trim().isNotEmpty
          ? dobController.text.trim()
          : (user.dob ?? ""),
      "age": ageController.text.trim().isNotEmpty
          ? ageController.text.trim()
          : (user.age ?? ""),
      //  "mobileNumber": mobileController.text.trim(),
      "profilePhoto": profileController.text,
      //"refferedBy": refferedByController.text,
    };
    print("==================================================");
    print("UPDATE USER API URL: $apiUrl");
    print("UPDATE USER REQUEST DATA: ${jsonEncode(data)}");
    print("==================================================");

    try {
      var response = await apiHelper.putApiWithBody(apiUrl, data);
      print("==================================================");
      print("UPDATE USER STATUS CODE: ${response.statusCode}");
      print("UPDATE USER RESPONSE BODY: ${response.body}");
      print("==================================================");
      log('Update User response === ${response.body}');
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);

        UpdateUserResponse updateUserResponse =
            UpdateUserResponse.fromJson(responseBody);
        log('Update User response === $updateUserResponse');

        if (updateUserResponse.success == true) {
          if (updateUserResponse.data != null) {
            userObject = updateUserResponse.data!.user!;
            firstNameController.text = userObject.firstName ?? "";
            lastNameController.text = userObject.lastName ?? "";
            final updatedFirst = (userObject.firstName ?? "").trim();
            final updatedLast = (userObject.lastName ?? "").trim();
            nameController.text = '$updatedFirst $updatedLast'.trim();
            emailController.text = userObject.emailId ?? "";
            mobileController.text = userObject.mobileNumber ?? "";
            dobController.text = userObject.dob ?? "";
            ageController.text = userObject.age ?? "";
            profileController.text = userObject.profilePhoto ?? "";

            LocalSharePreferences localSharePreferences =
                LocalSharePreferences();
            localSharePreferences.setString(
                SharedPreferencesConstant.currentUser,
                jsonEncode(updateUserResponse.data!.user));

            notifyListeners();
            return {
              'success': true,
              'message': updateUserResponse.message ?? ""
            };
          } else {
            return {
              'success': false,
              'message': updateUserResponse.message ?? 'No data returned'
            };
          }
        } else {
          return {
            'success': false,
            'message': updateUserResponse.message ?? 'Error in response'
          };
        }
      } else if (response.statusCode == 401 || response.statusCode == 500) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        AddUserResponse addUserResponse =
            AddUserResponse.fromJson(responseBody);

        return {
          'success': false,
          'message': addUserResponse.message ?? 'Error in response'
        };
      } else {
        return {'failure': true, 'message': 'Something went wrong!'};
      }
    } catch (error) {
      print("UPDATE USER ERROR: $error");
      return {
        'success': false,
        'message': 'An error occurred while update user: $error'
      };
    }
  }

  // Update user basic details data
  Future<Map<String, Object>> updateUserDetails() async {
    User? user = await LocalSharePreferences.localSharePreferences.getUser();
    if (user == null || user.id == null) {
      return {'success': false, 'message': 'User not found'};
    }
    final userId = user.id!;
    String apiUrl = ApiConstant.editUserById(userId);
    //log("API=====$apiUrl");
    final trimmedEmail = emailController.text.trim();
    final String? emailToSend = trimmedEmail.isNotEmpty
        ? trimmedEmail
        : (user.emailId != null && user.emailId!.trim().isNotEmpty
            ? user.emailId!.trim()
            : null);

    ApiHelper apiHelper = ApiHelper();
    Map<String, dynamic> data = {
      "id": userId,
      "emailId": emailToSend,
      "firstName": firstNameController.text.trim().isNotEmpty
          ? firstNameController.text.trim()
          : (user.firstName ?? ""),
      "lastName": lastNameController.text.trim().isNotEmpty
          ? lastNameController.text.trim()
          : (user.lastName ?? ""),
      "dob": dobController.text.trim().isNotEmpty
          ? dobController.text.trim()
          : (user.dob ?? ""),
      "age": ageController.text.trim().isNotEmpty
          ? ageController.text.trim()
          : (user.age ?? ""),
      // "mobileNumber": mobileController.text.trim(),
      "profilePhoto": profileController.text.trim().isNotEmpty
          ? profileController.text.trim()
          : (user.profilePhoto ?? ""),
      "refferedBy": refferedByController.text.trim().isNotEmpty
          ? refferedByController.text.trim()
          : (user.refferedBy ?? ""),
    };
    print("==================================================");
    print("UPDATE USER (1st DOB POPUP) API URL: $apiUrl");
    print("UPDATE USER (1st DOB POPUP) REQUEST DATA: ${jsonEncode(data)}");
    print("==================================================");

    try {
      var response = await apiHelper.putApiWithBody(apiUrl, data);
      print("==================================================");
      print("UPDATE USER (1st DOB POPUP) STATUS CODE: ${response.statusCode}");
      print("UPDATE USER (1st DOB POPUP) RESPONSE BODY: ${response.body}");
      print("==================================================");
      //log('Update User statusCode === ${response.statusCode}');
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);

        UpdateUserResponse updateUserResponse =
            UpdateUserResponse.fromJson(responseBody);
        //log('Update User response === ${updateUserResponse}');

        if (updateUserResponse.success == true) {
          if (updateUserResponse.data != null) {
            userObject = updateUserResponse.data!.user!;
            firstNameController.text = userObject.firstName ?? "";
            lastNameController.text = userObject.lastName ?? "";
            final updatedFirst = (userObject.firstName ?? "").trim();
            final updatedLast = (userObject.lastName ?? "").trim();
            nameController.text = '$updatedFirst $updatedLast'.trim();
            emailController.text = userObject.emailId ?? "";
            mobileController.text = userObject.mobileNumber ?? "";
            dobController.text = userObject.dob ?? "";
            ageController.text = userObject.age ?? "";
            profileController.text = userObject.profilePhoto ?? "";

            LocalSharePreferences localSharePreferences =
                LocalSharePreferences();
            localSharePreferences.setString(
                SharedPreferencesConstant.currentUser,
                jsonEncode(updateUserResponse.data!.user));

            notifyListeners();
            return {
              'success': true,
              'message': updateUserResponse.message ?? ""
            };
          } else {
            return {
              'success': false,
              'message': updateUserResponse.message ?? 'No data returned'
            };
          }
        } else {
          return {
            'success': false,
            'message': updateUserResponse.message ?? 'Error in response'
          };
        }
      } else if (response.statusCode == 401 || response.statusCode == 500) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        AddUserResponse addUserResponse =
            AddUserResponse.fromJson(responseBody);

        return {
          'success': false,
          'message': addUserResponse.message ?? 'Error in response'
        };
      } else {
        return {'failure': true, 'message': 'Something went wrong!'};
        // throw Exception('Failed to add user. Status code: ${response.statusCode}');
      }
    } catch (error) {
      print("UPDATE USER (1st DOB POPUP) ERROR: $error");
      return {
        'success': false,
        'message': 'An error occurred while update user: $error'
      };
    }
  }

  // Update user Location data
  Future<Map<String, Object>> updateUserLocation() async {
    User? user = await LocalSharePreferences.localSharePreferences.getUser();
    if (user == null || user.id == null) {
      return {'success': false, 'message': 'User not found'};
    }
    final userId = user.id!;
    String apiUrl = ApiConstant.editUserById(userId);
    log("API=====$apiUrl");
    ApiHelper apiHelper = ApiHelper();
    Map<String, dynamic> data = {
      "id": userId,
      "emailId": (user.emailId != null && user.emailId!.trim().isNotEmpty)
          ? user.emailId!.trim()
          : null,
      //  "mobileNumber": user.mobileNumber,
      "country": countryController.text.trim(),
      "state": stateController.text.trim(),
      "district": districtController.text.trim(),
      "city": cityController.text.trim().isNotEmpty
          ? cityController.text.trim()
          : talukaController.text.trim(),
      "taluka": talukaController.text.trim().isNotEmpty
          ? talukaController.text.trim()
          : cityController.text.trim(),
      "officeBuilding": officeBuildingController.text.trim(),
      "area": officeBuildingController.text.trim(),
      "pincode": pinCodeDateController.text.trim(),
    };
    log("data=====$data");

    try {
      var response = await apiHelper.putApiWithBody(apiUrl, data);
      log('Update User statusCode === ${response.statusCode}');
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);

        UpdateUserResponse updateUserResponse =
            UpdateUserResponse.fromJson(responseBody);
        log('Update User response === $updateUserResponse');

        if (updateUserResponse.success == true) {
          if (updateUserResponse.data != null) {
            userObject = updateUserResponse.data!.user!;

            LocalSharePreferences localSharePreferences =
                LocalSharePreferences();
            localSharePreferences.setString(
                SharedPreferencesConstant.currentUser,
                jsonEncode(updateUserResponse.data!.user));

            notifyListeners();
            return {
              'success': true,
              'message': updateUserResponse.message ?? ""
            };
          } else {
            return {
              'success': false,
              'message': updateUserResponse.message ?? 'No data returned'
            };
          }
        } else {
          return {
            'success': false,
            'message': updateUserResponse.message ?? 'Error in response'
          };
        }
      } else if (response.statusCode == 401 || response.statusCode == 500) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        AddUserResponse addUserResponse =
            AddUserResponse.fromJson(responseBody);

        return {
          'success': false,
          'message': addUserResponse.message ?? 'Error in response'
        };
      } else {
        return {'failure': true, 'message': 'Something went wrong!'};
        // throw Exception('Failed to add user. Status code: ${response.statusCode}');
      }
    } catch (error) {
      return {
        'success': false,
        'message': 'An error occurred while update user: $error'
      };
    }
  }

  Future<void> searchAddressSuggestions(String input) async {
    final query = input.trim();
    if (query.length < 3) {
      addressSuggestions = [];
      notifyListeners();
      return;
    }

    isSearchingAddress = true;
    notifyListeners();

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': query,
          'key': AppConstant.GOOGLE_KEY,
          'components': 'country:in',
        },
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final predictions = body['predictions'] as List? ?? [];
        addressSuggestions = predictions
            .map((item) {
              final data = item as Map<String, dynamic>;
              return {
                'description': data['description']?.toString() ?? '',
                'placeId': data['place_id']?.toString() ?? '',
              };
            })
            .where((item) =>
                item['description']!.isNotEmpty && item['placeId']!.isNotEmpty)
            .toList();
      } else {
        addressSuggestions = [];
      }
    } catch (error) {
      log('Places autocomplete error: $error');
      addressSuggestions = [];
    } finally {
      isSearchingAddress = false;
      notifyListeners();
    }
  }

  Future<void> selectAddressSuggestion(Map<String, String> suggestion) async {
    final placeId = suggestion['placeId'] ?? '';
    if (placeId.isEmpty) return;

    isSearchingAddress = true;
    notifyListeners();

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': placeId,
          'fields': 'formatted_address,address_components',
          'key': AppConstant.GOOGLE_KEY,
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) return;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status']?.toString() != 'OK') return;
      final result = body['result'] as Map<String, dynamic>?;
      if (result == null) return;

      _applyGoogleAddressResult(
        result,
        fallbackAddress: suggestion['description'],
      );

      addressSuggestions = [];
    } catch (error) {
      log('Places details error: $error');
    } finally {
      isSearchingAddress = false;
      notifyListeners();
    }
  }

  Future<bool> useCurrentLocationFromGoogle() async {
    isFetchingCurrentLocation = true;
    notifyListeners();

    try {
      final geocodeResult = await _resolveCurrentLocationAddress();
      if (geocodeResult != null) {
        _applyGoogleAddressResult(geocodeResult);
        addressSuggestions = [];
        return true;
      }
      addressSuggestions = [];
      return false;
    } catch (error) {
      log('Current location fetch error: $error');
      return false;
    } finally {
      isFetchingCurrentLocation = false;
      notifyListeners();
    }
  }

  /// Requests device location permissions, retrieves current GPS coordinates,
  /// and reverse-geocodes with Google Geocoding API without falling back to IP/hardcoded defaults.
  Future<Map<String, dynamic>> fetchAndApplyCurrentDeviceLocation() async {
    isFetchingCurrentLocation = true;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'success': false,
          'error':
              'Location services are disabled on your device. Please enable location services in Settings.',
          'isServiceDisabled': true,
        };
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        return {
          'success': false,
          'error':
              'Location permission is permanently denied. Please grant permission in App Settings, or tap Cancel.',
          'isPermanentlyDenied': true,
        };
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return {
          'success': false,
          'error':
              'Location permission is permanently denied. Please grant permission in App Settings, or tap Cancel.',
          'isPermanentlyDenied': true,
        };
      }

      if (permission == LocationPermission.denied) {
        return {
          'success': false,
          'error':
              'Location permission was denied. Tap Use Current Location to try again, or Cancel to continue.',
          'isDenied': true,
        };
      }

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (e) {
        return {
          'success': false,
          'error':
              'Unable to determine GPS location ($e). Please check your GPS and try again.',
        };
      }

      final geocodeUri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'latlng': '${position.latitude},${position.longitude}',
          'key': AppConstant.GOOGLE_KEY,
        },
      );

      final geocodeResponse =
          await http.get(geocodeUri).timeout(const Duration(seconds: 10));
      if (geocodeResponse.statusCode != 200) {
        return {
          'success': false,
          'error':
              'Reverse geocoding service returned status code ${geocodeResponse.statusCode}.',
        };
      }

      final geocodeBody =
          jsonDecode(geocodeResponse.body) as Map<String, dynamic>;
      final status = geocodeBody['status']?.toString();
      if (status != 'OK') {
        return {
          'success': false,
          'error':
              'Unable to resolve address (${geocodeBody['error_message'] ?? status}).',
        };
      }

      final results = geocodeBody['results'] as List? ?? [];
      if (results.isEmpty) {
        return {
          'success': false,
          'error': 'No address details found for your current coordinates.',
        };
      }

      final firstResult = results.first as Map<String, dynamic>;
      _applyGoogleAddressResult(firstResult);
      addressSuggestions = [];

      return {
        'success': true,
        'country': countryController.text,
        'state': stateController.text,
        'city': cityController.text,
        'formattedAddress': officeBuildingController.text,
      };
    } catch (error) {
      log('Current device location error: $error');
      return {
        'success': false,
        'error': 'An unexpected error occurred while fetching location: $error',
      };
    } finally {
      isFetchingCurrentLocation = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> _resolveCurrentLocationAddress() async {
    final deviceResult = await _lookupLocationViaDeviceGeolocation();
    if (deviceResult != null) return deviceResult;

    final browserResult = await _lookupLocationViaBrowserGeolocation();
    if (browserResult != null) return browserResult;

    return _lookupLocationViaGoogleGeolocation();
  }

  Future<Map<String, dynamic>?> _lookupLocationViaDeviceGeolocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final geocodeUri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'latlng': '${position.latitude},${position.longitude}',
          'key': AppConstant.GOOGLE_KEY,
        },
      );
      final geocodeResponse = await http.get(geocodeUri);
      if (geocodeResponse.statusCode != 200) return null;

      final geocodeBody =
          jsonDecode(geocodeResponse.body) as Map<String, dynamic>;
      final status = geocodeBody['status']?.toString();
      if (status != 'OK') return null;

      final results = geocodeBody['results'] as List? ?? [];
      if (results.isEmpty) return null;

      return results.first as Map<String, dynamic>;
    } catch (error) {
      log('Device geolocation error: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _lookupLocationViaBrowserGeolocation() async {
    if (!kIsWeb) return null;

    try {
      final geolocation = html.window.navigator.geolocation;
      final position = await geolocation.getCurrentPosition(
        enableHighAccuracy: true,
        timeout: const Duration(seconds: 15),
      );
      final lat = position.coords?.latitude;
      final lng = position.coords?.longitude;
      if (lat == null || lng == null) return null;

      final geocodeUri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'latlng': '$lat,$lng',
          'key': AppConstant.GOOGLE_KEY,
        },
      );
      final geocodeResponse = await http.get(geocodeUri);
      if (geocodeResponse.statusCode != 200) return null;

      final geocodeBody =
          jsonDecode(geocodeResponse.body) as Map<String, dynamic>;
      final status = geocodeBody['status']?.toString();
      if (status != 'OK') return null;

      final results = geocodeBody['results'] as List? ?? [];
      if (results.isEmpty) return null;

      return results.first as Map<String, dynamic>;
    } catch (error) {
      log('Browser geolocation error: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _lookupLocationViaGoogleGeolocation() async {
    try {
      final geoUri = Uri.https(
        'www.googleapis.com',
        '/geolocation/v1/geolocate',
        {'key': AppConstant.GOOGLE_KEY},
      );
      final geoResponse = await http.post(
        geoUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(<String, Object>{'considerIp': true}),
      );
      if (geoResponse.statusCode != 200) return null;

      final geoBody = jsonDecode(geoResponse.body) as Map<String, dynamic>;
      final location = geoBody['location'] as Map<String, dynamic>?;
      final lat = location?['lat'];
      final lng = location?['lng'];
      if (lat == null || lng == null) return null;

      final geocodeUri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'latlng': '$lat,$lng',
          'key': AppConstant.GOOGLE_KEY,
        },
      );
      final geocodeResponse = await http.get(geocodeUri);
      if (geocodeResponse.statusCode != 200) return null;

      final geocodeBody =
          jsonDecode(geocodeResponse.body) as Map<String, dynamic>;
      final status = geocodeBody['status']?.toString();
      if (status != 'OK') return null;
      final results = geocodeBody['results'] as List? ?? [];
      if (results.isEmpty) return null;

      return results.first as Map<String, dynamic>;
    } catch (error) {
      log('Google geolocation error: $error');
      return null;
    }
  }

  void _applyGoogleAddressResult(
    Map<String, dynamic> result, {
    String? fallbackAddress,
  }) {
    officeBuildingController.text =
        result['formatted_address']?.toString() ?? fallbackAddress ?? '';

    final components = result['address_components'] as List? ?? [];
    String valueForType(String type) {
      for (final component in components) {
        final data = component as Map<String, dynamic>;
        final types = (data['types'] as List? ?? []).map((e) => '$e');
        if (types.contains(type)) {
          return data['long_name']?.toString() ?? '';
        }
      }
      return '';
    }

    final country = valueForType('country');
    final state = valueForType('administrative_area_level_1');
    final district = valueForType('administrative_area_level_3').isNotEmpty
        ? valueForType('administrative_area_level_3')
        : valueForType('administrative_area_level_2');
    final city = valueForType('locality').isNotEmpty
        ? valueForType('locality')
        : valueForType('sublocality_level_1');
    final pincode = valueForType('postal_code');

    if (country.isNotEmpty) countryController.text = country;
    if (state.isNotEmpty) stateController.text = state;
    if (district.isNotEmpty) districtController.text = district;
    if (city.isNotEmpty) {
      cityController.text = city;
      talukaController.text = city;
    }
    if (pincode.isNotEmpty) pinCodeDateController.text = pincode;

    countryOptions = country.isEmpty ? [] : [country];
    stateOptions = state.isEmpty ? [] : [state];
    districtOptions = district.isEmpty ? [] : [district];
    talukaOptions = city.isEmpty ? [] : [city];
    pincodeOptions = pincode.isEmpty ? [] : [pincode];
  }

  // Update user data
  Future<Map<String, Object>> updateUserLang(List<String> langList) async {
    User? user = await LocalSharePreferences.localSharePreferences.getUser();
    if (user?.id == null) {
      return {'success': false, 'message': 'User not found'};
    }
    String apiUrl = ApiConstant.editUserById(user!.id);

    ApiHelper apiHelper = ApiHelper();
    Map<String, dynamic> data = {
      //"firstName": user!.firstName,
      "id": user.id,
      //"lastName": user.lastName,
      // "mobileNumber": user.mobileNumber,
      "languages": langList
    };
    try {
      var response = await apiHelper.putApiWithBody(apiUrl, data);

      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        UpdateUserResponse updateUserResponse =
            UpdateUserResponse.fromJson(responseBody);

        if (updateUserResponse.success == true) {
          if (updateUserResponse.data != null) {
            user = updateUserResponse.data!.user!;
            // Keep the provider synchronized with the persisted/backend user so
            // dashboards created after this update see the new preferences.
            userObject = user;

            LocalSharePreferences localSharePreferences =
                LocalSharePreferences();
            localSharePreferences.setString(
                SharedPreferencesConstant.currentUser,
                jsonEncode(updateUserResponse.data!.user));

            notifyListeners();
            return {
              'success': true,
              'message': updateUserResponse.message ?? ""
            };
          } else {
            return {
              'success': false,
              'message': updateUserResponse.message ?? 'No data returned'
            };
          }
        } else {
          return {
            'success': false,
            'message': updateUserResponse.message ?? 'Error in response'
          };
        }
      } else if (response.statusCode == 401 || response.statusCode == 500) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        AddUserResponse addUserResponse =
            AddUserResponse.fromJson(responseBody);

        return {
          'success': false,
          'message': addUserResponse.message ?? 'Error in response'
        };
      } else {
        return {'failure': true, 'message': 'Something went wrong!'};
        // throw Exception('Failed to add user. Status code: ${response.statusCode}');
      }
    } catch (error) {
      return {
        'success': false,
        'message': 'An error occurred while update user: $error'
      };
    }
  }

//Login - send otp
  sendOTP(String mobile) async {
    String apiUrl = ApiConstant.sendOTP(mobile);

    ApiHelper apiHelper = ApiHelper();
    final watch = Stopwatch()..start();

    try {
      var response = await apiHelper.postApiWithoutAuthToken(apiUrl);
      _logOtpPerformance(
        'Send OTP API completed in ${watch.elapsedMilliseconds}ms',
      );
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        GetUserResponse addUserResponse =
            GetUserResponse.fromJson(responseBody);

        //log("= data: ${addUserResponse.message}");

        if (addUserResponse.success == true) {
          //log('= $addUserResponse');
          return {
            'success': true,
            'message': addUserResponse.message ?? 'OTP sent',
            'data': responseBody['data'],
          };
        } else {
          return {
            'success': false,
            'message': addUserResponse.message ?? 'User not found',
          };
        }
      } else if (response.statusCode == 401 ||
          response.statusCode == 500 ||
          response.statusCode == 404) {
        final responseBody = json.decode(response.body);
        final message = responseBody is Map<String, dynamic>
            ? responseBody['message']?.toString()
            : null;
        return {
          'success': false,
          'message': message ?? 'Error in response',
        };
      } else {
        return {
          'failure': true,
          'message': 'Something went wrong!',
        };
        // throw Exception('Failed to add user. Status code: ${response.statusCode}');
      }
    } on io.SocketException {
      _logOtpPerformance(
        'Send OTP failed after ${watch.elapsedMilliseconds}ms: no connection',
      );
      return {
        'success': false,
        'message':
            'No internet connection. Please check your network and try again.',
      };
    } catch (error) {
      _logOtpPerformance(
        'Send OTP failed after ${watch.elapsedMilliseconds}ms',
      );
      log("Error: $error");
      return {'success': false, 'message': 'error: $error'};
    }
  }

//verify otp
  Future<Map<String, dynamic>> verifyOTP(
    String mobile,
    String otp, {
    BuildContext? context,
    String? referralCode,
  }) async {
    final totalWatch = Stopwatch()..start();
    final effectiveReferralCode = referralCode?.trim().isNotEmpty == true
        ? referralCode!.trim()
        : await ReferralService.instance.getPendingReferralCode();
    final deviceInfoFuture = DeviceTypeHelper.buildSessionInfo(
      context: context,
    );
    final deviceTokenFuture = NotificationService.instance.getDeviceToken();
    final deviceInfo = await deviceInfoFuture;
    final deviceToken = await deviceTokenFuture;
    _logOtpPerformance(
      'OTP device/session prep completed in ${totalWatch.elapsedMilliseconds}ms',
    );
    final apiUrl = ApiConstant.verifyOTP(
      mobileNum: mobile,
      otp: otp,
      deviceId: deviceInfo.deviceId,
      deviceName: deviceInfo.deviceName,
      deviceType: deviceInfo.deviceType.apiValue,
      appVersion: deviceInfo.appVersion,
      deviceMetadata: deviceInfo.deviceMetadata,
      deviceToken: deviceToken,
      referralCode: effectiveReferralCode,
    );
    final apiHelper = ApiHelper();

    try {
      final apiWatch = Stopwatch()..start();
      var response = await apiHelper.postApiWithoutAuthToken(apiUrl);
      _logOtpPerformance(
        'Verify OTP API completed in ${apiWatch.elapsedMilliseconds}ms',
      );
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        GetUserResponse addUserResponse =
            GetUserResponse.fromJson(responseBody);
        final sessionUser =
            _extractUser(responseBody) ?? addUserResponse.data?.user;
        final sessionSuccess = responseBody['success'] != false;

        if (sessionSuccess) {
          if (sessionUser != null) {
            await _persistAuthenticatedSession(responseBody);
            userObject = sessionUser;
            LocalSharePreferences localSharePreferences =
                LocalSharePreferences();
            localSharePreferences.setBool(
                SharedPreferencesConstant.isUserLoggedIn, true);
            localSharePreferences.setString(
                SharedPreferencesConstant.currentUser, jsonEncode(sessionUser));
            await ReferralService.instance.clearReferralCode();
            notifyListeners();
            _logOtpPerformance(
              'Verify OTP flow completed in ${totalWatch.elapsedMilliseconds}ms',
            );
            return {
              'success': true,
              'message':
                  addUserResponse.message ?? 'User logged in successfully',
              'data': responseBody['data'],
            };
          } else {
            return {
              'success': false,
              'message': addUserResponse.message ?? 'No data returned'
            };
          }
        } else {
          return {
            'success': false,
            'message': addUserResponse.message ?? 'Error in response'
          };
        }
      } else if (response.statusCode == 401 ||
          response.statusCode == 500 ||
          response.statusCode == 404) {
        return {
          'success': false,
          'message': SessionManager.extractMessage(response.body) ??
              'Error in response'
        };
      } else {
        return {'failure': true, 'message': 'Something went wrong!'};
        // throw Exception('Failed to add user. Status code: ${response.statusCode}');
      }
    } catch (error) {
      _logOtpPerformance(
        'Verify OTP failed after ${totalWatch.elapsedMilliseconds}ms',
      );
      return {
        'success': false,
        'message': 'An error occurred while logging user'
      };
    }
  }

  void _logOtpPerformance(String message) {
    if (!kDebugMode) return;
    log(message, name: 'OtpPerformance');
  }

  // Delete a user
  Future<void> deleteUser(int id) async {
    String apiUrl = ApiConstant.deleteUserById(id);
    ApiHelper apiHelper = ApiHelper();
    try {
      var response = await apiHelper.deleteApi(apiUrl);
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        AddUserResponse deleteUserResponse =
            AddUserResponse.fromJson(responseBody);
        if (deleteUserResponse.success == true) {
          notifyListeners();
        } else {}
      } else {
        throw Exception(
            'Failed to delete user. Status code: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('An error occurred while delete user.');
    }
  }

  Future<void> getUserById(int id) async {
    if (id <= 0) {
      await hydrateFromCache();
      return;
    }

    String apiUrl = ApiConstant.getUserById(id);
    ApiHelper apiHelper = ApiHelper();
    try {
      var response = await apiHelper.getApi(apiUrl);
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        GetUserResponse addUserResponse =
            GetUserResponse.fromJson(responseBody);
        if (addUserResponse.success == true) {
          if (addUserResponse.data != null &&
              addUserResponse.data!.user != null) {
            userObject = addUserResponse.data!.user!;
            final localSharePreferences = LocalSharePreferences();
            localSharePreferences.setString(
              SharedPreferencesConstant.currentUser,
              jsonEncode(addUserResponse.data!.user),
            );
            notifyListeners();
          } else {
            await hydrateFromCache();
          }
        } else {
          await hydrateFromCache();
        }
      } else {
        await hydrateFromCache();
      }
    } catch (error) {
      await hydrateFromCache();
    }
  }

  setDate(DateTime pickedDate) {
    dobController.text = pickedDate.toLocal().toString().split(' ')[0];
    notifyListeners();
  }

  /// Sets birth month and year in format e.g. "October 1992" without fabricating a day.
  void setBirthMonthAndYear(String month, int year) {
    dobController.text = '$month $year';
    final currentYear = DateTime.now().year;
    final age = currentYear - year;
    ageController.text = '$age';
    notifyListeners();
  }

// login email

  io.File? _imageFile; // Mobile/Desktop
  html.File? _webFile; // Web
  String? _uploadedImageUrl;
  bool _isUploading = false;

  io.File? get imageFile => _imageFile;
  html.File? get webFile => _webFile;
  String? get uploadedImageUrl => _uploadedImageUrl;
  bool get isUploading => _isUploading;

  // Pick Image
  Future<void> pickImage() async {
    try {
      if (kIsWeb) {
        final uploadInput = html.FileUploadInputElement();
        uploadInput.accept = 'image/*';
        uploadInput.click();

        uploadInput.onChange.listen((event) async {
          if (uploadInput.files != null && uploadInput.files!.isNotEmpty) {
            _webFile = uploadInput.files!.first;
            notifyListeners();
            await uploadImage();
          }
        });
      } else {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: ImageSource.gallery);

        if (pickedFile != null) {
          _imageFile = io.File(pickedFile.path);
          notifyListeners();
          await uploadImage();
        }
      }
    } catch (e) {
      log('Error picking image: $e');
    }
  }

  // Upload Image
  Future<void> uploadImage() async {
    if ((!kIsWeb && _imageFile == null) || (kIsWeb && _webFile == null)) {
      return;
    }

    _isUploading = true;
    notifyListeners();

    try {
      final uri = Uri.parse(
        ApiConstant.uploadImg,
      );

      final request = http.MultipartRequest('POST', uri);
      final token =
          await LocalSharePreferences.localSharePreferences.getAuthToken();
      if (token != null && token.trim().isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      if (kIsWeb && _webFile != null) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(_webFile!);
        await reader.onLoad.first;

        final bytes = reader.result as List<int>;
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: _webFile!.name,
          ),
        );
      } else if (_imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            _imageFile!.path,
          ),
        );
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final decoded = jsonDecode(responseBody);

        final fileUrl = decoded['data']?['fileUrl'];
        if (fileUrl != null && fileUrl is String) {
          _uploadedImageUrl = fileUrl;
          profileController.text = _uploadedImageUrl!;
          log('Image uploaded: $_uploadedImageUrl');
        } else {
          log('Upload success but fileUrl missing');
        }
      } else {
        log(
          'Upload failed: ${streamedResponse.statusCode} -> $responseBody',
        );
      }
    } catch (e) {
      log('Error uploading image: $e');
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  void clear() {
    _imageFile = null;
    _webFile = null;
    _uploadedImageUrl = null;
    notifyListeners();
  }

  Future<void> _persistAuthenticatedSession(
    Map<String, dynamic> responseBody,
  ) async {
    final token = _findStringValue(responseBody, const [
      'jwt',
      'token',
      'accessToken',
      'access_token',
    ]);
    await SessionManager.instance.saveToken(token);

    final sessionRecordId = _findStringValue(responseBody, const [
      'sessionRecordId',
      'session_record_id',
      'recordId',
      'record_id',
      'sessionId',
      'session_id',
    ]);
    await SessionManager.instance.saveSessionRecordId(sessionRecordId);
    SecurePlaybackRepository.instance.markRegistrationUnknown();
    unawaited(
      SecurePlaybackRepository.instance
          .registerCurrentDevice()
          .catchError((_) {}),
    );
  }

  String? _findStringValue(dynamic value, List<String> keys) {
    if (value is Map) {
      for (final key in keys) {
        final found = value[key];
        if (found != null && found.toString().trim().isNotEmpty) {
          return found.toString();
        }
      }
      for (final child in value.values) {
        final found = _findStringValue(child, keys);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _findStringValue(child, keys);
        if (found != null) return found;
      }
    }
    return null;
  }

  User? _extractUser(dynamic value) {
    if (value is Map) {
      final directUser = value['user'];
      if (directUser is Map<String, dynamic>) {
        return User.fromJson(directUser);
      }
      for (final child in value.values) {
        final user = _extractUser(child);
        if (user != null) return user;
      }
    } else if (value is List) {
      for (final child in value) {
        final user = _extractUser(child);
        if (user != null) return user;
      }
    }
    return null;
  }

  Future<void> loadCountryOptions() async {
    if (countryOptions.isNotEmpty) return;

    try {
      countryOptions = await _countryService.fetchCountryNames();
      notifyListeners();
    } catch (error) {
      log('Country list fetch error: $error');
    }
  }

  Future<void> loadStateOptionsByCountry(String country) async {
    final selectedCountry = country.trim();

    stateController.clear();
    districtController.clear();
    cityController.clear();
    pinCodeDateController.clear();
    districtOptions = [];
    talukaOptions = [];
    pincodeOptions = [];

    if (selectedCountry.isEmpty) {
      stateOptions = [];
      notifyListeners();
      return;
    }

    final cached = _stateOptionsCache[selectedCountry];
    if (cached != null) {
      stateOptions = List<String>.from(cached);
      notifyListeners();
      return;
    }

    try {
      final states =
          await _countryService.fetchStatesByCountry(selectedCountry);
      stateOptions = states;
      _stateOptionsCache[selectedCountry] = List<String>.from(states);
    } catch (error) {
      log('State list fetch error: $error');
      stateOptions = [];
    }

    notifyListeners();
  }

  Future<void> loadDistrictOptionsByState(String state) async {
    final selectedState = state.trim();

    districtController.clear();
    cityController.clear();
    pinCodeDateController.clear();
    districtOptions = [];
    talukaOptions = [];
    pincodeOptions = [];

    if (selectedState.isEmpty) {
      notifyListeners();
      return;
    }

    try {
      final districts =
          await _countryService.fetchDistrictsByState(selectedState);
      districtOptions = districts;
    } catch (error) {
      log('District list fetch error: $error');
      districtOptions = [];
    }

    notifyListeners();
  }

  Future<void> loadTalukaOptionsByDistrict(String district) async {
    final selectedDistrict = district.trim();

    cityController.clear();
    talukaController.clear();
    pinCodeDateController.clear();
    talukaOptions = [];
    pincodeOptions = [];

    if (selectedDistrict.isEmpty) {
      notifyListeners();
      return;
    }

    try {
      final talukas =
          await _countryService.fetchTalukasByDistrict(selectedDistrict);
      talukaOptions = talukas;
    } catch (error) {
      log('Taluka list fetch error: $error');
      talukaOptions = [];
    }

    notifyListeners();
  }

  Future<List<String>> resolveStateForCity({
    required String country,
    required String city,
  }) async {
    final cleanCountry = country.trim();
    final cleanCity = city.trim();
    if (cleanCountry.isEmpty || cleanCity.isEmpty) return [];

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'address': '$cleanCity, $cleanCountry',
          'key': AppConstant.GOOGLE_KEY,
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final results = body['results'] as List? ?? [];
        final Set<String> states = {};

        for (final item in results) {
          final data = item as Map<String, dynamic>;
          final components = data['address_components'] as List? ?? [];
          for (final comp in components) {
            final c = comp as Map<String, dynamic>;
            final types = (c['types'] as List? ?? []).map((e) => '$e');
            if (types.contains('administrative_area_level_1')) {
              final stateName = c['long_name']?.toString().trim() ?? '';
              if (stateName.isNotEmpty) {
                states.add(stateName);
              }
            }
          }
        }

        if (states.isNotEmpty) {
          final sortedStates = states.toList()..sort();
          if (sortedStates.length == 1) {
            stateController.text = sortedStates.first;
          }
          return sortedStates;
        }
      }
    } catch (e) {
      log('Geocode state resolve error: $e');
    }

    try {
      final availableStates =
          await _countryService.fetchStatesByCountry(cleanCountry);
      return availableStates;
    } catch (_) {
      return [];
    }
  }

  void disposeData() {
    firstNameController.clear();
    lastNameController.clear();
    cityController.clear();
    talukaController.clear();
    countryController.clear();
    addressSuggestions = [];
    countryOptions = [];
    stateOptions = [];
    _stateOptionsCache.clear();
    districtOptions = [];
    talukaOptions = [];
    pincodeOptions = [];
    confirmPasswordController.clear();
    districtController.clear();
    dobController.clear();
    ageController.clear();
    emailController.clear();
    mobileController.clear(); // double-check spelling here
    officeBuildingController.clear();
    profileController.clear();

    pinCodeDateController.clear();
    refferedByController.clear();
    roleController.clear();
    stateController.clear();
  }
}
