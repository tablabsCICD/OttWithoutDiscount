import 'location.dart';

class User {
  int? id;
  String? refferedBy;
  String? lastName;
  List<String>? role;
  String? gender;
  String? mobileNumber;
  bool? admin;
  String? emailId;
  String? refferCode;
  String? deviceId;
  String? deviceName;
  String? password;
  String? profilePhoto;
  String? joinDate;
  String? registrationDate;
  List<String>? selectedLanguages;
  bool? verified;
  bool? active;
  dynamic otp;
  String? osName;
  String? deviceToken;
  String? firstName;
  String? dob;
  Location? location;
  String? age;

  User({
    this.id,
    this.refferedBy,
    this.lastName,
    this.role,
    this.gender,
    this.mobileNumber,
    this.admin,
    this.emailId,
    this.refferCode,
    this.deviceId,
    this.deviceName,
    this.password,
    this.profilePhoto,
    this.joinDate,
    this.registrationDate,
    this.selectedLanguages,
    this.verified,
    this.active,
    this.otp,
    this.osName,
    this.deviceToken,
    this.firstName,
    this.dob,
    this.location,
    this.age,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json["id"] as int?,
      refferedBy: json["refferedBy"] as String? ?? "",
      lastName: json["lastName"] as String? ?? "",
      role: (json["role"] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
          [],
      gender: json["gender"] as String? ?? "",
      mobileNumber: json["mobileNumber"] as String? ?? "",
      admin: json["admin"] as bool? ?? false,
      emailId: (json["emailId"] == null ||
              json["emailId"].toString().trim().isEmpty)
          ? null
          : json["emailId"].toString().trim(),
      refferCode: json["refferCode"] as String? ?? "",
      deviceId: json["deviceId"] as String? ?? "",
      deviceName: json["deviceName"] as String? ?? "",
      password: json["password"] as String? ?? "",
      profilePhoto: json["profilePhoto"] as String? ?? "",
      joinDate: json["joinDate"] as String? ?? "",
      registrationDate: json["registrationDate"] as String? ?? "",
      selectedLanguages: (json["selectedLanguages"] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
          [],
      verified: json["verified"] as bool? ?? false,
      active: json["active"] as bool? ?? true,
      otp: json["otp"],
      osName: json["osName"] as String? ?? "",
      deviceToken: json["deviceToken"] as String? ?? "",
      firstName: json["firstName"] as String? ?? "",
      dob: json["dob"] as String? ?? "",
      location: json["location"] == null
          ? null
          : Location.fromJson(json["location"] as Map<String, dynamic>),
      age: json["age"] as String? ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "refferedBy": refferedBy ?? "",
      "lastName": lastName ?? "",
      "role": role ?? [],
      "gender": gender ?? "",
      "mobileNumber": mobileNumber ?? "",
      "admin": admin ?? false,
      "emailId": (emailId != null && emailId!.trim().isNotEmpty)
          ? emailId!.trim()
          : null,
      "refferCode": refferCode ?? "",
      "deviceId": deviceId ?? "",
      "deviceName": deviceName ?? "",
      "password": password ?? "",
      "profilePhoto": profilePhoto ?? "",
      "joinDate": joinDate ?? "",
      "registrationDate": registrationDate ?? "",
      "selectedLanguages": selectedLanguages ?? [],
      "verified": verified ?? false,
      "active": active ?? true,
      "otp": otp,
      "osName": osName ?? "",
      "deviceToken": deviceToken ?? "",
      "firstName": firstName ?? "",
      "dob": dob ?? "",
      "location": location?.toJson(),
      "age": age ?? "",
    };
  }
}