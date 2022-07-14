import 'package:assistance_kit/api/helpers/textHelper.dart';
import 'package:assistance_kit/api/helpers/urlHelper.dart';
import 'package:brandfit_server/app/pathNs.dart';
import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';

/// note: insert relative path no full path [for where]

class UserImageModelDb extends DbModel {
  late int user_id;
  late int type;
  String? imagePath;
  String? date;

  //type:
  // 1: Avatar,
  // 2: Certificate Face
  // 3: Biography
  static final String QTbl_UserImages = '''
		CREATE TABLE IF NOT EXISTS #tb (
       user_id BIGINT NOT NULL,
       type SMALLINT NOT NULL,
       image_path varchar(400) NOT NULL,
       date_of TIMESTAMP DEFAULT (now() at time zone 'utc'),
       CONSTRAINT fk1_#tb FOREIGN KEY (user_id) REFERENCES #ref (user_id)
      		ON DELETE CASCADE ON UPDATE CASCADE,
       CONSTRAINT fk2_#tb FOREIGN KEY (type) REFERENCES #ref2 (Key)
      		ON DELETE RESTRICT ON UPDATE CASCADE
      )
      PARTITION BY RANGE (user_id);
			'''
      .replaceAll('#tb', DbNames.T_UserImages)
      .replaceFirst('#ref', DbNames.T_Users)
      .replaceFirst('#ref2', DbNames.T_TypeForUserImage);

  static final String QIdx_UserImages$type = '''
		CREATE INDEX IF NOT EXISTS #tb_type_ix ON #tb
		USING BTREE (type);
		'''
      .replaceAll('#tb', DbNames.T_UserImages);

  static final String QTbl_UserImages$p1 = '''
      CREATE TABLE IF NOT EXISTS #tb_p1
      PARTITION OF #tb FOR VALUES FROM (0) TO (250000);
      '''
      .replaceAll('#tb', DbNames.T_UserImages);

  static final String QTbl_UserImages$p2 = '''
      CREATE TABLE IF NOT EXISTS #tb_p2
      PARTITION OF #tb FOR VALUES FROM (250000) TO (500000);
      '''
      .replaceAll('#tb', DbNames.T_UserImages);

  /* no need unique
  static final String QAltUk1_UserImages$p1 = '''
		DO \$\$ BEGIN ALTER TABLE #tb_p1
     ADD CONSTRAINT uk1_#tb_p1 UNIQUE (user_id, type);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM;
        END IF; END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_UserImages);

  static final String QAltUk1_UserImages$p2 = '''
		DO \$\$ BEGIN ALTER TABLE #tb_p2
     ADD CONSTRAINT uk1_#tb_p2 UNIQUE (user_id, type);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM;
        END IF; END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_UserImages);*/


  UserImageModelDb();

  @override
  UserImageModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    user_id = map[Keys.userId];
    type = map[Keys.type];
    imagePath = map[Keys.imagePath];
    date = map['date_of'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.userId] = user_id;
    map[Keys.type] = type;
    map[Keys.imagePath] = imagePath;
    map['date_of'] = date;

