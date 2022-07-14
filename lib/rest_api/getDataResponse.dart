import 'dart:async';
import 'package:alfred/alfred.dart';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:brandfit_server/database/models/conversation.dart';
import 'package:brandfit_server/database/models/conversationMessage.dart';
import 'package:brandfit_server/database/models/course.dart';
import 'package:brandfit_server/database/models/request.dart';
import 'package:brandfit_server/database/models/foodMaterial.dart';
import 'package:brandfit_server/database/models/foodProgram.dart';
import 'package:brandfit_server/database/models/ticket.dart';
import 'package:brandfit_server/database/models/ticketMessage.dart';
import 'package:brandfit_server/database/models/trainerData.dart';
import 'package:brandfit_server/database/models/userBlockList.dart';
import 'package:brandfit_server/database/models/userCardBank.dart';
import 'package:brandfit_server/database/models/userConnection.dart';
import 'package:brandfit_server/database/models/userNotifier.dart';
import 'package:brandfit_server/database/models/users.dart';
import 'package:brandfit_server/database/models/userFitnessData.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/adminCommands.dart';
import 'package:brandfit_server/rest_api/commonMethods.dart';
import 'package:brandfit_server/rest_api/httpCodes.dart';


class GetDataResponse {
  GetDataResponse._();

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
    final bJSON = await req.bodyAsJsonMap;

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

