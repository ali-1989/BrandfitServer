import 'dart:async';
import 'package:alfred/alfred.dart';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:assistance_kit/api/generator.dart';
import 'package:assistance_kit/api/helpers/LocaleHelper.dart';
import 'package:assistance_kit/api/helpers/textHelper.dart';
import 'package:brandfit_server/app/smsKaveh.dart';
import 'package:brandfit_server/database/databaseNs.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/database/models/mobileNumber.dart';
import 'package:brandfit_server/database/models/register.dart';
import 'package:brandfit_server/database/models/trainerData.dart';
import 'package:brandfit_server/database/models/userCurrency.dart';
import 'package:brandfit_server/database/models/users.dart';
import 'package:brandfit_server/database/models/userBlockList.dart';
import 'package:brandfit_server/database/models/userConnection.dart';
import 'package:brandfit_server/database/models/userCountry.dart';
import 'package:brandfit_server/database/models/userNameId.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/models/currencyModel.dart';
import 'package:brandfit_server/models/userTypeModel.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/commonMethods.dart';
import 'package:brandfit_server/rest_api/httpCodes.dart';

class RegisterResponse {
  RegisterResponse._();

  static Map<String, dynamic> generateResultOk() {
    return HttpCodes.generateResultOk();
  }

  static Map<String, dynamic> generateResultError(int causeCode, {String? cause}) {
    return HttpCodes.generateJsonError(causeCode, cause: cause);
  }

