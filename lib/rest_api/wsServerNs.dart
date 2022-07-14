import 'dart:io';
import 'package:alfred/alfred.dart';
import 'package:assistance_kit/api/checker.dart';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:assistance_kit/api/generator.dart';
import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/api/helpers/textHelper.dart';
import 'package:assistance_kit/extensions.dart';
import 'package:brandfit_server/app/logHelper.dart';
import 'package:brandfit_server/app/versionManager.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/database/models/users.dart';
import 'package:brandfit_server/database/models/userBlockList.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/httpCodes.dart';
import 'package:brandfit_server/rest_api/wsMessenger.dart';
import 'package:postgresql2/postgresql.dart';

class WsServerNs {
  WsServerNs._();

  static int minusOne = -1;
  static String key_AppVersionCode = 'app_version_code';
  static String key_UserId = 'user_id';
  static String key_Heart = 'heart';
  static String key_HowIs = 'how_is';
  static String key_Key = 'key';
  static String key_DeviceId = 'device_id';
  static String key_AppName = 'app_name';
  static String key_MessageKey = 'message_key';
  static String key_LanguageIso = 'language_iso';
  static String key_LastTouch = 'last_touch';
  static String key_IsLogin = 'is_login';
  static String key_NA = 'N/A';
  static String key_WebSocketId = 'websocket_id';
  
  static Alfred prepareWsServer(){
    final wsServer = Alfred();

    wsServer.get('/ws', (req, res) {
      return WebSocketSession(
          onOpen: (ws) {
            PublicAccess.webSockets[ws] = _generateId();
          },

          onClose: (ws) {
            final id = PublicAccess.webSockets.remove(ws);

            if(id != null) {
              onWsClosed(ws, id);
            }
          },

          onMessage: (ws, dynamic data) {
            final wId = PublicAccess.webSockets[ws];

            if(wId != null) {
              messageHandler(ws, wId, data);
            }
            else {
              PublicAccess.logger.logToAll('not found wsId.', type: '****** Ws [onMessage]');
            }
          },

          onError: (ws, dynamic data){
            PublicAccess.logger.logToAll(data, type: '****** Ws [onError]');
          }
      );
    });

    wsServer.onInternalError = (HttpRequest req, HttpResponse res){
      PublicAccess.logger.logToAll('Ws Internal Error: ${req.method}, ${req.uri} ');

      if(req.uri.toString() == '/ws'){
        req.response.close();//can comment this
        return null;
      }

      res.statusCode = 500;
      return {'message': 'WS Internal error, not handled'};
    };

    wsServer.onNotFound = (HttpRequest req, HttpResponse res) {
      PublicAccess.logger.logToAll('Ws Error [NotFound path]: ${req.uri} ');

      res.statusCode = 404;
      return {'message': 'not found'};
    };

    return wsServer;
  }
  ///======================================================================================================
  static void onWsClosed(WebSocket ws, String wsId) async {
    final query = '''SELECT * FROM ${DbNames.T_DeviceConnections} WHERE websocket_id = '$wsId';''';
    final cursor = await PublicAccess.psql2.queryCall(query);

    if (cursor != null && cursor.isNotEmpty) {
      final row = cursor.first.toMap();

      PublicAccess.logInDebug('====== WS Closed for Device(${row[key_DeviceId]}) "${row[key_AppName]}" ..... ($wsId)  [${DateTime.now()}]');
    }
    else {
      PublicAccess.logger.logToAll('====== WS Closed for Not exist device.    SESSION: $wsId  [${DateTime.now()}]');
    }

    updateDeviceWebSocketStateAny(wsId);
    updateUserWebSocketStateAny(wsId);
  }
  ///======================================================================================================
  static void updateDeviceWebSocketState(String appName, String webSocketId) {
    final query = '''UPDATE ${DbNames.T_DeviceConnections} SET websocket_id = NULL
      WHERE app_name = '$appName' AND websocket_id = '$webSocketId';''';
    PublicAccess.psql2.execution(query);
  }