    return map;
  }

  void changePathForClient(){
    if(imagePath != null) {
      imagePath = PathsNs.genUrlDomainFromLocalPathByDecoding(PublicAccess.domain, PathsNs.getCurrentPath(), imagePath!);
    }
  }

  void changePathForDb(){
    if(imagePath != null) {
      imagePath = PathsNs.encodeFilePathForDataBase(imagePath!);
    }
  }

  static Future<Map<String, dynamic>?> fetchFirst(int userId, int type) async {
    final q = '''SELECT * FROM ${DbNames.T_UserImages} WHERE user_id = $userId AND type = $type;''';
    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return null;
    }

    return cursor.elementAt(0).toMap() as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>?>> fetch(int userId, int type) async {
    final q = '''SELECT * FROM ${DbNames.T_UserImages} WHERE user_id = $userId AND type = $type;''';
    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return [];
    }

    return cursor.map((elm){
      return elm.toMap() as Map<String, dynamic>;
    }).toList();
  }

  static Future<bool> upsertUserImage(int userId, int type, String rawPath) async{
    final q = 'SELECT image_path FROM ${DbNames.T_UserImages} WHERE user_id = $userId AND type = $type;';
    final oldPath = await PublicAccess.psql2.getColumn(q, 'image_path');

    final value = [
      userId,
      type,
      PathsNs.encodeFilePathForDataBaseRelative(rawPath)
    ];

    final x = await PublicAccess.psql2.upsertWhere(DbNames.T_UserImages, ['user_id', 'type', 'image_path'], value,
        where: ' type = $type AND user_id = $userId');

    if(x != null && x > 0) {
      if(!TextHelper.isEmptyOrNull(oldPath)) {
        // no need to deCode, because again insert to DB
        PublicAccess.insertEncodedPathToJunkFile(oldPath);
      }

      return true;
    }

    return false;
  }

  static Future<bool> addUserImage(int userId, int type, String rawPath) async{
    final value = [
      userId,
      type,
      PathsNs.encodeFilePathForDataBaseRelative(rawPath)
    ];

    final x = await PublicAccess.psql2.insert(DbNames.T_UserImages, ['user_id', 'type', 'image_path'], value);
    return x != null && x > 0;
  }

  static Future<bool> deleteUserImageByType(int userId, int type) async {
    final q = 'SELECT image_path FROM ${DbNames.T_UserImages} WHERE user_id = $userId AND type = $type;';
    final oldRelPath = await PublicAccess.psql2.getColumn(q, 'image_path');

    final x = await PublicAccess.psql2.delete(DbNames.T_UserImages, 'user_id = $userId AND type = $type');

    if(x != null && x > 0){
      if(!TextHelper.isEmptyOrNull(oldRelPath)) {
        final deCode = UrlHelper.decodePathFromDataBase(oldRelPath)!;
        var p = PathsNs.addBasePathToLocalPath(deCode)!;

        p = PathsNs.encodeFilePathForDataBase(p)!;
        PublicAccess.insertEncodedPathToJunkFile(p);
      }

      return true;
    }

    return false;
  }

  static Future<bool> deleteUserImageByUrl(int userId, int type, String url) async{
    var deCode = UrlHelper.decodeUrl(url)!;

    var relPath = UrlHelper.removeDomain(deCode)!;
    relPath = UrlHelper.encodeUrl(relPath)!;

    final where = "user_id = $userId AND type = $type AND image_path = '$relPath'";

    final q = 'SELECT image_path FROM ${DbNames.T_UserImages} WHERE $where;';

    final oldRelPath = await PublicAccess.psql2.getColumn(q, 'image_path');

    final x = await PublicAccess.psql2.delete(DbNames.T_UserImages, where);

    if(x != null && x > 0){
      if(!TextHelper.isEmptyOrNull(oldRelPath)) {
        final deCode = UrlHelper.decodePathFromDataBase(oldRelPath)!;
        var p = PathsNs.addBasePathToLocalPath(deCode)!;

        p = PathsNs.encodeFilePathForDataBase(p)!;
        PublicAccess.insertEncodedPathToJunkFile(p);
      }

      return true;
    }

    return false;
  }

  static Future<bool> deleteUserImageByDate(int userId, int type, String date) async{
    final where = "user_id = $userId AND type = $type AND date_of = '$date'";

    final q = 'SELECT image_path FROM ${DbNames.T_UserImages} WHERE $where;';
    final oldRelPath = await PublicAccess.psql2.getColumn(q, 'image_path');

    final x = await PublicAccess.psql2.delete(DbNames.T_UserImages, where);

    if(x != null && x > 0){
      if(!TextHelper.isEmptyOrNull(oldRelPath)) {
        final deCode = UrlHelper.decodePathFromDataBase(oldRelPath)!;
        var p = PathsNs.addBasePathToLocalPath(deCode)!;

        p = PathsNs.encodeFilePathForDataBase(p)!;
        PublicAccess.insertEncodedPathToJunkFile(p);
      }

      return true;
    }

    return false;
  }
  //-----------------------------------------------------------------------------------------------
  Map<String, dynamic> _toMapForClient() {
    final res = <String, dynamic>{};

    res[Keys.userId] = user_id;
    res[Keys.profileImageUri] = imagePath;

    return res;
  }

  static Future<Map<String, dynamic>?> fetchProfileImageMap(int userId) async {
    final map = await UserImageModelDb.fetchFirst(userId, 1);

    if (map == null) {
      return null;
    }

    return map;
    //var res = UserImageDbModel.fromMap(m as Map<String, dynamic>);
    //res.changePathForClient();
    //return res.toMapForClient();
  }

  static Future<Map<String, dynamic>> getProfileImage(int userId) async {
    final map = await UserImageModelDb.fetchProfileImageMap(userId);

    if (map == null) {
      return <String, dynamic>{};
    }

    var res = UserImageModelDb.fromMap(map);
    res.changePathForClient();

    /*var res = <String, String?>{};
    res['profile_image_uri'] = image_path;*/

    return res._toMapForClient();
  }

  static Future<bool> deleteProfileImage(int userId, int type) async {
    final q = 'SELECT image_path FROM ${DbNames.T_UserImages} WHERE user_id = $userId AND type = $type;';
    final oldRelPath = await PublicAccess.psql2.getColumn(q, 'image_path');

    final x = await PublicAccess.psql2.delete(DbNames.T_UserImages,' type = $type AND user_id = $userId');

    if(x != null && x > 0) {
      if(!TextHelper.isEmptyOrNull(oldRelPath)) {
        final deCode = UrlHelper.decodePathFromDataBase(oldRelPath)!;
        var p = PathsNs.addBasePathToLocalPath(deCode)!;

        p = PathsNs.encodeFilePathForDataBase(p)!;
        PublicAccess.insertEncodedPathToJunkFile(p);
      }

      return true;
    }

    return false;
  }

}
