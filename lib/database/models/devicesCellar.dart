import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';

class DeviceCellarModelDb extends DbModel {
  late String device_id;
  int? user_id;
  String? brand;
  String? model;
  String? api;
  String? device_type;
  String? import_date;


  /// only on login time this is fill
  /// brand: onWeb => userAgent
  static final String QTbl_DevicesCellar = '''
		CREATE TABLE IF NOT EXISTS #tb (
      device_id varchar(40) NOT NULL,
      user_id BIGINT DEFAULT NULL,
      brand varchar(100) DEFAULT NULL,
      model varchar(40) DEFAULT NULL,
      api varchar(15) DEFAULT NULL,
      device_type varchar(20) DEFAULT NULL,
      import_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
      CONSTRAINT fk1_#tb FOREIGN KEY (user_id) REFERENCES #ref (user_id)
       	ON DELETE CASCADE ON UPDATE CASCADE
      )
      PARTITION BY HASH (device_id);
			'''
      .replaceAll('#tb', DbNames.T_DevicesCellar)
      .replaceFirst('#ref', DbNames.T_Users);

  static final String QIdx_DevicesCellar$user_id = '''
		CREATE INDEX IF NOT EXISTS #tb_user_id_idx ON #tb
		USING BTREE (user_id);
		'''
      .replaceAll('#tb', DbNames.T_DevicesCellar);

  static final String QTbl_DevicesCellar$p1 = '''
      CREATE TABLE IF NOT EXISTS #tb_p1
      PARTITION OF #tb FOR VALUES WITH (MODULUS 3, REMAINDER 0);
      '''
      .replaceAll('#tb', DbNames.T_DevicesCellar);

  static final String QTbl_DevicesCellar$p2 = '''
      CREATE TABLE IF NOT EXISTS #tb_p2
      PARTITION OF #tb FOR VALUES WITH (MODULUS 3, REMAINDER 1);
      '''
      .replaceAll('#tb', DbNames.T_DevicesCellar);

  static final String QTbl_DevicesCellar$p3 = '''
      CREATE TABLE IF NOT EXISTS #tb_p3
      PARTITION OF #tb FOR VALUES WITH (MODULUS 3, REMAINDER 2);
      '''
      .replaceAll('#tb', DbNames.T_DevicesCellar);

  static final String QAltUk1_DevicesCellar$p1 = '''
	DO \$\$ BEGIN ALTER TABLE #tb_p1
     ADD CONSTRAINT uk1_#tb_p1 UNIQUE (device_id, user_id);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_DevicesCellar);

  static final String QAltUk1_DevicesCellar$p2 = '''
	DO \$\$ BEGIN ALTER TABLE #tb_p2
		ADD CONSTRAINT uk1_#tb_p2 UNIQUE (device_id, user_id);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_DevicesCellar);

  static final String QAltUk1_DevicesCellar$p3 = '''
	DO \$\$ BEGIN ALTER TABLE #tb_p3
	ADD CONSTRAINT uk1_#tb_p3 UNIQUE (device_id, user_id);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_DevicesCellar);

  @override
  DeviceCellarModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    device_id = map[Keys.deviceId];
    user_id = map[Keys.userId];
    brand = map['brand'];
    model = map['model'];
    api = map['api'];
    device_type = map['device_type'];
    import_date = map['import_date'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.deviceId] = device_id;
    map[Keys.userId] = user_id;
    map['brand'] = brand;
    map['model'] = model;
    map['api'] = api;
    map['device_type'] = device_type;

    if(import_date != null) {
      map['import_date'] = import_date;
    }

    return map;
  }

  static Future<bool> upsertModel(DeviceCellarModelDb model) async {
    final kv = model.toMap();

    final cursor = await PublicAccess.psql2.upsertWhereKv(DbNames.T_DevicesCellar, kv,
        where: " user_id = ${model.user_id} AND device_id = '${model.device_id}'");

    return cursor != null &&  cursor > 0;
  }
}
