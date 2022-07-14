import 'dart:async';
import 'package:alfred/alfred.dart';
import 'package:assistance_kit/api/converter.dart';
import 'package:assistance_kit/api/generator.dart';
import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/api/helpers/mathHelper.dart';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:brandfit_server/app/pathNs.dart';
import 'package:brandfit_server/database/databaseNs.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/database/models/conversation.dart';
import 'package:brandfit_server/database/models/conversationMessage.dart';
import 'package:brandfit_server/database/models/conversationUser.dart';
import 'package:brandfit_server/database/models/course.dart';
import 'package:brandfit_server/database/models/programSuggestion.dart';
import 'package:brandfit_server/database/models/request.dart';
import 'package:brandfit_server/database/models/foodMaterial.dart';
import 'package:brandfit_server/database/models/foodProgram.dart';
import 'package:brandfit_server/database/models/ticket.dart';
import 'package:brandfit_server/database/models/ticketMessage.dart';
import 'package:brandfit_server/database/models/trainerData.dart';
import 'package:brandfit_server/database/models/userBlockList.dart';
import 'package:brandfit_server/database/models/userCardBank.dart';
import 'package:brandfit_server/database/models/userConnection.dart';
import 'package:brandfit_server/database/models/userCountry.dart';
import 'package:brandfit_server/database/models/userNotifier.dart';
import 'package:brandfit_server/database/models/users.dart';
import 'package:brandfit_server/database/models/userFitnessData.dart';
import 'package:brandfit_server/database/models/userImage.dart';
import 'package:brandfit_server/database/models/userNameId.dart';
import 'package:brandfit_server/database/models/userPersonalData.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/models/courseQuestionModel.dart';
import 'package:brandfit_server/models/enums.dart';
import 'package:brandfit_server/models/healthConditionModel.dart';
import 'package:brandfit_server/models/jobActivityModel.dart';
import 'package:brandfit_server/models/photoDataModel.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/ServerNs.dart';
import 'package:brandfit_server/rest_api/adminCommands.dart';
import 'package:brandfit_server/rest_api/commonMethods.dart';
import 'package:brandfit_server/rest_api/httpCodes.dart';
import 'package:brandfit_server/rest_api/httpMessages.dart';
import 'package:brandfit_server/rest_api/userNotifierCenter.dart';
import 'package:brandfit_server/rest_api/wsMessenger.dart';

