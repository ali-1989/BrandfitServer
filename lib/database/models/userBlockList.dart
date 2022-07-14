import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';


class UserBlockListModelDb extends DbModel {
  late int user_id;
  late int blocker_user_id;
  String? block_date;
  String? extra_js;

  static final String QTbl_UserBlockList = '''
		CREATE TABLE IF NOT EXISTS #tb(
			user_id BIGINT NOT NULL,
      blocker_user_id BIGINT NOT NULL,
      block_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
      extra_js JSONB DEFAULT NULL,
      CONSTRAINT pk_#tb PRIMARY KEY (user_id),
      CONSTRAINT fk1_#tb FOREIGN KEY (user_id) REFERENCES #ref (user_id)
 		    ON DELETE NO ACTION ON UPDATE CASCADE
 		);
			'''
      .replaceAll('#tb', DbNames.T_UserBlockList)
      .replaceFirst('#ref', DbNames.T_Users);

  UserBlockListModelDb();

  @override
  UserBlockListModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    user_id = map[Keys.userId];
    blocker_user_id = map['blocker_user_id'];
    block_date = map['block_date'];
    extra_js = map[Keys.extraJs];
  }

  @override
  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{};

    map[Keys.userId] = user_id;
    map['blocker_user_id'] = blocker_user_id;
    map['block_date'] = block_date;
    map[Keys.extraJs] = extra_js;

    return map;
  }

  static Future<bool> insertModel(UserBlockListModelDb model) async {
    final modelMap = model.toMap();
    return insertModelMap(modelMap);
  }

  static Future<bool> insertModelMap(Map<String, dynamic> userMap) async {
    final x = await PublicAccess.psql2.insertKv(DbNames.T_UserBlockList, userMap);

    return !(x == null || x < 1);
  }

  static Future<bool> blockUser(int userId, {int? blocker, String? cause}) async {
    final column = [Keys.userId, 'blocker_user_id'];
    final values = <dynamic>[userId, blocker?? PublicAccess.systemUserId];

    if(cause != null){
      column.add(Keys.extraJs);
      values.add(''' '{"cause": "$cause"}'::jsonb''');
    }

    return upsertCV(column, values, userId);
  }

  static Future<int?> unBlockUser(int userId) async{
    return await PublicAccess.psql2.delete(DbNames.T_UserBlockList, ' user_id = $userId');
  }

  static Future<bool> upsertCV(List<String> k, List v, int userId) async {
    final x = await PublicAccess.psql2.upsertWhere(DbNames.T_UserBlockList, k, v, where: 'user_id = $userId');

    return !(x == null || x < 1);
  }

  static Future<bool> insertCV(List<String> k, List v) async {
    final x = await PublicAccess.psql2.insert(DbNames.T_UserBlockList, k, v);

    return !(x == null || x < 1);
  }

  static Future<bool> isBlockedUser(int userId) async {
    return await PublicAccess.psql2.exist(DbNames.T_UserBlockList,' user_id = $userId');
  }


/*static Future<bool> deleteByUserId(int userId) async {
    var x = await PublicAccess.psql2.delete(DbNames.T_UserBlockList, ' user_id = $userId');

    return !(x == null || x < 1);
  }*/
}