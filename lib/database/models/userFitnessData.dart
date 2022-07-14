import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:brandfit_server/app/pathNs.dart';
import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/models/enums.dart';
import 'package:brandfit_server/publicAccess.dart';

class UserFitnessDataModelDb extends DbModel {
  late int user_id;
  String? nodes_js;


  /// node: weight_node[], height_node[], Side_photo_node[], FrontPhoto[], ...Node[]
  static final String QTbl_UserFitnessData = '''
		CREATE TABLE IF NOT EXISTS #tb (
      user_id BIGINT NOT NULL,
      nodes_js JSONB NOT NULL,
      CONSTRAINT pk_#tb PRIMARY KEY (user_id)
       ) 
       PARTITION BY RANGE (user_id) WITH (OIDS = FALSE);
			'''
      .replaceAll('#tb', DbNames.T_UserFitnessData);

  static final String crIdx_UserFitnessData_nodes_js = '''
		CREATE INDEX IF NOT EXISTS #tb_nodes_js_idx ON #tb
		USING GIN ((nodes_js) jsonb_path_ops);
		'''
      .replaceAll('#tb', DbNames.T_UserFitnessData);

  static final String QTbl_UserFitnessData$p1 = '''
      CREATE TABLE IF NOT EXISTS #tb_p1
      PARTITION OF #tb FOR VALUES FROM (0) TO (250000);
      '''
      .replaceAll('#tb', DbNames.T_UserFitnessData);

  static final String QTbl_UserFitnessData$p2 = '''
      CREATE TABLE IF NOT EXISTS #tb_p2
      PARTITION OF #tb FOR VALUES FROM (250000) TO (500000);
      '''
      .replaceAll('#tb', DbNames.T_UserFitnessData);


  UserFitnessDataModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    user_id = map[Keys.userId];
    nodes_js = map['nodes_js'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.userId] = user_id;
    map['nodes_js'] = nodes_js;

    return map;
  }

  // {'weight_node': [], 'front_image_node': [], ...}
  static Future<Map<String, dynamic>?> fetchMap(int userId) async {
    final q = 'SELECT nodes_js FROM ${DbNames.T_UserFitnessData} WHERE user_id = $userId;';
    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return null;
    }

    return cursor.elementAt(0).toMap() as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getUserFitnessStatusJs(int userId) async {
    final map = await UserFitnessDataModelDb.fetchMap(userId);

    if (map == null) {
      return <String, dynamic>{};
    }

    final res = <String, dynamic>{};
    res['fitness_status_js'] = map['nodes_js'];

    return res;
  }

  static Future<List<Map<String, dynamic>>> getUserFitnessNode(int userId, String nodeSection) async {
    final q = '''SELECT nodes_js->'$nodeSection' as c1 FROM ${DbNames.T_UserFitnessData} WHERE user_id = $userId;''';
    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    var m = cursor.elementAt(0).toMap();
    var list = m['c1'] as List;

    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  static Map<String, dynamic> _generateFitnessData(dynamic value, {String? utcDate}){
    return {Keys.value: value, Keys.date: utcDate?? DateHelper.getTimestampUtcWithoutMill()};
  }

  static Map<String, dynamic> _generatePhotoData(String uri, {String? utcDate}){
    return {Keys.imageUri: uri, Keys.date: utcDate?? DateHelper.getTimestampUtcWithoutMill()};
  }

  // upsertUserFitnessStatus(100, 'weight_node', 40);
  static Future<bool> upsertUserFitnessStatus(int userId, NodeNames node, dynamic value) async {
    final nodeName = node.name;
    final iNode = _generateFitnessData(value);
    final data = JsonHelper.mapToJson(iNode);
    final ts = iNode[Keys.date];

    final q = '''
      call replaceFitnessNodeItem('$ts', '$data', '$nodeName', $userId, 0);
    ''';

    final cursor = await PublicAccess.psql2.queryCall(q);
    final val = await PublicAccess.psql2.getCursorValue(cursor, 'res');

    if(val != null && val > 0) {
      return true;
    }

    return false;
  }

  static Future<bool> deleteUserFitnessStatus(int userId, String nodeName, String ts, dynamic value) async{
    final q = '''
      call deleteFitnessNodeItemByDate('$ts', '$nodeName', $userId, 0);
    ''';

    final cursor = await PublicAccess.psql2.queryCall(q);
    final val = await PublicAccess.psql2.getCursorValue(cursor, 'res');

    if(val != null && val > 0) {
      return true;
    }

    return false;
  }

  static Future<bool> upsertUserFitnessImage(int userId, String node, String uri) async {
    final iNode = _generatePhotoData(uri);
    final data = JsonHelper.mapToJson(iNode);

    final q = '''
      INSERT INTO ${DbNames.T_UserFitnessData} (user_id, nodes_js)
        values ($userId, '{"$node": [$data]}')
      ON CONFLICT (user_id) DO UPDATE
       SET nodes_js = jsonb_set(${DbNames.T_UserFitnessData}.nodes_js, '{"$node"}',
        coalesce(${DbNames.T_UserFitnessData}.nodes_js->'$node', '[]'::jsonb) || '$data'::jsonb);
    ''';

    final effected = await PublicAccess.psql2.execution(q);

    if(effected != null && effected > 0) {
      return true;
    }

    return false;
  }

  static Future<bool> deleteUserFitnessImage(int userId, String nodeName, String ts, String uri) async{
    final old = await getUserFitnessNode(userId, nodeName);

    final q = '''
      call deleteFitnessNodeItemByKey('${Keys.date}', '$ts', '$nodeName', $userId, 0);
    ''';

    final cursor = await PublicAccess.psql2.queryCall(q);
    final val = await PublicAccess.psql2.getCursorValue(cursor, 'res');

    if(val != null && val > 0) {
      for(var itm in old){
        if(itm[Keys.date] == ts){
          var pat = PathsNs.uriToPath(uri);
          pat = PathsNs.encodeFilePathForDataBase(pat)!;
          PublicAccess.insertEncodedPathToJunkFile(pat);
        }
      }

      return true;
    }

    return false;
  }

}
