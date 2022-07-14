import 'dart:core';
import 'package:assistance_kit/database/psql2.dart';
import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/api/helpers/urlHelper.dart';
import 'package:brandfit_server/app/pathNs.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/database/models/mobileNumber.dart';
import 'package:brandfit_server/database/models/userCardBank.dart';
import 'package:brandfit_server/database/models/userConnection.dart';
import 'package:brandfit_server/database/models/userCurrency.dart';
import 'package:brandfit_server/database/models/users.dart';
import 'package:brandfit_server/database/models/userCountry.dart';
import 'package:brandfit_server/database/models/userFitnessData.dart';
import 'package:brandfit_server/database/models/userImage.dart';
import 'package:brandfit_server/database/models/userNameId.dart';
import 'package:brandfit_server/database/models/userPersonalData.dart';
import 'package:brandfit_server/database/queryList.dart';
import 'package:brandfit_server/database/querySelector.dart';
import 'package:brandfit_server/models/enums.dart';
import 'package:brandfit_server/models/photoDataModel.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/queryFiltering.dart';
import 'package:brandfit_server/keys.dart';

class CommonMethods {
  CommonMethods._();

  static String? castToJsonb(dynamic mapOrJs, {bool nullIfNull = true}){
    return Psql2.castToJsonb(mapOrJs, nullIfNull: nullIfNull);
  }
  ///=====================================================================================================
  static Future<Map<String, dynamic>> getUserLoginInfo(int userId, bool password) async {
    final getDataTypes = <UserDataType>{};

    getDataTypes.add(UserDataType.personal);
    getDataTypes.add(UserDataType.country);
    getDataTypes.add(UserDataType.currency);
    getDataTypes.add(password? UserDataType.userNamePassword : UserDataType.userName);
    getDataTypes.add(UserDataType.mobileNumber);
    getDataTypes.add(UserDataType.profileImage);
    getDataTypes.add(UserDataType.healthCondition);
    getDataTypes.add(UserDataType.sportsEquipment);
    getDataTypes.add(UserDataType.jobActivity);
    getDataTypes.add(UserDataType.fitnessStatus);
    getDataTypes.add(UserDataType.bankCard);

    return _getInfoForUser(userId, getDataTypes);
  }

  static Future<Map<String, dynamic>> getUserAdvanced(int userId) async {
    final getDataTypes = <UserDataType>{};
    getDataTypes.add(UserDataType.personal);
    getDataTypes.add(UserDataType.userName);
    getDataTypes.add(UserDataType.profileImage);
    getDataTypes.add(UserDataType.lastTouch);

    final res = await _getInfoForUser(userId, getDataTypes);
    JsonHelper.removeKeys(res, [Keys.sex, Keys.birthdate, ...PublicAccess.avoidForLimitedUser]);

    return res;
  }

  static Future<Map<String, dynamic>> getUserAdvanced$fitnessStatus(int userId) async {
    final getDataTypes = <UserDataType>{};
    getDataTypes.add(UserDataType.userName);
    getDataTypes.add(UserDataType.profileImage);
    getDataTypes.add(UserDataType.fitnessStatus);

    final res = await _getInfoForUser(userId, getDataTypes);
    JsonHelper.removeKeys(res, PublicAccess.avoidForLimitedUser);

    return res;
  }

  static Future<Map<String, dynamic>> getUserAdvanced$course(int userId) async {
    final getDataTypes = <UserDataType>{};
    getDataTypes.add(UserDataType.personal);
    getDataTypes.add(UserDataType.userName);
    getDataTypes.add(UserDataType.profileImage);
    getDataTypes.add(UserDataType.fitnessStatus);

    final res = await _getInfoForUser(userId, getDataTypes);
    JsonHelper.removeKeys(res, PublicAccess.avoidForLimitedUser);

    return res;
  }

