import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';

class UserNameModelDb extends DbModel {
  late int user_id;
  late String user_name;
  String? password;
  String? hash_password;


  static final String QTbl_userNameId = '''
		CREATE TABLE IF NOT EXISTS #tb (
      user_id BIGINT NOT NULL,
      user_name varchar(40) NOT NULL,
      password varchar(20) DEFAULT NULL,
      hash_password varchar(60) DEFAULT NULL,
      CONSTRAINT pk_#tb PRIMARY KEY (user_id),
      CONSTRAINT fk1_#tb FOREIGN KEY (user_id) REFERENCES #ref (user_id)
        ON DELETE NO ACTION ON UPDATE CASCADE
    )PARTITION BY RANGE (user_id);
			'''
      .replaceAll('#tb', DbNames.T_UserNameId)
      .replaceFirst('#ref', DbNames.T_Users);

  static final String QIdx_userNameId$$user_name = '''
		CREATE INDEX IF NOT EXISTS #tb_user_name_idx
		 ON #tb USING BTREE (user_name, hash_password);
		'''
      .replaceAll('#tb', DbNames.T_UserNameId);

  static final String QTbl_userNameId$p1 = '''
      CREATE TABLE IF NOT EXISTS #tb_p1
      PARTITION OF #tb FOR VALUES FROM (0) TO (250000);
      '''
      .replaceAll('#tb', DbNames.T_UserNameId);

  static final String QTbl_userNameId$p2 = '''
      CREATE TABLE IF NOT EXISTS #tb_p2
      PARTITION OF #tb FOR VALUES FROM (250000) TO (500000);
      '''
      .replaceAll('#tb', DbNames.T_UserNameId);


  UserNameModelDb();

  @override
  UserNameModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    user_id = map[Keys.userId];
    user_name = map[Keys.userName];
    password = map['password'];
    hash_password = map['hash_password'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.userId] = user_id;
    map[Keys.userName] = user_name;
    map['password'] = password;
    map['hash_password'] = hash_password;

    return map;
  }

  static Future<bool> insertModel(UserNameModelDb model) async {
    final modelMap = model.toMap();
    return insertModelMap(modelMap);
  }

  static Future<bool> insertModelMap(Map<String, dynamic> userMap) async {
    final x = await PublicAccess.psql2.insertKv(DbNames.T_UserNameId, userMap);

    return !(x == null || x < 1);
  }

  static Future<Map<String, dynamic>?> fetchMap(int userId) async {
    final q = 'SELECT * FROM ${DbNames.T_UserNameId} WHERE user_id = $userId;';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if(cursor == null || cursor.isEmpty){
      return null;
    }

    return cursor[0].toMap() as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> fetchMapBy(String userName, String hashPassword) async {
    final query = '''SELECT * FROM ${DbNames.T_UserNameId} 
      WHERE user_name = '$userName' AND hash_password = '$hashPassword';''';

    final cursor = await PublicAccess.psql2.queryCall(query);

    if(cursor == null || cursor.isEmpty){
      return null;
    }

    return cursor[0].toMap() as Map<String, dynamic>;
  }

  static Future<bool> existThisUserName(String? userName) async {
    return (await PublicAccess.psql2.exist(DbNames.T_UserNameId, " user_name = '$userName'"));
  }

  static Future<bool> deleteByUserId(int userId) async {
    final x = await PublicAccess.psql2.delete(DbNames.T_UserNameId, ' user_id = $userId');

    return !(x == null || x < 1);
  }

  static Future<dynamic> getUserIdByUserName(String userName) async {
    final query = '''SELECT user_id FROM ${DbNames.T_UserNameId} WHERE user_name Like '$userName'; ''';

    return PublicAccess.psql2.getColumn(query, Keys.userId);
  }

  static Future<dynamic> getUserNameByUserId(int userId) async {
    final query = '''SELECT user_name FROM ${DbNames.T_UserNameId} WHERE user_id = $userId; ''';

    return PublicAccess.psql2.getColumn(query, Keys.userName);
  }

  static Future<bool> changeUserName(int userId, String userName) async {
    final value = <String, dynamic>{};
    value[Keys.userName] = userName;

    final effected = await PublicAccess.psql2.updateKv(DbNames.T_UserNameId, value, ' user_id = $userId');

    return (effected != null && effected > 0);
  }
}
