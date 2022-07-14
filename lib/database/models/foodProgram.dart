import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/api/helpers/mathHelper.dart';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:brandfit_server/database/models/course.dart';
import 'package:brandfit_server/database/models/request.dart';
import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/database/models/programSuggestion.dart';
import 'package:brandfit_server/database/models/userNameId.dart';
import 'package:brandfit_server/database/queryList.dart';
import 'package:brandfit_server/database/querySelector.dart';
import 'package:brandfit_server/holders/h1_food.dart';
import 'package:brandfit_server/holders/h2_food.dart';
import 'package:brandfit_server/holders/h3_food.dart';
import 'package:brandfit_server/holders/h4_food.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/queryFiltering.dart';
import 'package:brandfit_server/rest_api/userNotifierCenter.dart';

class FoodProgramModelDb extends DbModel {
  int? id;
  int trainer_id = 0;
  int requestId = 0;
  String? title;
  Map? pcl;
  String? register_date;
  String? cron_date;
  String? send_date;
  String? pupil_see_date;
  bool can_show = true;

  static final String QTbl_FoodPrograms = '''
  CREATE TABLE IF NOT EXISTS #tb (
       id BIGSERIAL,
       request_id int DEFAULT 0,
       trainer_id int DEFAULT 0,
       title varchar(120) NOT NULL,
       p_c_l JSONB DEFAULT '{}'::JSONB,
       register_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
       cron_date TIMESTAMP DEFAULT null,
       send_date TIMESTAMP DEFAULT null,
       pupil_see_date TIMESTAMP DEFAULT null,
       can_show BOOLEAN DEFAULT TRUE,
       CONSTRAINT pk_#tb PRIMARY KEY (id)
      );
      '''.replaceAll('#tb', DbNames.T_FoodProgram);

  static final String QIndex_FoodProgram$request_id = '''
    CREATE INDEX IF NOT EXISTS #tb_request_id_idx
    ON #tb USING BTREE (request_id);
    '''
      .replaceAll('#tb', DbNames.T_FoodProgram);

  static final String QIndex_FoodProgram$trainer_id = '''
    CREATE INDEX IF NOT EXISTS #tb_trainer_id_idx
    ON #tb USING BTREE (trainer_id);
    '''
      .replaceAll('#tb', DbNames.T_FoodProgram);

  static final String QIndex_FoodProgram$cron_date = '''
    CREATE INDEX IF NOT EXISTS #tb_cron_date_idx
    ON #tb USING BTREE (cron_date);
    '''
      .replaceAll('#tb', DbNames.T_FoodProgram);

  static final String QIndex_FoodProgram$send_date = '''
    CREATE INDEX IF NOT EXISTS #tb_send_date_idx
    ON #tb USING BTREE (send_date);
    '''
      .replaceAll('#tb', DbNames.T_FoodProgram);

  static final String QIndex_FoodProgram$pupil_see_date = '''
    CREATE INDEX IF NOT EXISTS #tb_pupil_see_date_idx
    ON #tb USING BTREE (pupil_see_date);
    '''
      .replaceAll('#tb', DbNames.T_FoodProgram);

  //----------------------------------------------------------
  // type_lkp: 1: day, 2: meal, 3: suggestion
  static final String QTbl_FoodProgramTree = '''
  CREATE TABLE IF NOT EXISTS #tb (
       id BIGSERIAL,
       parent_id BIGINT DEFAULT NULL,
       program_id BIGINT NOT NULL,
       type_lkp int NOT NULL DEFAULT 1,
       title varchar(120) DEFAULT NULL,
       ordering INT DEFAULT 0,
       is_base bool DEFAULT false,
       CONSTRAINT pk_#tb PRIMARY KEY (id),
       CONSTRAINT fk1_#tb FOREIGN KEY (program_id) REFERENCES #ref1 (id)
        ON DELETE CASCADE ON UPDATE CASCADE,
       CONSTRAINT fk2_#tb FOREIGN KEY (parent_id) REFERENCES #tb (id)
        ON DELETE CASCADE ON UPDATE CASCADE
      );
      '''.replaceAll('#tb', DbNames.T_FoodProgramTree)
      .replaceAll('#ref1', DbNames.T_FoodProgram);

  static final String QIndex_FoodProgramTree$program_id = '''
    CREATE INDEX IF NOT EXISTS #tb_program_id_idx
    ON #tb USING BTREE (program_id);
    '''
      .replaceAll('#tb', DbNames.T_FoodProgramTree);

  FoodProgramModelDb();

