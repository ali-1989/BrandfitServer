import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/publicAccess.dart';

class ConversationUserModelDb extends DbModel {
  late int conversation_id;
  late int user_id;
  int inviter_user_id = 0;
  int user_station = 5;
  String? invite_date;
  String? join_date;
  Map? user_settings;
  List<int> activity_rights = [1, 2];

  // user_station: 1:Manager, 2:Trainer, 3:Assistance, 4:Observer, 5:Normal User, 6:Guest
  // rights: 1:Send message, 2:Edit Own message, 3:Edit Others message, 4:Delete User, 5:Invite User, 6:Change User rights

  // ** if inviter_user_id == 0 means user is creator

  static final String QTbl_UserToConversation = '''
  CREATE TABLE IF NOT EXISTS #tb (
       conversation_id BIGINT NOT NULL,
       user_id BIGINT NOT NULL DEFAULT -1,
       inviter_user_id BIGINT NOT NULL,
       invite_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
       join_date TIMESTAMP DEFAULT NULL,
       user_station SMALLINT DEFAULT 1,
       user_settings JSONB DEFAULT NULL,
       activity_rights INT[] DEFAULT array[1, 2]::INT[],
       CONSTRAINT fk1_#tb FOREIGN KEY (user_id) REFERENCES ${DbNames.T_Users} (user_id)
       	ON DELETE CASCADE ON UPDATE CASCADE,
       CONSTRAINT fk2_#tb FOREIGN KEY (conversation_id) REFERENCES ${DbNames.T_Conversation} (id)
       	ON DELETE CASCADE ON UPDATE CASCADE
      )
      PARTITION BY HASH (conversation_id, user_id);
      '''.replaceAll('#tb', DbNames.T_UserToConversation);

  static final String QTbl_UserToConversation$p1 = '''
      CREATE TABLE IF NOT EXISTS #tb_p1
      PARTITION OF #tb FOR VALUES WITH (MODULUS 5, REMAINDER 0);
      '''.replaceAll('#tb', DbNames.T_UserToConversation);

  static final String QTbl_UserToConversation$p2 = '''
    CREATE TABLE IF NOT EXISTS #tb_p2
    PARTITION OF #tb FOR VALUES WITH (MODULUS 5, REMAINDER 1);
    '''.replaceAll('#tb', DbNames.T_UserToConversation);

  static final String QTbl_UserToConversation$p3 = '''
    CREATE TABLE IF NOT EXISTS #tb_p3
    PARTITION OF #tb FOR VALUES WITH (MODULUS 5, REMAINDER 2);
    '''.replaceAll('#tb', DbNames.T_UserToConversation);

  static final String QTbl_UserToConversation$p4 = '''
    CREATE TABLE IF NOT EXISTS #tb_p4
    PARTITION OF #tb FOR VALUES WITH (MODULUS 5, REMAINDER 3);
    '''.replaceAll('#tb', DbNames.T_UserToConversation);

  static final String QTbl_UserToConversation$p5 = '''
    CREATE TABLE IF NOT EXISTS #tb_p5
    PARTITION OF #tb FOR VALUES WITH (MODULUS 5, REMAINDER 4);
    '''.replaceAll('#tb', DbNames.T_UserToConversation);

  static final String QIdx_UserToConversation$inviterUserId = '''
    CREATE INDEX IF NOT EXISTS #tb_inviter_user_id_idx
    ON #tb USING GIN (inviter_user_id, conversation_id);
    '''.replaceAll('#tb', DbNames.T_UserToConversation);

  static final String QIdx_UserToConversation$joinDate = '''
    CREATE INDEX IF NOT EXISTS #tb_join_date_idx
    ON #tb USING BTREE (join_date DESC);
    '''.replaceAll('#tb', DbNames.T_UserToConversation);

  static final String QAltUk1_UserToConversation$p1 = '''
  DO \$\$ BEGIN
   ALTER TABLE #tb_p1
       ADD CONSTRAINT uk1_#tb UNIQUE (conversation_id, user_id);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF;
       END \$\$;
       '''.replaceAll('#tb', DbNames.T_UserToConversation);