  static Future<Map<String, dynamic>> _getInfoForUser(int userId, Set<UserDataType> tList) async {
    final res = <String, dynamic>{};

    for(final type in tList){
      if(type == UserDataType.personal) {
        res.addAll((await UserModelDb.fetchMap(userId))?? {});
      }

      if(type == UserDataType.country) {
        res.addAll((await UserCountryModelDb.getUserCountryJs(userId))?? {});
      }

      if(type == UserDataType.currency) {
        res.addAll((await UserCurrencyModelDb.getUserCurrencyJs(userId))?? {});
      }

      if(type == UserDataType.userNamePassword) {
        final r = await UserNameModelDb.fetchMap(userId)?? {};

        JsonHelper.removeKeys(r, ['hash_password']);
        res.addAll(r);
      }

      if(type == UserDataType.userName) {
        final r = await UserNameModelDb.fetchMap(userId)?? {};

        JsonHelper.removeKeys(r, ['hash_password', 'password']);
        res.addAll(r);
      }

      if(type == UserDataType.mobileNumber) {
        res.addAll((await MobileNumberModelDb.fetchMap(userId))?? {});
      }

      if(type == UserDataType.profileImage) {
        res.addAll((await UserImageModelDb.getProfileImage(userId)));
      }

      if(type == UserDataType.sportsEquipment) {
        res.addAll((await PersonalDataModelDb.getUserSportsEquipmentJs(userId)));
      }

      if(type == UserDataType.healthCondition) {
        res.addAll((await PersonalDataModelDb.getUserHealthConditionJs(userId)));
      }

      if(type == UserDataType.jobActivity) {
        res.addAll((await PersonalDataModelDb.getUserJobActivityJs(userId)));
      }

      if(type == UserDataType.fitnessStatus) {
        res.addAll((await UserFitnessDataModelDb.getUserFitnessStatusJs(userId)));
      }

      if(type == UserDataType.lastTouch) {
        res.addAll((await UserConnectionModelDb.fetchLastTouch(userId)));
      }

      if(type == UserDataType.bankCard) {
        final cb = await UserBankCardModelDb.getUserMainCardNumber(userId);

        if(cb != null) {
          res.putIfAbsent('bank_card_js', (){return cb.toMap();});
        }
      }
    }

    return res;
  }

