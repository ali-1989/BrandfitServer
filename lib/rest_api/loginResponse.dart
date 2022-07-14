import 'dart:async';
import 'package:alfred/alfred.dart';
import 'package:assistance_kit/api/generator.dart';
import 'package:brandfit_server/database/models/devicesCellar.dart';
import 'package:brandfit_server/database/models/mobileNumber.dart';
import 'package:brandfit_server/database/models/userBlockList.dart';
import 'package:brandfit_server/database/models/userConnection.dart';
import 'package:brandfit_server/database/models/users.dart';
import 'package:brandfit_server/database/models/userNameId.dart';
import 'package:brandfit_server/database/models/userPlace.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/models/countryModel.dart';
import 'package:brandfit_server/models/userTypeModel.dart';
import 'package:brandfit_server/rest_api/commonMethods.dart';
import 'package:brandfit_server/rest_api/httpCodes.dart';

class LoginResponse {
  LoginResponse._();

  static Map<String, dynamic> generateResultOk() {
    return HttpCodes.generateResultOk();
  }

  static Map<String, dynamic> generateResultError(int causeCode, {String? cause}) {
    return HttpCodes.generateJsonError(causeCode, cause: cause);
  }

  static Map<String, dynamic> generateResultBy(String result) {
    return HttpCodes.generateResultJson(result);
  }
  //===============================================================================================
  /*static FutureOr login(HttpRequest req, HttpResponse res) async {
    var result = await CommonMethods.getUserLoginInfo(1004, false);
    result[Keys.result] = 'Grant';
    result[Keys.token] = 'fake-hack';

    return result;
  }*/

  static FutureOr login(HttpRequest req, HttpResponse res) async{
    var bJSON = await req.bodyAsJsonMap;

    String userName = bJSON[Keys.userName]?? '';
    String deviceId = bJSON[Keys.deviceId];
    String languageIso = bJSON[Keys.languageIso];
    String appName = bJSON[Keys.appName];
    String countryIso = bJSON[Keys.countryIso];// device CountryIso

    int? userId = await UserNameModelDb.getUserIdByUserName(userName);

    if(userId == null) {
      if(userName.startsWith('0')){
        userName = userName.substring(1);
      }

      final countryCode = CountryModel.getCountryCodeByIso(countryIso);
      final userType = UserTypeModel.getUserTypeNumByAppName(appName);
      userId ??= await MobileNumberModelDb.getUserIdByMobile(userType, countryCode, userName);

      if(userId != null){
        userName = await UserNameModelDb.getUserNameByUserId(userId);
      }
    }

    if (userId == null) {
      return generateResultError(HttpCodes.error_userNotFound);
    }

    bJSON[Keys.userId] = userId;
    final hashPassword = bJSON['hash_password']?? '-';

    final map = await UserNameModelDb.fetchMapBy(userName, hashPassword);

    if (map == null) {
      return generateResultError(HttpCodes.error_userNamePassIncorrect);
    }

    if (await UserModelDb.isDeletedUser(userId)) {
      return generateResultError(HttpCodes.error_userNotFound);
    }

    if (!(await UserModelDb.checkUserIsMatchWithApp(userId, appName))) {
      return generateResultError(HttpCodes.error_userNamePassIncorrect);
    }

    if (await UserBlockListModelDb.isBlockedUser(userId)) {
      return generateResultError(HttpCodes.error_userIsBlocked);
    }

    final token = Generator.generateKey(40);

    await UserConnectionModelDb.upsertUserActiveTouch(userId, deviceId, langIso: languageIso, token: token);
    //...............................
    final deviceCaller = DeviceCellarModelDb.fromMap(bJSON);
    await DeviceCellarModelDb.upsertModel(deviceCaller);
    //...............................
    var userPlace = UserPlaceModelDb.fromMap(bJSON);
    await UserPlaceModelDb.upsertModel(userPlace);

    return loginUser(bJSON, userId, token);
  }
  ///----------------------------------------------------------------------------------------------------------
  static Future<Map> loginUser(Map<String, dynamic> json, int userId, String token) async {
    final res = await CommonMethods.getUserLoginInfo(userId, false);

    res[Keys.result] = 'Grant';
    res[Keys.token] = token;

    return res;
  }
}