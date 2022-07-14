import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/database/queryList.dart';
import 'package:brandfit_server/database/querySelector.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/queryFiltering.dart';

class ConversationModelDb extends DbModel {
  late int id;
  int type = 10;
  String? title;
  int creator_user_id = 0;
  int state_key = 4;
  String? creation_date;
  bool is_deleted = false;
  String? logo_path;
  String? description;

  //state_key: 1:IsClosed, 2:All-ReadOnly, 3:Manager-Active, 4:All-Free
  //type: 5:Group, 10: P2P, 14:Channel, 22:Course Group, 30:Course Channel, 40:Course Private,
  static final String QTbl_Conversation = '''
  CREATE TABLE IF NOT EXISTS #tb (
       id BIGINT NOT NULL DEFAULT nextval('${DbNames.Seq_Conversation}'),
       type INT2 NOT NULL DEFAULT 10,
       title varchar(100),
       state_key INT2 NOT NULL DEFAULT 4,
       creator_user_id BIGINT DEFAULT 0,
       creation_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
       is_deleted BOOLEAN DEFAULT false,
       logo_path varchar(400) DEFAULT '',
       description varchar(1000) DEFAULT NULL,
       CONSTRAINT pk_#tb PRIMARY KEY (id),
       CONSTRAINT fk1_#tb FOREIGN KEY (type) REFERENCES ${DbNames.T_TypeForConversation} (key) 
      		ON DELETE RESTRICT ON UPDATE CASCADE,
       CONSTRAINT fk2_#tb FOREIGN KEY (state_key) REFERENCES ${DbNames.T_TypeForConversationState} (key)
      		ON DELETE RESTRICT ON UPDATE CASCADE
      )
      PARTITION BY RANGE (id);
      '''.replaceAll('#tb', DbNames.T_Conversation);

  static final String QTbl_Conversation$p1 = '''
    CREATE TABLE IF NOT EXISTS #tb_p1
    PARTITION OF #tb
    FOR VALUES FROM (0) TO (500000);
    '''.replaceAll('#tb', DbNames.T_Conversation); //500_000

  static final String QTbl_Conversation$p2 = '''
    CREATE TABLE IF NOT EXISTS #tb_p2
    PARTITION OF #tb
    FOR VALUES FROM (500000) TO (1000000);
    '''.replaceAll('#tb', DbNames.T_Conversation); //1_000_000

  static final String QIdx_Conversation$type = '''
  CREATE INDEX IF NOT EXISTS type_idx
      ON ${DbNames.T_Conversation} USING BTREE (type);''';

  static final String QIdx_Conversation$creatorUserId = '''
  CREATE INDEX IF NOT EXISTS creator_user_id_idx
      ON ${DbNames.T_Conversation} USING BTREE (creator_user_id);''';

  static final String QIdx_Conversation$title = '''
  CREATE INDEX IF NOT EXISTS title_idx
      ON ${DbNames.T_Conversation} USING GIN (title);'''; //full search


  static final String QTbl_TypeForConversation = '''
    CREATE TABLE IF NOT EXISTS #tb (
       key SMALLSERIAL,
       caption varchar(40) NOT NULL,
       CONSTRAINT pk_#tb PRIMARY KEY (key),
       CONSTRAINT uk1_#tb UNIQUE (caption)
      );
      '''.replaceAll('#tb', DbNames.T_TypeForConversation);

  static final String QTbl_TypeForConversationState = '''
  CREATE TABLE IF NOT EXISTS #tb (
       key SMALLSERIAL,
       caption varchar(40) NOT NULL,
       CONSTRAINT pk_#tb PRIMARY KEY (key),
       CONSTRAINT uk1_#tb UNIQUE (caption)
      );
      '''.replaceAll('#tb', DbNames.T_TypeForConversationState);

