import 'dart:io';

import 'package:assistance_kit/api/helpers/urlHelper.dart';
import 'package:brandfit_server/app/pathNs.dart';
import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/database/queryList.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/commonMethods.dart';

class ConversationMessageModelDb extends DbModel {
  late int id;
  late int conversationId;
  String? mediaId;
  String? replyId;
  String? forwardId;
  int messageType = 1;
  int senderUserId = 0;
  bool is_deleted = false;
  bool is_edited = false;
  String? userSendTs;
  String? serverReceiveTs;
  String? receiveTs;
  String? seenTs;
  String? messageText;
  String? coverData;
  Map? extra_js;

  // status: 0 unKnown, [1 sending], 2 serverReceive, 3 userReceive, 4 seen, 10 error
  // cover_data : can be path or data
  // is_forward BOOLEAN DEFAULT false,
  static final String QTbl_ConversationMessage = '''
  CREATE TABLE IF NOT EXISTS #tb (
       id numeric(40,0) NOT NULL DEFAULT nextNum('${DbNames.Seq_ConversationMessageId}'),
       conversation_id BIGINT NOT NULL,
       media_id numeric(40,0) DEFAULT NULL,
       reply_id numeric(40,0) DEFAULT NULL,
       forward_id numeric(40,0) DEFAULT NULL,
       message_type SMALLINT NOT NULL,
       sender_user_id BIGINT NOT NULL,
       is_deleted BOOLEAN DEFAULT false,
       is_edited BOOLEAN DEFAULT false,
       user_send_ts TIMESTAMP NOT NULL,
       server_receive_ts TIMESTAMP DEFAULT (now() at time zone 'utc'),
       receive_ts TIMESTAMP DEFAULT NULL,
       seen_ts TIMESTAMP DEFAULT NULL,
       message_text VARCHAR(2000) DEFAULT NULL,
       extra_js JSONB DEFAULT NULL,
       cover_data VARCHAR(400) DEFAULT NULL,
       CONSTRAINT pk_#tb PRIMARY KEY (id),
       CONSTRAINT fk1_#tb FOREIGN KEY (message_type) REFERENCES ${DbNames.T_TypeForMessage} (key)
       	ON DELETE NO ACTION ON UPDATE CASCADE,
       CONSTRAINT fk2_#tb FOREIGN KEY (conversation_id) REFERENCES ${DbNames.T_Conversation} (id)
       	ON DELETE NO ACTION ON UPDATE CASCADE
      )
      PARTITION BY RANGE (id);
      '''.replaceAll('#tb', DbNames.T_ConversationMessage);

  static final String QTbl_ConversationMessage$p1 = '''
  CREATE TABLE IF NOT EXISTS #tb_p1
  PARTITION OF #tb
  FOR VALUES FROM (0) TO (1000000);
  '''.replaceAll('#tb', DbNames.T_ConversationMessage);//1_000_000

  static final String QTbl_ConversationMessage$p2 = '''
    CREATE TABLE IF NOT EXISTS #tb_p2
    PARTITION OF #tb
    FOR VALUES FROM (1000000) TO (2000000);
    '''.replaceAll('#tb', DbNames.T_ConversationMessage);//2_000_000

  static final String QAltUk1_ConversationMessage$p1 = '''
  DO \$\$ BEGIN
   ALTER TABLE #tb_p1
       ADD CONSTRAINT uk1_#tb UNIQUE (conversation_id, sender_user_id, user_send_ts);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF;
      END \$\$;
       '''.replaceAll('#tb', DbNames.T_ConversationMessage);

  static final String QIdx_ConversationMessage$message_type = '''
    CREATE INDEX IF NOT EXISTS #tb_message_type_idx
    ON #tb USING BTREE (message_type);
    '''.replaceAll('#tb', DbNames.T_ConversationMessage);

  static final String QIdx_ConversationMessage$sender_user_id = '''
    CREATE INDEX IF NOT EXISTS #tb_sender_user_id_idx
    ON #tb USING BTREE (sender_user_id);
    '''.replaceAll('#tb', DbNames.T_ConversationMessage);

  static final String QIdx_ConversationMessage$send_ts = '''
    CREATE INDEX IF NOT EXISTS #tb_send_TS_idx
    ON #tb USING BTREE (user_send_ts DESC);
    '''.replaceAll('#tb', DbNames.T_ConversationMessage);

static final String fn_fetchTopConversationMessage = '''
    CREATE OR REPLACE FUNCTION fetchTopConversationMessage(ids varchar, limitVal int)
    RETURNS setof conversationmessage
    AS \$\$
    DECLARE
            f1 bigint;
            arr bigint[] = ('{'|| ids ||'}')::bigint[];
    
        BEGIN
            FOREACH f1 IN ARRAY arr
                LOOP
                    return query SELECT * FROM conversationmessage
                    WHERE conversation_id = f1
                    ORDER BY server_receive_ts DESC NULLS LAST
                    LIMIT limitVal;
                END LOOP;
            RETURN;
  END \$\$ LANGUAGE plpgsql;
    '''.replaceAll('#tb', DbNames.T_ConversationMessage);


