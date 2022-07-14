import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';

class UserPlaceModelDb extends DbModel {
  late int user_id;
  late String device_id;
  String? country_iso;
  String? city_name;
  int timezone_offset = 0;
  int? latitude = 0;
  int? longitude = 0;
  String? register_date;

  // this is live city/country no birthdate
  static final String QTbl_UserPlace = '''
		CREATE TABLE IF NOT EXISTS #tb (
      user_id BIGINT NOT NULL,
      device_id varchar(40) NOT NULL,
      country_iso varchar(3) DEFAULT NULL,
      timezone_offset INT DEFAULT 0,
      city_name varchar(70) DEFAULT NULL,
      latitude INT DEFAULT 0,
      longitude INT DEFAULT 0,
      register_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
      CONSTRAINT fk1_#tb FOREIGN KEY (user_id) REFERENCES #ref (user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
    )
    PARTITION BY RANGE (user_id);
			'''
      .replaceAll('#tb', DbNames.T_UserPlace)
      .replaceFirst('#ref', DbNames.T_Users);

  static final String QIdx_UserPlace$device_id = '''
	CREATE INDEX IF NOT EXISTS #tb_device_id_idx
	 ON #tb USING BTREE (device_id);
		'''
      .replaceAll('#tb', DbNames.T_UserPlace);

  static final String QTbl_UserPlace$p1 = '''
  CREATE TABLE IF NOT EXISTS #tb_p1
  PARTITION OF #tb FOR VALUES FROM (0) TO (250000);
      '''
      .replaceAll('#tb', DbNames.T_UserPlace);

  static final String QTbl_UserPlace$p2 = '''
  CREATE TABLE IF NOT EXISTS #tb_p2
  PARTITION OF #tb FOR VALUES FROM (250000) TO (500000);
      '''
      .replaceAll('#tb', DbNames.T_UserPlace);

  static final String QAltUk1_UserPlace$p1 = '''
	DO \$\$ BEGIN ALTER
	    TABLE #tb_p1 ADD CONSTRAINT uk1_#tb UNIQUE (user_id, device_id);
     EXCEPTION WHEN others THEN
      IF SQLSTATE = '42P07' THEN null;
      ELSE RAISE EXCEPTION '> %', SQLERRM;
      END IF;
     END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_UserPlace);

  static final String QAltUk1_UserPlace$p2 = '''
	DO \$\$ BEGIN 
	     ALTER TABLE #tb_p2 ADD CONSTRAINT uk1_#tb UNIQUE (user_id, device_id);
     EXCEPTION WHEN others THEN
      IF SQLSTATE = '42P07' THEN null;
      ELSE RAISE EXCEPTION '> %', SQLERRM;
      END IF;
     END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_UserPlace);

  @override
  UserPlaceModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    user_id = map[Keys.userId];
    device_id = map[Keys.deviceId];
    city_name = map['city_name'];
    timezone_offset = map['timezone_offset'];
    country_iso = map[Keys.countryIso];
    register_date = map['register_date'];
    latitude = map['latitude'];
    longitude = map['longitude'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.userId] = user_id;
    map[Keys.deviceId] = device_id;
    map['city_name'] = city_name;
    map['timezone_offset'] = timezone_offset;
    map[Keys.countryIso] = country_iso;
    map['register_date'] = register_date;
    map['latitude'] = latitude;
    map['longitude'] = longitude;

    return map;
  }

  static Future<Map<String, dynamic>?> fetchMap(int userId, String deviceId) async {
    final q = '''SELECT * FROM 
        ${DbNames.T_UserPlace} WHERE user_id = $userId AND device_id = '$deviceId'; ''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return null;
    }

    final m = cursor.elementAt(0).toMap();

    m['Place_country_iso'] = m['country_iso'];
    m['Place_city_name'] = m['city_name'];

    return m as Map<String, dynamic>;
  }

  static Future<bool> upsertModel(UserPlaceModelDb model) async {
    final kv = model.toMap();

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_UserPlace, kv,
        where: " user_id = ${model.user_id} AND device_id = '${model.device_id}'");

    return cursor != null &&  cursor > 0;
  }
}