  static Map<String, dynamic> generateResultBy(String result) {
    return HttpCodes.generateResultJson(result);
  }
  ///==========================================================================================================
  static FutureOr register(HttpRequest req, HttpResponse res) async{
    var bJSON = await req.bodyAsJsonMap;

    var request = bJSON[Keys.request];

    if (request == null) {
      return generateResultError(HttpCodes.error_requestKeyNotFound);
    }

    try{
      switch (request) {
        case 'RegisterNewUser':
          return registerNewUser(req, bJSON);
        case 'VerifyNewUser':
          return verifyNewUser(req, bJSON);
        case 'RestorePassword':
          return restorePassword(req, bJSON);
        case 'ResendVerifyCode':
          return resendVerifyCode(req, bJSON);
      }
    } catch (e){
      // ignore: unawaited_futures
      PublicAccess.logger.logToAll('>>> Register Error: $e ');
    }

  }
  ///==========================================================================================================
  static dynamic registerNewUser(HttpRequest req, Map<String, dynamic> json) async {
    PublicAccess.logger.logToAll('>>> register NewUser: $json');

    var appName = json[Keys.appName];
    var isExerciseTrainer = json['is_exercise_trainer'];
    var isFoodTrainer = json['is_food_trainer'];

    var dbmRegister = RegisterModelDb.fromMap(json);
    dbmRegister.userType = UserTypeModel.getUserTypeNumByAppName(appName);

    var canRegister = await checkCanRegister(req, dbmRegister);

    if(canRegister != null) {
      return canRegister;
    }

    if(isFoodTrainer != null || isExerciseTrainer != null){
      var extra = {
        'is_exercise_trainer':isExerciseTrainer,
        'is_food_trainer':isFoodTrainer
      };
      dbmRegister.extra_js = extra;
    }

    dbmRegister.id = await DatabaseNs.getNextSequenceNumeric(DbNames.Seq_NewUser);
    dbmRegister.verify_code = Generator.getRandomInt(10099, 98989).toString();

    var x = await RegisterModelDb.upsertModel(dbmRegister);

    if(x != null && x > 0) {
      var res = generateResultBy('Registered');
      res[Keys.mobileNumber] = dbmRegister.mobileNumber;
      res[Keys.phoneCode] = dbmRegister.phoneCode;

      var text = PublicAccess.getVerifySmsText() + dbmRegister.verify_code;

      var pc = dbmRegister.phoneCode.toString().replaceFirst(RegExp(r'\+'), '00');
      // ignore: unawaited_futures
      Kaveh.sendSmsGet(pc + dbmRegister.mobileNumber!, text);

      return res;
    }
    else {
      return generateResultError(HttpCodes.error_spacialError);
    }
  }
  ///==========================================================================================================
  static Future<Map?> checkCanRegister(HttpRequest ctx, RegisterModelDb model) async{

    if (model.name == null || model.family == null || model.phoneCode == null
        || model.mobileNumber == null
        || model.userName == null
        || model.password == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if (await UserNameModelDb.existThisUserName(model.userName)) {
      return generateResultError(HttpCodes.error_spacialError, cause: 'ExistUserName');
    }

    if (await MobileNumberModelDb.existThisMobile(model.userType!, model.phoneCode, model.mobileNumber)) {
      return generateResultError(HttpCodes.error_spacialError, cause: 'ExistMobile');
    }

    if (await PublicAccess.psql2.exist(DbNames.T_BadWords, "word = '${model.userName}'")) {
      return generateResultError(HttpCodes.error_spacialError, cause: 'NotAcceptUserName');
    }

    if (await PublicAccess.psql2.exist(DbNames.T_ReservedWords, "word = '${model.userName}'")) {
      return generateResultError(HttpCodes.error_spacialError, cause: 'NotAcceptUserName');
    }

    if (await RegisterModelDb.existRegisteringFor(model.userName, model.phoneCode, model.mobileNumber)) {
      return generateResultError(HttpCodes.error_spacialError, cause: 'ExistUserName');
    }

    return null;
  }
  ///==========================================================================================================
  static dynamic resendVerifyCode(HttpRequest req, Map<String, dynamic> json) async {
    String? mobileNumber = json[Keys.mobileNumber];
    String? phoneCode = json[Keys.phoneCode];
    String? appName = json[Keys.appName];

    if (mobileNumber == null || phoneCode == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    var type = UserTypeModel.getUserTypeNumByAppName(appName);

    String? code = await RegisterModelDb.fetchRegisterCode(type, phoneCode, mobileNumber);

    if (!TextHelper.isEmptyOrNull(code)) {
      phoneCode = phoneCode.replaceFirst('\+', '00');
      code = PublicAccess.getVerifySmsText() + code!;
      // ignore: unawaited_futures
      Kaveh.sendSmsGet(code, phoneCode + mobileNumber);

      return generateResultOk();
    }
    else {
      return generateResultError(HttpCodes.error_dataNotExist);
    }
  }
  ///==========================================================================================================
  static dynamic verifyNewUser(HttpRequest req, Map<String, dynamic> json) async {
    String? mobileNumber = json[Keys.mobileNumber];
    String? phoneCode = json[Keys.phoneCode];
    String? code = json['code'];
    String? deviceId = json[Keys.deviceId];
    String? appName = json[Keys.appName];

    if (mobileNumber == null || phoneCode == null || code == null || deviceId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    phoneCode = LocaleHelper.numberToEnglish(phoneCode.trim());
    mobileNumber = LocaleHelper.numberToEnglish(mobileNumber.trim());
    code = LocaleHelper.numberToEnglish(code.trim());
    var type = UserTypeModel.getUserTypeNumByAppName(appName);

    var exist = await RegisterModelDb.existRegisteringUser(type, phoneCode, mobileNumber);

    if(!exist){
      return generateResultError(HttpCodes.error_spacialError, cause: 'MobileNotFound');
    }

    exist = await RegisterModelDb.isTimeoutRegistering(type, phoneCode, mobileNumber);

    if(exist){
      return generateResultError(HttpCodes.error_spacialError, cause: 'TimeOut');
    }

    exist = await RegisterModelDb.existUserAndCode(type, phoneCode!, mobileNumber!, code!);

    if (PublicAccess.verifyHackCode != code && !exist) {
      return generateResultError(HttpCodes.error_spacialError, cause: 'NotCorrect');
    }

    var rMap = await RegisterModelDb.fetchModelMap(type, phoneCode, mobileNumber);
    var user = RegisterModelDb.fromMap(rMap as Map<String, dynamic>);

    return registerUser(req, user, deviceId);
  }
  ///==========================================================================================================
  static dynamic registerUser(HttpRequest ctx, RegisterModelDb userModel, String deviceId) async{
    var userId = await DatabaseNs.getNextSequence(DbNames.Seq_User);

    var temp = userModel.toMap();
    temp[Keys.userId] = userId;
    temp[Keys.userType] = userModel.userType;

    ///............ Users
    var user = UserModelDb.fromMap(temp);

    var x = await UserModelDb.insertModel(user);

    if (!x) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Insert User Error');
    }

    ///............ User Name Pass
    var userName = UserNameModelDb.fromMap(temp);
    userName.hash_password = Generator.generateMd5(userName.password!);

    x = await UserNameModelDb.insertModel(userName);

    if (!x) {
      await UserModelDb.deleteByUserId(userId);
      return generateResultError(HttpCodes.error_databaseError, cause: 'Insert UserNameId Error');
    }

    ///............ mobile
    var userMobile = MobileNumberModelDb.fromMap(temp);

    x = await MobileNumberModelDb.insertModel(userMobile);

    if (!x) {
      await UserNameModelDb.deleteByUserId(userId);
      await UserModelDb.deleteByUserId(userId);

      return generateResultError(HttpCodes.error_databaseError, cause: 'Insert Mobile Error');
    }

    ///............ country
    var country = UserCountryModelDb.fromMap(temp);
    x = await UserCountryModelDb.insertModel(country);

    ///............ trainer
    if(userModel.userType == UserTypeModel.getUserTypeNumByType(UserType.trainerUser)) {
      final bool isExercise = userModel.extra_js?['is_exercise_trainer']?? false;
      final bool isFood = userModel.extra_js?['is_food_trainer']?? false;

      x = await TrainerDataModelDb.upsertState(userId, isExercise, isFood);

      ///............ currency
      var currency = UserCurrencyModelDb.fromMap(temp);
      currency.currency_code = CurrencyModel.getCurrencyModelByIso(currency.country_iso).currencyCode;
      x = await UserCurrencyModelDb.insertModel(currency);

    }

    await RegisterModelDb.deleteRecord(userModel.mobileNumber!, userModel.userName!);

    final token = Generator.generateKey(40);
    final uc = UserConnectionModelDb();

    uc.user_id = userId;
    uc.device_id = deviceId;
    uc.last_touch = DateHelper.getNowTimestampToUtc();
    uc.is_login = true;
    uc.token = token;

    await UserConnectionModelDb.upsertModel(uc);

    final res = generateResultOk();

    final info = await CommonMethods.getUserLoginInfo(userId, false);
    res.addAll(info);

    /// manager users must apply by manager first
    if(userModel.userType != UserTypeModel.getUserTypeNumByType(UserTypeModel.managerUser)){
      res[Keys.token] = token;
    }
    else {
      await UserBlockListModelDb.blockUser(userId, cause: 'wait for apply');
      //todo : send alert to manager user
    }

    return res;
  }
  ///==========================================================================================================
  static dynamic restorePassword(HttpRequest ctx, Map<String, dynamic> json) async{
    String? mobileNumber = json[Keys.mobileNumber];
    String? phoneCode = json[Keys.phoneCode];
    String? appName = json[Keys.appName];

    if (phoneCode == null || mobileNumber == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    mobileNumber = LocaleHelper.numberToEnglish(mobileNumber.trim());
    phoneCode = LocaleHelper.numberToEnglish(phoneCode.trim());
    var userType = UserTypeModel.getUserTypeNumByAppName(appName);

    if (!(await MobileNumberModelDb.existThisMobile(userType, phoneCode, mobileNumber))) {
      return generateResultError(HttpCodes.error_dataNotExist);
    }


    var userId = await MobileNumberModelDb.getUserId(userType, phoneCode, mobileNumber);

    var map = await UserNameModelDb.fetchMap(userId!);

    if (map == null) {
      return generateResultError(HttpCodes.error_dataNotExist);
    }

    var send = 'Your account';
    send += '\n\n';
    send += 'UserName: ${map[Keys.userName]}' ;
    send += '\n';
    send += 'Password: ${map['password']}';

    phoneCode = phoneCode!.replaceFirst('\+', '00');
    // ignore: unawaited_futures
    Kaveh.sendSmsGet(send, phoneCode + mobileNumber!);

    return generateResultOk();
  }
  ///==========================================================================================================
}