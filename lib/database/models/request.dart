import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/database/queryList.dart';
import 'package:brandfit_server/database/querySelector.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/commonMethods.dart';
import 'package:brandfit_server/rest_api/queryFiltering.dart';

class RequestModelDb extends DbModel {
  int? id;
  late int course_id;
  late int requester_user_id;
  int? register_user_id;
  String? request_date;
  String? pay_date;
  String? answer_date;
  Map? answer_js;
  String? amount_paid;
  String? user_card_number;
  String? tracking_code;

  static final String QTbl_courseRequest = '''
  CREATE TABLE IF NOT EXISTS #tb (
       id BIGSERIAL NOT NULL,
       course_id BIGINT NOT NULL,
       requester_user_id BIGINT NOT NULL,
       register_user_id BIGINT DEFAULT NULL,
       request_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
       pay_date TIMESTAMP DEFAULT NULL,
       answer_date TIMESTAMP DEFAULT NULL,
       answer_js JSONB DEFAULT NULL,
       amount_paid varchar(20) DEFAULT NULL,
       user_card_number varchar(24) DEFAULT NULL,
       tracking_code varchar(40) DEFAULT NULL,
       support_expire_date TIMESTAMP DEFAULT NULL,
 
       CONSTRAINT fk1_#tb FOREIGN KEY (requester_user_id) REFERENCES ${DbNames.T_Users} (user_id) 
      		ON DELETE CASCADE ON UPDATE CASCADE,
      CONSTRAINT fk2_#tb FOREIGN KEY (course_id) REFERENCES ${DbNames.T_Course} (id) 
      		ON DELETE CASCADE ON UPDATE CASCADE
      )
      PARTITION BY RANGE (id);
      '''.replaceAll('#tb', DbNames.T_CourseRequest);

