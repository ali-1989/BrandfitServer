import 'package:assistance_kit/api/helpers/boolHelper.dart';
import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/database/psql2.dart';
import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/database/queryList.dart';
import 'package:brandfit_server/database/querySelector.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/queryFiltering.dart';

class FoodMaterialModelDb extends DbModel {
  int? id;
  int creator_id = 0;
  String? title;
  List<String> alternatives = [];
  String? language;
  String? type;
  List fundamentals_js = []; // [ {'key': 'protein', 'value': 100}, ...]
  Map measure_js = {};
  bool can_show = true;
  String? register_date;
  String? path;

  static final String QTbl_FoodMaterial = '''
  CREATE TABLE IF NOT EXISTS #tb (
       id SERIAL,
       title varchar(100) NOT NULL,
       alternatives Text[] DEFAULT '{}'::Text[],
       language varchar(6) NOT NULL,
       type varchar(30) DEFAULT NULL,
       fundamentals_js JsonB NOT NULL DEFAULT '{}'::JsonB,
       measure_js JsonB NOT NULL DEFAULT '{}'::JsonB,
       can_show BOOLEAN DEFAULT TRUE,
       creator_id BIGINT NOT NULL,
       register_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
       path varchar(400) DEFAULT NULL,
       CONSTRAINT pk_#tb PRIMARY KEY (id),
       CONSTRAINT uk1_#tb UNIQUE (title)
      );
      '''.replaceAll('#tb', DbNames.T_FoodMaterial);

  static final String QIdx_FoodMaterial$alternatives = '''
  CREATE INDEX IF NOT EXISTS #tb_alternatives_idx
  ON #tb USING GIN (alternatives);
  '''.replaceAll('#tb', DbNames.T_FoodMaterial); // jsonb_ops,


  static final String QTbl_FoodMaterialTranslate = '''
  CREATE TABLE IF NOT EXISTS #tb (
       link_id int NOT NULL,
       language varchar(6) NOT NULL,
       title varchar(100) NOT NULL,
       CONSTRAINT pk_#tb PRIMARY KEY (link_id, language)
      );'''.replaceAll('#tb', DbNames.T_FoodMaterialTranslate);

  FoodMaterialModelDb();

  @override
  FoodMaterialModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    id = map['id'];
    creator_id = map['creator_id']?? 0;
    title = map['title'];
    alternatives = map['alternatives'];
    language = map['language'];
    type = map['type']?? 5;
    can_show = map['can_show']?? true;
    register_date = map['register_date'];
    path = map['path'];
    fundamentals_js = map['fundamentals_js']?? [];
    measure_js = map['measure_js']?? {};
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    if(id != null) {
      map['id'] = id;
    }

    map['creator_id'] = creator_id;
    map['title'] = title;
    map['alternatives'] = alternatives;
    map['language'] = language;
    map['type'] = type;
    map['can_show'] = can_show;
    map['register_date'] = register_date;
    map['path'] = path;
    map['fundamentals_js'] = fundamentals_js;
    map['measure_js'] = measure_js;

