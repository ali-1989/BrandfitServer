import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/database/queryList.dart';
import 'package:brandfit_server/database/querySelector.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/queryFiltering.dart';

class TicketModelDb extends DbModel {
  late int id;
  int type = 0;
  int starter_user_id = 0;
  late String title;
  String? start_date;
  bool is_deleted = false;
  bool is_close = false;

  //type: 0: general
  static final String QTbl_Ticket = '''
  CREATE TABLE IF NOT EXISTS #tb (
       id BIGINT NOT NULL DEFAULT nextval('${DbNames.Seq_ticket}'),
       type INT2 NOT NULL DEFAULT 0,
       title varchar(100) NOT NULL,
       starter_user_id BIGINT NOT NULL,
       start_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
       is_deleted BOOLEAN DEFAULT false,
       is_close BOOLEAN DEFAULT false,
       CONSTRAINT pk_#tb PRIMARY KEY (id)
      )
      PARTITION BY RANGE (id);
      '''.replaceAll('#tb', DbNames.T_Ticket);

  static final String QTbl_Ticket$p1 = '''
  CREATE TABLE IF NOT EXISTS #tb_p1
  PARTITION OF #tb
  FOR VALUES FROM (0) TO (500000);
  '''.replaceAll('#tb', DbNames.T_Ticket); //500_000

  static final String QTbl_Ticket$p2 = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_Ticket}_p2
  PARTITION OF ${DbNames.T_Ticket}
  FOR VALUES FROM (500000) TO (1000000);''';//1_000_000

  static final String QIdx_Ticket$type = '''
  CREATE INDEX IF NOT EXISTS #tb_type_idx
      ON #tb USING BTREE (type);
      '''.replaceAll('#tb', DbNames.T_Ticket);

  static final String QIdx_Ticket$starter_user_id = '''
  CREATE INDEX IF NOT EXISTS ticket_starter_user_id_idx
      ON ${DbNames.T_Ticket} USING BTREE (starter_user_id);''';

  static final String view_ticketsForManager1 = '''
  CREATE OR REPLACE VIEW ticketsForManager1 AS
  With c1 AS
         (SELECT id, title, start_date, starter_user_id, type,
                 is_close, is_deleted
          FROM ticket
          ORDER BY start_date DESC NULLS LAST
         ),
     c2 AS
         (SELECT DISTINCT ON(t2.ticket_id) t1.*, t2.id as message_id, t2.ticket_id,
            t2.server_receive_ts, t2.user_send_ts
          FROM C1 AS t1 LEFT JOIN ticketmessage AS t2
                   ON t1.id = t2.ticket_id
          WHERE t2.is_deleted = false
          ORDER BY t2.ticket_id, t2.server_receive_ts DESC
         )

  SELECT * FROM c2;
      ''';

  /*
  ,
    c3 AS
         (SELECT t1.*, t2.last_message_ts, t2.user_id
          FROM C2 AS t1 LEFT JOIN seenticketmessage AS t2
            ON t1.ticket_id = t2.ticket_id
         )
   */

  static final String view_ticketsForManager2 = '''
  CREATE OR REPLACE VIEW ticketsForManager2 AS
  With c1 AS
         (SELECT id, title, start_date, starter_user_id, type,
                 is_close, is_deleted
          FROM ticket
          ORDER BY start_date DESC NULLS LAST
         ),
     c2 AS
         (SELECT t1.*, t2.user_name
          FROM C1 AS t1 JOIN usernameid AS t2
                                  ON t1.starter_user_id = t2.user_id
         ),
     C3 AS
         (SELECT DISTINCT ON(t2.ticket_id) t1.*, t2.id as message_id, t2.ticket_id,
                                           t2.server_receive_ts, t2.user_send_ts
          FROM C2 AS t1 LEFT JOIN ticketmessage AS t2
                                  ON t1.id = t2.ticket_id
          WHERE t2.is_deleted = false
          ORDER BY t2.ticket_id, t2.server_receive_ts DESC
         )

  SELECT * FROM C3;
      ''';

  @override
  TicketModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    id = map[Keys.id];
    starter_user_id = map['starter_user_id'];
    type = map[Keys.type];
    title = map[Keys.title];
    start_date = map['start_date'];
    is_deleted = map['is_deleted'];
    is_close = map['is_close'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.id] = id;
    map[Keys.type] = type;
    map[Keys.title] = title;
    map['starter_user_id'] = starter_user_id;
    map['start_date'] = start_date;
    map['is_deleted'] = is_deleted;
    map['is_close'] = is_close;

    return map;
  }

  static Future<List<Map<String, dynamic>?>> fetchMap(int starterId) async {
    final q = '''SELECT * FROM 
        ${DbNames.T_Ticket} WHERE starter_user_id = $starterId; ''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<bool> upsertModel(TicketModelDb model) async {
    final kv = model.toMap();

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_Ticket, kv, where: ' id = ${model.id}');

    return cursor != null && cursor > 0;
  }

  static Future<bool> existTicket(TicketModelDb model) {
    final con = """
      title = '${model.title}'
      AND starter_user_id = ${model.starter_user_id}
      AND start_date = '${model.start_date}'
     """;

    return PublicAccess.psql2.exist(DbNames.T_Ticket, con);
  }
  ///----------------------------------------------------------------------------------------
  static Future<List<int>> getTicketListIds(int starterId) async {
    final q = '''SELECT id FROM 
        ${DbNames.T_Ticket} WHERE starter_user_id = $starterId; ''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return [];
    }

    return cursor.map((e) => e.toList()[0] as int).toList();
  }

  static Future searchOnTicketForManager(Map<String, dynamic> jsOption, int userId) async {
    final filtering = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    var qIndex = 0;

    qSelector.addQuery(QueryList.ticket_q2(filtering, userId));
    qSelector.addQuery(QueryList.ticket_q3(filtering, userId));

    replace['LIMIT x'] = 'LIMIT ${filtering.limit}';

    if(filtering.isSearchFor(SearchKeys.userNameKey)){
      qIndex = 1;
    }

    final listOrNull = await PublicAccess.psql2.queryCall(qSelector.generate(qIndex, replace));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return listOrNull.map((e) {
      return e.toMap() as Map<String, dynamic>;
    }).toList();
  }

  static Future searchOnTicketForUser(Map<String, dynamic> jsOption, int userId) async {
    final filtering = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    var qIndex = 0;

    qSelector.addQuery(QueryList.ticket_q1(filtering, userId));

    replace['LIMIT x'] = 'LIMIT ${filtering.limit}';

    var listOrNull = await PublicAccess.psql2.queryCall(qSelector.generate(qIndex, replace));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return listOrNull.map((e) {
      return (e.toMap() as Map<String, dynamic>);
    }).toList();
  }
}
