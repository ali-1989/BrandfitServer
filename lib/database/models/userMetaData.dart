import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';

class UserMetaDataModelDb extends DbModel {
  late int user_id;
  late String meta_key;
  late String value;
  int sort_order = 0;


  static final String QTbl_UserMetaData = '''
		CREATE TABLE IF NOT EXISTS #tb (
      user_id BIGINT NOT NULL,
      meta_key SMALLINT NOT NULL,
      value varchar(400) NOT NULL,
      sort_order SMALLINT DEFAULT 0,
      CONSTRAINT fk1_#tb FOREIGN KEY (user_id) REFERENCES #ref (user_id)
          ON DELETE NO ACTION ON UPDATE CASCADE,
      CONSTRAINT fk2_#tb FOREIGN KEY (meta_key) REFERENCES #ref2 (key) 
        ON DELETE RESTRICT ON UPDATE CASCADE
    )
    PARTITION BY RANGE (user_id);
			'''
      .replaceAll('#tb', DbNames.T_UserMetaData)
      .replaceFirst('#ref', DbNames.T_Users)
      .replaceFirst('#ref2', DbNames.T_TypeForUserMetaData);

  static final String QIdx_UserMetaData$meta_key = '''
		CREATE INDEX IF NOT EXISTS #tb_meta_key_idx ON #tb
		USING BTREE (meta_key);
		'''
      .replaceAll('#tb', DbNames.T_UserMetaData);

  static final String QTbl_UserMetaData$p1 = '''
      CREATE TABLE IF NOT EXISTS #tb_p1
      PARTITION OF #tb FOR valueS FROM (0) TO (250000);
      '''
      .replaceAll('#tb', DbNames.T_UserMetaData);

  static final String QTbl_UserMetaData$p2 = '''
      CREATE TABLE IF NOT EXISTS #tb_p2
      PARTITION OF #tb FOR valueS FROM (250000) TO (500000);
      '''
      .replaceAll('#tb', DbNames.T_UserMetaData);

  static final String QAltUk1_UserMetaData$p1 = '''
		DO \$\$ BEGIN ALTER TABLE #tb_p1
 	    ADD CONSTRAINT uk1_#tb UNIQUE (user_id, meta_key, value);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_UserMetaData);

  static final String QAltUk2_UserMetaData$p1 = '''
		DO \$\$ BEGIN ALTER TABLE #tb_p1
 	    ADD CONSTRAINT uk2_#tb UNIQUE (user_id, meta_key, sort_order);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_UserMetaData);

  static final String QAltUk1_UserMetaData$p2 = '''
		DO \$\$ BEGIN ALTER TABLE #tb_p2
 	    ADD CONSTRAINT uk1_#tb UNIQUE (user_id, meta_key, value);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_UserMetaData);

  static final String QAltUk2_UserMetaData$p2 = '''
		DO \$\$ BEGIN ALTER TABLE #tb_p2
 	    ADD CONSTRAINT uk2_#tb UNIQUE (user_id, meta_key, sort_order);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_UserMetaData);

  @override
  UserMetaDataModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    user_id = map[Keys.userId];
    meta_key = map['meta_key'];
    value = map[Keys.value];
    sort_order = map['sort_order'];
  }

  @override
  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{};

    map[Keys.userId] = user_id;
    map['meta_key'] = meta_key;
    map[Keys.value] = value;
    map['sort_order'] = sort_order;

    return map;
  }
}