  // [AppUser] for manager app
  static Future<List<Map<String, dynamic>>> searchOnUsers(Map<String, dynamic> jsOption) async {
    final fq = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    replace['LIMIT x'] = 'LIMIT ${fq.limit}';
    replace['OFFSET x'] = 'OFFSET ${fq.offset}';

    qSelector.addQuery(QueryList.simpleUsers_q1(fq));

    final cursor = await PublicAccess.psql2.queryCall(qSelector.generate(0, replace));

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      return (e.toMap() as Map<String, dynamic>);
    }).toList();
  }

  // [AppUser] for manager app
  static Future<List<Map<String, dynamic>>> searchOnTrainerUsers(Map<String, dynamic> jsOption) async {
    final fq = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    replace['LIMIT x'] = 'LIMIT ${fq.limit}';

    qSelector.addQuery(QueryList.searchOnTrainerUsers(fq));

    final cursor = await PublicAccess.psql2.queryCall(qSelector.generate(0, replace));

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      return e.toMap() as Map<String, dynamic>;
    }).toList();
  }

  // [~] for user app
  static Future<List<Map<String, dynamic>>> searchOnTrainerUserForSearch(Map<String, dynamic> jsOption) async {
    final fq = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    replace['LIMIT x'] = 'LIMIT ${fq.limit}';

    qSelector.addQuery(QueryList.searchOnTrainerUsers2(fq));

    final cursor = await PublicAccess.psql2.queryCall(qSelector.generate(0, replace));

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      return e.toMap() as Map<String, dynamic>;
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getAdvertisingListForUser() async {
    final q = QueryList.getAdvertisingListForUser();
    final cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      return (e.toMap() as Map<String, dynamic>);
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getAdvertisingList(Map<String, dynamic> jsOption) async {
    final fq = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};

    qSelector.addQuery(QueryList.getAdvertisingList(fq));

    replace['LIMIT x'] = 'LIMIT ${fq.limit}';

    final cursor = await PublicAccess.psql2.queryCall(qSelector.generate(0, replace));

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      return e.toMap() as Map<String, dynamic>;
    }).toList();
  }

  static Future<bool> addNewAdvertising(int userId, Map<String , dynamic> js, String rawPath) async{
    final p = PathsNs.removeBasePathFromLocalPath(PathsNs.getCurrentPath(), rawPath);

    final kv = <String, dynamic>{};
    kv['creator_id'] = userId;
    kv[Keys.title] = js[Keys.title];
    kv[Keys.type] = js[Keys.type];
    kv['tag'] = js['tag'];
    kv['click_link'] = js['link'];
    kv['order_num'] = js['order_num'];
    kv['can_show'] = js['can_show'];
    kv['start_show_date'] = js['start_date'];
    kv['finish_show_date'] = js['finish_date'];
    kv['path'] = UrlHelper.encodeUrl(p!);

    final effected = await PublicAccess.psql2.insertKv(DbNames.T_Advertising, kv);

    return effected != null && effected > 0;
  }

  static Future<bool> deleteAdvertising(int userId, int id) async{
    final effected = await PublicAccess.psql2.delete(DbNames.T_Advertising, 'id = $id');

    return effected != null && effected > 0;
  }

  static Future<bool> changeAdvertisingShowState(int userId, int id, bool state) async{
    final kv = <String, dynamic>{};
    kv['can_show'] = state;

    final effected = await PublicAccess.psql2.updateKv(DbNames.T_Advertising, kv, 'id = $id');

    return effected != null && effected > 0;
  }

  static Future<bool> changeAdvertisingTitle(int userId, int id, String title) async{
    final kv = <String, dynamic>{};
    kv['title'] = title;

    final effected = await PublicAccess.psql2.updateKv(DbNames.T_Advertising, kv, 'id = $id');

    return effected != null && effected > 0;
  }

  static Future<bool> changeAdvertisingTag(int userId, int id, String tag) async{
    final kv = <String, dynamic>{};
    kv['Tag'] = tag;

    final effected = await PublicAccess.psql2.updateKv(DbNames.T_Advertising, kv, 'id = $id');

    return effected != null && effected > 0;
  }

  static Future<bool> changeAdvertisingType(int userId, int id, String type) async{
    final kv = <String, dynamic>{};
    kv['type'] = type;

    final effected = await PublicAccess.psql2.updateKv(DbNames.T_Advertising, kv, 'id = $id');

    return effected != null && effected > 0;
  }

  static Future<bool> changeAdvertisingPhoto(int userId, int id, String rawPath) async{
    final p = PathsNs.removeBasePathFromLocalPath(PathsNs.getCurrentPath(), rawPath);

    final kv = <String, dynamic>{};
    kv['path'] = UrlHelper.encodeUrl(p!);

    final effected = await PublicAccess.psql2.updateKv(DbNames.T_Advertising, kv, 'id = $id');

    return effected != null && effected > 0;
  }

  static Future<bool> changeAdvertisingOrder(int userId, int id, int order) async{
    final kv = <String, dynamic>{};
    kv['order_num'] = order;

    final effected = await PublicAccess.psql2.updateKv(DbNames.T_Advertising, kv, 'id = $id');

    return effected != null && effected > 0;
  }

  static Future<bool> changeAdvertisingDate(int userId, int id, String section, String? dateTs) async{
    final kv = <String, dynamic>{};

    if(section == 'start_date') {
      kv['start_show_date'] = dateTs;
    }
    else {
      kv['finish_show_date'] = dateTs;
    }

    final effected = await PublicAccess.psql2.updateKv(DbNames.T_Advertising, kv, 'id = $id');

    return effected != null && effected > 0;
  }

  static Future<bool> changeAdvertisingLink(int userId, int id, String link) async{
    final kv = <String, dynamic>{};
    kv['click_link'] = link;

    final effected = await PublicAccess.psql2.updateKv(DbNames.T_Advertising, kv, 'id = $id');

    return effected != null && effected > 0;
  }

  static Future addBuyCourseQuestions(Map<String, dynamic> jsOption, int userId, int courseId, Map questionJs) async {
    final kv = <String, dynamic>{};
    kv['course_id'] = courseId;
    kv['user_id'] = userId;
    kv['questions_js'] = castToJsonb(questionJs);

    final effected = await PublicAccess.psql2.insertIgnoreWhere(
        DbNames.T_CourseBuyQuestion,
        kv,
        where: 'course_id = $courseId AND user_id = $userId');

    return effected != null && effected > 0;
  }

  static Future<Map> getCoursePayInfo(int userId, int courseId) async {
    var q = '''
      SELECT 
       questions_js->'card_photo' AS card_photo
        FROM coursebuyquestion
        WHERE user_id = $userId AND course_id = $courseId;
    ''';

    final listOrNull = await PublicAccess.psql2.queryCall(q);

    if(listOrNull == null || listOrNull.isEmpty){
      return {};
    }

    return listOrNull[0].toMap();
  }

  static Future<bool> deleteCoursePayPhoto(int userId, int courseId) async {
    var q = '''
      UPDATE coursebuyquestion
      SET
          questions_js = jsonb_delete_path(questions_js, Array['card_photo']::text[])
      WHERE user_id = $userId AND course_id = $courseId;
    ''';

    final num = await PublicAccess.psql2.execution(q);

    return num != null && num > -1;
  }

  static Future<bool> updateCoursePayPhoto(int userId, int courseId, PhotoDataModel pd) async {
    var q = '''
      UPDATE coursebuyquestion
      SET
          questions_js = jsonb_set(questions_js, Array['card_photo'], ${Psql2.castToJsonb(pd.toMap())})
      WHERE user_id = $userId AND course_id = $courseId;
    ''';

    final num = await PublicAccess.psql2.execution(q);

    return num != null && num > -1;
  }

  static Future getMediasByIds(int userId, List mediaIds) async {
    if(mediaIds.isEmpty){
      return <Map<String, dynamic>>[];
    }

    final replace = {};
    replace['@list'] = Psql2.listToSequenceNum(mediaIds);

    final qs = QuerySelector();
    qs.addQuery(QueryList.getMediasByIds());

    final listOrNull = await PublicAccess.psql2.queryCall(qs.generate(0, replace));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    // smpl: reWrite
    return listOrNull.map((e) {
      final m = e.toMap();
      m['uri'] = PathsNs.genUrlDomainFromLocalPathByDecoding(PublicAccess.domain, PathsNs.getCurrentPath(), m['uri']);
      return m as Map<String, dynamic>;
    }).toList();
  }

  static Future getChatUsersByIds(List userIds) async {
    if(userIds.isEmpty){
      return <Map<String, dynamic>>[];
    }

    final qs = QuerySelector();
    final replace = {};

    qs.addQuery(QueryList.getChatUsersByIds());

    replace['@list'] = Psql2.listToSequence(userIds);

    final listOrNull = await PublicAccess.psql2.queryCall(qs.generate(0, replace));

    if (listOrNull == null || listOrNull.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return listOrNull.map((e) {
      return e.toMap() as Map<String, dynamic>;
    }).toList();
  }

  static Future updateLastTicketSeen(int userId, int ticketId, String ts) async {
    final q = '''SELECT update_seen_ticket($userId, $ticketId, '$ts'::timestamp);''';
    final cursor = await PublicAccess.psql2.queryCall(q);

    if(cursor is List){
      return cursor!.first.toList()[0];
    }

    return null;
  }

  static Future updateLastChatSeen(int userId, int conversationId, String ts) async {
    final q = '''SELECT update_seen_chat($userId, $conversationId, '$ts'::timestamp);''';
    final cursor = await PublicAccess.psql2.queryCall(q);

    if(cursor is List){
      return cursor!.first.toList()[0];
    }

    return null;
  }

  static Future deleteTicketMessage(int userId, int ticketId, String msgId, bool isManager) async {
    final where;

    if(isManager) {
      where = ' id = $msgId ';
    }
    else {
      where = ' id = $msgId AND sender_user_id = $userId ';
    }

    final cursor = await PublicAccess.psql2.delete(DbNames.T_TicketMessage, where, returning: 'media_id');

    if(cursor is String || cursor is int){
      return deleteMediaMessage(userId, cursor);
    }

    return null;
  }

  static Future deleteMediaMessage(int userId, String mediaId) async {
    final cursor = await PublicAccess.psql2.delete(DbNames.T_MediaMessageData, ' id = $mediaId ');

    if(cursor is String || cursor is int){
      return cursor;
    }

    return null;
  }

  static Future updateTicketMessageSeen(int userId, int ticketId, String ts) async {
    final q = QueryList.updateChatMessageSeen(ticketId, userId, ts);

    final cursor = await PublicAccess.psql2.execution(q);
    return cursor != null;
  }

  static Future updateChatMessageSeen(int userId, int conversationId, String ts) async {
    final q = QueryList.updateChatMessageSeen(conversationId, userId, ts);

    final cursor = await PublicAccess.psql2.execution(q);
    return cursor != null;
  }

  static Future<int?> getStarterUserIdFromTicket(int ticketId) async {
    var q = '''SELECT starter_user_id FROM #tb WHERE id = $ticketId;''';
    q = q.replaceFirst(RegExp('#tb'), DbNames.T_Ticket);

    final cursor = await PublicAccess.psql2.getColumn(q, 'starter_user_id');

    if(cursor is num){
      return cursor.toInt();
    }

    if(cursor is String){
      return int.parse(cursor);
    }

    return null;
  }

  static Future getCourseQuestions(int courseId, int requesterId) async {
    var q = '''SELECT * FROM #tb WHERE course_id = $courseId AND user_id = $requesterId;''';

    q = q.replaceFirst(RegExp('#tb'), DbNames.T_CourseBuyQuestion);
    final cursor = await PublicAccess.psql2.queryCall(q);

    if(cursor == null || cursor.isEmpty){
      return null;
    }

    return cursor.elementAt(0).toMap();
  }

  static Future<List<Map>> searchOnTrainerPupils(Map<String, dynamic> jsOption, int userId) async {
    final filtering = FilterRequest.fromMap(jsOption[Keys.filtering]);
    final qSelector = QuerySelector();

    final replace = <String, dynamic>{};
    replace['LIMIT x'] = 'LIMIT ${filtering.limit}';

    qSelector.addQuery(QueryList.trainerPupil_q1(filtering, userId));

    final cursor = await PublicAccess.psql2.queryCall(qSelector.generate(0, replace));

    if (cursor == null || cursor.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return cursor.map((e) {
      return e.toMap() as Map<String, dynamic>;
    }).toList();
  }
}