      request = bJSON[Keys.subRequest]?? request;
    }
    ///.............................................................................................
    if (request == 'GetUtcTimeStamp') {
      return <String, dynamic>{}..[Keys.value] = DateHelper.getNowTimestampToUtc();
    }

    if (request == 'GetProfileInfo') {
      return getProfileInfo(req, bJSON);
    }

    if (request == 'GetOtherUserProfileInfo') {
      return getOtherUserProfileInfo(req, bJSON);
    }

    if (request == 'GetUserFitnessStatus') {
      return getUserFitnessStatus(req, bJSON);
    }

    if (request == 'GetRegisterUsers') {
      return getRegisterUsers(req, bJSON);
    }

    if (request == 'getTrainerUsers') {
      return getTrainerUsers(req, bJSON);
    }

    if (request == 'GetAdvertisingList') {
      return getAdvertisingList(req, bJSON);
    }

    if (request == 'GetUserAdvertisingList') {
      return getAdvertisingListForUser(req, bJSON);
    }

    if (request == 'CheckNewFoodMaterialName') {
      return checkNewFoodMaterialName(req, bJSON);
    }

    if (request == 'SearchOnFoodMaterial') {
      return searchOnFoodMaterial(req, bJSON);
    }

    if (request == 'SearchOnFoodPrograms') {
      return searchOnFoodPrograms(req, bJSON);
    }

    if (request == 'GetProgramsForRequest') {
      return getProgramsForRequest(req, bJSON);
    }

    if (request == 'GetCourseRequestProgramsForManager') {
      return getCourseRequestProgramsForManager(req, bJSON);
    }

    if (request == 'GetCursesForTrainer') {
      return getCursesForTrainer(req, bJSON);
    }

    if (request == 'GetCourseForManagerUnSet') {
      return getCourseForManagerUnSet(req, bJSON);
    }

    if (request == 'GetCoursesForShop') {
      return getCoursesForShop(req, bJSON);
    }

    if (request == 'SearchTrainerForUser') {
      return getTrainerInfoForSearch(req, bJSON);
    }

    if (request == 'GetRequestedCourses') {
      return getRequestedCourses(req, bJSON);
    }

    if (request == 'GetTicketsForManager') {
      return getTicketsForManager(req, bJSON);
    }

    if (request == 'GetTicketsForUser') {
      return getTicketsForUser(req, bJSON);
    }

    if (request == 'GetOldTicketMessages') {
      return getOldTicketMessages(req, bJSON);
    }

    if (request == 'GetChatsForUser') {
      return getChatsForUser(req, bJSON);
    }

    if (request == 'GetOldChatMessages') {
      return getOldChatMessages(req, bJSON);
    }

    if (request == 'GetTrainerRequests') {
      return getTrainerRequests(req, bJSON);
    }

    if (request == 'GetCourseRequestsForManager') {
      return getCourseRequestsForManager(req, bJSON);
    }

    if (request == 'GetUserCourseBuyInfo') {
      return getUserCourseBuyInfo(req, bJSON);
    }

    if (request == 'GetRequestExtraInfoForTrainer') {
      return getRequestExtraInfoForTrainer(req, bJSON);
    }

    if (request == 'GetCourseRequestInfoForManager') {
      return getCourseRequestInfoForManager(req, bJSON);
    }

    if (request == 'GetPupilRequestsAndProgramsForTrainer') {
      return GetPupilRequestsAndProgramsForTrainer(req, bJSON);
    }

    if (request == 'GetUserNotifiers') {
      return getUserNotifiers(req, bJSON);
    }

    // result can convert to [UserModel/LimitUserModel] in app
    if (request == 'GetUserLimit') {
      return getUserLimitInfo(req, bJSON);
    }

    if (request == 'GetTrainerPupilUsers') {
      return getTrainerPupilUsers(req, bJSON);
    }

    if (request == 'GetTrainerBio') {
      return getTrainerBio(req, bJSON);
    }

    if (request == 'GetChatsForManager') {
      return getChatsForManager(req, bJSON);
    }

    if (request == 'SearchOnPupilTrainer') {
      return searchOnPupilTrainer(req, bJSON);
    }

    if (request == 'UserHasBankCard') {
      return userHasBankCard(req, bJSON);
    }

    if (request == 'GetTrainerInfo') {
      return getTrainerInfo(req, bJSON);
    }

    if (request == 'GetCoursePayInfo') {
      return getCoursePayInfo(req, bJSON);
    }

    return generateResultError(HttpCodes.error_requestNotDefined);
  }
  ///==========================================================================================================
  static Future<Map<String, dynamic>> getProfileInfo(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];

    final res = generateResultOk();
    res.addAll(await CommonMethods.getUserLoginInfo(userId, false));

    return res;
  }

  static Future<Map<String, dynamic>> getOtherUserProfileInfo(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final forUserId = js[Keys.forUserId];

    if(userId == null || forUserId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final res = generateResultOk();
    res[Keys.userData] = await CommonMethods.getUserLoginInfo(forUserId, false);

    return res;
  }

  static Future<Map<String, dynamic>> getUserLimitInfo(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final forUserId = js[Keys.forUserId];

    if(userId == null || forUserId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    Map? user = await CommonMethods.getUserAdvanced(forUserId);

    final res = generateResultOk();
    res[Keys.data] = user;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getTrainerPupilUsers(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];

    if(userId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final users = await CommonMethods.searchOnTrainerPupils(js, userId);
    final limitUsers = <Map>[];

    for(final k in users){
      final uId = k['user_id'];

      final r = await CommonMethods.getUserAdvanced$fitnessStatus(uId);
      r['answer_date'] = k['answer_date'];
      limitUsers.add(r);
    }

    final res = generateResultOk();
    res[Keys.resultList] = limitUsers;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getUserFitnessStatus(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final forUserId = js[Keys.forUserId];

    final res = generateResultOk();
    res.addAll(await UserFitnessDataModelDb.getUserFitnessStatusJs(forUserId?? userId));

    return res;
  }

  static Future<Map<String, dynamic>> getRegisterUsers(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final res = generateResultOk();
    res[Keys.resultList] = await CommonMethods.searchOnUsers(js);
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  //@ admin
  static Future<Map<String, dynamic>> getTrainerUsers(HttpRequest req, Map<String, dynamic> js) async{
    //final userId = js[Keys.userId];
    final res = generateResultOk();
    res[Keys.resultList] = await CommonMethods.searchOnTrainerUsers(js);
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getAdvertisingList(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];

    final isManager = await UserModelDb.isManagerUser(userId);

    if(!isManager){
      return generateResultError(HttpCodes.error_canNotAccess);
    }

    final res = generateResultOk();
    res[Keys.resultList] = await CommonMethods.getAdvertisingList(js);
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getAdvertisingListForUser(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];

    if(userId == null || deviceId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final res = generateResultOk();
    res[Keys.resultList] = await CommonMethods.getAdvertisingListForUser();
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  //@ ~admin
  static Future<Map<String, dynamic>> checkNewFoodMaterialName(HttpRequest req, Map<String, dynamic> js) async{
    String? name = js[Keys.name];

    if(name == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final exist = await FoodMaterialModelDb.existFoodMaterialName(js, name.trim());

    if(exist) {
      return generateResultError(HttpCodes.error_existThis);
    }
    else {
      return generateResultOk();
    }
  }

  static Future<Map<String, dynamic>> searchOnFoodMaterial(HttpRequest req, Map<String, dynamic> js) async{
    //final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];

    if(deviceId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final res = generateResultOk();
    res[Keys.resultList] = await FoodMaterialModelDb.searchOnFoodMaterial(js);
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> searchOnFoodPrograms(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];

    if(userId == null || deviceId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    List<Map> foods = await FoodProgramModelDb.searchOnFoodPrograms(js, userId);
    final materialsIds = <int>{};

    for(final row in foods){
      List mealList = row['meals_js'];

      for(final m in mealList) {
        List mats = m['materials'];
        for(final k in mats) {
          final id = k['material_id'];

          if (id is int) {
            materialsIds.add(id);
          }
        }
      }
    }

    final res = generateResultOk();
    res[Keys.resultList] = foods;
    res['material_list'] = await FoodMaterialModelDb.getFoodMaterialsByIds(materialsIds);
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getProgramsForRequest(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    final requestId = js['request_id'];

    if(forUserId == null || requestId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final h3 = await FoodProgramModelDb.getRequestPrograms(requestId, false);

    final materialsInfo = await FoodMaterialModelDb.getFoodMaterialsByIds(h3.materialIds);
    final programsInfo = h3.programs;

    final res = generateResultOk();
    res['program_list'] = programsInfo;
    res['material_list'] = materialsInfo;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getCourseRequestProgramsForManager(HttpRequest req, Map<String, dynamic> js) async{
    final requesterId = js[Keys.requesterId];
    final courseId = js['course_id'];
    final requestId = js['request_id'];

    if(requesterId == null || courseId == null || requestId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final h3 = await FoodProgramModelDb.getRequestPrograms(requestId, false);

    final materialsInfo = await FoodMaterialModelDb.getFoodMaterialsByIds(h3.materialIds);
    final programsInfo = h3.programs;

    final res = generateResultOk();
    res['program_list'] = programsInfo;
    res['material_list'] = materialsInfo;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getCursesForTrainer(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    final deviceId = js[Keys.deviceId];

    if(forUserId == null || deviceId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    List<Map> foods = await CourseModelDb.searchOnCurses(js, forUserId);

    final res = generateResultOk();
    res[Keys.resultList] = foods;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getCourseForManagerUnSet(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];

    if(userId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    List<Map> foods = await CourseModelDb.searchOnCursesWithoutSet(js, userId);

    final res = generateResultOk();
    res[Keys.resultList] = foods;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getCoursesForShop(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];

    if(forUserId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    List<Map> foods = await CourseModelDb.searchOnCursesForShop(js, forUserId);

    final res = generateResultOk();
    res[Keys.resultList] = foods;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getRequestedCourses(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];

    if(forUserId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    List<Map> list = await RequestModelDb.searchOnRequestedCurses(js, forUserId);

    final res = generateResultOk();
    res[Keys.resultList] = list;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getTrainerInfoForSearch(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];

    if(forUserId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    List<Map> trainers = await CommonMethods.searchOnTrainerUserForSearch(js);

    final res = generateResultOk();
    res[Keys.resultList] = trainers;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  ///--------- Ticket > -------------------------------------------------------------------
  static Future<Map<String, dynamic>> getTicketsForManager(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];

    if(userId == null || deviceId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    List<Map> tickets = await TicketModelDb.searchOnTicketForManager(js, userId);

    final ticketIds = <int>{};
    final mediaIds = [];
    final userIds = [];

    for(final t in tickets){
      ticketIds.add(t[Keys.id]);
    }

    List<Map> messages = await TicketMessageModelDb.getTicketMessagesByIds(js, userId, ticketIds.toList());

    for(final t in messages){
      final mi = t['media_id'];
      final sender = t['sender_user_id'];

      if(mi != null) {
        mediaIds.add(mi);
      }

      if(!userIds.contains(sender)) {
        userIds.add(sender);
      }
    }

    if(!userIds.contains(userId)) {
      userIds.add(userId);
    }

    List<Map> medias = await CommonMethods.getMediasByIds(userId, mediaIds);

    List<Map> users = await CommonMethods.getChatUsersByIds(userIds);

    final res = generateResultOk();
    res['ticket_list'] = tickets;
    res['message_list'] = messages;
    res['media_list'] = medias;
    res['user_list'] = users;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getTicketsForUser(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];

    if(userId == null || deviceId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    List<Map> tickets1 = await TicketModelDb.searchOnTicketForUser(js, userId);

    final ticketIds = <int>{};
    final mediaIds = [];
    final userIds = [];

    for(final t in tickets1){
      ticketIds.add(t[Keys.id]);
    }

    List<Map> messages = await TicketMessageModelDb.getTicketMessagesByIds(js, userId, ticketIds.toList());

    for(final t in messages){
      final mi = t['media_id'];

      if(mi != null) {
        mediaIds.add(mi);
      }

      final ui = t['sender_user_id'];

      if(!userIds.contains(ui)) {
        userIds.add(ui);
      }
    }

    if(!userIds.contains(userId)) {
      userIds.add(userId);
    }

    List<Map> medias = await CommonMethods.getMediasByIds(userId, mediaIds);
    List<Map> users = await CommonMethods.getChatUsersByIds(userIds);

    final res = generateResultOk();
    res['ticket_list'] = tickets1;
    res['message_list'] = messages;
    res['media_list'] = medias;
    res['user_list'] = users;
    res['all_ticket_ids'] = await TicketModelDb.getTicketListIds(userId);
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getOldTicketMessages(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];

    if(userId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    List<Map> messages = await TicketMessageModelDb.searchOnTicketMessages(js);

    final mediaIds = [];
    final userIds = [];

    for(final t in messages){
      final mi = t['media_id'];

      if(mi != null) {
        mediaIds.add(mi);
      }

      final ui = t['sender_user_id'];

      if(!userIds.contains(ui)) {
        userIds.add(ui);
      }
    }

    List<Map> medias = await CommonMethods.getMediasByIds(userId, mediaIds);

    List<Map> users = await CommonMethods.getChatUsersByIds(userIds);

    final res = generateResultOk();
    res['message_list'] = messages;
    res['media_list'] = medias;
    res['user_list'] = users;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }
  ///------- Ticket <  Chat > -------------------------------------------------------------
  static Future<Map<String, dynamic>> getChatsForUser(HttpRequest req, Map<String, dynamic> js) async {
    final userId = js[Keys.userId];
    final deviceId = js[Keys.deviceId];

    if(userId == null || deviceId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final chats = await ConversationModelDb.searchOnChatsForUser(js, userId);

    final chatIds = <int>{};
    final mediaIds = [];
    final userIds = [];

    for(final t in chats){
      chatIds.add(t[Keys.id]);

      final ui = t['receiver_id'];

      if(!userIds.contains(ui)) {
        userIds.add(ui);
      }
    }

    final messages = await ConversationMessageModelDb.getChatMessagesByIds(userId, chatIds.toList());

    for(final t in messages){
      final mi = t['media_id'];

      if(mi != null) {
        mediaIds.add(mi);
      }

      final ui = t['sender_user_id'];

      if(!userIds.contains(ui)) {
        userIds.add(ui);
      }
    }

    if(!userIds.contains(userId)) {
      userIds.add(userId);
    }

    List<Map> medias = await CommonMethods.getMediasByIds(userId, mediaIds);
    List<Map> users = await CommonMethods.getChatUsersByIds(userIds);

    final res = generateResultOk();
    res['chat_list'] = chats;
    res['message_list'] = messages;
    res['media_list'] = medias;
    res['user_list'] = users;
    res['all_chat_ids'] = await ConversationModelDb.getChatListIdsByUser(userId);
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getOldChatMessages(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];

    if(userId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    List<Map> messages = await TicketMessageModelDb.searchOnTicketMessages(js);

    final mediaIds = [];
    final userIds = [];

    for(final t in messages){
      final mi = t['media_id'];

      if(mi != null) {
        mediaIds.add(mi);
      }

      final ui = t['sender_user_id'];

      if(!userIds.contains(ui)) {
        userIds.add(ui);
      }
    }

    List<Map> medias = await CommonMethods.getMediasByIds(userId, mediaIds);

    List<Map> users = await CommonMethods.getChatUsersByIds(userIds);

    final res = generateResultOk();
    res['message_list'] = messages;
    res['media_list'] = medias;
    res['user_list'] = users;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }
  ///---------| Chat  ---------------------------------------------------------------------
  static Future<Map<String, dynamic>> getTrainerRequests(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];

    if(forUserId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    List<Map> courses = await RequestModelDb.searchOnTrainerRequest(js, forUserId);

    final ids = <int>{};
    final limitUsers = <Map>[];

    for(final m in courses){
      ids.add(m['requester_user_id']);
    }

    for(final id in ids){
      limitUsers.add(await CommonMethods.getUserAdvanced(id));
    }

    final res = generateResultOk();
    res[Keys.resultList] = courses;
    res['advance_users'] = limitUsers;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getCourseRequestsForManager(HttpRequest req, Map<String, dynamic> js) async{
    final requesterId = js[Keys.requesterId];

    if(requesterId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    List<Map> courses = await RequestModelDb.searchOnCourseRequests(js, requesterId);

    final ids = <int>{};
    final limitUsers = <Map>[];

    for(final m in courses){
      ids.add(m['requester_user_id']);
    }

    for(final m in courses){
      ids.add(m['creator_user_id']);
    }

    for(final id in ids){
      limitUsers.add(await CommonMethods.getUserAdvanced(id));
    }

    final res = generateResultOk();
    res[Keys.resultList] = courses;
    res['advance_users'] = limitUsers;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getUserCourseBuyInfo(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    final courseId = js['course_id'];

    if(forUserId == null || courseId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    Map bodyInfo = await CommonMethods.getUserAdvanced(forUserId);

    final res = generateResultOk();
    res[Keys.data] = bodyInfo;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getRequestExtraInfoForTrainer(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    final courseId = js['course_id'];
    final requestId = js['request_id'];
    final requesterId = js['user_requester_id'];
    final withPrograms = js['with_programs']?? false;

    if(forUserId == null || courseId == null || requesterId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    Map? pupilData = await CommonMethods.getUserAdvanced$course(requesterId);
    Map? questionsInfo = await CommonMethods.getCourseQuestions(courseId, requesterId);
    List<Map>? programsInfo;
    List<Map>? materialsInfo;

    if(withPrograms) {
      final h3 = await FoodProgramModelDb.getRequestPrograms(requestId, true);
      materialsInfo = await FoodMaterialModelDb.getFoodMaterialsByIds(h3.materialIds);

      programsInfo = h3.programs;
    }

    final res = generateResultOk();
    res[Keys.userData] = pupilData;
    res['questions_data'] = questionsInfo;
    res['programs_data'] = programsInfo;
    res['material_data'] = materialsInfo;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getCourseRequestInfoForManager(HttpRequest req, Map<String, dynamic> js) async{
    final requesterId = js[Keys.requesterId];
    final courseId = js['course_id'];
    final cRequesterId = js['course_requester_id'];
    final creatorId = js['course_creator_id'];

    if(requesterId == null || courseId == null || cRequesterId == null || creatorId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    Map? userData = await CommonMethods.getUserAdvanced$course(cRequesterId);
    Map? trainerData = await CommonMethods.getUserAdvanced$course(creatorId);
    Map? questionsInfo = await CommonMethods.getCourseQuestions(courseId, cRequesterId);

    final res = generateResultOk();
    res[Keys.userData] = userData;
    res['trainer_profile_data'] = trainerData;
    res['questions_data'] = questionsInfo;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> GetPupilRequestsAndProgramsForTrainer(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    final pupilId = js['pupil_id'];

    if(forUserId == null || pupilId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final requestList = await RequestModelDb.getPupilRequestByTrainer(pupilId, forUserId);
    final programsInfo = <Map<String, dynamic>>[];
    final materialsInfo = <Map<String, dynamic>>[];

    for(final co in requestList){
      final h3 = await FoodProgramModelDb.getRequestPrograms(co['id'], false);
      materialsInfo.addAll(await FoodMaterialModelDb.getFoodMaterialsByIds(h3.materialIds));

      programsInfo.addAll(h3.programs);
    }

    final res = generateResultOk();
    res['request_list'] = requestList;
    res['program_list'] = programsInfo;
    res['material_list'] = materialsInfo;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getUserNotifiers(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];

    if(userId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    List<Map>? notifiers = await UserNotifierModel.searchOnUserNotifiers(js, userId);

    final res = generateResultOk();
    res[Keys.resultList] = notifiers;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getTrainerBio(HttpRequest req, Map<String, dynamic> js) async{
    final userId = js[Keys.userId];
    final forUserId = js[Keys.forUserId];

    if(userId == null || forUserId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    String? bio = await TrainerDataModelDb.getBiography(forUserId);
    List photos = await TrainerDataModelDb.getBioPhotos(forUserId);

    final res = generateResultOk();
    res['bio'] = bio;
    res['photos'] = photos;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getChatsForManager(HttpRequest req, Map<String, dynamic> js) async{
    /*if(userId == null || forUserId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }*/

    List chats = await ConversationModelDb.searchOnChatsForManager(js);

    final chatIds = <int>{};
    final mediaIds = [];
    final userIds = [];

    for(final t in chats){
      chatIds.add(t[Keys.id]);

      final members = t['members'];

      for(final m in members) {
        if (!userIds.contains(m)) {
          userIds.add(m);
        }
      }
    }

    final messages = await ConversationMessageModelDb.getChatMessagesByIds(0/*userId*/, chatIds.toList());

    for(final t in messages){
      final mi = t['media_id'];

      if(mi != null) {
        mediaIds.add(mi);
      }

      final ui = t['sender_user_id'];

      if(!userIds.contains(ui)) {
        userIds.add(ui);
      }
    }

    List<Map> medias = await CommonMethods.getMediasByIds(0/*userId*/, mediaIds);
    List<Map> users = await CommonMethods.getChatUsersByIds(userIds);

    final res = generateResultOk();
    res['chat_list'] = chats;
    res['message_list'] = messages;
    res['media_list'] = medias;
    res['user_list'] = users;
    //res['all_chat_ids'] = await ConversationModelDb.getChatListIdsByUser(userId);
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> searchOnPupilTrainer(HttpRequest req, Map<String, dynamic> js) async{
    /*if(userId == null || forUserId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }*/

    List advancedUsers = await UserModelDb.searchOnPupilTrainer(js);

    final res = generateResultOk();
    res[Keys.resultList] = advancedUsers;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> userHasBankCard(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];

    if(forUserId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    final res = generateResultOk();
    res[Keys.data] = (await UserBankCardModelDb.getUserMainCardNumber(forUserId)) != null;

    return res;
  }

  static Future<Map<String, dynamic>> getTrainerInfo(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];

    if(forUserId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    String? bio = await TrainerDataModelDb.getBiography(forUserId);
    List photos = await TrainerDataModelDb.getBioPhotos(forUserId);
    final model = await CommonMethods.getUserAdvanced(forUserId);
    final card = (await UserBankCardModelDb.getUserMainCardNumber(forUserId))?.card_number;

    final res = generateResultOk();
    res['bio'] = bio;
    res['photos'] = photos;
    res['card_number'] = card;
    res['trainer_data'] = model;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

  static Future<Map<String, dynamic>> getCoursePayInfo(HttpRequest req, Map<String, dynamic> js) async{
    final forUserId = js[Keys.forUserId];
    final courseId = js['course_id'];

    if(forUserId == null || courseId == null) {
      return generateResultError(HttpCodes.error_parametersNotCorrect);
    }

    Map? card = await CommonMethods.getCoursePayInfo(forUserId, courseId);

    final res = generateResultOk();
    res['card_photo_js'] = card;
    res[Keys.domain] = PublicAccess.domain;

    return res;
  }

}