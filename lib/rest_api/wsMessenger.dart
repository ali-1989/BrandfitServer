
import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:brandfit_server/database/models/conversationUser.dart';
import 'package:brandfit_server/database/models/userNotifier.dart';
import 'package:brandfit_server/database/models/users.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/rest_api/commonMethods.dart';
import 'package:brandfit_server/rest_api/httpCodes.dart';
import 'package:brandfit_server/rest_api/wsServerNs.dart';

class WsMessenger {
  WsMessenger._();

  static Map<String, dynamic> generateWsMessage({String section = 'none', String? command, dynamic data,}) {
    final res = <String, dynamic>{};

    // none | UserData | ChatData | TicketData | Command
    res[Keys.section] = section;
    res[Keys.command] = command;
    res[Keys.data] = data;

    return res;
  }
  ///-------------------------------------------------------------------------------------------
  static void logoffUser(int userId, String cause) {
    final sendJs = <String, dynamic>{};
    sendJs[Keys.command] = 'ForceLogOff';
    sendJs[Keys.userId] = userId;
    sendJs[Keys.cause] = cause;

    WsServerNs.sendToUser(userId, JsonHelper.mapToJson(sendJs));
  }

  static Future<void> sendCourseRequestAnswerNotifier(int userId, UserNotifierModel notify) async {
    final ms = WsMessenger.generateWsMessage(
        section: HttpCodes.sec_courseData,
        command: HttpCodes.com_notifyCourseRequestAnswer,
      data: notify.toMap(),
    );

    // ignore: unawaited_futures
    sendToAllUserDevice(userId, JsonHelper.mapToJson(ms));
  }

  static Future<void> sendNewCourseRequestNotifier(int userId, UserNotifierModel notify, Map courseInfo) async {
    final ms = WsMessenger.generateWsMessage(
        section: HttpCodes.sec_courseData,
        command: HttpCodes.com_notifyNewCourseRequest,
      data: notify.toMap(),
    );

    ms['course_data'] = courseInfo;
    // ignore: unawaited_futures
    sendToAllUserDevice(userId, JsonHelper.mapToJson(ms));
  }
  ///------- program > -------------------------------------------------------------------------------------
  static Future<void> sendNewProgramNotifier(int userId, UserNotifierModel notify) async {
    final ms = WsMessenger.generateWsMessage(
      section: HttpCodes.sec_courseData,
      command: HttpCodes.com_notifyNewProgram,
      data: notify.toMap(),
    );

    // ignore: unawaited_futures
    sendToAllUserDevice(userId, JsonHelper.mapToJson(ms));
  }

  ///------- ticket > -------------------------------------------------------------------------------------
  static Future<bool> sendSeenTicket(int senderId, String deviceId, int ticketId, String ts) async {
    final userIds = <int>[];
    // if user is in Admins: send to starter else send to all managers
    final isManager = await UserModelDb.isManagerUser(senderId);

    if (isManager) {
      final u = await CommonMethods.getStarterUserIdFromTicket(ticketId);

      if(u != null) {
        userIds.add(u);
      }
    }
    else {
      userIds.addAll(await UserModelDb.getManagerUsers());
    }

    if(userIds.isEmpty){
      return false;
    }

    final data = {};
    data[Keys.userId] = senderId;
    data['ticket_id'] = ticketId;
    data['seen_ts'] = ts;

    final js = generateWsMessage(section: HttpCodes.sec_ticketData, command: HttpCodes.com_userSeen, data: data);

    for(final id in userIds) {
      js[Keys.userId] = id;
      // ignore: unawaited_futures
      WsServerNs.sendToUserByAvoidDeviceId(id, deviceId, JsonHelper.mapToJson(js));
    }

    return true;
  }

  static Future<bool> sendNewTicketMessageToUser(Map message, Map? ticketData, Map? mediaData, Map? userData) async {
    int ticketId = message['ticket_id'];

    final userId = await CommonMethods.getStarterUserIdFromTicket(ticketId);

    if(userId == null){
      return false;
    }

    final js = generateWsMessage(section: HttpCodes.sec_ticketData, command: HttpCodes.com_newMessage);
    js[Keys.data] = message;
    js['ticket_data'] = ticketData;
    js['media_data'] = mediaData;
    js['user_data'] = userData;
    js[Keys.userId] = userId;

    // ignore: unawaited_futures
    WsServerNs.sendToUser(userId, JsonHelper.mapToJson(js));
    return true;
  }

