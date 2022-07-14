import 'package:assistance_kit/api/converter.dart';
import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/api/helpers/listHelper.dart';
import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/models/healthConditionModel.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/commonMethods.dart';
//import 'package:postgresql2/postgresql.dart';

class PersonalDataModelDb extends DbModel {
  int? user_id;
  String? body_info_js;
  String? sports_equipment_js;
  String? health_condition_js;
  String? job_activity_js;


  /// Keys: user_id, body_info_js, sports_equipment_js, health_condition_js, job_activity_js
  static final String QTbl_UserPersonalData = '''
		CREATE TABLE IF NOT EXISTS #tb (
      user_id BIGINT NOT NULL,
      body_info_js JSONB DEFAULT NULL,
      sports_equipment_js JSONB DEFAULT NULL,
      health_condition_js JSONB DEFAULT NULL,
      job_activity_js JSONB DEFAULT NULL,
      CONSTRAINT pk_#tb PRIMARY KEY (user_id)
 		 )
 		 PARTITION BY RANGE (user_id);
			'''
      .replaceAll('#tb', DbNames.T_UserPersonalData);

  static final String QTbl_UserPersonalData$p1 = '''
      CREATE TABLE IF NOT EXISTS #tb_p1
      PARTITION OF #tb FOR VALUES FROM (0) TO (250000);
      '''
      .replaceAll('#tb', DbNames.T_UserPersonalData);

  static final String QTbl_UserPersonalData$p2 = '''
      CREATE TABLE IF NOT EXISTS #tb_p2
      PARTITION OF #tb FOR VALUES FROM (250000) TO (500000);
      '''
      .replaceAll('#tb', DbNames.T_UserPersonalData);

  PersonalDataModelDb();

  @override
  PersonalDataModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    user_id = map[Keys.userId];
    body_info_js = map['body_info_js'];
    sports_equipment_js = map['sports_equipment_js'];
    health_condition_js = map['health_condition_js'];
    job_activity_js = map['job_activity_js'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.userId] = user_id;
    map['body_info_js'] = body_info_js;
    map['sports_equipment_js'] = sports_equipment_js;
    map['health_condition_js'] = health_condition_js;
    map['job_activity_js'] = job_activity_js;

