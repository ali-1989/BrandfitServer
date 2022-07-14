import 'package:assistance_kit/api/helpers/boolHelper.dart';
import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/database/queryList.dart';
import 'package:brandfit_server/database/querySelector.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/models/userTypeModel.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/queryFiltering.dart';


class UserModelDb extends DbModel {
  late int user_id;
  int user_type = 1;
  int sex = 0;  // 0:unKnow, 1:man, 2:woman, 5:bisexual
  String name = '';
  String family = '';
  String? birthdate;
  String? register_date;
  bool is_deleted = false;

  static final String QTbl_User = '''
		CREATE TABLE IF NOT EXISTS #tb(
			user_id BIGINT NOT NULL DEFAULT nextval('#seq'),
			user_type SmallInt NOT NULL DEFAULT 1,
			name varchar(70) DEFAULT '',
			family varchar(70) DEFAULT '',
			sex INT2 NOT NULL DEFAULT 0,
			birthdate Date DEFAULT NULL ,
			register_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
			is_deleted BOOLEAN DEFAULT false,
			CONSTRAINT pk_#tb PRIMARY KEY (user_id),
			CONSTRAINT fk1_#tb FOREIGN KEY (sex) REFERENCES ${DbNames.T_TypeForSex} (key)
					ON DELETE RESTRICT ON UPDATE CASCADE
			)
			PARTITION BY RANGE (User_id);
			'''
      .replaceAll('#tb', DbNames.T_Users)
      .replaceFirst('#seq', DbNames.Seq_User);

  static final String QIdx_User$birthdate = '''
		CREATE INDEX IF NOT EXISTS #tb_birthdate_idx
		ON #tb USING BTREE (birthdate DESC NULLS LAST);
			'''
      .replaceAll('#tb', DbNames.T_Users);

  static final String QTbl_User$p1 = '''
		CREATE TABLE IF NOT EXISTS #tb_p1
		PARTITION OF #tb FOR VALUES FROM (0) TO (250000);
			'''
      .replaceAll('#tb', DbNames.T_Users);

  static final String QTbl_User$p2 = '''
		CREATE TABLE IF NOT EXISTS #tb_p2
		PARTITION OF #tb FOR VALUES FROM (250000) TO (500000);
			'''
      .replaceAll('#tb', DbNames.T_Users);


