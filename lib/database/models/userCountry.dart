import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/models/countryModel.dart';
import 'package:brandfit_server/publicAccess.dart';

class UserCountryModelDb extends DbModel {
  late int user_id;
  late String country_iso;
  String? city_name;

  // this is birthdate city/country
  static final String QTbl_UserCountry = '''
		CREATE TABLE IF NOT EXISTS #tb (
      user_id BIGINT NOT NULL,
      country_iso varchar(3) NOT NULL,
      city_name varchar(70) DEFAULT NULL,
      CONSTRAINT pk_#tb PRIMARY KEY (user_id),
      CONSTRAINT fk1_#tb FOREIGN KEY (user_id) REFERENCES #ref (user_id)
        ON DELETE CASCADE ON UPDATE CASCADE)
      PARTITION BY RANGE (user_id);
			'''
      .replaceAll('#tb', DbNames.T_UserCountry)
      .replaceFirst('#ref', DbNames.T_Users);

  static final String QTbl_UserCountry$p1 = '''
      CREATE TABLE IF NOT EXISTS #tb_p1
      PARTITION OF #tb FOR VALUES FROM (0) TO (250000);
      '''
      .replaceAll('#tb', DbNames.T_UserCountry);

  static final String QTbl_UserCountry$p2 = '''
      CREATE TABLE IF NOT EXISTS #tb_p2
      PARTITION OF #tb FOR VALUES FROM (250000) TO (500000);
      '''
      .replaceAll('#tb', DbNames.T_UserCountry);

  static final String crIdx_UserCountry$country_iso = '''
      CREATE INDEX IF NOT EXISTS ${DbNames.T_UserCountry}_country_iso_idx
      ON ${DbNames.T_UserCountry} USING BTREE (country_iso);
      ''';


  @override
  UserCountryModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    user_id = map[Keys.userId];
    country_iso = map[Keys.countryIso];
    city_name = map['city_name'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.userId] = user_id;
    map[Keys.countryIso] = country_iso;
    map['city_name'] = city_name;

    return map;
  }

  Map<String, dynamic> toUserCountryJs() {
    var res = <String, dynamic>{};

    res['user_country_js'] = CountryModel.getCountryModelByIso(country_iso).toMap();

    return res;
  }

  static Future<Map<String, dynamic>?> fetchMap(int userId) async {
    final q = '''SELECT * FROM  ${DbNames.T_UserCountry} WHERE user_id = $userId;''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return null;
    }

    return cursor.elementAt(0).toMap() as Map<String, dynamic>;
    //final res = UserCountryDbModel.fromMap(m as Map<String, dynamic>);

    //return res.toMap();
    //return res.toUserCountryJs();
  }

  static Future<Map<String, dynamic>?> getUserCountryJs(int userId) async {
    final m = await UserCountryModelDb.fetchMap(userId);

    if(m == null){
      return null;
    }

    final res = UserCountryModelDb.fromMap(m);

    return res.toUserCountryJs();
  }

  static Future<bool> insertModel(UserCountryModelDb model) async {
    final modelMap = model.toMap();
    return insertModelMap(modelMap);
  }

  static Future<bool> insertModelMap(Map<String, dynamic> userMap) async {
    final effected = await PublicAccess.psql2.insertKv(DbNames.T_UserCountry, userMap);

    return !(effected == null || effected < 1);
  }

  static Future<bool> upsertUserCountry(int userId, String countryIso) async{
    final value = <String, dynamic>{};
    value[Keys.userId] = userId;
    value[Keys.countryIso] = countryIso;

    final effected = await PublicAccess.psql2.upsertWhereKv(DbNames.T_UserCountry, value, where: ' user_id = $userId');

    if(effected != null && effected > 0) {
      return true;
    }

    return false;
  }

}