    return map;
  }

  static Future<Map<String, dynamic>?> fetchMap(int userId) async {
    final q = 'SELECT * FROM ${DbNames.T_UserPersonalData} WHERE user_id = $userId;';

    final List? cursor = await PublicAccess.psql2.queryCall(q);

    if(cursor == null || cursor.isEmpty) {
      return null;
    }

    return cursor[0].toMap() as Map<String, dynamic>;
  }

  static Future<Map?> fetchJobActivityMap(int userId) async {
    final q = '''
      SELECT job_activity_js FROM ${DbNames.T_UserPersonalData} WHERE user_id = $userId;
    ''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if(cursor == null || cursor.isEmpty) {
      return null;
    }

    return cursor.elementAt(0).toList()[0];
  }

  static Future<Map?> fetchHealthConditionMap(int userId) async {
    final q = '''
      SELECT health_condition_js FROM ${DbNames.T_UserPersonalData} WHERE user_id = $userId;
    ''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if(cursor == null || cursor.isEmpty) {
      return null;
    }

    return cursor.elementAt(0).toList()[0];
  }

  static Future<Map?> fetchSportsEquipmentMap(int userId) async {
    final q = 'SELECT sports_equipment_js FROM ${DbNames.T_UserPersonalData} WHERE user_id = $userId;';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if(cursor == null || cursor.isEmpty) {
      return null;
    }

    return cursor[0].toList()[0];
  }

  static Future<bool> upsertJobActivity(int userId, Map jobActivityJs) async{
    final jobActivity = CommonMethods.castToJsonb(jobActivityJs);

    final q = '''
      INSERT INTO ${DbNames.T_UserPersonalData} (user_id, job_activity_js)
        values ($userId, $jobActivity')
      ON CONFLICT (user_id) DO UPDATE
       SET job_activity_js = $jobActivity';
    ''';

    final effected = await PublicAccess.psql2.execution(q);

    return (effected != null && effected > 0);
  }

  static Future<bool> upsertJobActivityByMerge(int userId, Map newJob) async{
    final jobMap = (await fetchJobActivityMap(userId))?? {};
    JsonHelper.mergeUnNull(jobMap, newJob);

    final jobActivity = CommonMethods.castToJsonb(jobMap);

    final q = '''
      INSERT INTO ${DbNames.T_UserPersonalData} (user_id, job_activity_js)
        values ($userId, $jobActivity)
      ON CONFLICT (user_id) DO UPDATE
       SET job_activity_js = $jobActivity;
    ''';

    final effected = await PublicAccess.psql2.execution(q);

    return (effected != null && effected > 0);
  }

  static Future<Map<String, dynamic>> getUserSportsEquipmentJs(int userId) async {
    final map = await PersonalDataModelDb.fetchSportsEquipmentMap(userId);

    if (map == null) {
      return <String, dynamic>{};
    }

    final res = <String, dynamic>{};
    res['sports_equipment_js'] = map;

    return res;
  }

  static Future<Map<String, dynamic>> getUserHealthConditionJs(int userId) async {
    final map = await PersonalDataModelDb.fetchHealthConditionMap(userId);

    if (map == null) {
      return <String, dynamic>{};
    }

    final res = <String, dynamic>{};
    res['health_condition_js'] = map;

    return res;
  }

  static Future<Map<String, dynamic>> getUserJobActivityJs(int userId) async {
    final map = await PersonalDataModelDb.fetchJobActivityMap(userId);

    if (map == null) {
      return <String, dynamic>{};
    }

    final res = <String, dynamic>{};
    res['job_activity_js'] = map;

    return res;
  }

  static Future<bool> upsertUserSportsEquipment(int userId, String? homeEq, String? gymEq) async{
    homeEq = Converter.multiLineToSqlWt(homeEq);
    gymEq = Converter.multiLineToSqlWt(gymEq);

    if(homeEq != null){
      homeEq = '"$homeEq"';
    }

    if(gymEq != null){
      gymEq = '"$gymEq"';
    }

    final q = '''
      INSERT INTO #tb (user_id, sports_equipment_js)
        values ($userId, '{"gym_tools": $gymEq, "home_tools": $homeEq}')
      ON CONFLICT (user_id) DO UPDATE
       SET sports_equipment_js = jsonb_set(
          jsonb_set(COALESCE(#tb.sports_equipment_js, '{}'), '{gym_tools}', '$gymEq')
           , '{home_tools}', '$homeEq');
    '''
        .replaceAll('#tb', DbNames.T_UserPersonalData);

    final effected = await PublicAccess.psql2.execution(q);

    if(effected != null && effected > 0) {
      return true;
    }

    return false;
  }

  // upsertUserHealthCondition(100, [] , 'ill have', 'yes no');
  static Future<bool> upsertUserHealthCondition(int userId, HealthConditionModel model) async {
    // var illStrings = illList.map((e) => e as String).toList();
    final illList = ListHelper.listToSequence(model.illList);
    final illDescription = Converter.multiLineToSqlWt(model.illDescription?? '')!;
    final medications = Converter.multiLineToSqlWt(model.illMedications??'')!;

    final q = '''
      INSERT INTO ${DbNames.T_UserPersonalData} (user_id, health_condition_js)
        values ($userId, '{"ill_list": [$illList], "ill_description": "$illDescription", "ill_medications": "$medications"}')
      ON CONFLICT (user_id) DO UPDATE
       SET health_condition_js = coalesce(${DbNames.T_UserPersonalData}.health_condition_js, '{}'::jsonb) || '{"ill_list": [$illList], "ill_description": "$illDescription", "ill_medications": "$medications"}';
    ''';

    final effected = await PublicAccess.psql2.execution(q);

    if(effected != null && effected > 0) {
      return true;
    }

    return false;
  }

  static Future<bool> upsertUserJobType(int userId, String jobType) async{
    final q = '''
      INSERT INTO ${DbNames.T_UserPersonalData} (user_id, job_activity_js)
        values ($userId, '{"job_type": "$jobType"}')
      ON CONFLICT (user_id) DO UPDATE
       SET job_activity_js = coalesce(${DbNames.T_UserPersonalData}.job_activity_js, '{}'::jsonb) || '{"job_type": "$jobType"}';
    ''';

    final effected = await PublicAccess.psql2.execution(q);

    if(effected != null && effected > 0) {
      return true;
    }

    return false;
  }

  static Future<bool> upsertUserNonWorkActivity(int userId, String nonWork) async{
    final q = '''
      INSERT INTO #tb (user_id, job_activity_js)
        values ($userId, '{"none_work_activity": "$nonWork"}')
      ON CONFLICT (user_id) DO UPDATE
       SET job_activity_js = coalesce(#tb2.job_activity_js, '{}'::jsonb) || '{"none_work_activity": "$nonWork"}';
    '''
        .replaceFirst('#tb', DbNames.T_UserPersonalData)
        .replaceFirst('#tb2', DbNames.T_UserPersonalData);

    final effected = await PublicAccess.psql2.execution(q);

    if(effected != null && effected > 0) {
      return true;
    }

    return false;
  }

  static Future<bool> upsertUserSleepStateProfile(int userId, int atDay, int atNight) async {
    var q = '''
      INSERT INTO ${DbNames.T_UserPersonalData} (user_id, job_activity_js)
        values ($userId, '{"sleep_hours_at_day": $atDay, "sleep_hours_at_night": $atNight}'::jsonb)
      ON CONFLICT (user_id) DO UPDATE
       SET job_activity_js = coalesce(${DbNames.T_UserPersonalData}.job_activity_js, '{}'::jsonb) || '{"sleep_hours_at_day": $atDay, "sleep_hours_at_night": $atNight}';
    ''';

    var effected = await PublicAccess.psql2.execution(q);

    if(effected != null && effected > 0) {
      return true;
    }

    return false;
  }

  static Future<bool> upsertUserExerciseState(int userId, int exerciseHours) async{
    var q = '''
      INSERT INTO ${DbNames.T_UserPersonalData} (user_id, job_activity_js)
        values ($userId, '{"exercise_hours": $exerciseHours}')
      ON CONFLICT (user_id) DO UPDATE
       SET job_activity_js = coalesce(${DbNames.T_UserPersonalData}.job_activity_js, '{}'::jsonb) || '{"exercise_hours": $exerciseHours}';
    ''';

    var effected = await PublicAccess.psql2.execution(q);

    if(effected != null && effected > 0) {
      return true;
    }

    return false;
  }

  static Future<bool> upsertUserGoalOfFitness(int userId, String goalOfFitness) async{
    var q = '''
      INSERT INTO ${DbNames.T_UserPersonalData} (user_id, job_activity_js)
        values ($userId, '{"goal_of_fitness": "$goalOfFitness"}')
      ON CONFLICT (user_id) DO UPDATE
       SET job_activity_js = coalesce(${DbNames.T_UserPersonalData}.job_activity_js, '{}'::jsonb) || '{"goal_of_fitness": "$goalOfFitness"}';
    ''';

    var effected = await PublicAccess.psql2.execution(q);

    if(effected != null && effected > 0) {
      return true;
    }

    return false;
  }

}
