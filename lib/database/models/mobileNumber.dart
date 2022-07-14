import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';

class MobileNumberModelDb extends DbModel {
  late int user_id;
  String? mobile_number;
  String? phone_code;
  int user_type = 1;


  static final String QTbl_mobileNumber = '''
		CREATE TABLE IF NOT EXISTS #tb (
      user_id BIGINT NOT NULL,
      user_type SmallInt NOT NULL DEFAULT 1,
      phone_code VARCHAR(6),
      mobile_number VARCHAR(15),
      CONSTRAINT fk1_#tb FOREIGN KEY (user_id) REFERENCES #ref (user_id)
        ON DELETE CASCADE ON UPDATE CASCADE)
      PARTITION BY RANGE (user_id);
			'''
      .replaceAll('#tb', DbNames.T_MobileNumber)
      .replaceFirst('#ref', DbNames.T_Users);

  static final String QIdx_mobileNumber$user_id = '''
		CREATE INDEX IF NOT EXISTS #tb_user_id_idx ON #tb
		USING BTREE (user_id);
		'''
      .replaceAll('#tb', DbNames.T_MobileNumber);

  static final String QIdx_mobileNumber$mobile_number = '''
		CREATE INDEX IF NOT EXISTS #tb_mobile_number_idx ON #tb
		USING BTREE (mobile_number);
		'''
      .replaceAll('#tb', DbNames.T_MobileNumber);

  static final String QTbl_mobileNumber$p1 = '''
      CREATE TABLE IF NOT EXISTS #tb_p1
      PARTITION OF #tb FOR VALUES FROM (0) TO (250000);
      '''
      .replaceAll('#tb', DbNames.T_MobileNumber);

  static final String QTbl_mobileNumber$p2 = '''
      CREATE TABLE IF NOT EXISTS #tb_p2
      PARTITION OF #tb FOR VALUES FROM (250000) TO (500000);
      '''
      .replaceAll('#tb', DbNames.T_MobileNumber);

  static final String QAltUk1_mobileNumber$p1 = '''
		DO \$\$ BEGIN ALTER TABLE #tb_p1
 	    ADD CONSTRAINT uk1_#tb_p1 UNIQUE (user_type, phone_code, mobile_number);
			 EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
			 ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_MobileNumber);

  static final String QAltUk1_mobile_number$p2 = '''
		DO \$\$ BEGIN ALTER TABLE #tb_p2
 	    ADD CONSTRAINT uk1_#tb_p2 UNIQUE (user_type, phone_code, mobile_number);
			 EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
			 ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;
		'''
      .replaceAll('#tb', DbNames.T_MobileNumber);


  @override
  MobileNumberModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    user_id = map[Keys.userId];
    phone_code = map[Keys.phoneCode];
    mobile_number = map[Keys.mobileNumber];
    user_type = map[Keys.userType]?? 1;
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.userId] = user_id;
    map[Keys.phoneCode] = phone_code;
    map[Keys.mobileNumber] = mobile_number;
    map[Keys.userType] = user_type;

    return map;
  }

  static Future<bool> existThisMobile(int userType, String? phoneCode, String? mobileNumber) async {
    final where = " user_type = $userType AND phone_code = '$phoneCode' AND mobile_number = '$mobileNumber' ";

    return (await PublicAccess.psql2.exist(DbNames.T_MobileNumber, where));
  }

  static Future<int?> getUserId(int userType, String? phoneCode, String? mobileNumber) async {
    final query = '''SELECT user_id FROM ${DbNames.T_MobileNumber}
      WHERE user_type = $userType AND phone_code = '$phoneCode' AND mobile_number = '$mobileNumber';''';

    return (await PublicAccess.psql2.getColumn(query, Keys.userId));
  }

  static Future<bool> insertModel(MobileNumberModelDb model) async {
    final modelMap = model.toMap();
    return insertModelMap(modelMap);
  }

  static Future<bool> insertModelMap(Map<String, dynamic> userMap) async {
    final x = await PublicAccess.psql2.insertKv(DbNames.T_MobileNumber, userMap);

    return !(x == null || x < 1);
  }

  static Future<dynamic> getUserIdByMobile(int userType, String phoneCode, String mobile) async {
    final query = '''SELECT user_id FROM ${DbNames.T_MobileNumber} 
      WHERE user_type = $userType AND phone_code = '$phoneCode' AND mobile_number = '$mobile'; ''';

    return PublicAccess.psql2.getColumn(query, Keys.userId);
  }

  static Future<Map<String, dynamic>?> fetchMap(int userId) async {
    final q = 'SELECT * FROM ${DbNames.T_MobileNumber} WHERE user_id = $userId;';
    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return null;
    }

    return cursor.elementAt(0).toMap() as Map<String, dynamic>;
    //final res = MobileNumberDbModel.fromMap(m as Map<String, dynamic>);
    //return res.toMap();
  }
}