  @override
  UserModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    user_id = map[Keys.userId];
    user_type = map[Keys.userType]?? 1;
    sex = map[Keys.sex]?? 0;
    name = map[Keys.name];
    family = map[Keys.family];
    birthdate = map[Keys.birthdate];
    register_date = map['register_date'];
    is_deleted = BoolHelper.itemToBool(map['is_deleted']);
  }

  @override
  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{};

    map[Keys.userId] = user_id;
    map[Keys.userType] = user_type;
    map[Keys.sex] = sex;
    map[Keys.name] = name;
    map[Keys.family] = family;
    map[Keys.birthdate] = birthdate;
    map['register_date'] = register_date;
    map['is_deleted'] = is_deleted;

    return map;
  }

  static Future<bool> insertModel(UserModelDb model) async {
    final modelMap = model.toMap();
    return insertModelMap(modelMap);
  }

  static Future<bool> insertModelMap(Map<String, dynamic> userMap) async {
    final x = await PublicAccess.psql2.insert(DbNames.T_Users, userMap.keys.toList(), userMap.values.toList());

    return !(x == null || x < 1);
  }

  static Future<Map<String, dynamic>?> fetchMap(int userId) async {
    final q = 'SELECT * FROM ${DbNames.T_Users} WHERE user_id = $userId;';
    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return null;
    }

    return cursor.elementAt(0).toMap() as Map<String, dynamic>;

    //var res = UserDbModel.fromMap(m as Map<String, dynamic>);
    //return res.toMap();
  }

  static Future<bool> deleteByUserId(int userId) async {
    final x = await PublicAccess.psql2.delete(DbNames.T_Users, ' user_id = $userId');

    return !(x == null || x < 1);
  }

  static Future<List<int>> getManagerUsers() async{
    final type = UserTypeModel.getUserTypeNumByType(UserTypeModel.managerUser);

    final con = '''SELECT user_id FROM ${DbNames.T_Users} WHERE user_type = $type;''';
    final cursor = await PublicAccess.psql2.queryCall(con);

    final res = <int>[];

    if(cursor != null){
      for(var i=0; i < cursor.length; i++){
        var m = cursor.elementAt(i).toMap();

        res.add(m[Keys.userId]);
      }
    }

    return res;
  }

  static Future<bool> isManagerUser(int userId) async{
    final type = UserTypeModel.getUserTypeNumByType(UserTypeModel.managerUser);

    final con = ''' user_id = $userId AND user_type = $type ''';
    return await PublicAccess.psql2.exist(DbNames.T_Users, con);
  }
  
  static Future<bool> checkUserIsMatchWithApp(int userId, String appName) async{
    final type = UserTypeModel.getUserTypeNumByAppName(appName);

    final con = ''' user_id = $userId AND user_type = $type ''';
    return await PublicAccess.psql2.exist(DbNames.T_Users, con);
  }

  static Future<List?> getNameAndFamilyForUser(int userId) async {
    final q = 'SELECT * FROM ${DbNames.T_Users} WHERE user_id = $userId;';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return null;
    }

    final m = cursor.elementAt(0).toMap();

    return [m[Keys.name], m[Keys.family]];
  }

  static Future<bool> isDeletedUser(int userId) async {
    final query = '''SELECT is_deleted FROM ${DbNames.T_Users} WHERE user_id = $userId; ''';

    final bool? isDeleted = await PublicAccess.psql2.getColumn(query, 'is_deleted');
    return isDeleted != null && isDeleted;
  }

  static Future<bool> changeNameFamily(int userId, String name, String family) async{
    final value = <String, dynamic>{};
    value[Keys.name] = name;
    value[Keys.family] = family;

    final effected = await PublicAccess.psql2.updateKv(DbNames.T_Users, value, ' user_id = $userId');

    if(effected != null && effected > 0) {
      return true;
    }

    return false;
  }

  static Future<bool> changeUserSex(int userId, int sex) async{
    final value = <String, dynamic>{};
    value[Keys.sex] = sex;

    final effected = await PublicAccess.psql2.updateKv(DbNames.T_Users, value, ' user_id = $userId');

    if(effected != null && effected > 0) {
      return true;
    }

    return false;
  }

  static Future<bool> changeUserBirthDate(int userId, String birthdate) async{
    final value = <String, dynamic>{};
    value[Keys.birthdate] = birthdate;

    final effected = await PublicAccess.psql2.updateKv(DbNames.T_Users, value, ' user_id = $userId');

    if(effected != null && effected > 0) {
      return true;
    }

    return false;
  }
  
  static Future<List<Map>> searchOnPupilTrainer(Map<String, dynamic> js) async{
    final fq = FilterRequest.fromMap(js[Keys.filtering]);
    final qSelector = QuerySelector();
    final replace = <String, dynamic>{};
    replace['LIMIT x'] = 'LIMIT ${fq.limit}';

    qSelector.addQuery(QueryList.users_q1(fq));

    final userIds = await PublicAccess.psql2.queryCall(qSelector.generate(0, replace));

    if(userIds == null || userIds.isEmpty) {
      return <Map>[];
    }

    final ides = <int>[];

    for(final itm in userIds){
      final id = itm.toList()[0];

      ides.add(id);
      //res.add(await CommonMethods.getUserAdvanced(id));
    }

    final advMaps = await PublicAccess.psql2.queryCall(QueryList.advancedUsers_q1(ides));

    if(advMaps == null || userIds.isEmpty) {
      return <Map>[];
    }

    return advMaps.map((e) => e.toMap() as Map<String, dynamic>).toList();
  }
}