    return map;
  }

  static Future<List<Map<String, dynamic>?>> fetchMap(int id) async {
    final q = '''SELECT * FROM ${DbNames.T_FoodMaterial} WHERE id = $id; ''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<bool> upsertModel(FoodMaterialModelDb model) async {
    final kv = model.toMap();

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_FoodMaterial, kv,
        where: ' id = ${model.id}');

    return cursor != null && cursor > 0;
  }
  ///----------------------------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> searchOnFoodMaterial(Map<String, dynamic> jsOption) async {
    final fq = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    replace['LIMIT x'] = 'LIMIT ${fq.limit}';

    qSelector.addQuery(QueryList.foodMaterial_q1(fq));

    final listOrNull = await PublicAccess.psql2.queryCall(qSelector.generate(0, replace));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return listOrNull.map((e) {
      return e.toMap() as Map<String, dynamic>;
    }).toList();
  }

  static Future<Map<String, dynamic>> getFoodMaterialItem(int id) async {
    var q = '''
    With c1 AS(
          SELECT id, title, alternatives, type, register_date,
                 fundamentals_js, language, can_show, path AS image_uri
          FROM FoodMaterial
          WHERE id = #id
          ),
     c2 AS
         (SELECT t1.*, t2.translates FROM c1 AS t1 
         LEFT JOIN
                  (select link_id, jsonb_object_agg(language, title) AS translates
                   FROM FoodMaterialTranslate GROUP BY link_id) AS t2
                on (t1.id = t2.link_id))

  SELECT * FROM c2;
    ''';

    q = q.replaceFirst(RegExp('FoodMaterial'), '${DbNames.T_FoodMaterial}');
    q = q.replaceFirst(RegExp('FoodMaterialTranslate'), '${DbNames.T_FoodMaterialTranslate}');
    q = q.replaceFirst(RegExp('#id'), '$id');

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <String, dynamic>{};
    }

    return cursor.first.toMap() as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getFoodMaterialsByIds(Set<int> idSet) async {
    final filtering = FilterRequest();

    final listOrNull = await PublicAccess.psql2.queryCall(QueryList.foodMaterial_q2(filtering, idSet));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return listOrNull.map((e) {
      return e.toMap() as Map<String, dynamic>;
    }).toList();
  }

  static Future<bool> existFoodMaterialName(Map<String, dynamic> jsOption, String name) async {
    var q = '''
    WITH c1 AS(
        SELECT title FROM FoodMaterial WHERE title ILike '#v'
        ),
      c2 AS(
        SELECT title FROM FoodMaterialTranslate WHERE title ILike '#v'
      )

      select EXISTS(SELECT * FROM c1) OR EXISTS(SELECT * FROM c2);
    ''';

    q = q.replaceFirst(RegExp('FoodMaterial'), '${DbNames.T_FoodMaterial}');
    q = q.replaceFirst(RegExp('FoodMaterialTranslate'), '${DbNames.T_FoodMaterialTranslate}');
    q = q.replaceAll(RegExp('#v'), '$name');

    var cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return false;
    }

    return BoolHelper.itemToBool(cursor.first.toList()[0]);
  }

  static FoodMaterialModelDb createModel(
      int userId,
      String title,
      String? type,
      List<String> alternatives,
      List fundamentals,
      Map measure,
      bool canShow,
      ) {
      final res = FoodMaterialModelDb();
      res.title = title;
      res.alternatives = alternatives;
      res.fundamentals_js = fundamentals;
      res.measure_js = measure;
      res.can_show = canShow;
      res.creator_id = userId;
      res.type = type?? 'matter';

      return res;
  }

  static Future<int> addNewFoodMaterial(Map<String, dynamic> jsOption, int userId, FoodMaterialModelDb model) async {
    final lan = await PublicAccess.detectLanguage(model.title!);

    //smpl: database
    final kv = model.toMap();
    kv['language'] = lan;
    kv['alternatives'] = Psql2.listToPgTextArray(model.alternatives);
    kv['fundamentals_js'] = Psql2.castToJsonb(model.fundamentals_js);
    kv['measure_js'] = "'${JsonHelper.mapToJson(model.measure_js)}'::jsonb";//same as above

    JsonHelper.removeKeys(kv, ['id']);

    if(model.register_date == null) {
      JsonHelper.removeKeys(kv, ['register_date']);
    }

    final res = await PublicAccess.psql2.insertKvReturning(DbNames.T_FoodMaterial, kv, 'id');

    var id;
    if(res != null && res.isNotEmpty){
      id = res[0].toList()[0];
    }

    if (id == null || id < 1) {
      return -1;
    }

    await insertFoodTranslate(id, model.title!, lan);

    return id;
  }

  static Future<bool> isUsageFromFoodMaterialInPrograms(int id) async {
    return await PublicAccess.psql2.existQuery(QueryList.foodMaterial_q4(id));
  }

  static Future<bool> deleteFoodMaterial(Map<String, dynamic> jsOption, int id) async {
    final res = await PublicAccess.psql2.delete(DbNames.T_FoodMaterial, ' id = $id');
    return res != null && res > 0;
  }

  static Future<bool?> updateFoodMaterialTitle(Map<String, dynamic> jsOption, int id, String title) async {
    final exist = await existFoodMaterialName(jsOption, title);

    if(exist){
      return null;
    }

    final lan = await PublicAccess.detectLanguage(title);

    final kv = <String, dynamic>{};
    kv[Keys.title] = title;
    kv['Language'] = lan;

    final res = await PublicAccess.psql2.updateKv(DbNames.T_FoodMaterial, kv, ' id = $id');

    if(res != null && res > 0){
      await PublicAccess.psql2.delete(DbNames.T_FoodMaterialTranslate, ' link_id = $id');
      await insertFoodTranslate(id, title, lan);
      return true;
    }

    return false;
  }

  static Future<bool> updateFoodMaterialAlternatives(Map<String, dynamic> jsOption, int id, List alt) async {
    final kv = <String, dynamic>{};
    kv['alternatives'] = Psql2.listToPgTextArray(alt);

    final res = await PublicAccess.psql2.updateKv(DbNames.T_FoodMaterial, kv, ' id = $id');
    return res != null && res > 0;
  }

  static Future<bool> updateFoodMaterialFundamentals(int id, List fundamentals, Map? measure) async {

    final kv = <String, dynamic>{};
    kv['fundamentals_js'] = Psql2.castToJsonb(fundamentals);

    if(measure != null) {
      kv['measure_js'] = Psql2.castToJsonb(measure);
    }

    final res = await PublicAccess.psql2.updateKv(DbNames.T_FoodMaterial, kv, ' id = $id');
    return res != null && res > 0;
  }

  static Future<bool?> updateFoodMaterialCanShow(Map<String, dynamic> jsOption, int id, bool state) async {
    if(state){
      final res = await PublicAccess.psql2.existQuery(QueryList.foodMaterial_q3(id));

      if(!res){
        return null;
      }
    }

    final kv = <String, dynamic>{};
    kv['can_show'] = state;

    final res = await PublicAccess.psql2.updateKv(DbNames.T_FoodMaterial, kv, ' id = $id');
    return res != null && res > 0;
  }

  static Future<void> insertFoodTranslate(int linkId, String title, String curLan) async {
    final kv = <String, dynamic>{};
    kv['link_id'] = linkId;

    final languages = <String>['en', 'fa'];

    for(var lan in languages){
      if(curLan == lan){
        continue;
      }

      try {
        final res = await PublicAccess.translator.translate(' $title ', to: lan);
        kv['language'] = lan;
        kv[Keys.title] = res.text;

        await PublicAccess.psql2.upsertWhereKv(DbNames.T_FoodMaterialTranslate, kv,
            where: "link_id = $linkId AND language = '$lan'");
      }
      catch(e){
        PublicAccess.logInDebug('@@ err > insert food Translate: $e');
      }
    }
  }
}
