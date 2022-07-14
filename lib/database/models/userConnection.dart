import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';


class UserConnectionModelDb extends DbModel {
  late int user_id;
  late String device_id;
  String? websocket_id;
  String? language_iso;
  String? last_touch;
  bool is_login = false;
  String? token;

  /// this table update on login (http request) & WebSocket if has user_id
  static final String QTbl_UserConnections = '''
		CREATE TABLE IF NOT EXISTS #tb(
			user_id BIGINT NOT NULL,
      device_id varchar(40) NOT NULL,
      websocket_id varchar(60) DEFAULT NULL,
      language_iso varchar(5) DEFAULT 'en',
      is_login BOOLEAN DEFAULT FALSE,
      last_touch TIMESTAMP DEFAULT (now() at time zone 'utc'),
      token varchar(40) DEFAULT NULL
    )
    PARTITION BY RANGE (user_id);
			'''
      .replaceAll('#tb', DbNames.T_UserConnections);

  static final String QTbl_UserConnections$p1 = '''
    CREATE TABLE IF NOT EXISTS #tb_p1
    PARTITION OF #tb FOR VALUES FROM (0) TO (1000000);
    '''.replaceAll('#tb', DbNames.T_UserConnections);

  static final String QTbl_UserConnections$p2 = '''
    CREATE TABLE IF NOT EXISTS #tb_p2
    PARTITION OF #tb FOR VALUES FROM (1000000) TO (2000000);
    '''.replaceAll('#tb', DbNames.T_UserConnections);

  static final String QAlt_Uk1_UserConnections$p1 = '''
    DO \$\$ BEGIN ALTER TABLE #tb_p1
       ADD CONSTRAINT uk1_#tb UNIQUE (user_id, device_id);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM;
        END IF;
      END \$\$;'''.replaceAll('#tb', DbNames.T_UserConnections);

  static final String QIdx_UserConnections$device_id = '''
    CREATE INDEX IF NOT EXISTS #tb_device_id_idx
    ON #tb USING BTREE (device_id);
    '''.replaceAll('#tb', DbNames.T_UserConnections);

  static final String QIdx_UserConnections$websocket_id = '''
    CREATE INDEX IF NOT EXISTS #tb_websocket_id_idx
    ON #tb USING BTREE (websocket_id);
    '''.replaceAll('#tb', DbNames.T_UserConnections);


  UserConnectionModelDb();

  @override
  UserConnectionModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    user_id = map[Keys.userId];
    device_id = map[Keys.deviceId];
    websocket_id = map['websocket_id'];
    language_iso = map[Keys.languageIso];
    last_touch = map['last_touch'];
    is_login = map['is_login'];
    token = map[Keys.token];
  }

  @override
  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{};

    map[Keys.userId] = user_id;
    map[Keys.deviceId] = device_id;
    map['websocket_id'] = websocket_id;
    map[Keys.languageIso] = language_iso;
    map['last_touch'] = last_touch;
    map['is_login'] = is_login;
    map[Keys.token] = token;

    return map;
  }

  static Future<bool> insertModel(UserConnectionModelDb model) async {
    final modelMap = model.toMap();
    return insertModelMap(modelMap);
  }

  static Future<bool> insertModelMap(Map<String, dynamic> userMap) async {
    final x = await PublicAccess.psql2.insertKv(DbNames.T_UserConnections, userMap);

    return !(x == null || x < 1);
  }

  static Future<bool> upsertModel(UserConnectionModelDb model) async {
    final where = " user_id = ${model.user_id} AND device_id = '${model.device_id}'";
    final kv = model.toMap();

    final x = await PublicAccess.psql2.upsertWhereKv(DbNames.T_UserConnections, kv, where: where);

    return !(x == null || x < 1);
  }

  static Future<bool> upsertUserActiveTouch(int userId, String deviceId, {String? langIso, String? token}) async {
    if (userId < 1) {
      return false;
    }

    final kv = <String, Object>{};
    kv[Keys.userId] = userId;
    kv[Keys.deviceId] = deviceId;
    kv['is_login'] = true;
    kv['last_touch'] = DateHelper.getNowTimestampToUtc();

    if(langIso != null){
      kv[Keys.languageIso] = langIso;
    }

    if(token != null){
      kv['token'] = token;
    }

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_UserConnections, kv,
        where: " user_id = $userId AND device_id = '$deviceId'");

    return cursor != null && cursor > 0;
  }

  static Future<bool> tokenIsActive(int userId, String deviceId, String? token) async {
    /// no need [AND is_login is true]
    final con = ''' user_id = $userId AND device_id = '$deviceId' AND token = '$token' ''';
    return await PublicAccess.psql2.exist(DbNames.T_UserConnections, con);
  }

  static Future<bool> setUserLogoff(int userId, String deviceId) async{
    final kv = <String, dynamic>{};
    kv[Keys.userId] = userId;
    kv[Keys.deviceId] = deviceId;
    kv['is_login'] = false;
    kv['last_touch'] = DateHelper.getNowTimestampToUtc();

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_UserConnections, kv,
        where: " user_id = $userId AND device_id = '$deviceId'");

    if(cursor != null && cursor > 0){
      return true;
    }

    return false;
  }

  static Future<Map<String, dynamic>> fetchLastTouch(int userId) async {
    final q = '''
      SELECT DISTINCT ON (user_id) bool_or(is_login) 
       OVER (PARTITION BY user_id) as is_login,
       last_touch, user_id
      FROM UserConnections WHERE user_id = $userId ORDER BY user_id, last_touch DESC NULLS LAST;
    ''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <String, dynamic>{};
    }

    return cursor.elementAt(0).toMap() as Map<String, dynamic>;
  }
}