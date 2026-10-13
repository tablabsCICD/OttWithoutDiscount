class UserRequest {
  bool? admin;
  String? age;
  String? area;
  String? city;
  String? country;
  String? deviceId;
  String? deviceName;
  String? deviceToken;
  String? district;
  String? dob;
  String? emailId;
  String? firstName;
  String? gender;
  int? id;
  String? joinDate;
  List<String>? languages;
  String? lastName;
  int? locationId;
  String? mobileNumber;
  String? officeBuilding;
  String? osName;
  String? password;
  String? pincode;
  String? profilePhoto;
  String? refferedBy;
  String? state;
  String? taluka;
  bool? verified;

  UserRequest({
    this.admin,
    this.age,
    this.area,
    this.city,
    this.country,
    this.deviceId,
    this.deviceName,
    this.deviceToken,
    this.district,
    this.dob,
    this.emailId,
    this.firstName,
    this.gender,
    this.id,
    this.joinDate,
    this.languages,
    this.lastName,
    this.locationId,
    this.mobileNumber,
    this.officeBuilding,
    this.osName,
    this.password,
    this.pincode,
    this.profilePhoto,
    this.refferedBy,
    this.state,
    this.taluka,
    this.verified,
  });

  factory UserRequest.fromJson(Map<String, dynamic> json) => UserRequest(
    admin: json["admin"],
    age: json["age"],
    area: json["area"],
    city: json["city"],
    country: json["country"],
    deviceId: json["deviceId"],
    deviceName: json["deviceName"],
    deviceToken: json["deviceToken"],
    district: json["district"],
    dob: json["dob"],
    emailId: json["emailId"],
    firstName: json["firstName"],
    gender: json["gender"],
    id: json["id"],
    joinDate: json["joinDate"],
    languages: json["languages"] == null ? [] : List<String>.from(json["languages"]!.map((x) => x)),
    lastName: json["lastName"],
    locationId: json["locationId"],
    mobileNumber: json["mobileNumber"],
    officeBuilding: json["officeBuilding"],
    osName: json["osName"],
    password: json["password"],
    pincode: json["pincode"],
    profilePhoto: json["profilePhoto"],
    refferedBy: json["refferedBy"],
    state: json["state"],
    taluka: json["taluka"],
    verified: json["verified"],
  );

  Map<String, dynamic> toJson() => {
    "admin": admin,
    "age": age,
    "area": area,
    "city": city,
    "country": country,
    "deviceId": deviceId,
    "deviceName": deviceName,
    "deviceToken": deviceToken,
    "district": district,
    "dob": dob,
    "emailId": (emailId != null && emailId!.trim().isNotEmpty)
        ? emailId!.trim()
        : null,
    "firstName": firstName,
    "gender": gender,
    "id": id,
    "joinDate": joinDate,
    "languages": languages == null ? [] : List<dynamic>.from(languages!.map((x) => x)),
    "lastName": lastName,
    "locationId": locationId,
    "mobileNumber": mobileNumber,
    "officeBuilding": officeBuilding,
    "osName": osName,
    "password": password,
    "pincode": pincode,
    "profilePhoto": profilePhoto,
    "refferedBy": refferedBy,
    "state": state,
    "taluka": taluka,
    "verified": verified,
  };
}
