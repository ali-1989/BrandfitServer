import 'dart:io';

import 'package:assistance_kit/api/helpers/urlHelper.dart';
import 'package:brandfit_server/app/pathNs.dart';
import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/database/queryList.dart';
import 'package:brandfit_server/database/querySelector.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/commonMethods.dart';
import 'package:brandfit_server/rest_api/queryFiltering.dart';

class TicketMessageModelDb extends DbModel {
  late int id;
  int ticket_id = 0;
  int message_type = 0;
  int sender_user_id = 0;
  String? media_id;
  String? reply_id;
  bool is_deleted = false;
  bool is_edited = false;
  String? user_send_ts;
  String? server_receive_ts;
  String? receive_ts;
  String? seen_ts;
  String? message_text;
  String? cover_data;
  Map? extra_js;

  // message_type: 0 unKnow, 1 file, 2 text, 3 audio, [Q_insert_TypeForMessage]
  // cover_data : can be path or data
  static final String QTbl_TicketMessage = '''
  CREATE TABLE IF NOT EXISTS #tb (
       id numeric(40,0) NOT NULL DEFAULT nextNum('${DbNames.Seq_ticketMessageId}'),
       ticket_id BIGINT NOT NULL,
       media_id numeric(40,0) DEFAULT NULL,
       reply_id numeric(40,0) DEFAULT NULL,
       message_type SMALLINT NOT NULL,
       sender_user_id BIGINT NOT NULL,
       is_deleted BOOLEAN DEFAULT false,
       is_edited BOOLEAN DEFAULT false,
       user_send_ts TIMESTAMP NOT NULL,
       server_receive_ts TIMESTAMP DEFAULT (now() at time zone 'utc'),
       receive_ts TIMESTAMP DEFAULT NULL,
       seen_ts TIMESTAMP DEFAULT NULL,
       message_text VARCHAR(2000) DEFAULT NULL,
       cover_data VARCHAR(300) DEFAULT NULL,
       extra_js JSONB DEFAULT NULL,
       CONSTRAINT pk_#tb PRIMARY KEY (id),
       CONSTRAINT fk1_#tb FOREIGN KEY (message_type) REFERENCES ${DbNames.T_TypeForMessage} (key)
       	ON DELETE NO ACTION ON UPDATE CASCADE,
       CONSTRAINT fk2_#tb FOREIGN KEY (ticket_id) REFERENCES ${DbNames.T_Ticket} (id)
       	ON DELETE NO ACTION ON UPDATE CASCADE
      )
      PARTITION BY RANGE (id);
      '''.replaceAll('#tb', DbNames.T_TicketMessage); // 'ticket_id' mayBe