  static void updateDeviceWebSocketStateAny(String webSocketId) {
    final query = '''UPDATE ${DbNames.T_DeviceConnections} SET websocket_id = NULL WHERE websocket_id = '$webSocketId';''';
    PublicAccess.psql2.execution(query);
  }

  static void updateUserWebSocketToNull(int userId, String webSocketId) {
    /// , IsLogin = false   << I think not need this
    final query = '''UPDATE ${DbNames.T_UserConnections} SET websocket_id = NULL 
      WHERE user_id = '$userId' AND websocket_id = '$webSocketId';''';
    PublicAccess.psql2.execution(query);
  }

  static void updateUserWebSocketStateAny(String webSocketId) {
    final query = '''UPDATE ${DbNames.T_UserConnections} SET websocket_id = NULL  WHERE websocket_id = '$webSocketId';''';
    PublicAccess.psql2.execution(query);
  }
  ///======================================================================================================
  static void messageHandler(WebSocket ws, String wsId, dynamic data) {
    final pr = '''> Ws Message: $data | wsId: $wsId,   ${DateTime.now()} ''';
    PublicAccess.logInDebug(pr);

    if (!Checker.isJson(data)) {
      PublicAccess.logInDebug('*** DANGER: WebSocket message not a Json');
      //ws.send('json please......');
      return;
    }

    final js = JsonHelper.jsonToMap<String, dynamic>(data)!;
    final deviceId = js[key_DeviceId];

    if (TextHelper.isEmptyOrNull(deviceId)) {
      PublicAccess.logInDebug('*** DANGER: DeviceId is null. $wsId');
      closeWs(ws);
      return;
    }

    int appVersionCode = js[key_AppVersionCode]?? minusOne;
    List? multiUsers = js['users'];

    if(multiUsers != null && multiUsers.isNotEmpty){
      for(var i=0; i < multiUsers.length; i++){
        final userId = multiUsers.elementAt(i);
        handlerUserData(js, ws, wsId, userId, deviceId, appVersionCode);
      }
    }
    else {
      final userId = js[key_UserId];
      handlerUserData(js, ws, wsId, userId, deviceId, appVersionCode);
    }
  }