class SetDataResponse {
  SetDataResponse._();

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
  static FutureOr response(HttpRequest req, HttpResponse res) async {
    final body = await req.bodyAsJsonMap;
    late Map<String, dynamic> bJSON;

    if(body.containsKey(Keys.jsonHttp)) {
      bJSON = JsonHelper.jsonToMap<String, dynamic>(body[Keys.jsonHttp]!)!;
      req.store.set('Body', body);
    }
    else {
      bJSON = body;
    }

    PublicAccess.logInDebug(bJSON.toString());

    var requesterId = bJSON[Keys.requesterId];
    final deviceId = bJSON[Keys.deviceId];
    var request = bJSON[Keys.request];
    var userId = bJSON[Keys.userId];

    if(deviceId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if (request == null) {
      return generateResultError(HttpCodes.error_requestKeyNotFound);
    }

    if(requesterId == null && userId != null){
      //bJSON[Keys.userId] = requesterId;
      requesterId = userId;
    }

    if (requesterId != null) {
      final token = bJSON[Keys.token];

      if (!(await UserConnectionModelDb.tokenIsActive(requesterId, deviceId, token))) {
        return generateResultError(HttpCodes.error_tokenNotCorrect);
      }

      // ignore: unawaited_futures
      UserConnectionModelDb.upsertUserActiveTouch(requesterId, deviceId);

      if (await UserModelDb.isDeletedUser(requesterId)) {
        return generateResultError(HttpCodes.error_userNotFound);
      }

      if (await UserBlockListModelDb.isBlockedUser(requesterId)) {
        return generateResultError(HttpCodes.error_userIsBlocked);
      }
    }

    if(request == Keys.adminCommand || AdminCommands.isAdminCommand(request)){
      if(requesterId == null) {
        return generateResultError(HttpCodes.error_parametersNotCorrect);
      }

      final isManager = await UserModelDb.isManagerUser(requesterId);

      if(!isManager){
        return generateResultError(HttpCodes.error_canNotAccess);
      }

      request = bJSON[Keys.subRequest];
    }
    ///.............................................................................................
    try{
      if(request != Keys.multiRequest) {
        return _process(request, req, bJSON);
      }
      else {
        int count = bJSON[Keys.count];
        var allResult = true;
        //bool rollback = bJSON['Rollback'];

        final resMap = <String, dynamic>{};

        for(var i=1; i <= count; i++){
          Map<String, dynamic> subJs = bJSON['${Keys.request}$i'];
          request = subJs[Keys.request];

          final r = await _process(request, req, subJs);
          resMap['$request'] = r;

          allResult = allResult && r[Keys.result] == Keys.ok;
        }

        resMap[Keys.result] = Keys.multiResult;
        resMap['all_result'] = allResult;

        return resMap;
      }
    }
    catch (e){
      PublicAccess.logInDebug('>>> Set-Data Error: $e ');
    }
  }
  ///==========================================================================================================
  static Future<Map<String, dynamic>> _process(String request, HttpRequest req, Map<String, dynamic> js) async{
    if (request == 'LogoffUserReport') {
      return setUserIsLogoff(req, js);
    }

    if (request == 'DeleteProfileAvatar') {
      return deleteProfileAvatar(req, js);
    }

    if (request == 'UpdateProfileAvatar') {
      return updateProfileAvatar(req, js);
    }

    if (request == 'UpdateBodyPhoto') {
      return updateBodyPhoto(req, js);
    }

    if (request == 'SetUserBlockingState') {
      return setUserBlockingState(req, js);
    }

    if (request == 'UpdateProfileUserName') {
      return updateProfileUserName(req, js);
    }

    if (request == 'UpdateProfileNameFamily') {
      return updateProfileNameFamily(req, js);
    }

    if (request == 'UpdateProfileSex') {
      return updateProfileSex(req, js);
    }

    if (request == 'UpdateProfileBirthDate') {
      return updateProfileBirthDate(req, js);
    }

    if (request == 'UpdateUserCountryIso') {
      return updateUserCountryIso(req, js);
    }

    if (request == 'UpdateSportsEquipment') {
      return updateSportsEquipment(req, js);
    }

    if (request == 'UpdateHealthCondition') {
      return updateHealthCondition(req, js);
    }

    if (request == 'UpdateJobTypeProfile') {
      return updateJobTypeProfile(req, js);
    }

    if (request == 'UpdateNonWorkActivityProfile') {
      return updateNonWorkActivityProfile(req, js);
    }

    if (request == 'UpdateSleepStateProfile') {
      return updateSleepStateProfile(req, js);
    }

    if (request == 'UpdateExerciseStateProfile') {
      return updateExerciseStateProfile(req, js);
    }

    if (request == 'UpdateGoalOfFitnessProfile') {
      return updateGoalOfFitnessProfile(req, js);
    }

    if (request == 'UpdateFitnessStatus') {
      return updateFitnessStatus(req, js);
    }

    if (request == 'DeleteFitnessStatus') {
      return deleteFitnessStatus(req, js);
    }

    if (request == 'DeleteBodyPhoto') {
      return deleteBodyPhoto(req, js);
    }

    if (request == 'AddAdvertising') {
      return addAdvertising(req, js);
    }

    if (request == 'DeleteAdvertising') {
      return deleteAdvertising(req, js);
    }

    if (request == 'ChangeAdvertisingShowState') {
      return changeAdvertisingShowState(req, js);
    }

    if (request == 'ChangeAdvertisingTitle') {
      return changeAdvertisingTitle(req, js);
    }

    if (request == 'ChangeAdvertisingTag') {
      return changeAdvertisingTag(req, js);
    }

    if (request == 'ChangeAdvertisingType') {
      return changeAdvertisingType(req, js);
    }

    if (request == 'ChangeAdvertisingPhoto') {
      return changeAdvertisingPhoto(req, js);
    }

    if (request == 'ChangeAdvertisingOrder') {
      return changeAdvertisingOrder(req, js);
    }

    if (request == 'ChangeAdvertisingDate') {
      return changeAdvertisingDate(req, js);
    }

    if (request == 'ChangeAdvertisingLink') {
      return changeAdvertisingLink(req, js);
    }

    if (request == 'AddNewFoodMaterial') {
      return addNewFoodMaterial(req, js);
    }

    if (request == 'DeleteFoodMaterial') {
      return deleteFoodMaterial(req, js);
    }

    if (request == 'UpdateFoodMaterialTitle') {
      return updateFoodMaterialTitle(req, js);
    }

    if (request == 'UpdateFoodMaterialAlternatives') {
      return updateFoodMaterialAlternatives(req, js);
    }

    if (request == 'UpdateFoodMaterialFundamentals') {
      return updateFoodMaterialFundamentals(req, js);
    }

    if (request == 'UpdateFoodMaterialShowState') {
      return updateFoodMaterialShowState(req, js);
    }

    if (request == 'AddFoodProgram') {
      return addFoodProgram(req, js);
    }

    if (request == 'RepeatFoodProgram') {
      return repeatFoodProgram(req, js);
    }

    if (request == 'EditFoodProgram') {
      return editFoodProgram(req, js);
    }

    if (request == 'DeleteFoodProgram') {
      return deleteFoodProgram(req, js);
    }

    if (request == 'UpdateFoodProgramDays') {
      return updateFoodProgramDays(req, js);
    }

    if (request == 'SendFoodProgram') {
      return sendFoodProgram(req, js);
    }

    if (request == 'SetSuggestionReport') {
      return setSuggestionReport(req, js);
    }

    if (request == 'AddNewCourse') {
      return addNewCourse(req, js);
    }

    if (request == 'EditCourse') {
      return editCourse(req, js);
    }

    if (request == 'DeleteCourse') {
      return deleteCourse(req, js);
    }

    if (request == 'BuyACourse') {
      return requestACourse(req, js);
    }

    if (request == 'ChangeCourseBlockState') {
      return changeCourseBlockState(req, js);
    }

    if (request == 'NewTicketTextMessage') {
      return newTicketTextMessage(req, js);
    }

    if (request == 'NewTicketMediaMessage') {
      return newTicketMediaMessage(req, js);
    }

    if (request == 'DeleteTicketMessages') {
      return deleteTicketMessages(req, js);
    }

    if (request == 'UpdateLastSeenTicket') {
      return updateLastSeenTicket(req, js);
    }

    if (request == 'NewChatTextMessage') {
      return newChatTextMessage(req, js);
    }

    if (request == 'NewChatMediaMessage') {
      return newChatMediaMessage(req, js);
    }

    if (request == 'DeleteChatMessages') {
      return deleteTicketMessages(req, js);
    }

    if (request == 'OpenChat') {
      return openChat(req, js);
    }

    if (request == 'UpdateLastSeenChat') {
      return updateLastSeenChat(req, js);
    }

    if (request == 'SetRejectCourseBuy') {
      return setRejectCourseBuy(req, js);
    }

    if (request == 'SetAcceptCourseBuy') {
      return setAcceptCourseBuy(req, js);
    }

    if (request == 'DeleteUserNotifier') {
      return deleteUserNotifier(req, js);
    }

    if (request == 'SetSeenUserNotifier') {
      return setSeenUserNotifier(req, js);
    }

    if (request == 'SetSeenUserNotifiers') {
      return setSeenUserNotifiers(req, js);
    }

    if (request == 'SetTrainerBroadcastCourseState') {
      return setTrainerBroadcastCourseState(req, js);
    }

    if (request == 'SetTrainerState') {
      return setTrainerState(req, js);
    }

    if (request == 'SetTrainerBio') {
      return setTrainerBio(req, js);
    }

    if (request == 'UpdateBioPhoto') {
      return updateBioPhoto(req, js);
    }

    if (request == 'DeleteBioPhoto') {
      return deleteBioPhoto(req, js);
    }

    if (request == 'AddUserBankCard') {
      return addUserBankCard(req, js);
    }

    if (request == 'DeleteUserBankCard') {
      return deleteUserBankCard(req, js);
    }

    if (request == 'UpdatePayPhoto') {
      return updatePayPhoto(req, js);
    }


    return generateResultError(HttpCodes.error_requestNotDefined);
  }
  ///==========================================================================================================
  static Future<Map<String, dynamic>> setUserIsLogoff(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];

    if(userId == null || deviceId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final r = await UserConnectionModelDb.setUserLogoff(userId, deviceId);

    if(!r) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not set user logoff');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;

    return res;
  }

  static Future<Map<String, dynamic>> deleteProfileAvatar(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];

    if(userId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final del = await UserImageModelDb.deleteProfileImage(userId, 1);

    if(!del) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'Not delete from[UserImages]');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;

    return res;
  }

  static Future<Map<String, dynamic>> updateProfileAvatar(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final partName = js[Keys.partName];
    final fileName = js[Keys.fileName];

    if(userId == null || partName == null || fileName == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final body = req.store.get('Body');
    //final file = body[partName] as HttpBodyFileUpload;
    final savedFile = await ServerNs.uploadFile(req, body, partName);

    if(savedFile == null){
      return generateResultError(HttpCodes.error_notUpload);
    }

    final okDb = await UserImageModelDb.upsertUserImage(userId, 1, savedFile.path);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'Not save [UserImages]');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;
    res[Keys.fileUri] = PathsNs.genUrlDomainFromFilePath(PublicAccess.domain, PathsNs.getCurrentPath(), savedFile.path);
    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToAllUserDevice(userId, JsonHelper.mapToJson(match));

    //--- To other user chats ------------------------------------
    WsMessenger.sendDataToOtherUserChats(userId, 'todo');

    return res;
  }

  static Future<Map<String, dynamic>> updateBodyPhoto(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    final partName = js[Keys.partName]; // back_photo, front_photo
    final fileName = js[Keys.fileName];

    if(userId == null || partName == null || fileName == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final body = req.store.get('Body');
    //final file = body[partName] as HttpBodyFileUpload;
    final savedFile = await ServerNs.uploadFile(req, body, partName);

    if(savedFile == null){
      return generateResultError(HttpCodes.error_notUpload);
    }

    final uri = PathsNs.genUrlDomainFromLocalPathByDecoding(PublicAccess.domain, PathsNs.getCurrentPath(), savedFile.path)!;

    final okDb = await UserFitnessDataModelDb.upsertUserFitnessImage(userId, partName, uri);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'Not save [fitness Image]');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;
    res[Keys.fileUri] = uri;
    res.addAll(await UserFitnessDataModelDb.getUserFitnessStatusJs(userId));

    //--------- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToOtherDeviceAvoidMe(userId, deviceId, JsonHelper.mapToJson(match));
    //---------------------------------------------------------------
    return res;
  }