  static Future<bool> sendNewTicketMessageToAdmins(Map message, Map? ticketData, Map? mediaData, Map? userData) async {
    final listIds = await UserModelDb.getManagerUsers();

    final js = generateWsMessage(section: HttpCodes.sec_ticketData, command: HttpCodes.com_newMessage);
    js[Keys.data] = message;
    js['ticket_data'] = ticketData;
    js['media_data'] = mediaData;
    js['user_data'] = userData;

    for(final i in listIds) {
      js[Keys.userId] = i;
      final jsString = JsonHelper.mapToJson(js);

      // ignore: unawaited_futures
      WsServerNs.sendToUser(i, jsString);
    }

    return true;
  }

  static Future<bool> sendDeleteTicketMessageToUser(int ticketId, String msgId) async {
    final userId = await CommonMethods.getStarterUserIdFromTicket(ticketId);

    if(userId == null){
      return false;
    }

    final js = generateWsMessage(section: HttpCodes.sec_ticketData, command: HttpCodes.com_delMessage);
    js[Keys.data] = {'ticket_id': ticketId, 'message_id': msgId};

    // ignore: unawaited_futures
    WsServerNs.sendToUser(userId, JsonHelper.mapToJson(js));
    return true;
  }

  static Future<bool> sendDeleteTicketMessageToAdmins(int ticketId, String msgId) async {
    final listIds = await UserModelDb.getManagerUsers();

    final js = generateWsMessage(section: HttpCodes.sec_ticketData, command: HttpCodes.com_delMessage);
    js[Keys.data] = {'ticket_id': ticketId, 'message_id': msgId};

    final jsString = JsonHelper.mapToJson(js);

    for(final i in listIds) {
      // ignore: unawaited_futures
      WsServerNs.sendToUser(i, jsString);
    }

    return true;
  }
  ///------- chat > -------------------------------------------------------------------------------------
  static void sendSeenChat(int userId, String deviceId, int conversationId, String dateTs) async {
    final userIds = await ConversationUserModelDb.getUsersInConversation(conversationId);

    if(userIds.isEmpty){
      return;
    }

    final data = {};
    data[Keys.userId] = userId;
    data['conversation_id'] = conversationId;
    data['seen_ts'] = dateTs;

    final js = generateWsMessage(section: HttpCodes.sec_chatData, command: HttpCodes.com_userSeen);
    js[Keys.data] = data;

    for(final id in userIds){
      js[Keys.userId] = id;

      // ignore: unawaited_futures
      WsServerNs.sendToUserByAvoidDeviceId(id, deviceId, JsonHelper.mapToJson(js));
    }
  }

  static Future<bool> sendNewChatMessageToUsers(Map message, Map? chatData, Map? mediaData, Map? userData, String deviceId) async {
    int conversationId = message['conversation_id'];

    final userIds = await ConversationUserModelDb.getUsersInConversation(conversationId);

    if(userIds.isEmpty){
      return false;
    }

    final js = generateWsMessage(section: HttpCodes.sec_chatData, command: HttpCodes.com_newMessage);
    js[Keys.data] = message;
    js['chat_data'] = chatData;
    js['media_data'] = mediaData;
    js['user_data'] = userData;

    for(final id in userIds){
      js[Keys.userId] = id;

      // note: can not test on 1 device,must use 2 device for chat
      await WsServerNs.sendToUserByAvoidDeviceId(id, deviceId, JsonHelper.mapToJson(js));
    }

    return true;
  }

  static void sendDataToOtherUserChats(int userId, String data){
    //todo
  }
  ///-------| chat -------------------------------------------------------------------------------------
  static void sendYouAreBlocked(int userId){
    final js = generateWsMessage(section: HttpCodes.sec_command, command: HttpCodes.com_forceLogOff);
    js[Keys.userId] = userId;

    WsServerNs.sendToUser(userId, JsonHelper.mapToJson(js));
  }
  ///------- send func ---------------------------------------------------------------------------------
  static Future<void> sendToAllUserDevice(int userId, String data){
    return WsServerNs.sendToUser(userId, data);
  }

  static Future<void> sendToOtherDeviceAvoidMe(int userId, String deviceId, String data){
    return WsServerNs.sendToUserByAvoidDeviceId(userId, deviceId, data);
  }
}
