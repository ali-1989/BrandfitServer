import 'package:assistance_kit/api/helpers/LocaleHelper.dart';
import 'package:assistance_kit/api/helpers/textHelper.dart';
import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/commonMethods.dart';


class RegisterModelDb extends DbModel {
  String id = '-1';
  int? userType;
  String? name;
  String? family;
  int sex = 0;
  String? birthdate;
  String? register_date;
  String? userName;
  String? password;
  String? country_iso;
  String? phoneCode;
  String? mobileNumber;
  String verify_code = '';
  Map? extra_js;

  static final String QTbl_RegisteringUser = '''
		CREATE TABLE IF NOT EXISTS #tb(
			id Numeric(40,0) DEFAULT nextNum('#seq'),
			user_type INT2 DEFAULT 1,
			name varchar(40) DEFAULT '',
			family varchar(40) DEFAULT '',
			sex INT2 NOT NULL DEFAULT 0,
			birthdate Date DEFAULT NULL,
			register_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
			user_name varchar(40) NOT NULL,
			password varchar(20) NOT NULL,
			country_iso varchar(3) NOT NULL,
			phone_code varchar(7) NOT NULL,
			mobile_number varchar(18) NOT NULL,
			verify_code varchar(8) NOT NULL,
			extra_js JSONB DEFAULT '{}'::JSONB,
			CONSTRAINT pk_#tb PRIMARY KEY (Id),
			CONSTRAINT uk1_#tb UNIQUE (phone_code, mobile_number),
			CONSTRAINT fk1_#tb FOREIGN KEY (sex) REFERENCES #ref (Key)
					ON DELETE RESTRICT ON UPDATE CASCADE
			);
			'''
      .replaceAll('#tb', DbNames.T_RegisteringUser)
      .replaceFirst('#seq', DbNames.Seq_NewUser)
      .replaceFirst('#ref', DbNames.T_TypeForSex);

  RegisterModelDb();

  @override
  RegisterModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    id = map[Keys.id]?? '-1';
    userType = map[Keys.userType]?? 1; //UserType.simpleUser
    sex = map[Keys.sex]?? 0;
    name = map[Keys.name];
    family = map[Keys.family];
    userName = map[Keys.userName];
    password = map['password'];
    birthdate = map[Keys.birthdate];
    register_date = map['register_date'];
    country_iso = map[Keys.countryIso];
    phoneCode = map[Keys.phoneCode]?? map['country_code'];
    mobileNumber = map[Keys.mobileNumber];
    verify_code = map['verify_code']?? '';
    extra_js = map[Keys.extraJs]; //JsonHelper.mapToJsonNullable();
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.id] = id;
    map[Keys.userType] = userType;
    map[Keys.sex] = sex;
    map[Keys.name] = name;
    map[Keys.family] = family;
    map[Keys.birthdate] = birthdate;
    map[Keys.userName] = userName;
    map['password'] = password;
    map[Keys.mobileNumber] = mobileNumber;
    map[Keys.countryIso] = country_iso;
    map[Keys.phoneCode] = phoneCode;
    map['verify_code'] = verify_code;
    map[Keys.extraJs] = CommonMethods.castToJsonb(extra_js);

    if(register_date != null) {
      map['register_date'] = register_date;
    }

    return map;
  }

  void normalize(){
    name = TextHelper.removeNonViewableFull(name!.trim());
    family = TextHelper.removeNonViewableFull(family!.trim());
    userName = TextHelper.removeNonViewableFull(userName!.trim());
    password = TextHelper.removeNonViewableFull(password!);
    phoneCode = LocaleHelper.numberToEnglish(phoneCode!.trim());
    mobileNumber = LocaleHelper.numberToEnglish(mobileNumber!.trim());
    mobileNumber = mobileNumber!.startsWith('0')? mobileNumber!.substring(1) : mobileNumber;
  }

  static Future<bool> existRegisteringFor(String? userName, String? phoneCode, String? mobileNumber) async {
    var whereExist = " user_name = '$userName'"
        " AND NOT (phone_code = '$phoneCode' AND mobile_number = '$mobileNumber')";

    return (await PublicAccess.psql2.exist(DbNames.T_RegisteringUser, whereExist));
  }

  static Future<bool> existRegisteringUser(int userType, String? phoneCode, String? mobileNumber) async {
    var where = " user_type = $userType AND phone_code = '$phoneCode' AND mobile_number = '$mobileNumber'";

    return (await PublicAccess.psql2.exist(DbNames.T_RegisteringUser, where));
  }

  static Future<bool> isTimeoutRegistering(int userType, String? phoneCode, String? mobileNumber) async {
    var where = " user_type = $userType AND phone_code = '$phoneCode' AND mobile_number = '$mobileNumber'";
    where += " AND (verify_code = '' OR verify_code IS null)";

    return (await PublicAccess.psql2.exist(DbNames.T_RegisteringUser, where));
  }

  static Future<bool> existUserAndCode(int userType, String phoneCode, String mobileNumber, String verifyCode) async {
    var where = " user_type = $userType AND phone_code = '$phoneCode'"
        " AND mobile_number = '$mobileNumber' AND verify_code = '$verifyCode'";

    return (await PublicAccess.psql2.exist(DbNames.T_RegisteringUser, where));
  }

  static Future upsertModel(RegisterModelDb model) async {
    final where = " phone_code = '${model.phoneCode}' AND mobile_number = '${model.mobileNumber}'";
    final kv = model.toMap();

    return PublicAccess.psql2.upsertWhere(
        DbNames.T_RegisteringUser,
        kv.keys.toList(),
        kv.values.toList(),
        where: where
    );
  }

  static Future fetchRegisterCode(int userType, String? phoneCode, String? mobileNumber) async {
    final query = '''SELECT * FROM ${DbNames.T_RegisteringUser} 
      WHERE user_type = '$userType' AND phone_code = '$phoneCode' AND mobile_number = '$mobileNumber';''';

    return PublicAccess.psql2.getColumn(query, 'verify_code');
  }

  static Future<Map?> fetchModelMap(int userType, String phoneCode, String mobileNumber) async {
    final query = '''SELECT * FROM ${DbNames.T_RegisteringUser}
     WHERE user_type = $userType AND phone_code = '$phoneCode' AND mobile_number = '$mobileNumber';''';

    final cursor = await PublicAccess.psql2.queryCall(query);

    if(cursor == null || cursor.isEmpty){
      return null;
    }

    return cursor.elementAt(0).toMap();
  }

  static Future<bool> deleteRecord(String mobileNumber, String userName) async {
    final where = " mobile_number = '$mobileNumber' AND user_name = '$userName'";

    final x = await PublicAccess.psql2.delete(DbNames.T_RegisteringUser, where);

    return !(x == null || x < 1);
  }
}
