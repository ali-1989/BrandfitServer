import 'dart:io';

import 'package:assistance_kit/api/helpers/jsonHelper.dart';
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

class CourseModelDb extends DbModel {
  late int id;
  late int creator_user_id;
  String title = '';
  String description = '';
  String price = '';
  Map? currency_js;
  Map? block_js;
  int duration_day = 0;
  bool has_food_program = false;
  bool has_exercise_program = false;
  bool is_private_show = true;
  bool is_block = false;
  String? start_date;
  String? finish_date;
  String? creation_date;
  String? image_path;
  List<String>? tags;

  // start_date: start to broadcast course

  static final String QTbl_Course = '''
		CREATE TABLE IF NOT EXISTS #tb (
       id BIGINT NOT NULL DEFAULT nextval('#sec'),
       creator_user_id BIGINT NOT NULL,
       title varchar(120) DEFAULT '',
       description varchar(1000) DEFAULT '',
       price varchar(20) DEFAULT '',
       has_food_program BOOLEAN DEFAULT FALSE,
       has_exercise_program BOOLEAN DEFAULT FALSE,
       is_private_show BOOLEAN DEFAULT TRUE,
       is_block BOOLEAN DEFAULT FALSE,
       start_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
       finish_date TIMESTAMP DEFAULT (now() at time zone 'utc') + interval '360 days',
       duration_day int DEFAULT 0,
       currency_js JSONB DEFAULT '{}'::JsonB,
       block_js JSONB DEFAULT '{}'::JsonB,
       image_path varchar(500),
       tags varchar(50)[] DEFAULT '{}',
       creation_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
       CONSTRAINT pk_#tb PRIMARY KEY (Id),
       CONSTRAINT fk1_#tb FOREIGN KEY (creator_user_id) REFERENCES #ref (user_id)
      		ON DELETE CASCADE ON UPDATE CASCADE
      )
      PARTITION BY RANGE (Id);
			'''
      .replaceAll('#tb', DbNames.T_Course)
      .replaceFirst('#sec', DbNames.Seq_Course)
      .replaceFirst('#ref', DbNames.T_Users);


  static final String QIdx_Course$start_date = '''
	CREATE INDEX IF NOT EXISTS ${DbNames.T_Course}_start_date_idx ON ${DbNames.T_Course}
	USING BRIN (start_date);
		''';

  static final String QIdx_Course$finish_date = '''
	CREATE INDEX IF NOT EXISTS ${DbNames.T_Course}_finish_date_idx ON ${DbNames.T_Course}
	USING BRIN (finish_date);
		''';

  static final String QTbl_Course$p1 = '''
  CREATE TABLE IF NOT EXISTS #tb_p1
  PARTITION OF #tb FOR VALUES FROM (0) TO (100000);
      '''
      .replaceAll('#tb', DbNames.T_Course);

  static final String QTbl_Course$p2 = '''
  CREATE TABLE IF NOT EXISTS #tb_p2
  PARTITION OF #tb FOR VALUES FROM (100000) TO (200000);
      '''
      .replaceAll('#tb', DbNames.T_Course);