  @override
  ConversationMessageModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    id = map[Keys.id];
    conversationId = map['conversation_id'];
    senderUserId = map['sender_user_id'];
    messageType = map['message_type'];
    mediaId = map['media_id'];
    replyId = map['reply_id'];
    forwardId = map['forward_id'];
    is_deleted = map['is_deleted'];
    is_edited = map['is_edited'];
    userSendTs = map['user_send_ts'];
    serverReceiveTs = map['server_receive_ts'];
    receiveTs = map['receive_ts'];
    seenTs = map['seen_ts'];
    coverData = map['cover_data'];
    extra_js = map['extra_js'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.id] = id;
    map['conversation_id'] = conversationId;
    map['sender_user_id'] = senderUserId;
    map['message_type'] = messageType;
    map['media_id'] = mediaId;
    map['reply_id'] = replyId;
    map['forward_id'] = forwardId;
    map['is_deleted'] = is_deleted;
    map['is_edited'] = is_edited;
    map['user_send_ts'] = userSendTs;
    map['server_receive_ts'] = serverReceiveTs;
    map['receive_ts'] = receiveTs;
    map['seen_ts'] = seenTs;
    map['cover_data'] = coverData;
    map['extra_js'] = extra_js;

    return map;
  }

  static Future<Map<String, dynamic>?> fetchMap(int id) async {
    final q = '''SELECT * FROM  ${DbNames.T_ConversationMessage} WHERE id = $id; ''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <String, dynamic>{};
    }

    return cursor.first.toMap() as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>?>> fetchMapForSender(int senderId) async {
    final q = '''SELECT * FROM  ${DbNames.T_ConversationMessage} WHERE sender_user_id = $senderId; ''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<bool> upsertModel(ConversationMessageModelDb model) async {
    final kv = model.toMap();

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_ConversationMessage, kv, where: ' id = ${model.id}');

    return cursor != null && cursor > 0;
  }
  ///----------------------------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getChatMessagesByIds( int userId, List<int> Ids) async {
    if(Ids.isEmpty){
      return <Map<String, dynamic>>[];
    }

    var listOrNull = await PublicAccess.psql2.queryCall(QueryList.chatMessage_q1(userId, Ids, false));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return listOrNull.map((e) {
      var m = e.toMap();
      return m as Map<String, dynamic>;
    }).toList();
  }

  static Future storeChatTextMessage(Map<String, dynamic> jsOption, Map message, int userId) async {
    final conversationId = message['conversation_id'];
    final userSendTs = message['user_send_ts'];
    final userId = message['sender_user_id'];

    final kv = <String, dynamic>{};
    kv['conversation_id'] = conversationId;
    kv['reply_id'] = message['reply_id'];
    kv['message_type'] = message['message_type'];
    kv['sender_user_id'] = userId;
    kv['user_send_ts'] = userSendTs;
    kv['message_text'] = message['message_text'];

    final cursor = await PublicAccess.psql2.insertIgnoreWhere(DbNames.T_ConversationMessage, kv,
        where: '''
          conversation_id = $conversationId AND 
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

  static Future storeChatMediaMessage(Map<String, dynamic> jsOption, Map message, String mediaId) async {
    final userSendTs = message['user_send_ts'];
    final conversationId = message['conversation_id'];
    final userId = message['sender_user_id'];

    final kv = <String, dynamic>{};
    kv['conversation_id'] = conversationId;
    kv['reply_id'] = message['reply_id'];
    kv['message_type'] = message['message_type'];
    kv['sender_user_id'] = userId;
    kv['user_send_ts'] = userSendTs;
    kv['message_text'] = message['message_text'];
    kv['media_id'] = mediaId;
    kv['cover_data'] = message['cover_data'];
    kv['extra_js'] = message['extra_js'];

    final where = ''' conversation_id = $conversationId AND 
             sender_user_id = $userId AND 
             user_send_ts = '$userSendTs'::TIMESTAMP ''';

    final cursor = await PublicAccess.psql2.insertIgnoreWhere(DbNames.T_ConversationMessage, kv,
        where: where, returning: '*');

    if(cursor is int && cursor == 0){
      final q = '''SELECT * FROM ${DbNames.T_ConversationMessage} WHERE  ''' + where;
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