  static final String QTbl_courseRequest$p1 = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_CourseRequest}_p1
  PARTITION OF ${DbNames.T_CourseRequest}
  FOR VALUES FROM (0) TO (250000);'''; //250_000

  static final String QTbl_courseRequest$p2 = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_CourseRequest}_p2
  PARTITION OF ${DbNames.T_CourseRequest}
  FOR VALUES FROM (250000) TO (500000);''';//500_000

  static final String QAltUk1_courseRequest$p1 = '''
  DO \$\$ BEGIN ALTER TABLE ${DbNames.T_CourseRequest}_p1
       ADD CONSTRAINT uk1_${DbNames.T_CourseRequest} UNIQUE (course_id, requester_user_id);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;
       ''';


  static final String view_requestSupportDate = '''
  CREATE OR REPLACE VIEW request_support_date_view AS
  SELECT
        t1.id as course_id, t1.duration_day, t1.creator_user_id as trainer_id,
        t2.id as request_id, t2.requester_user_id, t2.answer_date,
        t3.min_send_date,
           (t3.min_send_date + (duration_day || ' day')::interval) as support_date
    FROM course AS T1
             JOIN courseRequest AS T2
                  ON T1.id = T2.course_id
             JOIN (
        SELECT min(send_date) AS min_send_date, course_request_id
        FROM foodprogram
        GROUP BY course_request_id) AS T3
                  ON T2.id = T3.course_request_id
    WHERE
        T2.answer_date IS NOT NULL AND (answer_js->'accept')::bool = true;
       ''';


  RequestModelDb();

  @override
  RequestModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    id = map[Keys.id];
    requester_user_id = map['requester_user_id'];
    register_user_id = map['register_user_id'];
    course_id = map['course_id'];
    request_date = map['request_date'];
    pay_date = map['pay_date'];
    answer_date = map['answer_date'];
    answer_js = map['answer_js'];
    user_card_number = map['user_card_number'];
    tracking_code = map['tracking_code'];
    amount_paid = map['amount_paid'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    if(id != null){
      map[Keys.id] = id;
    }

    map['requester_user_id'] = requester_user_id;
    map['course_id'] = course_id;
    map['register_user_id'] = register_user_id;
    map['answer_js'] = answer_js;
    map['user_card_number'] = user_card_number;
    map['request_date'] = request_date;
    map['pay_date'] = pay_date;
    map['answer_date'] = answer_date;
    map['tracking_code'] = tracking_code;
    map['amount_paid'] = amount_paid;

    return map;
  }

  static Future<bool> insertModel(RequestModelDb model) async {
    final modelMap = model.toMap();
    return insertModelMap(modelMap);
  }

  static Future<bool> insertModelMap(Map<String, dynamic> userMap) async {
    if(userMap.containsKey('answer_js')){
      userMap['answer_js'] = CommonMethods.castToJsonb(userMap['answer_js']);
    }

    final x = await PublicAccess.psql2.insertKv(DbNames.T_CourseRequest, userMap);

    return !(x == null || x < 1);
  }

  static Future<Map<String, dynamic>?> fetchMap(int id) async {
    final q = 'SELECT * FROM ${DbNames.T_CourseRequest} WHERE id = $id;';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if(cursor == null || cursor.isEmpty){
      return null;
    }

    return cursor[0].toMap() as Map<String, dynamic>;
  }

  static Future addRequestCourse(int userId, int courseId) async {
    final kv = <String, dynamic>{};
    kv['course_id'] = courseId;
    kv['requester_user_id'] = userId;
    kv['register_user_id'] = userId;

    var effected = await PublicAccess.psql2.insertIgnoreWhere(DbNames.T_CourseRequest, kv,
        where: 'course_id = $courseId AND requester_user_id = $userId');

    return effected != null && effected > 0;
  }

  static Future<bool> setRejectCourseRequest(Map<String, dynamic> jsOption, int id, String cause) async {
    final kv = <String, dynamic>{};
    kv['answer_js'] = CommonMethods.castToJsonb({'reject': true, 'cause': cause});
    kv['answer_date'] = DateHelper.getNowTimestampToUtc();

    var cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_CourseRequest, kv, where: 'id = $id');

    return (cursor != null && cursor > 0);
  }

  static Future<bool> setAcceptCourseRequest(Map<String, dynamic> jsOption, int id, int dayToProgram) async {
    final kv = <String, dynamic>{};
    kv['answer_js'] = CommonMethods.castToJsonb({'accept': true, 'days': dayToProgram});
    kv['answer_date'] = DateHelper.getNowTimestampToUtc();

    var cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_CourseRequest, kv, where: 'id = $id');

    return (cursor != null && cursor > 0);
  }

  static Future<Map<String, dynamic>> getRequestDataBy(int requesterId, int courseId) async {
    var cursor = await PublicAccess.psql2.queryCall(QueryList.request_q2(courseId, requesterId));

    if (cursor == null || cursor.isEmpty) {
      return <String, dynamic>{};
    }

    return cursor[0].toMap() as Map<String, dynamic>;
  }

  static Future searchOnTrainerRequest(Map<String, dynamic> jsOption, int userId) async {
    final fq = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    replace['LIMIT x'] = 'LIMIT ${fq.limit}';

    qSelector.addQuery(QueryList.request_q1(fq, userId));

    final cursor = await PublicAccess.psql2.queryCall(qSelector.generate(0, replace));

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      return (e.toMap() as Map<String, dynamic>);
    }).toList();
  }

  static Future searchOnCourseRequests(Map<String, dynamic> jsOption, int userId) async {
    final filtering = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    replace['LIMIT x'] = 'LIMIT ${filtering.limit}';

    qSelector.addQuery(QueryList.request_q4(filtering, userId));

    final cursor = await PublicAccess.psql2.queryCall(qSelector.generate(0, replace));

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      return (e.toMap() as Map<String, dynamic>);
    }).toList();
  }

  static Future searchOnRequestedCurses(Map<String, dynamic> jsOption, int userId) async {
    final fq = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    replace['LIMIT x'] = 'LIMIT ${fq.limit}';

    qSelector.addQuery(QueryList.request_course_q1(fq, userId));

    final listOrNull = await PublicAccess.psql2.queryCall(qSelector.generate(0, replace));

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

  static Future<List<Map>> getPupilRequestByTrainer(int pupilId, int trainerId) async {
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    replace['LIMIT x'] = 'LIMIT 30';

    qSelector.addQuery(QueryList.request_q3(pupilId, trainerId));

    final listOrNull = await PublicAccess.psql2.queryCall(qSelector.generate(0, replace));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return listOrNull.map((e) {
      return (e.toMap() as Map<String, dynamic>);
    }).toList();
  }

  static Future<bool> setSupportExpireDate(int requestId, String date) async {
    final q = '''
      UPDATE courserequest
        SET support_expire_date = coalesce(support_expire_date, '$date'::timestamp)
        WHERE id = $requestId;
    ''';
    final listOrNull = await PublicAccess.psql2.queryCall(q);

    if (listOrNull == null || listOrNull.isEmpty) {
      return false;
    }

    return true;
  }

}