  @override
  CourseModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    id = map[Keys.id];
    creator_user_id = map['creator_user_id']?? 0;
    title = map[Keys.title];
    description = map[Keys.description];
    price = map['price'];
    start_date = map['start_date'];
    finish_date = map['finish_date'];
    creation_date = map['creation_date'];
    currency_js = map['currency_js'];
    duration_day = map['duration_day']?? 0;
    block_js = map['block_js'];
    has_exercise_program = map['has_exercise_program'];
    has_food_program = map['has_food_program'];
    is_private_show = map['is_private_show'];
    is_block = map['is_block'];
    tags = map['tags'];
    image_path = map[Keys.imagePath];
  }

  @override
  Map<String, dynamic> toMap() {
    final res = <String, dynamic>{};

    res[Keys.id] = id;
    res['creator_user_id'] = creator_user_id;
    res[Keys.title] = title;
    res[Keys.description] = description;
    res['price'] = price;
    res['currency_js'] = currency_js;
    res['block_js'] = block_js;
    res['start_date'] = start_date;
    res['finish_date'] = finish_date;
    res['creation_date'] = creation_date;
    res['duration_day'] = duration_day;
    res['has_exercise_program'] = has_exercise_program;
    res['has_food_program'] = has_food_program;
    res['is_private_show'] = is_private_show;
    res['is_block'] = is_block;
    res['tags'] = tags;
    res[Keys.imagePath] = image_path;

    return res;
  }

  static Future<Map<String, dynamic>?> fetchMap(int id) async {
    final q = 'SELECT * FROM ${DbNames.T_Course} WHERE id = $id;';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if(cursor == null || cursor.isEmpty){
      return null;
    }

    return cursor[0].toMap() as Map<String, dynamic>;
  }

  static Future searchOnCurses(Map<String, dynamic> jsOption, int userId) async {
    final fq = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    replace['LIMIT x'] = 'LIMIT ${fq.limit}';
    replace['OFFSET x'] = 'OFFSET ${fq.offset}';

    qSelector.addQuery(QueryList.course_q1(fq, userId));

    final listOrNull = await PublicAccess.psql2.queryCall(qSelector.generate(0, replace));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    //smpl: image uri
    return listOrNull.map((e) {
      var m = e.toMap();
      m[Keys.imageUri] = CourseModelDb.convertPathToUri(m[Keys.imageUri]);
      return m as Map<String, dynamic>;
      //return (e as Map<String, dynamic>);
    }).toList();
  }

  static Future<bool?> addCourse(Map<String, dynamic> jsOption, Map course, File? file) async {
    String? p;

    if(file != null) {
      p = PathsNs.removeBasePathFromLocalPath(PathsNs.getCurrentPath(), file.path);
    }

    final model = CourseModelDb.fromMap(course as Map<String, dynamic>);

    //smpl
    final kv = model.toMap();
    kv['currency_js'] = CommonMethods.castToJsonb(kv['currency_js'], nullIfNull: false);

    if(model.creator_user_id == 0) {
      kv['creator_user_id'] = jsOption[Keys.forUserId];
    }

    if(p != null) {
      kv['image_path'] = UrlHelper.encodeUrl(p);
    }

    if(model.creation_date == null){
      JsonHelper.removeKeys(kv, ['creation_date']);
    }

    JsonHelper.removeKeys(kv, ['id']);//must generate

    final effected = await PublicAccess.psql2.insertKv(DbNames.T_Course, kv);

    return effected != null && effected > 0;
  }

  static Future<bool?> editCourse(Map<String, dynamic> jsOption, Map course, File? file, String? partName) async {
    String? p;

    if(file != null) {
      p = PathsNs.removeBasePathFromLocalPath(PathsNs.getCurrentPath(), file.path);
    }

    final model = CourseModelDb.fromMap(course as Map<String, dynamic>);

    final kv = model.toMap();
    kv['currency_js'] = CommonMethods.castToJsonb(kv['currency_js'], nullIfNull: false);

    if(p != null) {
      kv['image_path'] = UrlHelper.encodeUrl(p);
    }

    if(partName == 'delete') {
      kv['image_path'] = null;
    }

    final effected = await PublicAccess.psql2.updateKv(DbNames.T_Course, kv, 'id = ${course['id']}');

    return effected != null && effected > 0;
  }

  static Future<bool> isDayLittleForEdit(Map course) async {
    final newModel = CourseModelDb.fromMap(course as Map<String, dynamic>);
    final oldMap = await CourseModelDb.fetchMap(newModel.id);
    final oldModel = CourseModelDb.fromMap(oldMap!);

    return oldModel.duration_day > newModel.duration_day;
  }

  static Future<bool> hasCourseARequest(int cId) async {
    var effected = await PublicAccess.psql2.existQuery(QueryList.course_q4(cId));

    return effected;
  }

  static Future<bool> deleteCourse(Map<String, dynamic> jsOption, int cId) async {
    var effected = await PublicAccess.psql2.delete(DbNames.T_Course, 'id = $cId');

    return effected != null && effected > 0;
  }

  static Future searchOnCursesWithoutSet(Map<String, dynamic> jsOption, int userId) async {
    final fq = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    replace['LIMIT x'] = 'LIMIT ${fq.limit}';
    var qIndex = 0;

    qSelector.addQuery(QueryList.course_q2A(fq, userId));
    qSelector.addQuery(QueryList.course_q2B(fq, userId));

    if(fq.isSearchFor(SearchKeys.userNameKey)){
      qIndex = 0;
    }
    else {
      qIndex = 1;
    }

    final listOrNull = await PublicAccess.psql2.queryCall(qSelector.generate(qIndex, replace));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    // smpl: edit field
    return listOrNull.map((e) {
      final m = e.toMap();
      //no need m[Keys.imageUri] = CourseDbModel.convertPathToUri(m[Keys.imageUri]);
      return m as Map<String, dynamic>;
      //return (e as Map<String, dynamic>);
    }).toList();
  }

  static Future searchOnCursesForShop(Map<String, dynamic> jsOption, int userId) async {
    final fq = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    replace['LIMIT x'] = 'LIMIT ${fq.limit}';

    qSelector.addQuery(QueryList.course_q3A(fq, userId));
    qSelector.addQuery(QueryList.course_q3B(fq, userId));

    var qIdx = 0;

    if(fq.querySearchingList.isNotEmpty){
      qIdx = 1;
    }

    final listOrNull = await PublicAccess.psql2.queryCall(qSelector.generate(qIdx, replace));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return listOrNull.map((e) {
      return (e.toMap() as Map<String, dynamic>);
    }).toList();
  }

  static Future changeCourseBlockState(Map<String, dynamic> jsOption, int courseId, bool state) async {
    var kv = <String, dynamic>{};
    kv['is_block'] = state;

    var cursor = await PublicAccess.psql2.updateKv(DbNames.T_Course, kv, ' id = $courseId');

    if(cursor is num || cursor is String){
      return cursor;
    }

    return null;
  }

  static String? convertPathToUri(String? path){
    if(path == null){
      return null;
    }

    return PathsNs.genUrlDomainFromLocalPathByDecoding(PublicAccess.domain, PathsNs.getCurrentPath(), path);
  }
}