  static Future handlerUserData(Map<String, dynamic> js, WebSocket ws, String wsId, int? userId, String deviceId, int appVersionCode) async{
    await updateSessionInfo(ws, wsId, userId, deviceId, js);

    if(userId != null) {
      await checkUserIsBlock(ws, wsId, deviceId, userId);
      checkNewVersion_checkCanContinueByVersion(ws, userId, appVersionCode);
    }

    if (js.containsKey(key_Heart) || js.containsKey(key_HowIs)) {
      if (userId != null) {
        sendUserMessages(ws, userId);
      }

      return;
    }
    //--------------------------------------------------------------------------------------------------
    final key = js[key_Key];

    if (key == null) {
      return;
    }

    if (key.equals('notify_logoff')) {
      final q = '''UPDATE ${DbNames.T_UserConnections} SET is_login = false, last_touch = ${DateHelper.getNowTimestampToUtc()} 
       WHERE user_id = $userId AND device_id ='$deviceId';''';

      await PublicAccess.psql2.execution(q);
    }
    else if (key.equals('crash_list')) {
      LogHelper.logUserCrash(js, deviceId);
    }
    else if (key.equals('device_info')) {
      LogHelper.logUserDeviceInfo(js, deviceId);
    }

    final msgKey = js[key_MessageKey];

    // remove message from Device Database
    if (!TextHelper.isEmptyOrNull(msgKey)) {
      final sendJs = <String, dynamic>{}..[HttpCodes.sec_command] = 'ClientMessageReceived'..[key_MessageKey] = msgKey;
      sendData(ws, JsonHelper.mapToJson(sendJs));
    }
  }
  //------------------------------------------------------------------------------------------------
  static Future updateSessionInfo(WebSocket ws, String wsId, int? userId, String deviceId, Map<String, dynamic> js) async {
    final appName = js[key_AppName];

    final qry = '''SELECT * FROM ${DbNames.T_DeviceConnections}
      WHERE app_name = '$appName' AND device_id = '$deviceId' Limit 1;''';

    final cursor = await PublicAccess.psql2.queryCall(qry);

    if (cursor != null && cursor.isNotEmpty) {
      final hm = <String, dynamic>{};
      hm[key_WebSocketId] = wsId;
      hm[key_LanguageIso] = js[key_LanguageIso] ?? key_NA;
      hm[key_LastTouch] = DateHelper.getNowTimestampToUtc();

      final x = await PublicAccess.psql2.updateKv(DbNames.T_DeviceConnections, hm, " app_name = '$appName' AND device_id = '$deviceId'");

      PublicAccess.logInDebug('-------- Update Device-Session ($deviceId) ..... ($wsId)   updated: $x');
    }
    else {
      final hm = <String, dynamic>{};
      hm[key_DeviceId] = deviceId;
      hm[key_AppName] = appName;
      hm[key_WebSocketId] = wsId;
      hm[key_LanguageIso] = js[key_LanguageIso] ?? key_NA;
      hm[key_LastTouch] = DateHelper.getNowTimestampToUtc();

      final x = await PublicAccess.psql2.insertKv(DbNames.T_DeviceConnections, hm);
      PublicAccess.logInDebug('-------- insert new Device-Session ($deviceId) ..... ($wsId)   inserted: $x');
    }

    if (userId != null && userId > 0) {
      final q = '''SELECT * FROM ${DbNames.T_UserConnections} WHERE user_id = $userId AND device_id = '$deviceId' Limit 1;''';
      final cursor = await PublicAccess.psql2.queryCall(q);

      if (cursor != null && cursor.isNotEmpty) {
        final hm = <String, dynamic>{};
        hm[key_WebSocketId] = wsId;
        hm[key_IsLogin] = true;
        hm[key_LastTouch] = DateHelper.getNowTimestampToUtc();

        final x = await PublicAccess.psql2.updateKv(DbNames.T_UserConnections, hm, "user_id = $userId AND device_id = '$deviceId'");

        PublicAccess.logInDebug('-------- Update User-Session ($userId), Device($deviceId) ..... ($wsId)   updated: $x');
      }
      else {
        final hm = <String, dynamic>{};
        hm[key_UserId] = userId;
        hm[key_DeviceId] = deviceId;
        hm[key_WebSocketId] = wsId;
        hm[key_IsLogin] = true;
        hm[key_LastTouch] = DateHelper.getNowTimestampToUtc();

        final x = await PublicAccess.psql2.insertKv(DbNames.T_UserConnections, hm);

        PublicAccess.logInDebug('-------- insert new User-Session ($userId), Device($deviceId) ..... ($wsId)  inserted: $x');
      }
    }
  }

  static Future checkUserIsBlock(WebSocket ws, String wsId, String deviceId, int userId) async {
    if (userId < 1) {
      return;
    }

    final isBlocked = await UserBlockListModelDb.isBlockedUser(userId);
    final isDeleted = await UserModelDb.isDeletedUser(userId);

    if (isDeleted || isBlocked) {
      final sendJs = <String, dynamic>{};
      sendJs[HttpCodes.sec_command] = HttpCodes.com_forceLogOff;
      sendJs[Keys.cause] = 'blocked';
      sendJs[key_UserId] = userId;

      sendData(ws, JsonHelper.mapToJson(sendJs));
    }
  }

  static void checkNewVersion_checkCanContinueByVersion(WebSocket ws, int userId, int appVersion) async {
    final canWork = await VersionManager.checkCanContinueByVersion_SendNewVersionIfNeed(ws, appVersion, null);

    if (!canWork) {
      WsMessenger.logoffUser(userId, 'DeprecateAppVersion');
    }
  }

