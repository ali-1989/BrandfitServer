import 'package:assistance_kit/database/psql2.dart';
import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/database/queryList.dart';
import 'package:brandfit_server/publicAccess.dart';

class ProgramSuggestionModelDb extends DbModel {
  int? id;
  int program_id = 0;
  int program_tree_id = 0;
  List<Map> materials_js = [];
  List<Map> used_materials_js = [];

  static final String QTbl_ProgramSuggestion = '''
  CREATE TABLE IF NOT EXISTS #tb (
       id BIGSERIAL,
       program_id BIGINT NOT NULL,
       program_tree_id BIGINT NOT NULL,
       materials_js JsonB DEFAULT '[]'::JsonB,
       used_materials_js JsonB DEFAULT NULL,
       
       CONSTRAINT pk_#tb PRIMARY KEY (id),
       CONSTRAINT fk1_#tb FOREIGN KEY (program_id) REFERENCES #ref1 (id)
        ON DELETE CASCADE ON UPDATE CASCADE,
       CONSTRAINT fk2_#tb FOREIGN KEY (program_tree_id) REFERENCES #ref2 (id)
        ON DELETE CASCADE ON UPDATE CASCADE
      );
      '''.replaceAll('#tb', DbNames.T_ProgramSuggestion)
      .replaceAll('#ref1', DbNames.T_FoodProgram)
      .replaceAll('#ref2', DbNames.T_FoodProgramTree);

  static final String QIdx_ProgramSuggestion$program_id = '''
  CREATE INDEX IF NOT EXISTS #tb_program_id_idx
  ON #tb USING BTREE (program_id);
  '''.replaceAll('#tb', DbNames.T_ProgramSuggestion);

  ProgramSuggestionModelDb();

  @override
  ProgramSuggestionModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    id = map['id'];
    program_id = map['program_id']?? 0;
    program_tree_id = map['program_tree_id'];
    materials_js = map['materials_js']?? [];
    used_materials_js = map['used_materials_js']?? [];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    if(id != null) {
      map['id'] = id;
    }

    map['program_id'] = program_id;
    map['program_tree_id'] = program_tree_id;
    map['materials_js'] = materials_js;
    map['used_materials_js'] = used_materials_js;

    return map;
  }

  static Future<Map<String, dynamic>?> fetchMap(int id) async {
    final q = '''SELECT * FROM ${DbNames.T_ProgramSuggestion} WHERE id = $id; ''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <String, dynamic>{};
    }

    return cursor.first as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>?>> fetchMapByProgram(int programId) async {
    final q = '''SELECT * FROM ${DbNames.T_ProgramSuggestion} WHERE program_id = $programId; ''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<bool> upsertModel(ProgramSuggestionModelDb model) async {
    final kv = model.toMap();

    final cursor = await PublicAccess.psql2.upsertWhereKv(
        DbNames.T_ProgramSuggestion,
        kv,
        where: ' id = ${model.id}'
    );

    return cursor != null && cursor > 0;
  }
  ///----------------------------------------------------------------------------------------
  static Future<List<Map>> getProgramSuggestions(int parentId) async {
    var suggestionList = <Map>[];

    final listOrNull = await PublicAccess.psql2.queryCall(QueryList.foodSuggestion_q1(parentId));

    if(listOrNull != null && listOrNull.isNotEmpty){
      suggestionList = listOrNull.map((e) {
        return e.toMap();
      }).toList();
    }

    return suggestionList;
  }

  static Future<bool> setReport(int programId, int suggestionId, List<Map> data) async {
    final kv = <String, dynamic>{};
    kv['used_materials_js'] = Psql2.castToJsonb(data);

    final res = await PublicAccess.psql2.updateKv(
        DbNames.T_ProgramSuggestion,
        kv,
        'program_id = $programId AND program_tree_id = $suggestionId'
    );

    return res != null && res > 0;
  }
}