  static final String QAltUk1_UserToConversation$p2 = '''
  DO \$\$ BEGIN
   ALTER TABLE #tb_p2
       ADD CONSTRAINT uk1_#tb UNIQUE (conversation_id, user_id);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF;
      END \$\$;
       '''.replaceAll('#tb', DbNames.T_UserToConversation);

  static final String QAltUk1_UserToConversation$p3 = '''
  DO \$\$ BEGIN
   ALTER TABLE #tb_p3
       ADD CONSTRAINT uk1_#tb UNIQUE (conversation_id, user_id);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF;
      END \$\$;
       '''.replaceAll('#tb', DbNames.T_UserToConversation);

  static final String QAltUk1_UserToConversation$p4 = '''
  DO \$\$ BEGIN
   ALTER TABLE #tb_p4
       ADD CONSTRAINT uk1_#tb UNIQUE (conversation_id, user_id);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF;
      END \$\$;
       '''.replaceAll('#tb', DbNames.T_UserToConversation);

  static final String QAltUk1_UserToConversation$p5 = '''
  DO \$\$ BEGIN 
    ALTER TABLE #tb_p5
       ADD CONSTRAINT uk1_#tb UNIQUE (conversation_id, user_id);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; 
      END \$\$;
       '''.replaceAll('#tb', DbNames.T_UserToConversation);


  ConversationUserModelDb();

  @override
  ConversationUserModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    conversation_id = map['conversation_id'];
    user_id = map['user_id'];
    inviter_user_id = map['inviter_user_id']?? 0;
    invite_date = map['invite_date'];
    join_date = map['join_date'];
    user_station = map['user_station']?? 5;
    user_settings = map['user_settings'];
    activity_rights = map['activity_rights'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map['conversation_id'] = conversation_id;
    map['user_id'] = user_id;
    map['inviter_user_id'] = inviter_user_id;
    map['join_date'] = join_date;
    map['user_station'] = user_station;
    map['user_settings'] = user_settings;
    map['activity_rights'] = activity_rights;

    if(invite_date != null){
      map['invite_date'] = invite_date;
    }

    return map;
  }

  static Future<List<Map<String, dynamic>?>> fetchMap(int starterId) async {
    final q = '''SELECT * FROM 
        ${DbNames.T_UserToConversation} WHERE starter_user_id = $starterId; ''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<bool> upsertModel(ConversationUserModelDb model) async {
    final kv = model.toMap();

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_UserToConversation, kv,
        where: ' conversation_id = ${model.conversation_id} AND user_id = ${model.user_id}');

    return cursor != null && cursor > 0;
  }
  ///----------------------------------------------------------------------------------------
  static Future<bool> existConversationFor(int userId, int another) {
    var q = '''
      SELECT EXISTS (
        SELECT * FROM(
                 SELECT array_agg(user_id) as users, conversation_id FROM usertoconversation
                 GROUP BY conversation_id
                 ) AS T1
    WHERE T1.users @> array[$userId, $another]::bigint[];
    )
    ''';

    return PublicAccess.psql2.existQuery(q);
  }

  static Future<int?> getConversationIdFor(int userId, int another) async {
    var q = '''
      SELECT conversation_id FROM(
                 SELECT array_agg(user_id) as users, conversation_id FROM usertoconversation
                 GROUP BY conversation_id
                 ) AS T1
    WHERE T1.users @> array[$userId, $another]::bigint[];
    ''';

    final listOrNull = await PublicAccess.psql2.queryCall(q);

    if (listOrNull == null || listOrNull.isEmpty) {
      return null;
    }

    return listOrNull[0].toList()[0];
  }

  static Future<List<int>> getUsersInConversation(int conversationId) async {
    var query = '''
      SELECT user_id FROM #tb WHERE conversation_id = #c;
    ''';

    query = query.replaceFirst('#tb', DbNames.T_UserToConversation);
    query = query.replaceFirst('#c', '$conversationId');

    final listOrNull = await PublicAccess.psql2.queryCall(query);

    if (listOrNull == null || listOrNull.isEmpty) {
      return <int>[];
    }

    return listOrNull.map((e) {
      final x = e.toList()[0];
      return (x is int)? x : int.parse(x);
    }).toList();
  }
}
