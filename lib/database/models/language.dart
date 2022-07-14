import 'package:assistance_kit/api/helpers/boolHelper.dart';
import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';

class LanguageModelDb extends DbModel {
  late String iso;
  late String iso_and_country;
  late String english_name;
  String? local_name;
  bool is_usable = true;

  // old : 'Key VARBIT(160) NOT NULL," // 1 EN, FA 2, AR 4, TR 8, 16, 32
  // CONSTRAINT "uk1_LanguagesTB" UNIQUE (Key),
  // CONSTRAINT "uk2_LanguagesTB" UNIQUE (english_name)
  // iso:  en, fa, hmn
  static final String QTbl_Language = '''
		CREATE TABLE IF NOT EXISTS #tb (
      iso varchar(3) NOT NULL,
      iso_and_country varchar(6) NOT NULL,
      english_name varchar(40) NOT NULL,
      local_name varchar(40) DEFAULT NULL,
      is_usable BOOLEAN DEFAULT TRUE,
      CONSTRAINT uk_#tb UNIQUE (iso, iso_and_country)
 		);
			'''
      .replaceAll('#tb', DbNames.T_Language);


  @override
  LanguageModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    iso = map[Keys.iso];
    iso_and_country = map['iso_and_country'];
    english_name = map['english_name'];
    local_name = map['local_name'];
    is_usable = BoolHelper.itemToBool(map['is_usable']);
  }

  @override
  Map<String, dynamic> toMap() {
    var res = <String, dynamic>{};

    res[Keys.iso] = iso;
    res['iso_and_country'] = iso_and_country;
    res['english_name'] = english_name;
    res['local_name'] = local_name;
    res['is_usable'] = is_usable;

    return res;
  }
}