  static Future<Map<String, dynamic>> setUserBlockingState(HttpRequest req, Map<String, dynamic> js) async{
    final requesterId = js[Keys.requesterId];
    final forUserId = js[Keys.forUserId];
    bool? state = js[Keys.state];
    String? cause = js[Keys.cause];

    if(forUserId == null || state == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    // before call this method ,check requester is manager

    if(state) {
      final okDb = await UserBlockListModelDb.blockUser(forUserId, blocker: requesterId, cause: cause);

      if(!okDb) {
        return generateResultError(HttpCodes.error_databaseError , cause: 'Not change user block state');
      }
    }
    else {
      final okDb = await UserBlockListModelDb.unBlockUser(forUserId);

      if(okDb == null || okDb < 1) {
        return generateResultError(HttpCodes.error_databaseError , cause: 'Not change user block state');
      }
    }

    final res = generateResultOk();
    res[Keys.userId] = forUserId;

    //--- To all user's devices ------------------------------------
    WsMessenger.sendYouAreBlocked(forUserId);

    return res;
  }

  static Future<Map<String, dynamic>> updateProfileUserName(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    String? userName = js[Keys.userName];

    if(forUserId == null || userName == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(userName.isEmpty){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await UserNameModelDb.changeUserName(forUserId, userName);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'Not save userName');
    }

    final res = generateResultOk();
    res[Keys.userId] = forUserId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = forUserId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(forUserId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToAllUserDevice(forUserId, JsonHelper.mapToJson(match));

    return res;
  }

  //@ admin
  static Future<Map<String, dynamic>> updateProfileNameFamily(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    String? name = js[Keys.name];
    String? family = js['family'];

    if(forUserId == null || name == null || family == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }


    if(name.isEmpty || family.isEmpty){
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await UserModelDb.changeNameFamily(forUserId, name, family);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not save name family');
    }

    final res = generateResultOk();
    res[Keys.userId] = forUserId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = forUserId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(forUserId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToAllUserDevice(forUserId, JsonHelper.mapToJson(match));

    return res;
  }

  //@ admin
  static Future<Map<String, dynamic>> updateProfileSex(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    int? sex = js['sex'];

    if(forUserId == null || sex == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await UserModelDb.changeUserSex(forUserId, sex);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not save sex');
    }

    final res = generateResultOk();
    res[Keys.userId] = forUserId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = forUserId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(forUserId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToAllUserDevice(forUserId, JsonHelper.mapToJson(match));

    return res;
  }

  //@ admin
  static Future<Map<String, dynamic>> updateProfileBirthDate(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    String? birthDate = js['birthdate'];

    if(forUserId == null || birthDate == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await UserModelDb.changeUserBirthDate(forUserId, birthDate);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not save birthDate');
    }

    final res = generateResultOk();
    res[Keys.userId] = forUserId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = forUserId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(forUserId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToAllUserDevice(forUserId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> updateUserCountryIso(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    String? countryCode = js[Keys.phoneCode];
    String? countryIso = js[Keys.countryIso];

    if(userId == null || countryCode == null || countryIso == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await UserCountryModelDb.upsertUserCountry(userId, countryIso);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not save user Country');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToAllUserDevice(userId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> updateSportsEquipment(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    String? homeEq = js['sports_equipment_in_home'];
    String? gymEq = js['sports_equipment_in_gym'];

    if(userId == null || deviceId == null || homeEq == null || gymEq == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await PersonalDataModelDb.upsertUserSportsEquipment(userId, homeEq, gymEq);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not save SportsEquipment');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToOtherDeviceAvoidMe(userId, deviceId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> updateHealthCondition(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    List? illList = js['ill_list'];
    String? illDescription = js['ill_description'];
    String? medications = js['ill_medications'];

    if(userId == null || deviceId == null || illList == null || illDescription == null || medications == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final health = HealthConditionModel.fromMap(js);

    final okDb = await PersonalDataModelDb.upsertUserHealthCondition(userId, health);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not sink HealthCondition');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToOtherDeviceAvoidMe(userId, deviceId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> updateJobTypeProfile(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    String? jobType = js['job_type'];

    if(userId == null || deviceId == null || jobType == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await PersonalDataModelDb.upsertUserJobType(userId, jobType);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not sink JobType');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToOtherDeviceAvoidMe(userId, deviceId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> updateNonWorkActivityProfile(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    String? nonWorkActivity = js['none_work_activity'];

    if(userId == null || deviceId == null || nonWorkActivity == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await PersonalDataModelDb.upsertUserNonWorkActivity(userId, nonWorkActivity);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not sink NonWorkActivity');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToOtherDeviceAvoidMe(userId, deviceId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> updateSleepStateProfile(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    int? atDay = js['sleep_hours_at_day'];
    int? atNight = js['sleep_hours_at_night'];

    if(userId == null || deviceId == null || atDay == null || atNight == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await PersonalDataModelDb.upsertUserSleepStateProfile(userId, atDay, atNight);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not sink SleepStateProfile');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToOtherDeviceAvoidMe(userId, deviceId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> updateExerciseStateProfile(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    int? exerciseHours = js['exercise_hours'];

    if(userId == null || deviceId == null || exerciseHours == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await PersonalDataModelDb.upsertUserExerciseState(userId, exerciseHours);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not sink exercise hours');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToOtherDeviceAvoidMe(userId, deviceId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> updateGoalOfFitnessProfile(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    String? goalOfFitness = js['goal_of_fitness'];

    if(userId == null || deviceId == null || goalOfFitness == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await PersonalDataModelDb.upsertUserGoalOfFitness(userId, goalOfFitness);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not sink GoalOfFitness');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToOtherDeviceAvoidMe(userId, deviceId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> updateFitnessStatus(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    final String? nodeName = js['node_name'];
    final value = js[Keys.value];

    if(userId == null || deviceId == null || nodeName == null || value == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final node = NodeNames.height_node.byName(nodeName);

    if(node == null) {
      return generateResultError(HttpCodes.error_spacialError, cause: 'nodeName is inCorrect');
    }

    final okDb = await UserFitnessDataModelDb.upsertUserFitnessStatus(userId, node, value);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not sink User FitnessStatus');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;
    res.addAll(await UserFitnessDataModelDb.getUserFitnessStatusJs(userId));

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToAllUserDevice(userId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> deleteFitnessStatus(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    String? nodeName = js['node_name'];
    String? date = js[Keys.date];
    final value = js[Keys.value];

    if(userId == null || deviceId == null || nodeName == null || date == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await UserFitnessDataModelDb.deleteUserFitnessStatus(userId, nodeName, date, value);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not delete User FitnessStatus');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;
    res.addAll(await UserFitnessDataModelDb.getUserFitnessStatusJs(userId));

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(section: HttpCodes.sec_userData, command: HttpCodes.com_updateProfileSettings);
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToAllUserDevice(userId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> deleteBodyPhoto(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    String? nodeName = js[Keys.nodeName];
    String? date = js[Keys.date];
    final uri = js[Keys.imageUri];

    if(userId == null || deviceId == null || nodeName == null || date == null || uri == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await UserFitnessDataModelDb.deleteUserFitnessImage(userId, nodeName, date, uri);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not delete User FitnessStatus image');
    }

    final res = generateResultOk();
    res[Keys.userId] = userId;
    res.addAll(await UserFitnessDataModelDb.getUserFitnessStatusJs(userId));

    //--- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(
        section: HttpCodes.sec_userData,
        command: HttpCodes.com_updateProfileSettings
    );
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    WsMessenger.sendToOtherDeviceAvoidMe(userId, deviceId, JsonHelper.mapToJson(match));

    return res;
  }

  static Future<Map<String, dynamic>> addAdvertising(HttpRequest req, Map<String, dynamic> js) async{
    final requesterId = js[Keys.requesterId];
    final partName = js[Keys.partName];
    final fileName = js[Keys.fileName];

    if(requesterId == null || partName == null || fileName == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final body = req.store.get('Body');
    final savedFile = await ServerNs.uploadFile(req, body, partName);

    if(savedFile == null){
      return generateResultError(HttpCodes.error_notUpload);
    }

    final okDb = await CommonMethods.addNewAdvertising(requesterId, js, savedFile.path);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not add new Advertising');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> deleteAdvertising(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final id = js['advertising_id'];

    if(userId == null || id == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final okDb = await CommonMethods.deleteAdvertising(userId, id);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not delete Advertising');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> changeAdvertisingShowState(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final advId = js['advertising_id'];
    final state = js[Keys.state];

    if(userId == null || advId == null || state == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final okDb = await CommonMethods.changeAdvertisingShowState(userId, advId, state);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Advertising state');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> changeAdvertisingTitle(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final advId = js['advertising_id'];
    final title = js[Keys.title];

    if(userId == null || advId == null || title == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final okDb = await CommonMethods.changeAdvertisingTitle(userId, advId, title);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Advertising title');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> changeAdvertisingTag(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final advId = js['advertising_id'];
    final tag = js['tag'];

    if(userId == null || advId == null || tag == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final okDb = await CommonMethods.changeAdvertisingTag(userId, advId, tag);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Advertising tag');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> changeAdvertisingType(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final advId = js['advertising_id'];
    final type = js[Keys.type];

    if(userId == null || advId == null || type == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final okDb = await CommonMethods.changeAdvertisingType(userId, advId, type);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Advertising type');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> changeAdvertisingPhoto(HttpRequest req, Map<String, dynamic> js) async{
    final requesterId = js[Keys.requesterId];
    final advId = js['advertising_id'];
    final fileName = js[Keys.fileName];
    final partName = js[Keys.partName];

    if(requesterId == null || fileName == null || partName == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(requesterId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final body = req.store.get('Body');
    final savedFile = await ServerNs.uploadFile(req, body, partName);

    if(savedFile == null){
      return generateResultError(HttpCodes.error_notUpload);
    }

    final okDb = await CommonMethods.changeAdvertisingPhoto(requesterId, advId, savedFile.path);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Advertising photo');
    }

    final res = generateResultOk();
    res[Keys.fileUri] = PathsNs.genUrlDomainFromFilePath(PublicAccess.domain, PathsNs.getCurrentPath(), savedFile.path);

    return res;
  }

  static Future<Map<String, dynamic>> changeAdvertisingOrder(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final advId = js['advertising_id'];
    final orderNum = js['order_num'];

    if(userId == null || orderNum == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final okDb = await CommonMethods.changeAdvertisingOrder(userId, advId, orderNum);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Advertising orderNum');
    }

    final res = generateResultOk();

    return res;
  }

  static Future<Map<String, dynamic>> changeAdvertisingDate(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final advId = js['advertising_id'];
    final section = js[Keys.section];
    final dateTs = js[Keys.date];

    if(userId == null || section == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final okDb = await CommonMethods.changeAdvertisingDate(userId, advId, section, dateTs);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Advertising date');
    }

    final res = generateResultOk();

    return res;
  }

  static Future<Map<String, dynamic>> changeAdvertisingLink(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final advId = js['advertising_id'];
    final link = js['link'];

    if(userId == null || link == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final okDb = await CommonMethods.changeAdvertisingLink(userId, advId, link);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Advertising link');
    }

    final res = generateResultOk();

    return res;
  }

  //@ ~admin
  static Future<Map<String, dynamic>> addNewFoodMaterial(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final title = js[Keys.title];
    final alternatives = Converter.correctList<String>(js['alternatives'])?? [];
    final fundamentals = js['fundamentals_js'];
    final measure = js['measure_js'];
    final canShow = js['can_show']?? true;
    final type = js['type'];

    if(userId == null || title == null || fundamentals == null || measure == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    /*final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }*/

    final model = FoodMaterialModelDb.createModel(userId, title, type, alternatives, fundamentals, measure, canShow);

    final okDb = await FoodMaterialModelDb.addNewFoodMaterial(js, userId, model);

    if(okDb < 0) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not add new Food material');
    }

    return generateResultOk();
  }

  static Future<Map<String, dynamic>> deleteFoodMaterial(HttpRequest req, Map<String, dynamic> js) async {
    ///info: is manager checked before [AdminCommand]
    final id = js['id'];

    if(id == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final used = await FoodMaterialModelDb.isUsageFromFoodMaterialInPrograms(id);

    if(used) {
      return generateResultError(HttpCodes.error_operationCannotBePerformed, cause: 'this material used in programs');
    }

    final okDb = await FoodMaterialModelDb.deleteFoodMaterial(js, id);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not delete Food material');
    }

    return generateResultOk();
  }

  static Future<Map<String, dynamic>> updateFoodMaterialTitle(HttpRequest req, Map<String, dynamic> js) async {
    ///info: is manager checked before [AdminCommand]
    final id = js['id'];
    final title = js[Keys.title];

    if(id == null || title == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await FoodMaterialModelDb.updateFoodMaterialTitle(js, id, title);

    if(okDb == null) {
      return generateResultError(HttpCodes.error_existThis);
    }

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Food material title');
    }

    final res = generateResultOk();
    res.addAll(await FoodMaterialModelDb.getFoodMaterialItem(id));
    return res;
  }

  static Future<Map<String, dynamic>> updateFoodMaterialAlternatives(HttpRequest req, Map<String, dynamic> js) async {
    final id = js['id'];
    final alternatives = js['alternatives'];

    if(id == null || alternatives == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await FoodMaterialModelDb.updateFoodMaterialAlternatives(js, id, alternatives);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Food material alt');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> updateFoodMaterialFundamentals(HttpRequest req, Map<String, dynamic> js) async {
    final id = js['id'];
    final fundamentals = js['fundamentals_js'];
    final measure = js['measure_js'];

    if(id == null || fundamentals == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await FoodMaterialModelDb.updateFoodMaterialFundamentals(id, fundamentals, measure);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Food material fundamentals');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> updateFoodMaterialShowState(HttpRequest req, Map<String, dynamic> js) async {
    final id = js['id'];
    final state = js[Keys.state];

    if(id == null || state == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await FoodMaterialModelDb.updateFoodMaterialCanShow(js, id, state);

    if(okDb == null) {
      return generateResultError(HttpCodes.error_operationCannotBePerformed);
    }

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Food material state');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> addFoodProgram(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final programData = js['program_data'] as Map<String, dynamic>?;

    if(userId == null || programData == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await FoodProgramModelDb.addFoodProgram(js, programData, userId);

    if(okDb == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not add Food program');
    }

    final res = generateResultOk();
    res['program_id'] = okDb.foodProgramId;
    res['register_date'] = okDb.registerDate;
    return res;
  }

  static Future<Map<String, dynamic>> repeatFoodProgram(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final oldId = js['old_program_id'];
    final programData = js['program_data'] as Map<String, dynamic>?;

    if(userId == null || programData == null || oldId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await FoodProgramModelDb.repeatFoodProgram(js, programData, userId, oldId);

    if(okDb == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not repeat Food program');
    }

    final res = generateResultOk();
    res['program_id'] = okDb.foodProgramId;
    res['register_date'] = okDb.registerDate;
    return res;
  }

  static Future<Map<String, dynamic>> editFoodProgram(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final programId = js['program_id'];
    final programData = js['program_data'] as Map<String, dynamic>?;

    if(userId == null || programData == null || programId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(await FoodProgramModelDb.isProgramSend(programId)){
      return generateResultError(HttpCodes.error_operationCannotBePerformed, cause: 'this is send');
    }

    final okDb = await FoodProgramModelDb.updateFoodProgram(js, programData, programId);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not edit Food program');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> deleteFoodProgram(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final programId = js['program_id'];

    if(userId == null || programId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(await FoodProgramModelDb.isProgramSend(programId)){
      return generateResultError(HttpCodes.error_operationCannotBePerformed, cause: 'this is send');
    }

    final okDb = await FoodProgramModelDb.deleteFoodProgram(js, programId);

    if(okDb == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not delete Food program');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> updateFoodProgramDays(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final programId = js['program_id'];
    final days = Converter.correctList<Map>(js['days']);

    if(userId == null || programId == null || days == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(await FoodProgramModelDb.isProgramSend(programId)){
      return generateResultError(HttpCodes.error_operationCannotBePerformed, cause: 'this is send');
    }

    final okDb = await FoodProgramModelDb.setProgramDays(js, userId, programId, days);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update Food program days');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> sendFoodProgram(HttpRequest req, Map<String, dynamic> js) async {
    final forUserId = js[Keys.forUserId];
    final programId = js['program_id'];

    if(forUserId == null || programId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(await FoodProgramModelDb.isProgramSend(programId)){
      return generateResultError(HttpCodes.error_operationCannotBePerformed, cause: 'this is send');
    }

    final h4 = await FoodProgramModelDb.setProgramIsSend(programId);

    if(h4 == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not send Food program to user');
    }

    final requestId = h4.requestId!;
    final cMap = await RequestModelDb.fetchMap(requestId);
    final requestModel = RequestModelDb.fromMap(cMap!);
    final courseMap = await CourseModelDb.fetchMap(requestModel.course_id);
    final courseModel = CourseModelDb.fromMap(courseMap!);
    final activeDays = courseModel.duration_day + MathHelper.percentInt(courseModel.duration_day, PublicAccess.supportPercent);

    final expireDate = DateHelper.getNowToUtc().add(Duration(days: activeDays));
    await RequestModelDb.setSupportExpireDate(h4.requestId!, DateHelper.toTimestamp(expireDate));
    //------ notify Pupil ----------------------------------------------------
    final userName = await UserNameModelDb.getUserNameByUserId(forUserId);
    final description = {'trainer_name': userName, 'course_name': courseModel.title, 'active_days': activeDays};

    // ignore: unawaited_futures
    UserNotifierCenter.sendProgram(requestModel.requester_user_id, description);
    //------| notify Pupil ----------------------------------------------------

    final res = generateResultOk();
    res['send_date'] = h4.sendDate;
    res['cron_date'] = h4.cronDate;

    return res;
  }

  static Future<Map<String, dynamic>> setSuggestionReport(HttpRequest req, Map<String, dynamic> js) async {
    final forUserId = js[Keys.forUserId];
    final programId = js['program_id'];
    final suggestionId = js['suggestion_id'];
    final data = js['data'];

    if(forUserId == null || programId == null || suggestionId == null || data == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final report = Converter.correctList<Map<String, dynamic>>(data)!;

    final ok = await ProgramSuggestionModelDb.setReport(programId, suggestionId, report);

    if(!ok) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not set suggestion report');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> addNewCourse(HttpRequest req, Map<String, dynamic> js) async {
    final forUserId = js[Keys.forUserId];
    final courseJsText = js['course_js'];

    if(forUserId == null || courseJsText == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final partName = js[Keys.partName];
    var imageFile;

    if(partName != null) {
      if(partName == 'CourseBackground') {
        final body = req.store.get('Body');
        imageFile = await ServerNs.uploadFile(req, body, partName, '${Generator.generateDateMillWithKey(6)}.jpg');

        if (imageFile == null) {
          return generateResultError(HttpCodes.error_notUpload);
        }
      }
    }

    final courseJs = JsonHelper.jsonToMap(courseJsText);
    final okDb = await CourseModelDb.addCourse(js, courseJs!, imageFile);

    if(okDb == null || !okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not add a course');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> editCourse(HttpRequest req, Map<String, dynamic> js) async {
    final courseJsText = js['course_js'];

    if(courseJsText == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final courseJs = JsonHelper.jsonToMap<String, dynamic>(courseJsText);

    if(!(await CourseModelDb.isDayLittleForEdit(courseJs!))){
      return generateResultError(HttpCodes.error_translateMessage, cause: HttpMessages.addCourse_daysCountCanNot.name);
    }

    final partName = js[Keys.partName];
    var imageFile;

    if(partName != null) {
      if(partName == 'CourseBackground') {
        final body = req.store.get('Body');

        imageFile = await ServerNs.uploadFile(req, body, partName, '${Generator.generateDateMillWithKey(6)}.jpg');

        if (imageFile == null) {
          return generateResultError(HttpCodes.error_notUpload);
        }
      }
    }

    final okDb = await CourseModelDb.editCourse(js, courseJs, imageFile, partName);

    if(okDb == null || !okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not add/Edit a course');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> deleteCourse(HttpRequest req, Map<String, dynamic> js) async {
    final courseId = js['course_id'];

    if(courseId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final hasActiveRequest = await CourseModelDb.hasCourseARequest(courseId);

    if(hasActiveRequest) {
      return generateResultError(HttpCodes.error_operationCannotBePerformed, cause: 'has active request');
    }

    final okDb = await CourseModelDb.deleteCourse(js, courseId);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not delete course $courseId');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> requestACourse(HttpRequest req, Map<String, dynamic> js) async {
    final forUserId = js[Keys.forUserId];
    final courseId = js['course_id'];
    final trainerId = js['trainer_id'];
    final questionJs = js['question_js'];
    final partNames = js['part_names'];

    if(forUserId == null || courseId == null || trainerId == null || questionJs == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final questions = CourseQuestionModel.fromMap(questionJs);
    final body = req.store.get('Body');

    for(final part in partNames){
      final savedFile = await ServerNs.uploadFile(req, body, part);

      if(savedFile == null){
        return generateResultError(HttpCodes.error_notUpload);
      }

      questions.updatePhotoPathUrl(savedFile, part);
    }

    final buyQuestionDb = await CommonMethods.addBuyCourseQuestions(js, forUserId, courseId, questions.toMap());

    if(buyQuestionDb == null || !buyQuestionDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not buy question course $courseId');
    }

    final buyDb = await RequestModelDb.addRequestCourse(forUserId, courseId);

    if(buyDb == null || !buyDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not buy course $courseId');
    }

    final health = HealthConditionModel.fromMap(questionJs);
    final job = JobActivityModel.fromMap(questionJs);

    // ignore: unawaited_futures
    PersonalDataModelDb.upsertUserHealthCondition(forUserId, health);

    // ignore: unawaited_futures
    PersonalDataModelDb.upsertJobActivityByMerge(forUserId, job.toMap());
    // ignore: unawaited_futures
    PersonalDataModelDb.upsertUserSportsEquipment(forUserId, questions.homeToolsDescription, questions.gymToolsDescription);

    // ignore: unawaited_futures
    UserFitnessDataModelDb.upsertUserFitnessStatus(forUserId, NodeNames.height_node, questions.height);

    // ignore: unawaited_futures
    UserFitnessDataModelDb.upsertUserFitnessStatus(forUserId, NodeNames.weight_node, questions.weight);

    // ignore: unawaited_futures
    UserModelDb.changeUserSex(forUserId, questions.sex);

    // ignore: unawaited_futures
    UserModelDb.changeUserBirthDate(forUserId, DateHelper.toTimestamp(questions.birthdate));
    //--------- notify trainer ---------------------------------------------------------
    final requestData = await RequestModelDb.getRequestDataBy(forUserId, courseId);
    final userName = await UserNameModelDb.getUserNameByUserId(forUserId);
    final description = {'user_name': userName, 'course_name': requestData['title'],};

    // ignore: unawaited_futures
    UserNotifierCenter.requestCourse(trainerId, description, requestData);
    //---------| notify trainer ---------------------------------------------------------------

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> setRejectCourseBuy(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final requestId = js[Keys.id];
    final courseId = js['course_id'];
    final cause = js['cause'];
    final requesterUserId = js['requester_user_id'];
    final courseName = js['course_name'];
    final trainerId = js['trainer_id'];

    if(userId == null || courseId == null || cause == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await RequestModelDb.setRejectCourseRequest(js, requestId, cause);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not reject course buy');
    }
    //---- close chat ------------------------------------------------------------
    final conversationId = await ConversationUserModelDb.getConversationIdFor(userId, requesterUserId);

    if(conversationId != null) {
      await ConversationModelDb.closeChat(conversationId);
    }
    //---- to user ---------------------------------------------------------------
    final userName = await UserNameModelDb.getUserNameByUserId(trainerId);
    final description = {'trainer_name': userName, 'course_name': courseName, 'cause': cause};

    // ignore: unawaited_futures
    UserNotifierCenter.rejectRequest(requesterUserId, description);
    //------| to user -------------------------------------------------------------
    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> setAcceptCourseBuy(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final requestId = js[Keys.id];
    final courseId = js['course_id'];
    final days = js['days'];
    final requesterUserId = js['requester_user_id'];
    final courseName = js['course_name'];
    final trainerId = js['trainer_id'];

    if(userId == null || courseId == null || days == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await RequestModelDb.setAcceptCourseRequest(js, requestId, days);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not accept course buy');
    }

    var today = DateHelper.getNowToUtc();
    today = today.add(Duration(days: days));
    final sendDate = DateHelper.toTimestamp(today);


    //---- add chat --------------------------------------------------------------
    final existChat = await ConversationUserModelDb.getConversationIdFor(userId, requesterUserId);

    if(existChat == null) {
      final ch = ConversationModelDb();
      ch.id = await DatabaseNs.getNextSequence(DbNames.Seq_Conversation);
      ch.type = 10;
      ch.creator_user_id = PublicAccess.systemUserId;

      final kv = ch.toMap();
      JsonHelper.removeKeys(kv, ['creation_date']);

      /*final storeChat =*/ await ConversationModelDb.upsertModel(kv);

      /*if(!storeChat){
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not sink a new chat');
      }*/

      final lu1 = ConversationUserModelDb();
      lu1.conversation_id = ch.id;
      lu1.user_id = userId;
      lu1.inviter_user_id = userId;

      await ConversationUserModelDb.upsertModel(lu1);

      final lu2 = ConversationUserModelDb();
      lu2.conversation_id = ch.id;
      lu2.user_id = requesterUserId;
      lu2.inviter_user_id = userId;

      await ConversationUserModelDb.upsertModel(lu2);
    }
    else {
      await ConversationModelDb.openChat(existChat);
    }
    //---- to user ---------------------------------------------------------------
    final userName = await UserNameModelDb.getUserNameByUserId(trainerId);
    final description = {'trainer_name': userName, 'course_name': courseName, 'days': days, 'send_date': sendDate};

    // ignore: unawaited_futures
    UserNotifierCenter.acceptRequest(requesterUserId, description);
    //-------| to user ------------------------------------------------------------
    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> changeCourseBlockState(HttpRequest req, Map<String, dynamic> js) async {
    //final userId = js[Keys.userId];
    final courseId = js['course_id'];
    final state = js[Keys.state];

    if(courseId == null || state == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await CourseModelDb.changeCourseBlockState(js, courseId, state);

    if(okDb == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not add a course');
    }

    final res = generateResultOk();
    return res;
  }
  ///----------------------------------------------------------------------------
  static Future<Map<String, dynamic>> newTicketTextMessage(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final messageData = js['message_data'];
    final ticketData = js['ticket_data'];

    if(userId == null || messageData == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(ticketData != null){
      final tm = TicketModelDb.fromMap(ticketData);
      final existBefore = await TicketModelDb.existTicket(tm);

      if(!existBefore) {
        ticketData['id'] = await DatabaseNs.getNextSequence(DbNames.Seq_ticket);
        final tm = TicketModelDb.fromMap(ticketData);
        final storeTicket = await TicketModelDb.upsertModel(tm);

        if (!storeTicket) {
          return generateResultError(HttpCodes.error_databaseError, cause: 'Not sink a new ticket');
        }

        messageData['ticket_id'] = tm.id;
      }
    }

    final message = await TicketMessageModelDb.storeTicketTextMessage(js, messageData, userId);

    if(message == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not add a ticket message');
    }

    await CommonMethods.updateLastTicketSeen(userId, message['ticket_id'], message['server_receive_ts']);
    //--------------------------------------------------------------------------------
    // send to pear
    /// if user is in Admins: send to starter else send to all managers
    final isManager = await UserModelDb.isManagerUser(userId);
    final List<Map> users = await CommonMethods.getChatUsersByIds([userId]);

    if(isManager){
      // ignore: unawaited_futures
      WsMessenger.sendNewTicketMessageToUser(message, ticketData, null, users[0]);
    }
    else {
      // ignore: unawaited_futures
      WsMessenger.sendNewTicketMessageToAdmins(message, ticketData, null, users[0]);
    }
    //--------------------------------------------------------------------------------
    final res = generateResultOk();
    res[Keys.mirror] = message;
    return res;
  }

  static Future<Map<String, dynamic>> newTicketMediaMessage(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final messageData = js['message_data'];
    final mediaData = js['media_data'];
    final ticketData = js['ticket_data'];
    final partName = js[Keys.partName];
    final screenshotFileName = js['screenshot_file_name'];

    if(userId == null || messageData == null || mediaData == null || partName == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(ticketData != null){
      final tm = TicketModelDb.fromMap(ticketData);
      final existBefore = await TicketModelDb.existTicket(tm);

      if(!existBefore) {
        final tm = TicketModelDb.fromMap(ticketData);
        tm.id = await DatabaseNs.getNextSequence(DbNames.Seq_ticket);

        final storeTicket = await TicketModelDb.upsertModel(tm);

        if(!storeTicket){
          return generateResultError(HttpCodes.error_databaseError, cause: 'Not sink a new ticket [+media]');
        }

        messageData['ticket_id'] = tm.id;
      }
    }

    final body = req.store.get('Body');
    req.store.set(Keys.isChat, true);
    final savedFile = await ServerNs.uploadFile(req, body, partName);
    var screenshotFile;

    if(savedFile == null){
      return generateResultError(HttpCodes.error_notUpload);
    }

    if(screenshotFileName != null) {
      screenshotFile = await ServerNs.uploadFile(req, body, 'screenshot');

      if(screenshotFile == null){
        return generateResultError(HttpCodes.error_notUpload);
      }
    }

    final mediaDb = await TicketMessageModelDb.storeMediaMessage(mediaData, savedFile, screenshotFile);

    if(mediaDb == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not add a media message for ticket');
    }

    final message = await TicketMessageModelDb.storeTicketMediaMessage(js, messageData, mediaDb['id']);

    if(message == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not add a ticket message');
    }

    await CommonMethods.updateLastTicketSeen(userId, message['ticket_id'], message['server_receive_ts']);
    //--------------------------------------------------------------------------------
    // send to pear
    /// if user is in Admins: send to starter else send to all managers
    final isManager = await UserModelDb.isManagerUser(userId);
    final List<Map> users = await CommonMethods.getChatUsersByIds([userId]);

    if(isManager){
      // ignore: unawaited_futures
      WsMessenger.sendNewTicketMessageToUser(message, ticketData, mediaDb, users[0]);
    }
    else {
      // ignore: unawaited_futures
      WsMessenger.sendNewTicketMessageToAdmins(message, ticketData, mediaDb, users[0]);
    }
    //--------------------------------------------------------------------------------
    final res = generateResultOk();
    res[Keys.mirror] = message;
    res['media_mirror'] = mediaDb;

    return res;
  }

  static Future<Map<String, dynamic>> updateLastSeenTicket(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    final ticketId = js['ticket_id'];
    final dateTs = js['date_ts'];

    if(userId == null || ticketId == null || dateTs == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    var okDb = await CommonMethods.updateLastTicketSeen(userId, ticketId, dateTs);

    if(okDb == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update last seen');
    }

    okDb = await CommonMethods.updateTicketMessageSeen(userId, ticketId, dateTs);
    //-------------------------------------------------------------------
    // ignore: unawaited_futures
    WsMessenger.sendSeenTicket(userId, deviceId, ticketId, dateTs);
    //-------------------------------------------------------------------
    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> deleteTicketMessages(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final ticketId = js['ticket_id'];
    final messageId = js['message_id'];

    if(userId == null || ticketId == null || messageId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await CommonMethods.deleteTicketMessage(userId, ticketId, messageId, false);

    if(okDb == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not delete ticket message');
    }

    //-------- send to pear ------------------------------------------------------------------------
    // if user is in Admins: send to starter else send to all managers
    final isManager = await UserModelDb.isManagerUser(userId);

    if(isManager){
      // ignore: unawaited_futures
      WsMessenger.sendDeleteTicketMessageToUser(ticketId, messageId);
    }
    else {
      // ignore: unawaited_futures
      WsMessenger.sendDeleteTicketMessageToAdmins(ticketId, messageId);
    }
    //--------------------------------------------------------------------------------
    final res = generateResultOk();

    return res;
  }

  static Future<Map<String, dynamic>> openChat(HttpRequest req, Map<String, dynamic> js) async {
    final forUserId = js[Keys.forUserId];
    final chatId = js['chat_id'];

    if(forUserId == null || chatId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await ConversationModelDb.openChat(chatId);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not open chat');
    }

    //-------- send to pear ------------------------------------------------------------------------
    // if user is in Admins: send to starter else send to all managers
    /*final isManager = await UserModelDb.isManagerUser(forUserId);

    if(isManager){
      // ignore: unawaited_futures
      WsMessenger.sendDeleteTicketMessageToUser(ticketId, messageId);
    }
    else {
      // ignore: unawaited_futures
      WsMessenger.sendDeleteTicketMessageToAdmins(ticketId, messageId);
    }*/
    //--------------------------------------------------------------------------------
    final res = generateResultOk();
    return res;
  }
  ///----------------------------------------------------------------------------
  static Future<Map<String, dynamic>> newChatTextMessage(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    final messageData = js['message_data'];
    final chatData = js['chat_data'];

    if(userId == null || messageData == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(chatData != null) {
      final cm = ConversationModelDb.fromMap(chatData);
      final existBefore = await ConversationModelDb.existChat(cm);

      if (!existBefore) {
        chatData['id'] = await DatabaseNs.getNextSequence(DbNames.Seq_Conversation);

        final ch = ConversationModelDb.fromMap(chatData);
        final storeChat = await ConversationModelDb.upsertModel(ch.toMap());

        if (!storeChat) {
          return generateResultError(HttpCodes.error_databaseError, cause: 'Not sink a new chat');
        }

        messageData['conversation_id'] = ch.id;

        final lu1 = ConversationUserModelDb();
        lu1.user_id = userId;
        lu1.conversation_id = ch.id;
        lu1.inviter_user_id = 0;

        await ConversationUserModelDb.upsertModel(lu1);

        if (ch.type == 10 /* p2p*/) {
          final lu2 = ConversationUserModelDb();
          lu2.user_id = chatData['receiver_id'];
          lu2.conversation_id = ch.id;
          lu2.inviter_user_id = userId;

          await ConversationUserModelDb.upsertModel(lu2);
        }
      }
    }

    final message = await ConversationMessageModelDb.storeChatTextMessage(js, messageData, userId);

    if(message == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not add a chat message');
    }

    await CommonMethods.updateLastChatSeen(userId, message['conversation_id'], message['server_receive_ts']);
    //----- send to pear -------------------------------------------------------------
    final List<Map> users = await CommonMethods.getChatUsersByIds([userId]);
    // ignore: unawaited_futures
    WsMessenger.sendNewChatMessageToUsers(message, chatData, null, users[0], deviceId);
    //--------------------------------------------------------------------------------
    final res = generateResultOk();
    res[Keys.mirror] = message;
    return res;
  }

  static Future<Map<String, dynamic>> newChatMediaMessage(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    final messageData = js['message_data'];
    final mediaData = js['media_data'];
    final chatData = js['chat_data'];
    final partName = js[Keys.partName];
    final screenshotFileName = js['screenshot_file_name'];

    if(userId == null || messageData == null || mediaData == null || partName == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(chatData != null) {
      final cm = ConversationModelDb.fromMap(chatData);
      final existBefore = await ConversationModelDb.existChat(cm);

      if (!existBefore) {
        final ch = ConversationModelDb.fromMap(chatData);
        ch.id = await DatabaseNs.getNextSequence(DbNames.Seq_Conversation);

        final storeChat = await ConversationModelDb.upsertModel(ch.toMap());

        if (!storeChat) {
          return generateResultError(HttpCodes.error_databaseError, cause: 'Not sink a new chat');
        }

        messageData['conversation_id'] = ch.id;
      }
    }

    final body = req.store.get('Body');
    req.store.set(Keys.isChat, true);
    final savedFile = await ServerNs.uploadFile(req, body, partName);
    var screenshotFile;

    if(savedFile == null){
      return generateResultError(HttpCodes.error_notUpload);
    }

    if(screenshotFileName != null) {
      screenshotFile = await ServerNs.uploadFile(req, body, 'screenshot');

      if(screenshotFile == null){
        return generateResultError(HttpCodes.error_notUpload);
      }
    }

    final mediaDb = await ConversationMessageModelDb.storeMediaMessage(mediaData, savedFile, screenshotFile);

    if(mediaDb == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not add a media message for chat');
    }

    final message = await ConversationMessageModelDb.storeChatMediaMessage(js, messageData, mediaDb['id']);

    if(message == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not add a chat message');
    }

    await CommonMethods.updateLastChatSeen(userId, message['conversation_id'], message['server_receive_ts']);
    //--------send to others > -------------------------------------------------------
    final List<Map> users = await CommonMethods.getChatUsersByIds([userId]);
    // ignore: unawaited_futures
    WsMessenger.sendNewChatMessageToUsers(message, chatData, mediaDb, users[0], deviceId);
    //--------------------------------------------------------------------------------
    final res = generateResultOk();
    res[Keys.mirror] = message;
    res['media_mirror'] = mediaDb;

    return res;
  }

  static Future<Map<String, dynamic>> updateLastSeenChat(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];
    final conversationId = js['conversation_id'];
    final dateTs = js['date_ts'];

    if(userId == null || conversationId == null || dateTs == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    var okDb = await CommonMethods.updateLastChatSeen(userId, conversationId, dateTs);

    if(okDb == null) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not update chat last seen');
    }

    okDb = await CommonMethods.updateChatMessageSeen(userId, conversationId, dateTs);
    //--------send to others > -------------------------------------------------------
    WsMessenger.sendSeenChat(userId, deviceId, conversationId, dateTs);
    //--------------------------------------------------------------------------------
    final res = generateResultOk();
    return res;
  }
  ///----------------------------------------------------------------------------
  static Future<Map<String, dynamic>> deleteUserNotifier(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final notifierId = js[Keys.id];

    if(userId == null || notifierId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await UserNotifierModel.setIsDelete(notifierId, true);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not delete notifier');
    }

    //-------------------------------------------------------------------
    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> setSeenUserNotifier(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final notifierId = js[Keys.id];

    if(userId == null || notifierId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await UserNotifierModel.setIsSeen([notifierId], true);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not set seen notifier');
    }
    //-------------------------------------------------------------------
    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> setSeenUserNotifiers(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final ids = Converter.correctList<int>(js['ids']);

    if(userId == null || ids == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await UserNotifierModel.setIsSeen(ids, true);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError, cause: 'Not set seen notifiers');
    }
    //-------------------------------------------------------------------
    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> setTrainerBio(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final forUserId = js[Keys.forUserId];
    final bio = js[Keys.data];

    if(userId == null || forUserId == null || bio == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await TrainerDataModelDb.upsertBiography(forUserId, bio);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'Not save biography');
    }

    final res = generateResultOk();

    //--------- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(
        section: HttpCodes.sec_userData,
        command: HttpCodes.com_updateProfileSettings);//todo: change command and mirror to app
    match[Keys.userId] = userId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(userId, false);

    // ignore: unawaited_futures
    //WsMessenger.sendToOtherDeviceAvoidMe(userId, deviceId, JsonHelper.mapToJson(match));
    //---------------------------------------------------------------
    return res;
  }

  static Future<Map<String, dynamic>> setTrainerBroadcastCourseState(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    final isBroadcast = js['is_broadcast_course'];

    if(forUserId == null || isBroadcast == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await TrainerDataModelDb.changeCourseBroadcastState(forUserId, isBroadcast);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'Not change course Broadcast state');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> setTrainerState(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    final isExercise = js['is_exercise'];
    final isFood = js['is_food'];

    if(forUserId == null || isExercise == null || isFood == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await TrainerDataModelDb.changeTrainerState(forUserId, isExercise, isFood);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'Not change trainer state');
    }

    final res = generateResultOk();
    return res;
  }

  static Future<Map<String, dynamic>> updateBioPhoto(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    final partName = js[Keys.partName];
    final fileName = js[Keys.fileName];

    if(forUserId == null || partName == null || fileName == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final body = req.store.get('Body');
    final savedFile = await ServerNs.uploadFile(req, body, partName);

    if(savedFile == null){
      return generateResultError(HttpCodes.error_notUpload);
    }

    final okDb = await TrainerDataModelDb.addBioPhoto(forUserId, savedFile.path);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'Not save [bio Image]');
    }

    final uri = PathsNs.genUrlDomainFromLocalPathByDecoding(PublicAccess.domain, PathsNs.getCurrentPath(), savedFile.path)!;

    final res = generateResultOk();
    res[Keys.userId] = forUserId;
    res[Keys.fileUri] = uri;

    //--------- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(
        section: HttpCodes.sec_userData,
        command: HttpCodes.com_updateProfileSettings);//todo: change command and mirror to app
    match[Keys.userId] = forUserId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(forUserId, false);

    // ignore: unawaited_futures
    //WsMessenger.sendToOtherDeviceAvoidMe(userId, deviceId, JsonHelper.mapToJson(match));
    //---------------------------------------------------------------
    return res;
  }

  static Future<Map<String, dynamic>> deleteBioPhoto(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    final imgUri = js[Keys.imageUri];

    if(forUserId == null || imgUri == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await TrainerDataModelDb.deleteBioPhoto(forUserId, imgUri);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'Not delete [bio Image]');
    }

    final res = generateResultOk();
    res[Keys.userId] = forUserId;

    //--------- To other user's devices ------------------------------------
    final match = WsMessenger.generateWsMessage(
        section: HttpCodes.sec_userData,
        command: HttpCodes.com_updateProfileSettings);//todo: change command and mirror to app
    match[Keys.userId] = forUserId;
    match[Keys.data] = await CommonMethods.getUserLoginInfo(forUserId, false);

    // ignore: unawaited_futures
    //WsMessenger.sendToOtherDeviceAvoidMe(userId, deviceId, JsonHelper.mapToJson(match));
    //---------------------------------------------------------------
    return res;
  }

  static Future<Map<String, dynamic>> addUserBankCard(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    final card = js['card'];

    if(forUserId == null || card == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await UserBankCardModelDb.insertModelMap(card);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'can not save bank card');
    }

    final res = generateResultOk();

    //--------- To other user's devices ------------------------------------

    //---------------------------------------------------------------
    return res;
  }

  static Future<Map<String, dynamic>> deleteUserBankCard(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    final card = js['card'];

    if(forUserId == null || card == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final okDb = await UserBankCardModelDb.deleteCardNumber(forUserId, card['card_number']);

    if(!okDb) {
      return generateResultError(HttpCodes.error_databaseError , cause: 'can not delete bank card');
    }

    final res = generateResultOk();

    //--------- To other user's devices ------------------------------------

    //---------------------------------------------------------------
    return res;
  }

  static Future<Map<String, dynamic>> updatePayPhoto(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    final courseId = js['course_id'];
    final photoData = js['photo_data'];
    final partName = js[Keys.partName];

    if(forUserId == null || courseId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    if(partName == 'delete'){
      final okDb = await CommonMethods.deleteCoursePayPhoto(forUserId, courseId);

      if(!okDb) {
        return generateResultError(HttpCodes.error_databaseError , cause: 'can not delete pay photo');
      }
    }
    else {
      final body = req.store.get('Body');
      final savedFile = await ServerNs.uploadFile(req, body, partName, '${Generator.generateDateMillWithKey(6)}.jpg');

      if(savedFile == null){
        return generateResultError(HttpCodes.error_notUpload);
      }

      final pd = PhotoDataModel.fromMap(photoData);
      pd.uri = PathsNs.genUrlDomainFromFilePath(PublicAccess.domain, PathsNs.getCurrentPath(), savedFile.path);

      final okDb = await CommonMethods.updateCoursePayPhoto(forUserId, courseId, pd);

      if(!okDb) {
        return generateResultError(HttpCodes.error_databaseError , cause: 'can not update pay photo');
      }
    }

    final res = generateResultOk();
    return res;
  }

}