  static void sendUserMessages(WebSocket ws, int userId) async{
    final q = '''SELECT * FROM ${DbNames.T_SystemMessageVsUser} WHERE is_send != true AND user_id = $userId;''';
    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor != null && cursor.isNotEmpty) {
      for (var i = 0; i < cursor.length; i++) {
        final row = cursor[i].toMap();
        final id = row['id'];

        final json = <String, dynamic>{};
        json[Keys.command] = 'server_message';
        json['id'] = id;
        json['user_id'] = userId;
        json['message'] = row['message'];
        json['start_time'] = row['start_time'];
        json['expire_time'] = row['expire_time'];
        json['extra_js'] = row['extra_js'];
        json['type'] = row['type'];
        json['must_show_count'] = row['show_count'];

        sendData(ws, JsonHelper.mapToJson(json));

        if (true) {
          final hm = <String, dynamic>{}..['is_send'] = true;
          // ignore: unawaited_futures
          PublicAccess.psql2.updateKv(DbNames.T_SystemMessageVsUser, hm, ' id = $id');
        }
      }
    }
  }
  ///======================================================================================================
  static String _generateId(){
    return Generator.generateDateMillWithKey(26);
  }
  ///======================================================================================================
  static Future closeWs(WebSocket ws){
    return ws.close();
  }

  static WebSocket? getWebSocket(String wsId) {
    final find = PublicAccess.webSockets.entries.firstWhereSafe((element) {
      return element.value == wsId;
    });

    return find?.key;
  }

  static Future<Stream<Row>?> getAllConnectedUsers() async{

    final cursor = await PublicAccess.psql2.queryBigData(
        '''SELECT user_id FROM ${DbNames.T_UserConnections} WHERE websocket_id IS NOT NULL AND is_login = true;''');

    return cursor;
  }

  static Future<Stream<Row>?> getAllConnectedDevice() async{

    final cursor = await PublicAccess.psql2.queryBigData(
        '''SELECT * FROM ${DbNames.T_DeviceConnections} WHERE websocket_id IS NOT NULL;''');

    return cursor;
  }

  static Future<List<WebSocket>> getAllWebSocketsFor(int userId) async {
    final res = <WebSocket>[];

    final cursor = await PublicAccess.psql2.queryCall(
        '''SELECT websocket_id FROM ${DbNames.T_UserConnections} WHERE user_id = $userId AND websocket_id IS NOT NULL;''');

    if (cursor != null && cursor.isNotEmpty) {
      for (var i = 0; i < cursor.length; i++) {
        final row = cursor.elementAt(i).toMap();
        final ws = getWebSocket(row[key_WebSocketId]);

        if(ws != null) {
          res.add(ws);
        }
      }
    }

    return res;
  }

  static Future<List<UserSession>> getAllUserSessionsByUserId(int userId) async{
    final res = <UserSession>[];

    final cursor = await PublicAccess.psql2.queryCall(
        '''SELECT * FROM ${DbNames.T_UserConnections} WHERE user_id = $userId AND websocket_id IS NOT NULL;''');

    if (cursor != null && cursor.isNotEmpty) {
      for (var i = 0; i < cursor.length; i++) {
        final row = cursor.elementAt(i).toMap();
        final us = UserSession();

        us.deviceId = row[key_DeviceId];
        us.userId = row[key_UserId];
        us.webSocketId = row[key_WebSocketId];
        us.lastTouch = row[key_LastTouch];

        res.add(us);
      }
    }

    return res;
  }

  static Future<List<UserSession>> getAllUserSessionsByWsId(String wsId) async{
    final res = <UserSession>[];

    final cursor = await PublicAccess.psql2.queryCall(
        '''SELECT * FROM ${DbNames.T_UserConnections} WHERE websocket_id = '$wsId';''');

    if (cursor != null && cursor.isNotEmpty) {
      for (var i = 0; i < cursor.length; i++) {
        final row = cursor.elementAt(i).toMap();
        final us = UserSession();

        us.deviceId = row[key_DeviceId];
        us.userId = row[key_UserId];
        us.webSocketId = row[key_WebSocketId];
        us.lastTouch = row[key_LastTouch];

        res.add(us);
      }
    }

    return res;
  }

  static Future<List<UserSession>> getAllUserSessionsIfLogin(int userId) async{
    final cursor = await PublicAccess.psql2.queryCall(
        '''SELECT * FROM ${DbNames.T_UserConnections} WHERE user_id = $userId AND websocket_id IS NOT NULL
         AND is_login = true;''');

    final res = <UserSession>[];

    if (cursor != null && cursor.isNotEmpty) {
      for (var i = 0; i < cursor.length; i++) {
        final row = cursor.elementAt(i).toMap();
        final us = UserSession();

        us.userId = userId;
        us.deviceId = row[key_DeviceId];
        us.webSocketId = row[key_WebSocketId];
        us.lastTouch = DateHelper.tsToSystemDate(row[key_LastTouch])!;//DateHelper.toTimestamp()

        res.add(us);
      }
    }

    return res;
  }
  ///-------------------------------------------------------------------------------------------------
  static void sendForAllConnection(String text) async{
    final list = await getAllConnectedDevice();

    if(list == null) {
      return;
    }

    list.listen((Row row) {
      final map = row.toMap();
      final ws = getWebSocket(map[key_WebSocketId]);

      if(ws != null) {
        sendData(ws, text);
      }
    });
  }

  static void sendForAllLoginUsers(String text) async {
    final list = await getAllConnectedUsers();

    if(list == null) {
      return;
    }

    list.listen((Row row) {
      final map = row.toMap();
      final ws = getWebSocket(map[key_WebSocketId]);

      if(ws != null) {
        sendData(ws, text);
      }
    });
  }

  static void sendUtf(WebSocket ws, List<int> data){
    ws.addUtf8Text(data);
  }

  static void sendData(WebSocket ws, String data){
    try{
      ws.send(data);
    }
    catch (e){
      PublicAccess.logInDebug('****** sendData for WebSocket: $e \n Data: $data');
    }
  }

  static Future<void> sendToUser(int userId, String data) async {
    final list = await getAllUserSessionsIfLogin(userId);

    for(final u in list) {
      final ws = getWebSocket(u.webSocketId);

      if(ws == null || _isPastLastTouch(u.lastTouch)) {
        updateUserWebSocketToNull(u.userId, u.webSocketId);

        if(ws != null){
          // ignore: unawaited_futures
          closeWs(ws);
        }

        continue;
      }

      sendData(ws, data);
    }
  }

  static void sendToUserForDeviceId(int userId, String deviceId, String data) async {
    final list = await getAllUserSessionsIfLogin(userId);

    for(final u in list) {
      final ws = getWebSocket(u.webSocketId);

      if(_isPastLastTouch(u.lastTouch) || ws == null) {
        updateUserWebSocketToNull(u.userId, u.webSocketId);

        if(ws != null){
          // ignore: unawaited_futures
          closeWs(ws);
        }

        continue;
      }

      if(u.deviceId != deviceId) {
        continue;
      }

      sendData(ws, data);
    }
  }

  static Future<void> sendToUserByAvoidDeviceId(int userId, String deviceId, String data) async{
    final list = await getAllUserSessionsIfLogin(userId);

    for(final u in list) {
      final ws = getWebSocket(u.webSocketId);

      if(_isPastLastTouch(u.lastTouch) || ws == null) {
        updateUserWebSocketToNull(u.userId, u.webSocketId);

        if(ws != null){
          // ignore: unawaited_futures
          closeWs(ws);
        }

        continue;
      }

      if(u.deviceId == deviceId) {
        continue;
      }

      sendData(ws, data);
    }
  }

  /// means: 10 min is past that device not send Heart data to server
  static bool _isPastLastTouch(DateTime dt, {int minutes = 10}) {
    try {
      var cal = DateTime.fromMillisecondsSinceEpoch(dt.millisecondsSinceEpoch);
      cal = cal.add(Duration(minutes: minutes));

      final utc = DateHelper.localToUtc(DateTime.now());

      return utc.isAfter(cal);
    }
    catch (e){
      return false;
    }
  }

  /*static bool _isPastLastTouchTs(String ts) {
    try {
      final cal = DateHelper.tsStringToSystemDate(ts)!;
      cal.add(Duration(minutes: 8));

      return utc.isAfter(cal);
    }
    catch (e){
      return false;
    }
  }*/
}
///==============================================================================================
class DeviceSession {
  late String deviceId;
  late String appName;
  late String webSocketId;
  late String lastTouch;
}

class UserSession {
  late int userId;
  late String deviceId;
  late String webSocketId;
  late DateTime lastTouch;
}