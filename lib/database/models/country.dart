import 'package:assistance_kit/api/helpers/boolHelper.dart';
import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';

class CountryModelDb extends DbModel {
  late String iso;
  int? continent_key;
  late String name;
  String? phone_code;
  String? language_iso;
  String? flag_path;
  bool is_usable = true;

  static final String QTbl_Country = '''
		CREATE TABLE IF NOT EXISTS #tb (
			iso varchar(2) NOT NULL,
			name varchar(60) NOT NULL,
			continent_key INT2 DEFAULT NULL,
			phone_code varchar(8) DEFAULT NULL,
			language_iso varchar(3) DEFAULT NULL,
			flag_path varchar(400) DEFAULT NULL,
			is_usable BOOLEAN DEFAULT TRUE,
			CONSTRAINT pk_#tb PRIMARY KEY (iso),
			CONSTRAINT uk1_#tb UNIQUE (name)
			);
			'''
      .replaceAll('#tb', DbNames.T_Country);

  static final String QIdx_Country$phone_code = '''
		CREATE INDEX IF NOT EXISTS #tb_phone_code_idx
		ON #tb USING BTREE (phone_code);
			'''
      .replaceAll('#tb', DbNames.T_Country);

  /*CONSTRAINT fk1_countries FOREIGN KEY (continent_key) REFERENCES ${Dbnames.T_Continent (Key)
					ON DELETE RESTRICT ON UPDATE CASCADE)*/

  @override
  CountryModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    iso = map[Keys.iso];
    continent_key = map['continent_key'];
    name = map[Keys.name];
    language_iso = map[Keys.languageIso];
    phone_code = map[Keys.phoneCode];
    flag_path = map['flag_path'];
    is_usable = BoolHelper.itemToBool(map['is_usable']);
  }

  @override
  Map<String, dynamic> toMap() {
    final res = <String, dynamic>{};

    res[Keys.iso] = iso;
    res['continent_key'] = continent_key;
    res[Keys.name] = name;
    res[Keys.languageIso] = language_iso;
    res[Keys.phoneCode] = phone_code;
    res['flag_path'] = flag_path;
    res['is_usable'] = is_usable;

    return res;
  }
}