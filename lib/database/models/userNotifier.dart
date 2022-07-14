import 'package:assistance_kit/database/psql2.dart';
import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/database/queryList.dart';
import 'package:brandfit_server/database/querySelector.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/commonMethods.dart';
import 'package:brandfit_server/rest_api/queryFiltering.dart';

class UserNotifierModel extends DbModel {
  int? id;
  late int user_id;
  late String title;
  String? titleTranslateKey;
  Map? descriptionJs;
  String batch = 'none';
  bool is_seen = false;
  bool is_delete = false;
  String? register_date;


  static final String QTbl_userNotifier = '''
		CREATE TABLE IF NOT EXISTS #tb (
      id BIGSERIAL NOT NULL,
      user_id BIGINT NOT NULL,
      title varchar(100) NOT NULL,
      title_translate_key varchar(40) DEFAULT NULL,
      description_js JSONB DEFAULT NULL,
      batch varchar(20) DEFAULT NULL,
      is_seen BOOL DEFAULT FALSE,
      is_delete BOOL DEFAULT FALSE,
      register_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
      CONSTRAINT pk_#tb PRIMARY KEY (id),
      CONSTRAINT fk1_#tb FOREIGN KEY (user_id) REFERENCES #ref (user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
    )PARTITION BY RANGE (id);
			'''
      .replaceAll('#tb', DbNames.T_UserNotifier)
      .replaceFirst('#ref', DbNames.T_Users);


  static final String QTbl_userNotifier$p1 = '''
      CREATE TABLE IF NOT EXISTS #tb_p1
      PARTITION OF #tb FOR VALUES FROM (0) TO (500000);
      '''
      .replaceAll('#tb', DbNames.T_UserNotifier);

  static final String QTbl_userNotifier$p2 = '''
      CREATE TABLE IF NOT EXISTS #tb_p2
      PARTITION OF #tb FOR VALUES FROM (500000) TO (1000000);
      '''
      .replaceAll('#tb', DbNames.T_UserNotifier);


  UserNotifierModel();

  @override
  UserNotifierModel.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    id = map[Keys.id];
    user_id = map[Keys.userId];
    title = map[Keys.title];
    titleTranslateKey = map['title_translate_key'];
    descriptionJs = map['description_js'];
    batch = map['batch']?? NotifiersBatch.none.name;
    is_seen = map['is_seen'];
    is_delete = map['is_delete'];
    register_date = map['register_date'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    if(id != null) {
      map[Keys.id] = id;
    }

    map[Keys.userId] = user_id;
    map[Keys.title] = title;
    map['title_translate_key'] = titleTranslateKey;
    map['description_js'] = descriptionJs;
    map['batch'] = batch;
    map['is_seen'] = is_seen;
    map['is_delete'] = is_delete;
    map['register_date'] = register_date;

    return map;
  }

  static Future<int> insertModel(UserNotifierModel model) async {
    final modelMap = model.toMap();
    return insertModelMap(modelMap);
  }

  static Future<int> insertModelMap(Map<String, dynamic> userMap) async {
    if(userMap.containsKey('description_js')){
      userMap['description_js'] = CommonMethods.castToJsonb(userMap['description_js']);
    }

    final x = await PublicAccess.psql2.insertKvReturning(DbNames.T_UserNotifier, userMap, 'id');

    //return !(x == null || x < 1);
    if(x != null && x.isNotEmpty){
      return x[0].toList()[0];
    }

    return -1;
  }

  static Future<Map<String, dynamic>?> fetchMap(int id) async {
    final q = 'SELECT * FROM ${DbNames.T_UserNotifier} WHERE id = $id;';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if(cursor == null || cursor.isEmpty){
      return null;
    }

    return cursor[0].toMap() as Map<String, dynamic>;
  }

  static Future<bool> setIsSeen(List<int> ids, bool state) async {
    final value = <String, dynamic>{};
    value['is_seen'] = state;

    final idList = Psql2.listToSequence(ids);

    final effected = await PublicAccess.psql2.updateKv(DbNames.T_UserNotifier, value, ' id IN($idList)');

    return (effected != null && effected > 0);
  }

  static Future<bool> setIsDelete(int id, bool state) async {
    final value = <String, dynamic>{};
    value['is_delete'] = state;

    final effected = await PublicAccess.psql2.updateKv(DbNames.T_UserNotifier, value, ' id = $id');

    return (effected != null && effected > 0);
  }


  static Future searchOnUserNotifiers(Map<String, dynamic> jsOption, int userId) async {
    final filtering = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    var qIndex = 0;

    qSelector.addQuery(QueryList.userNotifiers_q1(filtering, userId));

    replace['LIMIT x'] = 'LIMIT ${filtering.limit}';

    var cursor = await PublicAccess.psql2.queryCall(qSelector.generate(qIndex, replace));

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      return (e.toMap() as Map<String, dynamic>);
    }).toList();
  }
}
///======================================================================================
enum NotifiersBatch {
  none,
  courseRequest,
  courseAnswer,
  programs,
}