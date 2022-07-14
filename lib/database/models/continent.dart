import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';

class ContinentModelDb extends DbModel {
  late int key;
  String name = '';

  static final String QTbl_Continent = '''
		CREATE TABLE IF NOT EXISTS #tb (
 		key SMALLSERIAL,
 		name varchar(40) NOT NULL,
 		CONSTRAINT pk_#tb PRIMARY key (key),
 		CONSTRAINT uk1_#tb UNIQUE (name)
 		);
			'''
      .replaceAll('#tb', DbNames.T_Continent);

  @override
  ContinentModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    key = map[Keys.key];
    name = map[Keys.name];
  }

  @override
  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{};

    map[Keys.key] = key;
    map[Keys.name] = name;

    return map;
  }
}