  @override
  FoodProgramModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    id = map['id'];
    requestId = map['request_id']?? 0;
    trainer_id = map['trainer_id']?? 0;
    pcl = map['p_c_l']?? {};
    title = map['title'];
    can_show = map['can_show']?? true;
    register_date = map['register_date'];
    cron_date = map['cron_date'];
    send_date = map['send_date'];
    pupil_see_date = map['pupil_see_date'];
  }

  @override
  Map<String, dynamic> toMap({bool withId = true}) {
    final map = <String, dynamic>{};

    if(withId) {
      map['id'] = id;
    }

    map['request_id'] = requestId;
    map['trainer_id'] = trainer_id;
    map['title'] = title;
    map['p_c_l'] = pcl;
    map['register_date'] = register_date;
    map['cron_date'] = cron_date;
    map['send_date'] = send_date;
    map['pupil_see_date'] = pupil_see_date;
    map['can_show'] = can_show;

    return map;
  }

  static Future<List<Map<String, dynamic>?>> fetchMap(int id) async {
    final q = '''SELECT * FROM ${DbNames.T_FoodProgram} WHERE id = $id; ''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<dynamic> insertModel(FoodProgramModelDb model) async {
    final kv = model.toMap(withId: false);
    return await PublicAccess.psql2.insertKvReturning(DbNames.T_FoodProgram, kv, 'id, register_date');
  }

  static Future<bool> upsertModel(FoodProgramModelDb model) async {
    final kv = model.toMap();
    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_FoodProgram, kv, where: ' id = ${model.id}');

    return cursor != null && cursor > 0;
  }
  ///----------------------------------------------------------------------------------------
  static Future<H1?> addFoodProgram(Map<String, dynamic> jsOption, Map<String, dynamic> foodProgram, int userId) async {
    final program = FoodProgramModelDb.fromMap(foodProgram);
    final res = await insertModel(program);

    if(res != null && res.isNotEmpty){
      final result = H1();
      result.foodProgramId = res[0].toList()[0];
      result.registerDate = res[0].toList()[1];
      //result.daysLinker = dayLinks;

      return result;
    }

    return null;
  }

  static Future<H1?> repeatFoodProgram(Map<String, dynamic> jsOption, Map<String, dynamic> foodProgram, int userId, int oldProgramId) async {
    final h1 = await addFoodProgram(jsOption, foodProgram, userId);

    if(h1 != null){
      final h2 = await getProgramDays(oldProgramId);
      final s = await setProgramDays(null, userId, h1.foodProgramId, h2.days);

      if(s) {
        return h1;
      }
    }

    return null;
  }

  static Future<bool> updateFoodProgram(Map<String, dynamic> jsOption, Map<String, dynamic> foodProgram, int programId) async {
    final program = FoodProgramModelDb.fromMap(foodProgram);
    return await upsertModel(program);
  }

  static Future deleteFoodProgram(Map<String, dynamic> jsOption, int programId) async {
    final cursor = await PublicAccess.psql2.delete(DbNames.T_FoodProgram, 'id = $programId');

    if(cursor is num || cursor is String){
      return cursor;
    }

    return null;
  }

  static Future<bool> isProgramSend(int programId) async {
    var where = 'id = $programId AND send_date IS NOT NULL';
    return await PublicAccess.psql2.exist(DbNames.T_FoodProgram, where);
  }

  static Future<H4?> setProgramIsSend(int programId) async {
    final rowOrNull = await PublicAccess.psql2.queryCall(QueryList.foodProgram_q9(programId));

    if(rowOrNull == null || rowOrNull.isEmpty){
      return null;
    }

    final h4 = H4();
    h4.sendDate = rowOrNull[0].toMap()['send_date'];
    h4.cronDate = rowOrNull[0].toMap()['cron_date'];
    h4.requestId = rowOrNull[0].toMap()['request_id'];

    return h4;
  }

  static Future searchOnFoodPrograms(Map<String, dynamic> jsOption, int userId) async {
    final filtering = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    var qIndex = 0;

    qSelector.addQuery(QueryList.foodProgram_q1(filtering, userId));

    replace['LIMIT x'] = 'LIMIT ${filtering.limit}';

    final listOrNull = await PublicAccess.psql2.queryCall(qSelector.generate(qIndex, replace));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return listOrNull.map((e) {
      return e.toMap() as Map<String, dynamic>;
    }).toList();
  }

  static Future<H3> getRequestPrograms(int requestId, bool withPending) async {
    final result = H3();

    final listOrNull = await PublicAccess.psql2.queryCall(QueryList.foodProgram_q2(requestId, withPending));

    if (listOrNull == null || listOrNull.isEmpty) {
      return result;
    }

    final fetchList = listOrNull.map((e) {
      return e.toMap() as Map<String, dynamic>;
    }).toList();

    for(final i in fetchList){
      final programId = i['id'];

      final h2 = await getProgramDays(programId);

      i['days'] = h2.days;
      result.materialIds.addAll(h2.materialIds);
    }

    result.programs = fetchList;
    return result;
  }

  static Future deleteFoodProgramTree(int programId) async {
    final cursor = await PublicAccess.psql2.delete(DbNames.T_FoodProgramTree, 'program_id = $programId');

    if(cursor is num || cursor is String){
      return cursor;
    }

    return null;
  }

  static Future<bool> setProgramDays(Map<String, dynamic>? jsOption, int userId, int programId, List<Map> days) async {
    await deleteFoodProgramTree(programId);

    try{
      for(final day in days){
        //final dayId = day[Keys.id];
        final dayOrdering = day['ordering'];
        final meals = day['meals']?? [];

        final listOrNull = await PublicAccess.psql2.queryCall(QueryList.foodProgram_q3(userId, programId, dayOrdering));

        if(listOrNull == null){
          await deleteFoodProgramTree(programId);
          return false;
        }

        int dayRId = listOrNull[0].toList()[0];

        for(final meal in meals){
          //final mealId = meal[Keys.id];
          final mealName = meal[Keys.title];
          final mealOrdering = meal['ordering'];
          //final eatTime = meal['eat_time'];
          final suggestions = meal['suggestions']?? [];

          final listOrNull = await PublicAccess.psql2.queryCall(QueryList.foodProgram_q4(userId, dayRId, programId, mealName, mealOrdering));

          if(listOrNull == null){
            await deleteFoodProgramTree(programId);
            return false;
          }

          int mealRId = listOrNull[0].toList()[0];

          for(final sug in suggestions){
            //final sugId = sug[Keys.id];
            final sugName = sug[Keys.title];
            final sugOrdering = sug['ordering'];
            final isBase = sug['is_base']?? false;
            final materials = sug['materials']?? [];

            var listOrNull = await PublicAccess.psql2.queryCall(QueryList.foodProgram_q5(userId, mealRId, programId, sugName, isBase, sugOrdering));

            if(listOrNull == null){
              await deleteFoodProgramTree(programId);
              return false;
            }

            int sRId = listOrNull[0].toList()[0];
            final matJs = JsonHelper.objToJson(materials);

            listOrNull = await PublicAccess.psql2.queryCall(QueryList.foodProgram_q6(userId, sRId, programId, matJs));
          }
        }
      }
    }
    catch (e){
      await deleteFoodProgramTree(programId);
      return false;
    }

    return true;
  }

  static Future<H2> getProgramDays(int programId) async {
    final result = H2();

    final daysOrNull = await PublicAccess.psql2.queryCall(QueryList.foodProgram_q8(programId));

    if(daysOrNull == null || daysOrNull.isEmpty){
      return result;
    }

    for(final i in daysOrNull){
      final day = i.toMap();
      var mealList = <Map>[];

      final mealOrNull = await PublicAccess.psql2.queryCall(QueryList.foodProgram_q7(programId, day['id']));

      if(mealOrNull != null && mealOrNull.isNotEmpty){
        mealList = await (Future.wait(mealOrNull.map((e) async {
          final m = e.toMap();
          final suggestions = await ProgramSuggestionModelDb.getProgramSuggestions(m['id']);
          m['suggestions'] = suggestions;

          /// fetch material_id
          for(final s in suggestions){
            final matList = s['materials'];
            final usedMatList = s['used_materials'];

            if(matList != null){
              for(final k in matList){
                final id = k['material_id'];
                result.materialIds.add(id?? 0);
              }
            }

            if(usedMatList is List){
              for(final k in usedMatList){
                final id = k['material_id'];
                result.materialIds.add(id?? 0);
              }
            }
          }

          return m;
        }).toList()));
      }

      day['meals'] = mealList;
      result.days.add(day);
    }

    return result;
  }

  static Future sendCronPrograms() async {
    final q = '''
      SELECT * FROM foodprogram
      WHERE cron_date IS NOT NULL
        AND send_date IS NULL
        AND cron_date <= (now() at time zone 'utc');
    ''';

    final res = await PublicAccess.psql2.queryCall(q);

    if(res == null || res.isEmpty){
      return;
    }

    for(final row in res){
      final food = FoodProgramModelDb.fromMap(row.toMap().map((key, value) => MapEntry<String, dynamic>(key, value)));

      final h4 = await setProgramIsSend(food.id!);

      if(h4 != null) {
        final requestId = h4.requestId!;
        final cMap = await RequestModelDb.fetchMap(requestId);
        final requestModel = RequestModelDb.fromMap(cMap!);
        final courseMap = await CourseModelDb.fetchMap(requestModel.course_id);
        final courseModel = CourseModelDb.fromMap(courseMap!);
        final activeDays = courseModel.duration_day + MathHelper.percentInt(courseModel.duration_day, PublicAccess.supportPercent);

        final expireDate = DateHelper.getNowToUtc().add(Duration(days: activeDays));
        await RequestModelDb.setSupportExpireDate(h4.requestId!, DateHelper.toTimestamp(expireDate));
        //------ notify Pupil ----------------------------------------------------
        final userName = await UserNameModelDb.getUserNameByUserId(courseModel.creator_user_id);
        final description = {'trainer_name': userName, 'course_name': courseModel.title, 'active_days': activeDays};

        // ignore: unawaited_futures
        UserNotifierCenter.sendProgram(requestModel.requester_user_id, description);
        //------| notify Pupil ----------------------------------------------------
      }
    }
  }
}