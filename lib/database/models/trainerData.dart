import 'package:brandfit_server/app/pathNs.dart';
import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/database/models/userImage.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';

class TrainerDataModelDb extends DbModel {
  late int user_id;
  late int rank;
  bool is_exercise = false;
  bool is_food = false;
  bool broadcastCourse = false;
  String? bio;


  static final String QTbl_TrainerData = '''
    CREATE TABLE IF NOT EXISTS #tb (
       user_id BIGINT NOT NULL,
       rank INT DEFAULT 0,
       is_exercise BOOL DEFAULT FALSE,
       is_food BOOL DEFAULT FALSE,
       broadcast_course BOOL DEFAULT FALSE,
       bio varchar(5500) DEFAULT NULL,
      CONSTRAINT pk_#tb PRIMARY KEY (user_id)
      );'''
      .replaceAll('#tb', DbNames.T_TrainerData);


  @override
  TrainerDataModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    user_id = map[Keys.userId];
    rank = map['rank'];
    is_exercise = map['is_exercise'];
    is_food = map['is_food'];
    //cardNumber = map['card_number'];
    broadcastCourse = map['broadcast_course'];
    bio = map['bio'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.userId] = user_id;
    map['rank'] = rank;
    map['is_exercise'] = is_exercise;
    map['is_food'] = is_food;
    //map['card_number'] = cardNumber;
    map['broadcast_course'] = broadcastCourse;
    map['bio'] = bio;

    return map;
  }

  static Future<bool> insertModel(TrainerDataModelDb model) async {
    final modelMap = model.toMap();
    return insertModelMap(modelMap);
  }

  static Future<bool> insertModelMap(Map<String, dynamic> userMap) async {
    final x = await PublicAccess.psql2.insertKv(DbNames.T_TrainerData, userMap);

    return !(x == null || x < 1);
  }

  static Future<Map<String, dynamic>?> fetchMap(int userId) async {
    final q = 'SELECT * FROM ${DbNames.T_TrainerData} WHERE user_id = $userId;';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if(cursor == null || cursor.isEmpty){
      return null;
    }

    return cursor[0].toMap() as Map<String, dynamic>;
  }

  static Future<bool> upsertState(int userId, bool isExercise, bool isFood) async {
    final value = <String, dynamic>{};
    value[Keys.userId] = userId;
    value['is_exercise'] = isExercise;
    value['is_food'] = isFood;

    final effected = await PublicAccess.psql2.upsertWhereKv(DbNames.T_TrainerData, value, where: ' user_id = $userId');

    return (effected != null && effected > 0);
  }

  static Future<dynamic> getBiography(int userId) async {
    final query = '''SELECT bio FROM ${DbNames.T_TrainerData} WHERE user_id = $userId; ''';

    return PublicAccess.psql2.getColumn(query, 'bio');
  }

  static Future<bool> upsertBiography(int userId, String? bio) async {
    final value = <String, dynamic>{};
    value[Keys.userId] = userId;
    value['bio'] = bio;

    final effected = await PublicAccess.psql2.upsertWhereKv(DbNames.T_TrainerData, value, where: ' user_id = $userId');

    return (effected != null && effected > 0);
  }

  static Future<List<String>> getBioPhotos(int userId) async {
    final List<Map?> res = await UserImageModelDb.fetch(userId, 3);

    if(res.isEmpty){
      return [];
    }

    return res.map((e) {
      var p = e!['image_path'] as String;
      PathsNs.genUrlFromLocalPathByDecodingNoDomain(PathsNs.getCurrentPath(), p);
      return p;
    }).toList();
  }

  static Future<bool> addBioPhoto(int userId, String path) async {
    return await UserImageModelDb.addUserImage(userId, 3, path);
  }

  static Future<bool> deleteBioPhoto(int userId, String url) async {
    return await UserImageModelDb.deleteUserImageByUrl(userId, 3, url);
  }

  /*static Future<bool> setCardNumber(int userId, String cn) async {
    final value = <String, dynamic>{};
    value[Keys.userId] = userId;
    value['card_number'] = cn;

    final effected = await PublicAccess.psql2.upsertWhereKv(DbNames.T_TrainerData, value, where: ' user_id = $userId');

    return (effected != null && effected > 0);
  }*/

  static Future<bool> changeCourseBroadcastState(int userId, bool broadcast) async {
    final value = <String, dynamic>{};
    value[Keys.userId] = userId;
    value['broadcast_course'] = broadcast;

    final effected = await PublicAccess.psql2.upsertWhereKv(DbNames.T_TrainerData, value, where: ' user_id = $userId');

    return (effected != null && effected > 0);
  }

  static Future<bool> changeTrainerState(int userId, bool isExercise, bool isFood) async {
    final value = <String, dynamic>{};
    value[Keys.userId] = userId;
    value['is_exercise'] = isExercise;
    value['is_food'] = isFood;

    final effected = await PublicAccess.psql2.upsertWhereKv(DbNames.T_TrainerData, value, where: ' user_id = $userId');

    return (effected != null && effected > 0);
  }

}