  static final String QTbl_TicketMessage$p1 = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_TicketMessage}_p1
  PARTITION OF ${DbNames.T_TicketMessage}
  FOR VALUES FROM (0) TO (1000000);''';//1_000_000

  static final String QTbl_TicketMessage$p2 = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_TicketMessage}_p2
  PARTITION OF ${DbNames.T_TicketMessage}
  FOR VALUES FROM (1000000) TO (2000000);''';//2_000_000

  static final String QIdx_TicketMessage$ticket_id = '''
  CREATE INDEX IF NOT EXISTS #tb_ticket_id_idx
  ON #tb USING BTREE (ticket_id);
  '''.replaceAll('#tb', DbNames.T_TicketMessage);

  static final String QIdx_TicketMessage$message_type = '''
  CREATE INDEX IF NOT EXISTS #tb_Message_type_idx
  ON #tb USING BTREE (message_type);
  '''.replaceAll('#tb', DbNames.T_TicketMessage);

  static final String QIdx_TicketMessage$sender_user_id = '''
  CREATE INDEX IF NOT EXISTS TicketMessage_sender_user_id_idx
  ON ${DbNames.T_TicketMessage} USING BTREE (sender_user_id);''';

  static final String QIdx_TicketMessage$send_ts = '''
  CREATE INDEX IF NOT EXISTS TicketMessage_user_send_ts_idx
  ON ${DbNames.T_TicketMessage} USING BTREE (user_send_ts DESC);''';

  static final String QAltUk1_TicketMessage$p1 = '''
  DO \$\$ BEGIN 
      ALTER TABLE ${DbNames.T_TicketMessage}_p1
       ADD CONSTRAINT uk1_${DbNames.T_TicketMessage} UNIQUE (ticket_id, sender_user_id, user_send_ts);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF;
  END \$\$;''';

  @override
  TicketMessageModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    id = map[Keys.id];
    ticket_id = map['ticket_id'];
    message_type = map['message_type'];
    media_id = map['media_id'];
    reply_id = map['reply_id'];
    sender_user_id = map['sender_user_id'];
    is_deleted = map['is_deleted'];
    is_edited = map['is_edited'];
    user_send_ts = map['user_send_ts'];
    receive_ts = map['receive_ts'];
    server_receive_ts = map['server_receive_ts'];
    seen_ts = map['seen_ts'];
    message_text = map['message_text'];
    extra_js = map['extra_js'];
    cover_data = map['cover_data'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.id] = id;
    map['ticket_id'] = ticket_id;
    map['message_type'] = message_type;
    map['sender_user_id'] = sender_user_id;
    map['media_id'] = media_id;
    map['reply_id'] = reply_id;
    map['is_deleted'] = is_deleted;
    map['is_edited'] = is_edited;
    map['user_send_ts'] = user_send_ts;
    map['receive_ts'] = receive_ts;
    map['server_receive_ts'] = server_receive_ts;
    map['seen_ts'] = seen_ts;
    map['message_text'] = message_text;
    map['extra_js'] = extra_js;
    map['cover_data'] = cover_data;

    return map;
  }

  static Future<List<Map<String, dynamic>?>> fetchMap(int senderId) async {
    final q = '''SELECT * FROM 
        ${DbNames.T_TicketMessage} WHERE sender_user_id = $senderId; ''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<bool> upsertModel(TicketMessageModelDb model) async {
    final kv = model.toMap();

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_TicketMessage, kv,
        where: ' id = ${model.id}');

    return cursor != null &&  cursor > 0;
  }
  ///----------------------------------------------------------------------------------------
  static Future<List<int>> getTicketListIds(int starterId) async {
    final q = '''SELECT id FROM 
        ${DbNames.T_TicketMessage} WHERE starter_user_id = $starterId; ''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return [];
    }

    return cursor.map((e) => e.toList()[0] as int).toList();
  }

  static Future getTicketMessagesByIds(Map<String, dynamic> jsOption, int userId, List<int> ticketIds) async {
    if(ticketIds.isEmpty){
      return <Map<String, dynamic>>[];
    }

    final filtering = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};

    qSelector.addQuery(QueryList.ticketMessage_q1(filtering, userId, ticketIds, false));

    var listOrNull = await PublicAccess.psql2.queryCall(qSelector.generate(0, replace));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return listOrNull.map((e) {
      var m = e.toMap();
      return m as Map<String, dynamic>;
    }).toList();
  }

  static Future searchOnTicketMessages(Map<String, dynamic> jsOption) async {
    final ticketId = jsOption['ticket_id'];
    final filtering = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};

    qSelector.addQuery(QueryList.ticketMessage_q2(filtering, ticketId, false));

    replace['LIMIT x'] = 'LIMIT ${filtering.limit}';

    var listOrNull = await PublicAccess.psql2.queryCall(qSelector.generate(0, replace));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return listOrNull.map((e) {
      return e.toMap() as Map<String, dynamic>;
    }).toList();
  }

  static Future storeTicketTextMessage(Map<String, dynamic> jsOption, Map message, int userId) async {
    final ticketId = message['ticket_id'];
    final userSendTs = message['user_send_ts'];
    final userId = message['sender_user_id'];

    final kv = <String, dynamic>{};
    kv['ticket_id'] = ticketId;
    kv['reply_id'] = message['reply_id'];
    kv['message_type'] = message['message_type'];
    kv['sender_user_id'] = userId;
    kv['user_send_ts'] = userSendTs;
    kv['message_text'] = message['message_text'];

    final cursor = await PublicAccess.psql2.insertIgnoreWhere(DbNames.T_TicketMessage,
        kv,
        where: '''
          ticket_id = $ticketId AND 
          sender_user_id = $userId AND 
          user_send_ts = '$userSendTs'::TIMESTAMP ''',
        returning: '*');

    if(cursor is List){
      return cursor.elementAt(0).toMap();
    }

    return null;
  }

  static Future storeMediaMessage(Map media, File mediaFile, File? screenShotFile) async {
    var screenshotJs = media['screenshot_js'];

    if(screenshotJs != null && screenShotFile != null){
      final p = PathsNs.removeBasePathFromLocalPath(PathsNs.getCurrentPath(), screenShotFile.path)!;
      screenshotJs['uri'] = UrlHelper.encodeUrl(p);
    }

    final kv = <String, dynamic>{};
    kv['message_type'] = media['message_type'];
    kv['group_id'] = media['group_id'];
    kv['extension'] = media['extension'];
    kv['name'] = media['name'];
    kv['width'] = media['width'];
    kv['height'] = media['height'];
    kv['volume'] = media['volume'];
    kv['duration'] = media['duration'];
    kv['screenshot_js'] = CommonMethods.castToJsonb(screenshotJs);
    //kv['screenshot_path'] = PathsNs.encodeFilePathForDataBase(screenShotFile?.path);
    kv['extra_js'] = CommonMethods.castToJsonb(media['extra_js']);
    kv['path'] = PathsNs.encodeFilePathForDataBase(mediaFile.path);

    final where = ''' message_type = ${media['message_type']} AND 
             name = '${media['name']}' AND 
             volume = ${media['volume']} ''';

    final cursor = await PublicAccess.psql2.insertIgnoreWhere(DbNames.T_MediaMessageData, kv,
        where: where, returning: '*');

    //final cursor = await PublicAccess.psql2.insertKvReturning(DbNames.T_MediaMessageData, kv, '*');
    if(cursor is int && cursor == 0){
      final q = '''SELECT * FROM ${DbNames.T_MediaMessageData} WHERE  ''' + where;
      final list = await PublicAccess.psql2.queryCall(q);

      if(list is List){
        return list!.elementAt(0).toMap();
      }
    }

    if(cursor is List){
      var m = cursor.elementAt(0).toMap();

      // smpl: reformat map
      return (m as Map).map((key, value) {
        if(key == 'path'){
          return MapEntry('uri', PathsNs.genUrlDomainFromFilePath(PublicAccess.domain, PathsNs.getCurrentPath(), mediaFile.path));
        }

        return MapEntry(key, value);
      });
    }

    return null;
  }

  static Future storeTicketMediaMessage(Map<String, dynamic> jsOption, Map message, String mediaId) async {
    final userSendTs = message['user_send_ts'];
    final ticketId = message['ticket_id'];
    final userId = message['sender_user_id'];
    //var mediaId = message['media_id'];

    final kv = <String, dynamic>{};
    kv['ticket_id'] = ticketId;
    kv['reply_id'] = message['reply_id'];
    kv['message_type'] = message['message_type'];
    kv['sender_user_id'] = userId;
    kv['user_send_ts'] = userSendTs;
    kv['message_text'] = message['message_text'];
    kv['media_id'] = mediaId;
    kv['cover_data'] = message['cover_data'];
    kv['extra_js'] = message['extra_js'];

    final where = ''' ticket_id = $ticketId AND 
             sender_user_id = $userId AND 
             user_send_ts = '$userSendTs'::TIMESTAMP ''';

    final cursor = await PublicAccess.psql2.insertIgnoreWhere(DbNames.T_TicketMessage, kv,
        where: where, returning: '*');

    if(cursor is int && cursor == 0){
      final q = '''SELECT * FROM ${DbNames.T_TicketMessage} WHERE  ''' + where;
      final list = await PublicAccess.psql2.queryCall(q);

      if(list is List){
        return list!.elementAt(0).toMap();
      }
    }

    if(cursor is List){
      return cursor.elementAt(0).toMap();
    }

    return null;
  }

}