  static final String QTbl_TypeForUserStation = '''
    CREATE TABLE IF NOT EXISTS #tb (
       key SMALLSERIAL,
       caption varchar(40) NOT NULL,
       CONSTRAINT pk_#tb PRIMARY KEY (key),
       CONSTRAINT uk1_#tb UNIQUE (caption)
      );
      '''.replaceAll('#tb', DbNames.T_TypeForUserStation);

  static final String view_conversationsMembers = '''
    CREATE OR REPLACE VIEW conversations_members_view AS
    SELECT conversation_id, array_agg(user_id) as members
     FROM usertoconversation group by conversation_id;
      '''.replaceAll('#tb', DbNames.T_TypeForUserStation);

  ConversationModelDb();

  @override
  ConversationModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    id = map[Keys.id];
    type = map[Keys.type] ?? 10;
    title = map[Keys.title];
    creator_user_id = map['creator_user_id'] ?? 0;
    creation_date = map['creation_date'];
    is_deleted = map['is_deleted'];
    state_key = map['state_key'] ?? 4;
    logo_path = map['logo_path'];
    description = map['description'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.id] = id;
    map[Keys.type] = type;
    map[Keys.title] = title;
    map['creator_user_id'] = creator_user_id;
    map['creation_date'] = creation_date;
    map['is_deleted'] = is_deleted;
    map['state_key'] = state_key;
    map['logo_path'] = logo_path;
    map['description'] = description;

    return map;
  }

  static Future<bool> upsertModel(Map<String, dynamic> model) async {
    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_Conversation, model, where: ' id = ${model['id']}');

    return cursor != null && cursor > 0;
  }

  ///----------------------------------------------------------------------------------------
  static Future<bool> openChat(int conversationId) async {
    final cursor = await PublicAccess.psql2.update(DbNames.T_Conversation, 'state_key = 4', ' id = $conversationId');
    return cursor != null && cursor > 0;
  }

  static Future<bool> closeChat(int conversationId) async {
    final cursor = await PublicAccess.psql2.update(DbNames.T_Conversation, 'state_key = 1', ' id = $conversationId');
    return cursor != null && cursor > 0;
  }

  static Future<List<Map>> searchOnChatsForUser(Map<String, dynamic> jsOption, int userId) async {
    final filtering = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    replace['LIMIT x'] = 'LIMIT ${filtering.limit}';
    var qIndex = 0;

    qSelector.addQuery(QueryList.chat_q1(filtering, userId));
    qSelector.addQuery(QueryList.chat_q2(filtering, userId));

    if (filtering.isSearchFor(SearchKeys.userNameKey)) {
      qIndex = 1;
    }

    var listOrNull = await PublicAccess.psql2.queryCall(qSelector.generate(qIndex, replace));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return listOrNull.map((e) {
      return e.toMap() as Map<String, dynamic>;
    }).toList();
  }

  static Future<List<int>> getChatListIdsByUser(int userId) async {
    final q = '''SELECT conversation_id FROM 
        ${DbNames.T_UserToConversation} WHERE user_id = $userId; ''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return [];
    }

    return cursor.map((e) => e.toList()[0] as int).toList();
  }

  static Future<List<Map>> searchOnChatsForManager(Map<String, dynamic> js) async {
    final filtering = FilterRequest.fromMap(js[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    replace['LIMIT x'] = 'LIMIT ${filtering.limit}';
    var qIndex = 0;


    qSelector.addQuery(QueryList.chat_q3(filtering));

    var listOrNull = await PublicAccess.psql2.queryCall(qSelector.generate(qIndex, replace));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return listOrNull.map((e) {
      return e.toMap() as Map<String, dynamic>;
    }).toList();
  }

  static Future<bool> existChat(ConversationModelDb model) {
    final con = """
      title = '${model.title}'
      AND creator_user_id = ${model.creator_user_id}
      AND creation_date = '${model.creation_date}'
     """;

    return PublicAccess.psql2.exist(DbNames.T_Conversation, con);
  }
}
