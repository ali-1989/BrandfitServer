import 'package:brandfit_server/database/models/dbModel.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';

class UserBankCardModelDb extends DbModel {
  late int user_id;
  String? card_number;
  bool is_main = false;
  Map? extra;

  static final String QTbl_BankCard = '''
		CREATE TABLE IF NOT EXISTS #tb (
      user_id BIGINT NOT NULL,
      card_number VARCHAR(24) DEFAULT NULL,
      extra JSONB DEFAULT NULL,
      is_main BOOL DEFAULT FALSE,
      CONSTRAINT pk_#tb PRIMARY KEY (user_id, card_number),
      CONSTRAINT ck_#tb CHECK(check_one_true_bankCard(is_main) = 1),
      CONSTRAINT fk1_#tb FOREIGN KEY (user_id) REFERENCES #ref (user_id)
        ON DELETE CASCADE ON UPDATE CASCADE)
      PARTITION BY RANGE (user_id);
			'''
      .replaceAll('#tb', DbNames.T_UserBankCard)
      .replaceFirst('#ref', DbNames.T_Users);

  static final String QTbl_BankCard$p1 = '''
      CREATE TABLE IF NOT EXISTS #tb_p1
      PARTITION OF #tb FOR VALUES FROM (0) TO (250000);
      '''
      .replaceAll('#tb', DbNames.T_UserBankCard);

  static final String QTbl_BankCard$p2 = '''
      CREATE TABLE IF NOT EXISTS #tb_p2
      PARTITION OF #tb FOR VALUES FROM (250000) TO (500000);
      '''
      .replaceAll('#tb', DbNames.T_UserBankCard);

  static final String crIdx_BankCard$card_number = '''
      CREATE INDEX IF NOT EXISTS #tb_card_number_idx
      ON #tb USING GIN (card_number);
      '''
      .replaceAll('#tb', DbNames.T_UserBankCard);

  static final String fn_BankCard$check1 = r'''
      CREATE OR REPLACE FUNCTION check_one_true_bankCard(new_val bool)
      RETURNS int AS
      $$
      BEGIN
          RETURN 
          (
              SELECT COUNT(*) + (CASE new_val WHEN true THEN 1 ELSE 0 END)
              FROM #tb 
              WHERE is_main = true
          );
      END
      $$
      LANGUAGE PLPGSQL STABLE;
      '''
      .replaceAll('#tb', DbNames.T_UserBankCard);


  @override
  UserBankCardModelDb.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    user_id = map[Keys.userId];
    card_number = map['card_number'];
    extra = map['extra'];
    is_main = map['is_main'];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    map[Keys.userId] = user_id;
    map['card_number'] = card_number;
    map['extra'] = extra;
    map['is_main'] = is_main;

    return map;
  }
  
  static Future<List<Map<String, dynamic>>> fetchMap(int userId) async {
    final q = '''SELECT * FROM  ${DbNames.T_UserBankCard} WHERE user_id = $userId;''';

    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) => e.toMap() as Map<String, dynamic>).toList();
  }

  static Future<List<UserBankCardModelDb>> getUserCardNumbers(int userId) async {
    final list = await UserBankCardModelDb.fetchMap(userId);
    final res = <UserBankCardModelDb>[];

    for(final m in list) {
      final bc = UserBankCardModelDb.fromMap(m);
      res.add(bc);
    }

    return res;
  }

  static Future<UserBankCardModelDb?> getUserMainCardNumber(int userId) async {
    final cards = await getUserCardNumbers(userId);

    for(final m in cards) {
      if(m.is_main){
        return m;
      }
    }

    return null;
  }

  static Future<bool> insertModel(UserBankCardModelDb model) async {
    final modelMap = model.toMap();
    return insertModelMap(modelMap);
  }

  static Future<bool> insertModelMap(Map<String, dynamic> dataMap) async {
    final effected = await PublicAccess.psql2.insertKv(DbNames.T_UserBankCard, dataMap);

    return !(effected == null || effected < 1);
  }

  static Future<bool> changeUserCardNumber(int userId, String oldCardNumber, UserBankCardModelDb newData) async{
    final effected = await PublicAccess.psql2.upsertWhereKv(
        DbNames.T_UserBankCard,
        newData.toMap(),
        where: " user_id = $userId AND card_number = '$oldCardNumber'");

    if(effected != null && effected > 0) {
      return true;
    }

    return false;
  }

  static Future<bool> deleteCardNumber(int userId, String cardNumber) async{
    final effected = await PublicAccess.psql2.delete(
        DbNames.T_UserBankCard,
        " user_id = $userId AND card_number = '$cardNumber'");

    if(effected != null && effected > 0) {
      return true;
    }

    return false;
  }

}
