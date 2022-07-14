import 'dart:math';
import 'package:brandfit_server/constants.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/database/models/continent.dart';
import 'package:brandfit_server/database/models/conversation.dart';
import 'package:brandfit_server/database/models/country.dart';
import 'package:brandfit_server/database/models/course.dart';
import 'package:brandfit_server/database/models/request.dart';
import 'package:brandfit_server/database/models/devicesCellar.dart';
import 'package:brandfit_server/database/models/foodMaterial.dart';
import 'package:brandfit_server/database/models/foodProgram.dart';
import 'package:brandfit_server/database/models/language.dart';
import 'package:brandfit_server/database/models/mobileNumber.dart';
import 'package:brandfit_server/database/models/programSuggestion.dart';
import 'package:brandfit_server/database/models/register.dart';
import 'package:brandfit_server/database/models/ticket.dart';
import 'package:brandfit_server/database/models/ticketMessage.dart';
import 'package:brandfit_server/database/models/trainerData.dart';
import 'package:brandfit_server/database/models/userCardBank.dart';
import 'package:brandfit_server/database/models/userCurrency.dart';
import 'package:brandfit_server/database/models/userNotifier.dart';
import 'package:brandfit_server/database/models/users.dart';
import 'package:brandfit_server/database/models/userBlockList.dart';
import 'package:brandfit_server/database/models/userConnection.dart';
import 'package:brandfit_server/database/models/userCountry.dart';
import 'package:brandfit_server/database/models/userFitnessData.dart';
import 'package:brandfit_server/database/models/userImage.dart';
import 'package:brandfit_server/database/models/userMetaData.dart';
import 'package:brandfit_server/database/models/userNameId.dart';
import 'package:brandfit_server/database/models/userPersonalData.dart';
import 'package:brandfit_server/database/models/userPlace.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:assistance_kit/extensions.dart';

import 'models/conversationMessage.dart';
import 'models/conversationUser.dart';

class DatabaseNs {
  DatabaseNs._();
  static var DB = PublicAccess.psql2;

  static Future initial() async{
    await improveAndSetting();
    await createSequences();
    await prepareTables();
    //no need await initialSequence();
    await prepareFunctions();
    await alters();
    setPreData();
  }

  static Future improveAndSetting() async{
    await PublicAccess.psql2.execution('SET enable_partition_pruning = on;');
    await PublicAccess.psql2.execution('SET constraint_exclusion = on;');
  }

  static Future createSequence(String seqName, int min, int max, int start) async{
    var q = 'CREATE SEQUENCE IF NOT EXISTS $seqName MINVALUE $min MAXVALUE $max CYCLE START $start;';
    await PublicAccess.psql2.execution(q);
  }

  static Future createNumericSequence(String tblName, String seqName, String min, String start) async{
    var q = '''INSERT INTO $tblName (name, Value, StepValue, MinValue)
         values('$seqName', '$start', 1, '$min') ON CONFLICT (name) DO NOTHING;''';

    await PublicAccess.psql2.execution(q);
  }

  static Future setSequenceVal(String seqName, int val) async{
    var q = '''SELECT setval('$seqName', $val);''';

    await DB.execution(q);
  }

  // setNumericSequenceVal(DbNames.T_NumericSequence, DbNames.Seq_NewUser,)
  //val: int, BigInt, numeric
  static Future setNumericSequenceVal(String tblName, String seqName, String val) async{
    var q = '''UPDATE "$tblName" SET value = '$val' WHERE name = '$seqName';''';

    await DB.execution(q);
  }

  static Future<String> getLastSequenceNumeric(String table, String seqName, String min) async {
    var cursor = await DB.queryCall('SELECT * FROM "$table" ORDER BY $seqName DESC LIMIT 1;');

    if(cursor == null || cursor.isEmpty) {
      return min;
    }

    var r = cursor.elementAt(0);
    return r.toMap()[seqName];
  }

  static Future<int> getLastSequenceVal(String table, String seqName, int min) async{
    var cursor = await DB.queryCall('''SELECT * FROM "$table" ORDER BY $seqName DESC LIMIT 1;''');

    if(cursor == null || cursor.isEmpty) {
      return min;
    }

    var s = cursor.elementAt(0).toMap()[seqName];

    return max(s ?? min, min);
  }

  static Future<int> getNextSequence(String sName, {int def = 1}) async{
    return (await DB.getColumn("SELECT nextval('$sName') as seq;", 'seq')) ?? def;
  }

  static Future<int> getNextSerial(String table, String column, {int def = 1}) async{
    return (await DB.getColumn("SELECT nextval('${table}_${column}_seq') as ser;", 'ser')) ?? def;
    // SELECT pg_get_serial_sequence('table', 'column');
    // SELECT nextval(pg_get_serial_sequence('ticketreplymessage', 'id')) as ser;
  }

  static Future<String> getNextSequenceNumeric(String sName) async{
    //var cursor = await DB.execution("SELECT nextNum('$sName') as n;");
    var n = await DB.getColumn("SELECT CAST(nextNum('$sName') AS TEXT) as seq;", 'seq');

    if(n == null) {
      return '1';
    }

    if(n is num){
      return n.toInt().toString();
    }

    return n.toString();
  }

  static Future createSequences() async{
    await DB.execution(QTbl_NumericSequence);
    await DB.execution(Q_fn_nextNum);

    await createSequence(DbNames.Seq_User, 100, Constants.MAX_long, 100);
    await createSequence(DbNames.Seq_SystemMessage, 99, Constants.MAX_long, 99);
    await createSequence(DbNames.Seq_Conversation, 199, Constants.MAX_long, 199);
    await createSequence(DbNames.Seq_ticket, 99, Constants.MAX_long, 99);
    await createSequence(DbNames.Seq_MediaGroupId, 99, Constants.MAX_long, 99);
    await createSequence(DbNames.Seq_Course, 99, Constants.MAX_long, 99);
    await createSequence(DbNames.Seq_Pack, 99, Constants.MAX_int, 99);
    await createSequence(DbNames.Seq_DiscountVsUser, 99, Constants.MAX_long, 99);

    await createNumericSequence(DbNames.T_NumericSequence, DbNames.Seq_NewUser, '1', '1');
    await createNumericSequence(DbNames.T_NumericSequence, DbNames.Seq_ConversationMessageId, '100', '100');
    await createNumericSequence(DbNames.T_NumericSequence, DbNames.Seq_ticketMessageId, '100', '100');
    await createNumericSequence(DbNames.T_NumericSequence, DbNames.Seq_MediaId, '100', '100');
  }

  static Future initialSequence() async {
    await setSequenceVal(DbNames.Seq_User, await getLastSequenceVal(DbNames.T_Users, 'user_id'.L, 100));
    await setSequenceVal(DbNames.Seq_Course, await getLastSequenceVal(DbNames.T_Course, 'id', 99));
    await setSequenceVal(DbNames.Seq_ticket, await getLastSequenceVal(DbNames.T_Ticket, 'id', 99));
    await setSequenceVal(DbNames.Seq_MediaGroupId, await getLastSequenceVal(DbNames.T_MediaMessageData, 'group_id', 99));
    var conSec = await getLastSequenceVal(DbNames.T_Conversation, 'id', 199);
    await setSequenceVal(DbNames.Seq_Conversation, max(conSec, 199));
    var s1 = await getLastSequenceVal(DbNames.T_SystemMessageVsCommon, 'id', 99);
    var s2 = await getLastSequenceVal(DbNames.T_SystemMessageVsUser, 'id', 99);
    var s3 = await getLastSequenceVal(DbNames.T_SystemMessageVsBatch, 'id', 99);
    s1 = max(s1, s2);
    await setSequenceVal(DbNames.Seq_SystemMessage, max(s1, s3));
    //await setSequenceVal(DbNames.Seq_DiscountVsUser, await getLastSequenceVal(DbNames.T_DiscountForUser, 'id', 99));
    //await setSequenceVal(DbNames.Seq_Pack, await getLastSequenceVal(DbNames.T_Pack, 'id', 99));

    await setNumericSequenceVal(DbNames.T_NumericSequence, DbNames.Seq_NewUser, await getLastSequenceNumeric(DbNames.T_RegisteringUser, 'id','0'));
    await setNumericSequenceVal(DbNames.T_NumericSequence, DbNames.Seq_MediaId, await getLastSequenceNumeric(DbNames.T_MediaMessageData, 'id', '100'));
    await setNumericSequenceVal(DbNames.T_NumericSequence, DbNames.Seq_ConversationMessageId, await getLastSequenceNumeric(DbNames.T_ConversationMessage, 'group_id', '100'));
    await setNumericSequenceVal(DbNames.T_NumericSequence, DbNames.Seq_ticketMessageId, await getLastSequenceNumeric(DbNames.T_TicketMessage, 'id', '100'));
  }

  // SELECT * FROM pg_sequences;  Or information_schema.sequences   [are view]
  // COPY (SELECT * FROM pg_sequences) TO 'E:\sequences.csv' WITH (FORMAT CSV, HEADER);

  /*
    select 'select ''' || relname  || ''' as sequence, last_value from '  || relname || '  union'
    FROM pg_catalog.pg_class AS t
    WHERE t.relkind IN ('S','');
   */
  static Future listOfSequenceByLastValue() async {
    var q = '''
    select sequence_name, (xpath('/row/last_value/text()', xml_count))[1]::text::int as last_value
    from (
        select sequence_schema, sequence_name,         
                query_to_xml(format('select last_value from %I.%I', sequence_schema, sequence_name), false, true, '') as xml_count
        from information_schema.sequences
        where sequence_schema = 'public'
    ) AS new_table order by last_value desc;
    ''';
  }

  static Future prepareTables() async{
    await DB.execution(QTbl_TypeForSex);
    await DB.execution(UserModelDb.QTbl_User);
    await DB.execution(UserModelDb.QTbl_User$p1);//part
    await DB.execution(UserModelDb.QTbl_User$p2);//part
    await DB.execution(UserModelDb.QIdx_User$birthdate);//idx

    await DB.execution(UserBlockListModelDb.QTbl_UserBlockList);

    await DB.execution(RegisterModelDb.QTbl_RegisteringUser);

    await DB.execution(ContinentModelDb.QTbl_Continent);
    await DB.execution(CountryModelDb.QTbl_Country);
    await DB.execution(CountryModelDb.QIdx_Country$phone_code);

    await DB.execution(LanguageModelDb.QTbl_Language);

    await DB.execution(QTbl_BatchKey);
    await DB.execution(QIdx_BatchKey$title);

    await DB.execution(QTbl_UserToBatch);
    await DB.execution(QTbl_UserToBatch$p1);//part
    await DB.execution(QTbl_UserToBatch$p2);//part
    await DB.execution(QTbl_UserToBatch$p3);//part
    await DB.execution(QTbl_UserToBatch$p4);//part
    await DB.execution(QTbl_UserToBatch$p5);//part
    await DB.execution(QIdx_UserToBatch$batch_key);//idx
    await DB.execution(QIdx_UserToBatch$user_id);//idx

    await DB.execution(QTbl_Rights);

    await DB.execution(QTbl_Roles);
    await DB.execution(QIdx_Roles$has_rights);

    await DB.execution(QTbl_UserToRoles);
    await DB.execution(QTbl_UserToRoles$p1);//part
    //await DB.execution(QAlt_Pk_UserToRoles$p1);//alt
    await DB.execution(QIdx_UserToRoles$Role);//idx

    await DB.execution(PersonalDataModelDb.QTbl_UserPersonalData);
    await DB.execution(PersonalDataModelDb.QTbl_UserPersonalData$p1);
    await DB.execution(PersonalDataModelDb.QTbl_UserPersonalData$p2);

    await DB.execution(UserFitnessDataModelDb.QTbl_UserFitnessData);
    await DB.execution(UserFitnessDataModelDb.QTbl_UserFitnessData$p1);
    await DB.execution(UserFitnessDataModelDb.QTbl_UserFitnessData$p2);
    await DB.execution(UserFitnessDataModelDb.crIdx_UserFitnessData_nodes_js);

    await DB.execution(QTbl_BadWords);
    await DB.execution(QIdx_BadWords$Word);
    await DB.execution(QTbl_ReservedWord);
    await DB.execution(QIdx_ReserveWords$Word);

    await DB.execution(QTbl_SystemMessageVsCommon);
    await DB.execution(QIdx_SystemMessageVsCommon$start_time);
    await DB.execution(QIdx_SystemMessageVsCommon$expire_time);

    await DB.execution(QTbl_SystemMessageVsBatch);
    await DB.execution(QIdx_SystemMessageVsBatch$batch_key);
    await DB.execution(QIdx_SystemMessageVsBatch$start_time);
    await DB.execution(QIdx_SystemMessageVsBatch$expire_time);

    await DB.execution(QTbl_SystemMessageVsUser);
    await DB.execution(QIdx_SystemMessageVsUser$user_id);
    await DB.execution(QIdx_SystemMessageVsUser$start_time);
    await DB.execution(QIdx_SystemMessageVsUser$expire_time);

    await DB.execution(QTbl_SystemMessageResult);
    await DB.execution(QIdx_SystemMessageResult$user_id);

    await DB.execution(UserCountryModelDb.QTbl_UserCountry);
    await DB.execution(UserCountryModelDb.QTbl_UserCountry$p1);//part
    await DB.execution(UserCountryModelDb.QTbl_UserCountry$p2);//part
    await DB.execution(UserCountryModelDb.crIdx_UserCountry$country_iso);//idx

    await DB.execution(UserBankCardModelDb.fn_BankCard$check1);
    await DB.execution(UserBankCardModelDb.QTbl_BankCard);
    await DB.execution(UserBankCardModelDb.QTbl_BankCard$p1);//part
    await DB.execution(UserBankCardModelDb.QTbl_BankCard$p2);//part
    await DB.execution(UserBankCardModelDb.crIdx_BankCard$card_number);//idx

    await DB.execution(UserCurrencyModelDb.QTbl_UserCurrency);
    await DB.execution(UserCurrencyModelDb.QTbl_UserCurrency$p1);//part
    await DB.execution(UserCurrencyModelDb.QTbl_UserCurrency$p2);//part
    await DB.execution(UserCurrencyModelDb.crIdx_UserCurrency$country_iso);//idx

    await DB.execution(UserPlaceModelDb.QTbl_UserPlace);
    await DB.execution(UserPlaceModelDb.QTbl_UserPlace$p1);//part
    await DB.execution(UserPlaceModelDb.QTbl_UserPlace$p2);//part
    await DB.execution(UserPlaceModelDb.QIdx_UserPlace$device_id);//idx
    await DB.execution(UserPlaceModelDb.QAltUk1_UserPlace$p1);//alter
    await DB.execution(UserPlaceModelDb.QAltUk1_UserPlace$p2);//alter

    await DB.execution(UserNameModelDb.QTbl_userNameId);
    await DB.execution(UserNameModelDb.QIdx_userNameId$$user_name);//idx
    await DB.execution(UserNameModelDb.QTbl_userNameId$p1);//part
    await DB.execution(UserNameModelDb.QTbl_userNameId$p2);//part

    await DB.execution(UserNotifierModel.QTbl_userNotifier);
    await DB.execution(UserNotifierModel.QTbl_userNotifier$p1);//part
    await DB.execution(UserNotifierModel.QTbl_userNotifier$p2);//part

    await DB.execution(QTbl_TypeForUserMetaData);

    await DB.execution(UserMetaDataModelDb.QTbl_UserMetaData);
    await DB.execution(UserMetaDataModelDb.QTbl_UserMetaData$p1);//part
    await DB.execution(UserMetaDataModelDb.QTbl_UserMetaData$p2);//part
    await DB.execution(UserMetaDataModelDb.QIdx_UserMetaData$meta_key);//idx
    await DB.execution(UserMetaDataModelDb.QAltUk1_UserMetaData$p1);//alter
    await DB.execution(UserMetaDataModelDb.QAltUk2_UserMetaData$p1);//alter
    await DB.execution(UserMetaDataModelDb.QAltUk1_UserMetaData$p2);//alter
    await DB.execution(UserMetaDataModelDb.QAltUk2_UserMetaData$p2);//alter

    await DB.execution(MobileNumberModelDb.QTbl_mobileNumber);
    await DB.execution(MobileNumberModelDb.QTbl_mobileNumber$p1);//part
    await DB.execution(MobileNumberModelDb.QTbl_mobileNumber$p2);//part
    await DB.execution(MobileNumberModelDb.QIdx_mobileNumber$user_id);//idx
    await DB.execution(MobileNumberModelDb.QIdx_mobileNumber$mobile_number);//idx
    await DB.execution(MobileNumberModelDb.QAltUk1_mobileNumber$p1);//alter

    await DB.execution(QTbl_TypeForUserImage);

    await DB.execution(UserImageModelDb.QTbl_UserImages);
    await DB.execution(UserImageModelDb.QTbl_UserImages$p1);//part
    await DB.execution(UserImageModelDb.QTbl_UserImages$p2);//part
    await DB.execution(UserImageModelDb.QIdx_UserImages$type);//idx
    //await DB.execution(UserImageModelDb.QAltUk1_UserImages$p1);//alter

    await DB.execution(TicketModelDb.QTbl_Ticket);
    await DB.execution(TicketModelDb.QTbl_Ticket$p1);//part
    await DB.execution(TicketModelDb.QTbl_Ticket$p2);//part
    await DB.execution(TicketModelDb.QIdx_Ticket$type);//idx
    await DB.execution(TicketModelDb.QIdx_Ticket$starter_user_id);//idx

    await DB.execution(TicketMessageModelDb.QTbl_TicketMessage);
    await DB.execution(TicketMessageModelDb.QTbl_TicketMessage$p1);//part
    await DB.execution(TicketMessageModelDb.QTbl_TicketMessage$p2);//part
    await DB.execution(TicketMessageModelDb.QIdx_TicketMessage$ticket_id);//idx
    await DB.execution(TicketMessageModelDb.QIdx_TicketMessage$message_type);//idx
    await DB.execution(TicketMessageModelDb.QIdx_TicketMessage$sender_user_id);//idx
    await DB.execution(TicketMessageModelDb.QIdx_TicketMessage$send_ts);//idx
    await DB.execution(TicketMessageModelDb.QAltUk1_TicketMessage$p1);//alt
    await DB.execution(TicketModelDb.view_ticketsForManager1);//view
    await DB.execution(TicketModelDb.view_ticketsForManager2);//view

    await DB.execution(QTbl_seenTicketMessage);
    await DB.execution(QTbl_seenTicketMessage$p1);
    await DB.execution(QTbl_seenTicketMessage$p2);
    await DB.execution(QAlt_Uk1_seenTicketMessage$p1);

    await DB.execution(QTbl_TicketEditedMessage);

    await DB.execution(QTbl_TicketReplyMessage);
    await DB.execution(QTbl_TicketReplyMessage$p1); //part
    await DB.execution(QIdx_TicketReplyMessage$mentionUserId); //idx

    await DB.execution(ConversationModelDb.QTbl_Conversation);
    await DB.execution(ConversationModelDb.QTbl_Conversation$p1);//part
    await DB.execution(ConversationModelDb.QTbl_Conversation$p2);//part
    await DB.execution(ConversationModelDb.QIdx_Conversation$type);//idx
    await DB.execution(ConversationModelDb.QIdx_Conversation$creatorUserId);//idx
    await DB.execution(ConversationModelDb.QIdx_Conversation$title);//idx
    await DB.execution(ConversationModelDb.QTbl_TypeForUserStation);
    await DB.execution(ConversationModelDb.QTbl_TypeForConversation);
    await DB.execution(ConversationModelDb.QTbl_TypeForConversationState);
    await DB.execution(QTbl_TypeForMessage);
    await DB.execution(QTbl_RightsForConversationActivity);


    await DB.execution(ConversationUserModelDb.QTbl_UserToConversation);
    await DB.execution(ConversationUserModelDb.QTbl_UserToConversation$p1);//part
    await DB.execution(ConversationUserModelDb.QTbl_UserToConversation$p2);//part
    await DB.execution(ConversationUserModelDb.QTbl_UserToConversation$p3);//part
    await DB.execution(ConversationUserModelDb.QTbl_UserToConversation$p4);//part
    await DB.execution(ConversationUserModelDb.QTbl_UserToConversation$p5);//part
    await DB.execution(ConversationUserModelDb.QIdx_UserToConversation$inviterUserId);//idx
    await DB.execution(ConversationUserModelDb.QIdx_UserToConversation$joinDate);//idx
    await DB.execution(ConversationUserModelDb.QAltUk1_UserToConversation$p1);//alt
    await DB.execution(ConversationUserModelDb.QAltUk1_UserToConversation$p2);//alt
    await DB.execution(ConversationUserModelDb.QAltUk1_UserToConversation$p3);//alt
    await DB.execution(ConversationUserModelDb.QAltUk1_UserToConversation$p4);//alt
    await DB.execution(ConversationUserModelDb.QAltUk1_UserToConversation$p5);//alt
    await DB.execution(ConversationModelDb.view_conversationsMembers);

    await DB.execution(QTbl_UserConversationHistory);
    await DB.execution(QTbl_UserConversationHistory$p1);
    await DB.execution(QTbl_UserConversationHistory$p2);
    await DB.execution(QTbl_UserConversationHistory$p3);
    await DB.execution(QTbl_UserConversationHistory$p4);
    await DB.execution(QTbl_UserConversationHistory$p5);
    await DB.execution(QIdx_UserConversationHistory$left_date);//idx
    await DB.execution(QIdx_UserConversationHistory$throwout_date);//idx

    await DB.execution(QTbl_seenConversationMessage);
    await DB.execution(QTbl_seenConversationMessage$p1);//part
    await DB.execution(QTbl_seenConversationMessage$p2);//part
    await DB.execution(QAlt_Uk1_seenConversationMessage$p1);//alt

    await DB.execution(QTbl_MediaMessageData);
    await DB.execution(QTbl_MediaMessageData$p1);//part
    await DB.execution(QTbl_MediaMessageData$p2);//part
    await DB.execution(QIdx_MediaMessageData$message_type);//idx

    await DB.execution(ConversationMessageModelDb.QTbl_ConversationMessage);
    await DB.execution(ConversationMessageModelDb.QTbl_ConversationMessage$p1);//part
    await DB.execution(ConversationMessageModelDb.QTbl_ConversationMessage$p2);//part
    await DB.execution(ConversationMessageModelDb.QAltUk1_ConversationMessage$p1);//alt
    await DB.execution(ConversationMessageModelDb.QIdx_ConversationMessage$message_type);//idx
    await DB.execution(ConversationMessageModelDb.QIdx_ConversationMessage$sender_user_id);//idx
    await DB.execution(ConversationMessageModelDb.QIdx_ConversationMessage$send_ts);//idx
    await DB.execution(ConversationMessageModelDb.fn_fetchTopConversationMessage);//fn

    await DB.execution(QTbl_EditedMessage);

    await DB.execution(QTbl_ReplyMessage);
    await DB.execution(QTbl_ReplyMessage$p1);//part
    await DB.execution(QIdx_ReplyMessage$mentionUserId);//idx

    await DB.execution(QTbl_ForwardMessage);
    await DB.execution(QTbl_ForwardMessage$p1);//part
    await DB.execution(QIdx_ForwardMessage$mentionUserId);//idx

    await DB.execution(CourseModelDb.QTbl_Course);
    await DB.execution(CourseModelDb.QTbl_Course$p1);//part
    await DB.execution(CourseModelDb.QTbl_Course$p2);//part
    await DB.execution(CourseModelDb.QIdx_Course$start_date);
    await DB.execution(CourseModelDb.QIdx_Course$finish_date);

    await DB.execution(RequestModelDb.QTbl_courseRequest);
    await DB.execution(RequestModelDb.QTbl_courseRequest$p1);
    await DB.execution(RequestModelDb.QTbl_courseRequest$p2);
    await DB.execution(RequestModelDb.QAltUk1_courseRequest$p1);

    await DB.execution(QTbl_courseBuyQuestion);
    await DB.execution(QTbl_courseBuyQuestion$p1);
    await DB.execution(QTbl_courseBuyQuestion$p2);
    await DB.execution(QAltUk1_courseBuyQuestion$p1);

    await DB.execution(DeviceCellarModelDb.QTbl_DevicesCellar);
    await DB.execution(DeviceCellarModelDb.QTbl_DevicesCellar$p1);//part
    await DB.execution(DeviceCellarModelDb.QAltUk1_DevicesCellar$p1);//alt
    await DB.execution(DeviceCellarModelDb.QTbl_DevicesCellar$p2);//part
    await DB.execution(DeviceCellarModelDb.QAltUk1_DevicesCellar$p2);//alt
    await DB.execution(DeviceCellarModelDb.QTbl_DevicesCellar$p3);//part
    await DB.execution(DeviceCellarModelDb.QAltUk1_DevicesCellar$p3);//alt
    await DB.execution(DeviceCellarModelDb.QIdx_DevicesCellar$user_id);//idx

    await DB.execution(QTbl_DeviceConnections);
    await DB.execution(QTbl_DeviceConnections$p1);//part
    await DB.execution(QAltUk1_DeviceConnections$p1);//alt
    await DB.execution(QTbl_DeviceConnections$p2);//part
    await DB.execution(QAltUk1_DeviceConnections$p2);//alt
    await DB.execution(QTbl_DeviceConnections$p3);//part
    await DB.execution(QAltUk1_DeviceConnections$p3);//alt
    await DB.execution(QTbl_DeviceConnections$p4);//part
    await DB.execution(QAltUk1_DeviceConnections$p4);//alt
    await DB.execution(QTbl_DeviceConnections$p5);//part
    await DB.execution(QAltUk1_DeviceConnections$p5);//alt
    await DB.execution(QIdx_DeviceConnections$websocket_id);//idx

    await DB.execution(UserConnectionModelDb.QTbl_UserConnections);
    await DB.execution(UserConnectionModelDb.QIdx_UserConnections$device_id);//idx
    await DB.execution(UserConnectionModelDb.QIdx_UserConnections$websocket_id);//idx
    await DB.execution(UserConnectionModelDb.QTbl_UserConnections$p1);//part
    await DB.execution(UserConnectionModelDb.QTbl_UserConnections$p2);//part
    await DB.execution(UserConnectionModelDb.QAlt_Uk1_UserConnections$p1);//alt

    await DB.execution(TrainerDataModelDb.QTbl_TrainerData);

    await DB.execution(QTbl_CandidateToDelete);
    await DB.execution(QTbl_Advertising);

    await DB.execution(FoodMaterialModelDb.QTbl_FoodMaterial);
    await DB.execution(FoodMaterialModelDb.QIdx_FoodMaterial$alternatives);
    await DB.execution(FoodMaterialModelDb.QTbl_FoodMaterialTranslate);

    await DB.execution(FoodProgramModelDb.QTbl_FoodPrograms);
    await DB.execution(FoodProgramModelDb.QIndex_FoodProgram$request_id);
    await DB.execution(FoodProgramModelDb.QIndex_FoodProgram$trainer_id);
    await DB.execution(FoodProgramModelDb.QIndex_FoodProgram$cron_date);
    await DB.execution(FoodProgramModelDb.QIndex_FoodProgram$send_date);
    await DB.execution(FoodProgramModelDb.QIndex_FoodProgram$pupil_see_date);
    await DB.execution(FoodProgramModelDb.QTbl_FoodProgramTree);
    await DB.execution(FoodProgramModelDb.QIndex_FoodProgramTree$program_id);
    await DB.execution(ProgramSuggestionModelDb.QTbl_ProgramSuggestion);
    await DB.execution(ProgramSuggestionModelDb.QIdx_ProgramSuggestion$program_id);

    //await DB.execution(RequestModelDb.view_requestSupportDate);

    await DB.execution(QTable_AppVersions);
    await DB.execution(QIndex_AppVersions$version_code);
  }

  static Future prepareFunctions() async{
    await DB.execution(fn_replaceFitnessNodeItem);
    await DB.execution(fn_deleteFitnessNodeItemByDate);
    await DB.execution(fn_deleteFitnessNodeItemByKey);
    await DB.execution(fn_update_seen_ticket);
    await DB.execution(fn_update_seen_chat);
  }

  static Future alters() async{
    //await DatabaseAlters.courseBuy_add_receiveProgramDate();
  }

  static void setPreData(){
    DB.execution(Q_insert_sexType);
    DB.execution(Q_insert_imageType);
    DB.execution(Q_insert_userMetaType);
    DB.execution(Q_insert_UserSystem);
    DB.execution(Q_insert_UserNameId);
    DB.execution(Q_insert_Rights);
    DB.execution(Q_insert_Roles);
    DB.execution(Q_insert_UserRoles);
    DB.execution(Q_insert_conversationType);
    DB.execution(Q_insert_TypeForConversationState);
    DB.execution(Q_insert_TypeForMessage);
    DB.execution(Q_insert_TypeForUserStation);
    DB.execution(Q_insert_rightsForConversation);
    DB.execution(Q_insert_languages);
  }
  ///==========================================================================================
  static final String QTbl_NumericSequence = '''
		CREATE TABLE IF NOT EXISTS #tb (
			name varchar(100) NOT NULL,
			value Numeric NOT NULL DEFAULT 0,
			StepValue INTEGER NOT NULL DEFAULT 1,
			MinValue Numeric NOT NULL DEFAULT 0,
			MaxValue Numeric NOT NULL DEFAULT 9999999999999999999999999999999999999999::numeric(40,0),
			CONSTRAINT pk_numericSequence PRIMARY KEY (name)
			);
			'''
    .replaceFirst('#tb', DbNames.T_NumericSequence);

  static final String Q_fn_nextNum = '''
			CREATE OR REPLACE FUNCTION nextNum(secName varchar)
			 RETURNS Numeric AS \$\$
			  DECLARE lastV Numeric;
			  minV Numeric;
			  maxV Numeric;
			  addStep integer;
			  BEGIN
			  	LOCK TABLE ${DbNames.T_NumericSequence} IN ROW EXCLUSIVE MODE;
			  	SELECT value,MinValue,MaxValue,StepValue INTO lastV,minV,maxV,addStep 
			  	  FROM ${DbNames.T_NumericSequence} WHERE name = \$1;
			  	 	
			  	IF lastV IS NULL THEN RAISE EXCEPTION 'nextNum() not found sequence, %', secName;
			  	END IF;
			  	
				BEGIN
				lastV := lastV + addStep;
					EXCEPTION WHEN OTHERS THEN lastV := minV;
				END;
				
				IF lastV > maxV THEN lastV := minV;
				END IF;
				
				BEGIN
				UPDATE ${DbNames.T_NumericSequence} SET value = lastV WHERE name = secName;
					EXCEPTION WHEN OTHERS THEN
						RAISE WARNING 'nextNum(%)> %', \$1, SQLERRM; RETURN nextNum(\$1);
				END;
				
				RETURN lastV;
			  END; 
			\$\$ language plpgsql;
			''';


  static final String QTbl_CandidateToDelete = '''
 		CREATE TABLE IF NOT EXISTS #tb (
			id BIGSERIAL,
			path varchar(400) NOT NULL,
			register_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
			CONSTRAINT pk_candidateToDelete PRIMARY KEY (Id),
			CONSTRAINT uk1_candidateToDelete UNIQUE (path));
			'''
      .replaceFirst('#tb', DbNames.T_CandidateToDelete);


  // // 'notSet' 0, 'male' 1, 'female' 2, 'bisexual'5
  static final String QTbl_TypeForSex = '''
		CREATE TABLE IF NOT EXISTS #tb (
			key SMALLINT NOT NULL,
			caption varchar(15) NOT NULL,
			is_usable BOOLEAN DEFAULT true,
			CONSTRAINT pk_typeForSex PRIMARY KEY (key),
			CONSTRAINT uk1_typeForSex UNIQUE (caption)
			);
			'''
      .replaceFirst('#tb', DbNames.T_TypeForSex);

  static final String Q_insert_sexType = '''
		 INSERT INTO ${DbNames.T_TypeForSex} (key, caption, is_usable)
		 values
		   ( 0, 'notSet', true)
		   , ( 1, 'male', true)
		   , ( 2, 'female', true)
		   , ( 5, 'bisexual', false)
			ON CONFLICT DO NOTHING;
			''';


  static final String QTbl_BatchKey = '''
   		CREATE TABLE IF NOT EXISTS #tb (
			key SERIAL,
			title varchar(40) NOT NULL,
			CONSTRAINT pk_BatchKey PRIMARY KEY (key),
			CONSTRAINT uk1_BatchKey UNIQUE (title)
			);
			'''.replaceFirst('#tb', DbNames.T_BatchKey);

  static final String QIdx_BatchKey$title = '''
   		CREATE INDEX IF NOT EXISTS BatchKey_Title_idx
   		ON #tb USING GIN (title gin_trgm_ops);
   		'''
      .replaceFirst('#tb', DbNames.T_BatchKey);



  static final String QTbl_UserToBatch = '''
 		CREATE TABLE IF NOT EXISTS #tb (
 		 batch_key INT NOT NULL,
 		 user_id BIGINT NOT NULL,
 		 CONSTRAINT uk1_UserToBatch UNIQUE (batch_key, user_id),
 		 CONSTRAINT fk1_UserToBatch FOREIGN KEY (user_id) REFERENCES #ref (user_id)
 		  ON DELETE CASCADE ON UPDATE CASCADE
 		 )
 		 PARTITION BY HASH (batch_key, user_id);
 		 '''
      .replaceFirst('#tb', DbNames.T_UserToBatch)
      .replaceFirst('#ref', DbNames.T_Users);

  static final String QTbl_UserToBatch$p1 = '''
      CREATE TABLE IF NOT EXISTS ${DbNames.T_UserToBatch}_p1
      PARTITION OF ${DbNames.T_UserToBatch} FOR VALUES WITH (MODULUS 5, REMAINDER 0);''';

  static final String QTbl_UserToBatch$p2 = '''
    CREATE TABLE IF NOT EXISTS ${DbNames.T_UserToBatch}_p2
    PARTITION OF ${DbNames.T_UserToBatch} FOR VALUES WITH (MODULUS 5, REMAINDER 1);''';

  static final String QTbl_UserToBatch$p3 = '''
    CREATE TABLE IF NOT EXISTS ${DbNames.T_UserToBatch}_p3
    PARTITION OF ${DbNames.T_UserToBatch} FOR VALUES WITH (MODULUS 5, REMAINDER 2);''';

  static final String QTbl_UserToBatch$p4 = '''
    CREATE TABLE IF NOT EXISTS ${DbNames.T_UserToBatch}_p4
    PARTITION OF ${DbNames.T_UserToBatch} FOR VALUES WITH (MODULUS 5, REMAINDER 3);''';

  static final String QTbl_UserToBatch$p5 = '''
    CREATE TABLE IF NOT EXISTS ${DbNames.T_UserToBatch}_p5
    PARTITION OF ${DbNames.T_UserToBatch} FOR VALUES WITH (MODULUS 5, REMAINDER 4);''';

  static final String QIdx_UserToBatch$batch_key = '''
    CREATE INDEX IF NOT EXISTS UserToBatch_BatchKey_idx
    ON ${DbNames.T_UserToBatch} USING BTREE (batch_key);''';

  static final String QIdx_UserToBatch$user_id = '''
    CREATE INDEX IF NOT EXISTS UserToBatch_user_id_idx
    ON ${DbNames.T_UserToBatch} USING BTREE (user_id);''';



  static final String QTbl_Rights = '''
 		CREATE TABLE IF NOT EXISTS ${DbNames.T_Rights} (
      key SMALLSERIAL,
      title VARCHAR(40) NOT NULL,
      description VARCHAR(100) DEFAULT NULL,
      CONSTRAINT pk_Rights PRIMARY KEY (key),
      CONSTRAINT uk1_Rights UNIQUE (title));
 		''';

  static final String QTbl_Roles = '''
 		CREATE TABLE IF NOT EXISTS ${DbNames.T_Roles} (
      key SMALLSERIAL,
      title VARCHAR(40) NOT NULL,
      description VARCHAR(100) DEFAULT NULL,
      has_rights INT[] DEFAULT NULL,
      creator_user_id BIGINT NOT NULL,
      creation_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
      CONSTRAINT pk_Roles PRIMARY KEY (key),
      CONSTRAINT uk1_Roles UNIQUE (title),
      CONSTRAINT fk1_Roles FOREIGN KEY (creator_user_id) REFERENCES ${DbNames.T_Users} (user_id)
        ON DELETE CASCADE ON UPDATE CASCADE);
 			''';

  static final String QIdx_Roles$has_rights = '''
   	CREATE INDEX IF NOT EXISTS #tb_has_rights_idx
   	ON #tb USING GIN (has_rights gin__int_ops);
   '''
      .replaceAll('#tb', DbNames.T_Roles);


  /// no use INT2, because error gin__int_ops
  static final String QTbl_UserToRoles = '''
    CREATE TABLE IF NOT EXISTS ${DbNames.T_UserToRoles} (
       user_id BIGINT NOT NULL,
       roles INT[] NOT NULL DEFAULT '{}'::int[],
       rights INT[] NOT NULL DEFAULT '{}'::int[],
       CONSTRAINT pk_UserToRoles PRIMARY KEY (user_id),
       CONSTRAINT fk1_UserToRoles FOREIGN KEY (user_id) REFERENCES ${DbNames.T_Users} (user_id) 
      		ON DELETE CASCADE ON UPDATE CASCADE
      )
      PARTITION BY RANGE (user_id);
      ''';

  static final String QTbl_UserToRoles$p1 = '''
    CREATE TABLE IF NOT EXISTS ${DbNames.T_UserToRoles}_p1
     PARTITION OF ${DbNames.T_UserToRoles} FOR VALUES FROM (0) TO (500000);''';

  /*static final String QAlt_Pk_UserToRoles$p1 = '''
    DO \$\$ BEGIN ALTER TABLE ${DbNames.T_UserToRoles}_p1
       ADD CONSTRAINT pk_UserToRoles PRIMARY KEY (user_id);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM;
        END IF;
      END \$\$;''';   is set by parent */

  static final String QIdx_UserToRoles$Role = '''
    CREATE INDEX IF NOT EXISTS ${DbNames.T_UserToRoles}_Role_idx
    ON ${DbNames.T_UserToRoles} USING GIN (roles gin__int_ops);''';



  static final String QTbl_BadWords = '''
 		CREATE TABLE IF NOT EXISTS ${DbNames.T_BadWords} (
      word varchar(20) NOT NULL,
      language_iso varchar(5) NOT NULL,
      CONSTRAINT pk_BadWords PRIMARY KEY (Word));
 		''';

  static final String QIdx_BadWords$Word = '''
    CREATE INDEX IF NOT EXISTS ${DbNames.T_BadWords}_Word_idx
    ON ${DbNames.T_BadWords} USING GIN (word);''';//for full search


  static final String QTbl_ReservedWord = '''
 		CREATE TABLE IF NOT EXISTS ${DbNames.T_ReservedWords} (
      word varchar(20) NOT NULL,
      is_case_sensitive BOOLEAN DEFAULT FALSE,
      CONSTRAINT pk_${DbNames.T_ReservedWords} PRIMARY KEY (word));
 		''';

  static final String QIdx_ReserveWords$Word = '''
      CREATE INDEX IF NOT EXISTS ${DbNames.T_ReservedWords}_Word_idx
      ON ${DbNames.T_ReservedWords} USING GIN (Word);''';//for full search



  // extra_js: 'CallBackKey'
  static final String QTbl_SystemMessageVsCommon = '''
 	 CREATE TABLE IF NOT EXISTS ${DbNames.T_SystemMessageVsCommon} (
 		id BIGINT NOT NULL DEFAULT nextval('${DbNames.Seq_SystemMessage}'),
 		message varchar(500) NOT NULL,
 		type varchar(20) DEFAULT 'OkDialog',
 		extra_js JSONB DEFAULT NULL,
 		start_time TIMESTAMP DEFAULT (now() at time zone 'utc'),
 		expire_time TIMESTAMP DEFAULT (now() at time zone 'utc') + interval '7 days',
 		CONSTRAINT pk_${DbNames.T_SystemMessageVsCommon} PRIMARY KEY (Id)
 		);
 		''';

  static final String QIdx_SystemMessageVsCommon$start_time = '''
   	CREATE INDEX IF NOT EXISTS ${DbNames.T_SystemMessageVsCommon}_start_time_idx
   	ON ${DbNames.T_SystemMessageVsCommon}
   	USING BTREE (start_time DESC);
   	 ''';

  static final String QIdx_SystemMessageVsCommon$expire_time = '''
    CREATE INDEX IF NOT EXISTS ${DbNames.T_SystemMessageVsCommon}_expire_time_idx
    ON ${DbNames.T_SystemMessageVsCommon}
    USING BTREE (expire_time DESC);
 	''';


  static final String QTbl_SystemMessageVsBatch = '''
    CREATE TABLE IF NOT EXISTS #tb (
      id BIGINT NOT NULL DEFAULT nextval('Seq_SystemMessage'),
      batch_key INT NOT NULL,
      show_count INT DEFAULT 1,
      message varchar(1000) NOT NULL,
      type varchar(20) DEFAULT 'OkDialog',
      extra_js JSONB DEFAULT NULL,
      start_time TIMESTAMP DEFAULT (now() at time zone 'utc'),
      expire_time TIMESTAMP DEFAULT (now() at time zone 'utc') + interval '7 days',
      CONSTRAINT pk_#tb PRIMARY KEY (Id),
      CONSTRAINT fk1_#tb FOREIGN KEY (batch_key) REFERENCES ${DbNames.T_BatchKey} (key)
      ON DELETE CASCADE ON UPDATE CASCADE);
    '''
      .replaceAll('#tb', DbNames.T_SystemMessageVsBatch)
      .replaceFirst('Seq_SystemMessage', DbNames.Seq_SystemMessage);

  static final String QIdx_SystemMessageVsBatch$batch_key = '''
 	  CREATE INDEX IF NOT EXISTS ${DbNames.T_SystemMessageVsBatch}_Batch_key_idx
 	  ON ${DbNames.T_SystemMessageVsBatch}
 	  USING BTREE (batch_key);
 	''';

  static final String QIdx_SystemMessageVsBatch$start_time = '''
    CREATE INDEX IF NOT EXISTS ${DbNames.T_SystemMessageVsBatch}_Start_time
    ON ${DbNames.T_SystemMessageVsBatch}
    USING BTREE (start_time DESC);
 	''';

  static final String QIdx_SystemMessageVsBatch$expire_time = '''
    CREATE INDEX IF NOT EXISTS ${DbNames.T_SystemMessageVsBatch}_Expire_time
    ON ${DbNames.T_SystemMessageVsBatch}
    USING BTREE (start_time DESC);
 	''';

  static final String QTbl_SystemMessageVsUser = '''
 	CREATE TABLE IF NOT EXISTS #tb (
    id BIGINT NOT NULL DEFAULT nextval('Seq_SystemMessage'),
    user_id BIGINT NOT NULL DEFAULT -1,
    show_count INT DEFAULT 1,
    message varchar(1000) NOT NULL,
    type varchar(20) DEFAULT 'OkDialog',
    extra_js JSONB DEFAULT NULL,
    start_time TIMESTAMP DEFAULT (now() at time zone 'utc'),
    expire_time TIMESTAMP DEFAULT (now() at time zone 'utc') + interval '7 days',
    is_send BOOLEAN DEFAULT FALSE,
    CONSTRAINT pk_#tb PRIMARY KEY (id),
    CONSTRAINT fk1_#tb FOREIGN KEY (user_id) REFERENCES ${DbNames.T_Users} (user_id)
    ON DELETE SET DEFAULT ON UPDATE CASCADE);
 	'''
      .replaceAll('#tb', DbNames.T_SystemMessageVsUser)
      .replaceFirst('Seq_SystemMessage', DbNames.Seq_SystemMessage);

  static final String QIdx_SystemMessageVsUser$user_id = '''
      CREATE INDEX IF NOT EXISTS ${DbNames.T_SystemMessageVsUser}_user_id_idx
      ON ${DbNames.T_SystemMessageVsUser}
      USING BTREE (user_id);
      ''';

  static final String QIdx_SystemMessageVsUser$start_time = '''
    CREATE INDEX IF NOT EXISTS ${DbNames.T_SystemMessageVsUser}_Start_time_idx
    ON ${DbNames.T_SystemMessageVsUser}
    USING BTREE (start_time DESC);
      ''';

  static final String QIdx_SystemMessageVsUser$expire_time = '''
    CREATE INDEX IF NOT EXISTS ${DbNames.T_SystemMessageVsUser}_Expire_time_idx
    ON ${DbNames.T_SystemMessageVsUser}
    USING BTREE (expire_time DESC);
      ''';


  static final String QTbl_SystemMessageResult = '''
 	CREATE TABLE IF NOT EXISTS ${DbNames.T_SystemMessageResult} (
    message_id BIGINT NOT NULL,
    user_id BIGINT DEFAULT NULL,
    result varchar(20) NOT NULL,
    register_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
    CONSTRAINT uk1_SystemMessageResult UNIQUE (message_id, user_id));
 	''';

  static final String QIdx_SystemMessageResult$user_id = '''
    CREATE INDEX IF NOT EXISTS SystemMessageResult_user_id_idx
    ON ${DbNames.T_SystemMessageResult}
    USING BTREE (user_id);
      ''';


  static final String QTbl_TypeForUserMetaData = '''
 	CREATE TABLE IF NOT EXISTS ${DbNames.T_TypeForUserMetaData} (
 	key SMALLSERIAL,
 	caption varchar(40) NOT NULL,
 	CONSTRAINT pk_TypeForUserMetaData PRIMARY KEY (key),
 	CONSTRAINT uk1_TypeForUserMetaData UNIQUE (caption));
 	''';


  static final String QTbl_TypeForUserImage = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_TypeForUserImage} (
       key SMALLSERIAL,
       caption VARCHAR(40) NOT NULL,
       CONSTRAINT pk_TypeForUserImage PRIMARY KEY (key),
       CONSTRAINT uk1_TypeForUserImage UNIQUE (caption)
      );''';


  //if users count grow in future, create more partition
  /// this table update on (webSocket request)
  static final String QTbl_DeviceConnections = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_DeviceConnections} (
       device_id varchar(40) NOT NULL,
       app_name varchar(30) NOT NULL,
       websocket_id varchar(60) DEFAULT NULL,
       language_iso varchar(5) DEFAULT 'en',
       last_touch TIMESTAMP DEFAULT (now() at time zone 'utc'),
       CONSTRAINT pk_DeviceConnections PRIMARY KEY (device_id, app_name)
      )
      PARTITION BY HASH (device_id);''';

  static final String QTbl_DeviceConnections$p1 = '''
    CREATE TABLE IF NOT EXISTS ${DbNames.T_DeviceConnections}_p1
    PARTITION OF ${DbNames.T_DeviceConnections} FOR VALUES WITH (MODULUS 5, REMAINDER 0);
      ''';

  static final String QAltUk1_DeviceConnections$p1 = '''
   DO \$\$ BEGIN ALTER TABLE ${DbNames.T_DeviceConnections}_p1
       ADD CONSTRAINT uk1_${DbNames.T_DeviceConnections} UNIQUE (device_id, app_name);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;''';

  static final String QTbl_DeviceConnections$p2 = '''
    CREATE TABLE IF NOT EXISTS ${DbNames.T_DeviceConnections}_p2
    PARTITION OF ${DbNames.T_DeviceConnections} FOR VALUES WITH (MODULUS 5, REMAINDER 1);''';

  static final String QAltUk1_DeviceConnections$p2 = '''
  DO \$\$ BEGIN ALTER TABLE ${DbNames.T_DeviceConnections}_p2
       ADD CONSTRAINT uk1_${DbNames.T_DeviceConnections} UNIQUE (device_id, app_name);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;''';

  static final String QTbl_DeviceConnections$p3 = '''
    CREATE TABLE IF NOT EXISTS ${DbNames.T_DeviceConnections}_p3
    PARTITION OF ${DbNames.T_DeviceConnections} FOR VALUES WITH (MODULUS 5, REMAINDER 2);''';

  static final String QAltUk1_DeviceConnections$p3 = '''
  DO \$\$ BEGIN ALTER TABLE ${DbNames.T_DeviceConnections}_p3
       ADD CONSTRAINT uk1_${DbNames.T_DeviceConnections} UNIQUE (device_id, app_name);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;''';

  static final String QTbl_DeviceConnections$p4 = '''
    CREATE TABLE IF NOT EXISTS ${DbNames.T_DeviceConnections}_p4
    PARTITION OF ${DbNames.T_DeviceConnections} FOR VALUES WITH (MODULUS 5, REMAINDER 3);''';

  static final String QAltUk1_DeviceConnections$p4 = '''
    DO \$\$ BEGIN ALTER TABLE ${DbNames.T_DeviceConnections}_p4
      ADD CONSTRAINT uk1_${DbNames.T_DeviceConnections} UNIQUE (device_id, app_name);
      EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
      ELSE RAISE EXCEPTION '> %', SQLERRM; 
      END IF; END \$\$;''';

  static final String QTbl_DeviceConnections$p5 = '''
      CREATE TABLE IF NOT EXISTS ${DbNames.T_DeviceConnections}_p5
      PARTITION OF ${DbNames.T_DeviceConnections} FOR VALUES WITH (MODULUS 5, REMAINDER 4);''';

  static final String QAltUk1_DeviceConnections$p5 = '''
    DO \$\$ BEGIN ALTER TABLE ${DbNames.T_DeviceConnections}_p5
       ADD CONSTRAINT uk1_${DbNames.T_DeviceConnections} UNIQUE (device_id, app_name);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;''';

  static final String QIdx_DeviceConnections$websocket_id = '''
    CREATE INDEX IF NOT EXISTS DeviceConnections_WebSocketId_idx
     ON ${DbNames.T_DeviceConnections} USING BTREE (websocket_id);''';

  //.....................................................................................................

  // discount:  num > 0: value | num < 0: percent
  // count: 0 means infinite
  /*static final String QTbl_DiscountCoupon = '''
 		CREATE TABLE IF NOT EXISTS ${DbNames.T_DiscountCoupon} (
 		coupon_key varchar(40) NOT NULL,
 		discount INT NOT NULL,
 		description varchar(200) DEFAULT NULL,
 		count INT DEFAULT 0,
 		creator_user_id BIGINT NOT NULL,
 		creation_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
 		start_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
 		finish_date TIMESTAMP NOT NULL,
 		extra_js JSONB DEFAULT NULL,
 		CONSTRAINT pk_DiscountCoupon PRIMARY KEY (coupon_key));
 		''';

  static final String QIdx_DiscountCoupon$start_date = '''
   	CREATE INDEX IF NOT EXISTS DiscountCoupon_StartDate_idx
   	ON ${DbNames.T_DiscountCoupon}
   	USING BTREE (start_date DESC NULLS FIRST); ''';

  static final String QIdx_DiscountCoupon$finish_date = '''
    CREATE INDEX IF NOT EXISTS DiscountCoupon_FinishDate_idx
    ON ${DbNames.T_DiscountCoupon} 
    USING BTREE (finish_date DESC);''';


  static final String QTbl_DiscountForUser = '''
 		CREATE TABLE IF NOT EXISTS ${DbNames.T_DiscountForUser} (
      id BIGINT NOT NULL DEFAULT nextval('${DbNames.Seq_DiscountVsUser}'),
      coupon_key varchar(40) NOT NULL,
      user_id BIGINT NOT NULL,
      product_id BIGINT NOT NULL,
      register_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
      CONSTRAINT pk_DiscountVsUser PRIMARY KEY (id),
      CONSTRAINT uk1_DiscountVsUser UNIQUE (coupon_key, user_id, product_id),
      CONSTRAINT fk1_DiscountVsUser FOREIGN KEY (user_id) REFERENCES ${DbNames.T_Users} (user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
      CONSTRAINT fk2_DiscountVsUser FOREIGN KEY (coupon_key) REFERENCES ${DbNames.T_DiscountCoupon} (coupon_key)
        ON DELETE RESTRICT ON UPDATE CASCADE);
 			''';

  static final String QIdx_DiscountVsUser$user_id = '''
    CREATE INDEX IF NOT EXISTS DiscountVsUser_user_id_idx
    ON ${DbNames.T_DiscountForUser} USING BTREE (user_id);''';

  static final String QIdx_DiscountVsUser$coupon_key = '''
    CREATE INDEX IF NOT EXISTS DiscountVsUser_CouponKey_idx
    ON ${DbNames.T_DiscountForUser} USING BTREE (coupon_key);''';*/


  static final String QTbl_TypeForMessage = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_TypeForMessage} (
       key SMALLSERIAL,
       caption varchar(40) NOT NULL,
       CONSTRAINT pk_TypeForMessage PRIMARY KEY (key),
       CONSTRAINT uk1_TypeForMessage UNIQUE (caption)
      );''';

  static final String QTbl_RightsForConversationActivity = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_RightsForConversationActivity} (
       key SMALLSERIAL,
       caption varchar(40) NOT NULL,
       CONSTRAINT pk_RightsForConversationActivity PRIMARY KEY (key),
       CONSTRAINT uk1_RightsForConversationActivity UNIQUE (caption)
      );''';

  //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  // last_message_ts <-> seen_ts
  static final String QTbl_seenTicketMessage = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_seenTicketMessage}(
      user_id BIGINT NOT NULL,
      ticket_id BIGINT NOT NULL,
      last_message_ts TIMESTAMP NOT NULL,
      CONSTRAINT fk1_seenTicketMessage FOREIGN KEY (user_id) REFERENCES ${DbNames.T_Users} (user_id)
      	ON DELETE CASCADE ON UPDATE CASCADE
      )
      PARTITION BY RANGE (user_id);''';

  static final String QTbl_seenTicketMessage$p1 = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_seenTicketMessage}_p1
  PARTITION OF ${DbNames.T_seenTicketMessage}
  FOR VALUES FROM (0) TO (500000);''';//500_000

  static final String QTbl_seenTicketMessage$p2 = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_seenTicketMessage}_p2
  PARTITION OF ${DbNames.T_seenTicketMessage}
  FOR VALUES FROM (500000) TO (1000000);''';

  static final String QAlt_Uk1_seenTicketMessage$p1 = '''
  DO \$\$ BEGIN ALTER TABLE ${DbNames.T_seenTicketMessage}_p1
       ADD CONSTRAINT uk1_seenTicketMessage UNIQUE (user_id, ticket_id);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;
       ''';


  static final String QTbl_TicketEditedMessage = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_TicketEditedMessage}(
       message_id Numeric(40,0) NOT NULL,
       old_send_ts TIMESTAMP NOT NULL,
       old_text varchar(2000) DEFAULT NULL,
       old_media_id numeric(40,0) DEFAULT NULL,
       CONSTRAINT uk1_ticketEditedMessage UNIQUE (message_id, old_send_ts),
       CONSTRAINT fk1_ticketEditedMessage FOREIGN KEY (message_id) REFERENCES ${DbNames.T_TicketMessage} (id)
       	ON DELETE SET DEFAULT ON UPDATE CASCADE
      );''';



  static final String QTbl_TicketReplyMessage = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_TicketReplyMessage}(
       id BIGSERIAL,  
       mention_message_id Numeric(40,0) NOT NULL,
       mention_user_id BIGINT NOT NULL,
       message_type SMALLINT NOT NULL,
       alternative_mention_name VARCHAR(70) DEFAULT NULL,
       short_text VARCHAR(120) DEFAULT NULL,
       thumb_data VARCHAR(400) DEFAULT NULL,
       CONSTRAINT pk_TicketReplyMessage PRIMARY KEY (id)
      )
      PARTITION BY RANGE (id);''';

  static final String QTbl_TicketReplyMessage$p1 = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_TicketReplyMessage}_p1
  PARTITION OF ${DbNames.T_TicketReplyMessage}
  FOR VALUES FROM (0) TO (1000000);''';//1_000_000

  static final String QIdx_TicketReplyMessage$mentionUserId = '''
  CREATE INDEX IF NOT EXISTS TicketReplyMessage_mention_user_id_idx
  ON ${DbNames.T_TicketReplyMessage} USING BTREE (mention_user_id);''';

  /*static final String QAlt_Uk1_TicketReplyMessage$p1 = '''
  DO \$\$ BEGIN ALTER TABLE ${DbNames.T_TicketReplyMessage}_p1
       ADD CONSTRAINT uk1_TicketReplyMessage UNIQUE (message_id, mention_message_id);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;''';*/

  //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++



  static final String QTbl_UserConversationHistory = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_UserConversationHistory}(
       user_id BIGINT NOT NULL,
       conversation_id BIGINT NOT NULL,
       inviter_user_id BIGINT NOT NULL,
       invite_date TIMESTAMP,
       join_date TIMESTAMP DEFAULT NULL,
       reject_date TIMESTAMP DEFAULT NULL,
       left_date TIMESTAMP DEFAULT NULL,
       throwout_date TIMESTAMP DEFAULT NULL
      )
      PARTITION BY HASH (user_id, conversation_id);''';

  static final String QTbl_UserConversationHistory$p1 = '''
      CREATE TABLE IF NOT EXISTS ${DbNames.T_UserConversationHistory}_p1
      PARTITION OF ${DbNames.T_UserConversationHistory} FOR VALUES WITH (MODULUS 5, REMAINDER 0);''';

  static final String QTbl_UserConversationHistory$p2 = '''
    CREATE TABLE IF NOT EXISTS ${DbNames.T_UserConversationHistory}_p2
    PARTITION OF ${DbNames.T_UserConversationHistory} FOR VALUES WITH (MODULUS 5, REMAINDER 1);''';

  static final String QTbl_UserConversationHistory$p3 = '''
    CREATE TABLE IF NOT EXISTS ${DbNames.T_UserConversationHistory}_p3
    PARTITION OF ${DbNames.T_UserConversationHistory} FOR VALUES WITH (MODULUS 5, REMAINDER 2);''';

  static final String QTbl_UserConversationHistory$p4 = '''
    CREATE TABLE IF NOT EXISTS ${DbNames.T_UserConversationHistory}_p4
    PARTITION OF ${DbNames.T_UserConversationHistory} FOR VALUES WITH (MODULUS 5, REMAINDER 3);''';

  static final String QTbl_UserConversationHistory$p5 = '''
    CREATE TABLE IF NOT EXISTS ${DbNames.T_UserConversationHistory}_p5
    PARTITION OF ${DbNames.T_UserConversationHistory} FOR VALUES WITH (MODULUS 5, REMAINDER 4);''';

  static final String QIdx_UserConversationHistory$left_date = '''
  CREATE INDEX IF NOT EXISTS UserToConversation_LeftDate_idx
  ON ${DbNames.T_UserConversationHistory} USING BTREE (left_date DESC NULLS LAST);''';

  static final String QIdx_UserConversationHistory$throwout_date = '''
  CREATE INDEX IF NOT EXISTS UserToConversation_ThrowOutDate_idx
  ON ${DbNames.T_UserConversationHistory} USING BTREE (throwout_date DESC NULLS LAST);''';



  static final String QTbl_seenConversationMessage = '''
  CREATE TABLE IF NOT EXISTS #tb (
      user_id BIGINT NOT NULL,
      conversation_id BIGINT NOT NULL,
      last_message_ts TIMESTAMP NOT NULL,
      CONSTRAINT fk1_#tb FOREIGN KEY (user_id) REFERENCES ${DbNames.T_Users} (user_id)
      	ON DELETE CASCADE ON UPDATE CASCADE
      )
      PARTITION BY RANGE (user_id);
      '''.replaceAll('#tb', DbNames.T_seenConversationMessage);

  static final String QTbl_seenConversationMessage$p1 = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_seenConversationMessage}_p1
  PARTITION OF ${DbNames.T_seenConversationMessage}
  FOR VALUES FROM (0) TO (500000);''';//500_000

  static final String QTbl_seenConversationMessage$p2 = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_seenConversationMessage}_p2
  PARTITION OF ${DbNames.T_seenConversationMessage}
  FOR VALUES FROM (500000) TO (1000000);''';

  static final String QAlt_Uk1_seenConversationMessage$p1 = '''
  DO \$\$ BEGIN ALTER TABLE ${DbNames.T_seenConversationMessage}_p1
       ADD CONSTRAINT uk1_LastSeenConversationMessage UNIQUE (user_id, conversation_id);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;
       ''';

  // message_type: 0 unKnown, 1 file, 2 audio, 3 video, [Q_insert_TypeForMessage]
  // extra_js: ,...
  static final String QTbl_MediaMessageData = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_MediaMessageData}(
       id numeric(40,0) NOT NULL DEFAULT nextNum('${DbNames.Seq_MediaId}'),
       message_type SMALLINT DEFAULT 0,
       group_id numeric(40,0) DEFAULT NULL,
       extension VARCHAR(10) DEFAULT NULL,
       name VARCHAR(70) DEFAULT '',
       width SMALLINT DEFAULT 0,
       height SMALLINT DEFAULT 0,
       volume INT DEFAULT NULL,
       duration INT DEFAULT NULL,
       path VARCHAR(400) NOT NULL,
       screenshot_js JSONB DEFAULT NULL,
       extra_js JSONB DEFAULT NULL,
       CONSTRAINT pk_MediaMessageData PRIMARY KEY (id),
       CONSTRAINT fk1_MediaMessageData FOREIGN KEY (message_type) REFERENCES ${DbNames.T_TypeForMessage} (key)
       	ON DELETE NO ACTION ON UPDATE CASCADE
      )
      PARTITION BY RANGE (id);''';

  static final String QTbl_MediaMessageData$p1 = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_MediaMessageData}_p1
  PARTITION OF ${DbNames.T_MediaMessageData}
  FOR VALUES FROM (0) TO (1000000);''';//1_000_000

  static final String QTbl_MediaMessageData$p2 = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_MediaMessageData}_p2
  PARTITION OF ${DbNames.T_MediaMessageData}
  FOR VALUES FROM (1000000) TO (2000000::numeric(40,0));'''; //2_000_000

  static final String QIdx_MediaMessageData$message_type = '''
  CREATE INDEX IF NOT EXISTS MediaMessageData_MessageType_idx
  ON ${DbNames.T_MediaMessageData} USING BTREE (message_type);''';




  static final String QTbl_EditedMessage = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_EditedMessage}(
       message_id Numeric(40,0) NOT NULL,
       old_send_ts TIMESTAMP NOT NULL,
       old_text varchar(2000) DEFAULT NULL,
       old_media_id numeric(40,0) DEFAULT NULL,
       CONSTRAINT uk1_EditedMessage UNIQUE (message_id, old_send_ts),
       CONSTRAINT fk1_EditedMessage FOREIGN KEY (message_id) REFERENCES ${DbNames.T_ConversationMessage} (id)
       	ON DELETE SET DEFAULT ON UPDATE CASCADE
      );''';


  //old: message_id Numeric(40,0), reference
  //replier_id: senderId
  static final String QTbl_ReplyMessage = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_ReplyMessage}( 
       id BIGSERIAL,  
       mention_message_id Numeric(40,0) NOT NULL,
       mention_user_id BIGINT NOT NULL,
       message_type SMALLINT NOT NULL,
       alternative_mention_name VARCHAR(40) DEFAULT NULL,
       short_text VARCHAR(100) DEFAULT NULL,
       thumb_data VARCHAR(400) DEFAULT NULL,
       CONSTRAINT pk_ReplyMessage PRIMARY KEY (id)
      )
      PARTITION BY RANGE (id);''';

  static final String QTbl_ReplyMessage$p1 = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_ReplyMessage}_p1 
  PARTITION OF ${DbNames.T_ReplyMessage}
  FOR VALUES FROM (0) TO (1000000);''';//1_000_000

  /*static final String QAlt_Uk1_ReplyMessage$p1 = '''
  DO \$\$ BEGIN ALTER TABLE ${DbNames.T_ReplyMessage}_p1
       ADD CONSTRAINT uk1_ReplyMessage UNIQUE (message_id, mention_message_id);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;''';*/

  static final String QIdx_ReplyMessage$mentionUserId = '''
  CREATE INDEX IF NOT EXISTS ReplyMessage_mention_user_id_idx
  ON ${DbNames.T_ReplyMessage} USING BTREE (mention_user_id);''';



  static final String QTbl_ForwardMessage = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_ForwardMessage}(
       id BIGSERIAL,
       mention_conversation_id BIGINT NOT NULL,
       mention_message_id Numeric(40,0) NOT NULL,
       message_type SMALLINT NOT NULL,
       alternative_title VARCHAR(70) DEFAULT NULL,
       CONSTRAINT pk_ForwardMessage PRIMARY KEY (id)
       )
      PARTITION BY RANGE (id);''';

  static final String QTbl_ForwardMessage$p1 = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_ForwardMessage}_p1 
  PARTITION OF ${DbNames.T_ForwardMessage}
  FOR VALUES FROM (0) TO (1000000);''';//1_000_000

  static final String QIdx_ForwardMessage$mentionUserId = '''
  CREATE INDEX IF NOT EXISTS ForwardMessage_mention_conversation_id_idx
  ON ${DbNames.T_ForwardMessage} USING BTREE (mention_conversation_id);''';



  static final String QTbl_Advertising = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_Advertising} (
       id SERIAL,
       title varchar(200) DEFAULT NULL,
       tag varchar(50) DEFAULT NULL,
       type varchar(30) DEFAULT NULL,
       can_show BOOLEAN DEFAULT TRUE,
       creator_id BIGINT NOT NULL,
       order_num SMALLINT DEFAULT 1,
       register_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
       start_show_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
       finish_show_date TIMESTAMP DEFAULT null,
       click_link varchar(400) DEFAULT NULL,
       path varchar(400) NOT NULL,
       CONSTRAINT pk_Advertising PRIMARY KEY (id),
       CONSTRAINT uk1_Advertising UNIQUE (path)
      );''';



  static final String QTable_AppVersions = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_AppVersions} (
       id SMALLSERIAL,
       apk_name varchar(50) NOT NULL,
       version_code INT NOT NULL,
       version_name varchar(15) NOT NULL,
       is_restrict BOOLEAN DEFAULT FALSE,
       is_usable BOOLEAN DEFAULT TRUE,
       is_deprecate BOOLEAN DEFAULT FALSE,
       change_note varchar(1000) DEFAULT '',
       register_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
       tag varchar(15) DEFAULT '',
       path varchar(400) NOT NULL,
       CONSTRAINT pk_AppVersions PRIMARY KEY (id),
       CONSTRAINT uk1_AppVersions UNIQUE (apk_name, path)
      );''';

  static final String QIndex_AppVersions$version_code = '''
  CREATE INDEX IF NOT EXISTS AppVersions_VersionCode_idx
  ON ${DbNames.T_AppVersions} USING BTREE (version_code);''';



  static final String QTbl_courseBuyQuestion = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_CourseBuyQuestion} (
       id BIGSERIAL NOT NULL,
       course_id BIGINT NOT NULL,
       user_id BIGINT NOT NULL,
       questions_js JSONB DEFAULT NULL,
       register_date TIMESTAMP DEFAULT (now() at time zone 'utc'),
       CONSTRAINT fk1_${DbNames.T_CourseBuyQuestion} FOREIGN KEY (user_id) REFERENCES ${DbNames.T_Users} (user_id) 
      		ON DELETE CASCADE ON UPDATE CASCADE,
       CONSTRAINT fk2_${DbNames.T_CourseBuyQuestion} FOREIGN KEY (course_id) REFERENCES ${DbNames.T_Course} (id) 
      		ON DELETE CASCADE ON UPDATE CASCADE
      )
      PARTITION BY RANGE (id);''';

  static final String QTbl_courseBuyQuestion$p1 = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_CourseBuyQuestion}_p1
  PARTITION OF ${DbNames.T_CourseBuyQuestion}
  FOR VALUES FROM (0) TO (250000);'''; //250_000

  static final String QTbl_courseBuyQuestion$p2 = '''
  CREATE TABLE IF NOT EXISTS ${DbNames.T_CourseBuyQuestion}_p2
  PARTITION OF ${DbNames.T_CourseBuyQuestion}
  FOR VALUES FROM (250000) TO (500000);''';//500_000

  static final String QAltUk1_courseBuyQuestion$p1 = '''
  DO \$\$ BEGIN ALTER TABLE ${DbNames.T_CourseBuyQuestion}_p1
       ADD CONSTRAINT uk1_${DbNames.T_CourseBuyQuestion} UNIQUE (course_id, user_id);
       EXCEPTION WHEN others THEN IF SQLSTATE = '42P07' THEN null;
       ELSE RAISE EXCEPTION '> %', SQLERRM; END IF; END \$\$;
       ''';


  //======	Function	=====================================================================
  /*static final String Q_fn_utc = "CREATE OR REPLACE FUNCTION utc()\n" +
			"\tRETURNS timestamp\n" +
			"AS \$\$\n" +
			"\n" +
			"begin\n" +
			"\treturn now() at time zone 'utc';\n" +
			"end; \$\$\n" +
			"language 'plpgsql';";*/

  static final String fn_update_seen_ticket = '''
    CREATE OR REPLACE FUNCTION update_seen_ticket(in userId int, in ticketId int, in ts timestamp)
    RETURNS BOOL AS \$\$
    DECLARE existBefore bool;
    BEGIN
        SELECT into existBefore EXISTS(SELECT 1 FROM seenticketmessage where user_id = userId AND ticket_id = ticketId);
    
        IF existBefore = false THEN
            INSERT INTO seenticketmessage (user_id, ticket_id, last_message_ts) VALUES (userId, ticketId, ts);
        ELSE
            UPDATE seenticketmessage SET last_message_ts = ts 
              WHERE user_id = userId AND ticket_id = ticketId AND last_message_ts < ts;
        END IF;
    
    RETURN TRUE;
    END;
    \$\$ language plpgsql;
''';

  static final String fn_update_seen_chat = '''
    CREATE OR REPLACE FUNCTION update_seen_chat(in userId int, in conversationId int, in ts timestamp)
    RETURNS BOOL AS \$\$
    DECLARE existBefore bool;
    BEGIN
        SELECT into existBefore EXISTS(SELECT 1 FROM seenconversationmessage where user_id = userId AND conversation_id = conversationId);
    
        IF existBefore = false THEN
            INSERT INTO seenconversationmessage (user_id, conversation_id, last_message_ts) VALUES (userId, conversationId, ts);
        ELSE
            UPDATE seenconversationmessage SET last_message_ts = ts 
              WHERE user_id = userId AND conversation_id = conversationId AND last_message_ts < ts;
        END IF;
    
    RETURN TRUE;
    END;
    \$\$ language plpgsql;
''';



  //======	preData	=====================================================================
  static final String Q_insert_imageType = '''
  INSERT INTO ${DbNames.T_TypeForUserImage} 
      ( key,caption)
      values
        ( 1, 'Profile')
      , ( 2, 'Certificate Face')
      , ( 3, 'Introduction Face')
       ON CONFLICT DO NOTHING
      ;''';

  static final String Q_insert_userMetaType = '''
  INSERT INTO ${DbNames.T_TypeForUserMetaData} 
      (key, caption)
      values
        ( 1, 'Mobile Number')
      , ( 2, 'Phone Number')
      , ( 3, 'Email')
      , ( 4, 'TelegramId')
      , ( 5, 'WhatsAppId')
       ON CONFLICT DO NOTHING
      ;''';

  static final String Q_insert_UserSystem = '''
    INSERT INTO ${DbNames.T_Users} 
      ( user_id, name, Family, user_type)
      values
        ( ${PublicAccess.systemUserId}, 'System1', 'system', 3)
      , ( ${PublicAccess.adminUserId}, 'Admin', 'admin', 3)
       ON CONFLICT DO NOTHING
      ;''';

  // Generator.generateMd5('admin@@')
  static final String Q_insert_UserNameId = '''
 	INSERT INTO ${DbNames.T_UserNameId}  
 	  (user_id, user_name, password, hash_password)
		values
		 (${PublicAccess.adminUserId}, 'Admin', 'admin@@', '37f67fb3b89a94e1fba1fc86c7765b0a')
		 ON CONFLICT DO NOTHING;
 	 ''';

  static final String Q_insert_Rights = '''
    INSERT INTO ${DbNames.T_Rights} 
      (key, title, description)
      values
       ( 3, 'EditRights', 'Change rights info, Add/Change roles')
      , ( 5, 'EditUserRights', 'edit user rights/roles')
      , ( 10, 'SeeUser', 'See user info')
      , ( 11, 'CreateUser', 'Create/verify new user')
      , ( 12, 'BlockUser', 'Set user as deleted/blocked')
      , ( 13, 'EditUser', 'Change user info')
      , ( 16, 'CreatePack', 'Create new pack')
      , ( 18, 'EditPack', 'Change pack info')
      , ( 22, 'EditConversation', 'Add/Change conversation info')
      , ( 26, 'EditConference', 'Change conference info')
      , ( 28, 'EditLanguages', 'Add/Change languages info')
      , ( 30, 'EditCertificate', 'Add/Change certificate')
      , ( 32, 'EditUserCertificate', 'Add/Change user certificate')
      , ( 34, 'SeeCash', 'See cash info')
      , ( 36, 'EditCash', 'Add/Change cash info')
      , ( 38, 'ManageTrainers', 'Add/Change trainers info')
      , ( 40, 'SeeUsersChats', 'See chats')
      , ( 42, 'EditUsersChats', 'Change chats messages')
      , ( 44, 'EditAdvertising', 'Add/Change advertising')
      , ( 46, 'EditContent', 'Add/Change Contents')
       ON CONFLICT DO NOTHING
      ;''';

  static final String Q_insert_Roles = '''
   	INSERT INTO ${DbNames.T_Roles}
			(key, title, description, has_rights, creator_user_id)
			values
			(1, 'SuperAdmin', 'Top access', '{3,5,10,11,12,13,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46}', ${PublicAccess.systemUserId})
			,(2, 'Admin', 'Admin of system', '{10,12,16,18,20,22,24,26,28,30,32,38,40}', ${PublicAccess.systemUserId})
			ON CONFLICT DO NOTHING;
			''';

  static final String Q_insert_UserRoles = '''
 	INSERT INTO ${DbNames.T_UserToRoles} (user_id, roles)
		values
		(${PublicAccess.systemUserId}, '{1}')
		,(${PublicAccess.systemUserId}, '{1}')
 	 ON CONFLICT DO NOTHING;
 	 ''';

  /*
    , ( 3, 'Pack Group')
      , ( 4, 'Pack Channel')
      , ( 5, 'Pack Private')
   */
  static final String Q_insert_conversationType = '''
    INSERT INTO ${DbNames.T_TypeForConversation} 
      (key, caption)
      values
        ( 5, 'Group')
      , ( 10, 'P2P')
      , ( 14, 'Channel')
      , ( 22, 'Course Group')
      , ( 30, 'Course Channel')
      , ( 40, 'Course Private')
       ON CONFLICT DO NOTHING
      ;''';

  /*static final String Q_insert_CategoryForContent = "INSERT INTO ${DbNames.T_CategoryForContent '\" "
			' (key, caption)"
			' values"
			'  ( 1, 'Video')"
			', ( 2, 'Audio')"
			', ( 3, 'Image')"
			', ( 4, 'Gif')"
			', ( 5, 'PDF')"
			', ( 6, 'Text')"
			', ( 7, 'Youtube')"
			' ON CONFLICT DO NOTHING"
			';";*/

  static final String Q_insert_TypeForMessage = '''
  INSERT INTO ${DbNames.T_TypeForMessage} 
      (key, caption)
      values
        ( 0, 'File')
      , ( 1, 'Text')
      , ( 2, 'Audio')
      , ( 3, 'Video')
      , ( 4, 'Image')
      , ( 5, 'Gif/Animation')
      , ( 6, 'Gallery')
      , ( 7, 'Location')
      , ( 8, 'Contact')
      , ( 9, 'Game')
      , ( 10, 'Html')
       ON CONFLICT DO NOTHING
      ;''';

  static final String Q_insert_TypeForConversationState = '''
  INSERT INTO ${DbNames.T_TypeForConversationState}
      (key, caption)
      values
        ( 1, 'IsClosed')
      , ( 2, 'All-ReadOnly')
      , ( 3, 'Manager-Active')
      , ( 4, 'All-Free')
       ON CONFLICT DO NOTHING
      ;''';

  static final String Q_insert_TypeForUserStation = '''
  INSERT INTO ${DbNames.T_TypeForUserStation} 
      (key, caption)
      values
        ( 1, 'Manager')
      , ( 2, 'Trainer')
      , ( 3, 'Assistance')
      , ( 4, 'Observer')
      , ( 5, 'Normal User')
      , ( 6, 'Guest')
       ON CONFLICT DO NOTHING
      ;''';

  /*static final String Q_insert_userStation = "INSERT INTO ${DbNames.T_StationForConversationUser '\" "
			' (key, caption)"
			'values"
			'  ( 1, 'Superior Manager')"
			', ( 2, 'Manager')"
			', ( 3, 'Assistance')"
			', ( 4, 'Normal User')"
			', ( 5, 'Observer')"
			', ( 6, 'Guest')"
			' ON CONFLICT DO NOTHING"
			';";*/

  static final String Q_insert_rightsForConversation = '''
  INSERT INTO ${DbNames.T_RightsForConversationActivity} 
      (key, caption)
      values
        ( 1, 'Send message')
      , ( 2, 'Edit Own message')
      , ( 3, 'Edit Others message')
      , ( 4, 'Delete User')
      , ( 5, 'Invite User')
      , ( 6, 'Change User rights')
       ON CONFLICT DO NOTHING
      ;''';

  static final String Q_insert_languages = '''
		INSERT INTO ${DbNames.T_Language} 
		(iso, iso_and_country, english_name)
			values
			( 'en', 'en', 'English')
			,( 'en', 'en_US', 'English')
			,( 'fa', 'fa_IR', 'Farsi')
			,( 'ar', 'ar', 'Arabic')
			,( 'tr', 'tr_TR', 'Turkish')
			,( 'fr', 'fr_FR', 'French')
			,( 'de', 'de_DE', 'German')
			,( 'es', 'es_ES', 'Spanish')
			,( 'pt', 'pt_PT', 'Portuguese')
			,( 'ru', 'ru_RU', 'Russian')
			,( 'zh', 'zh_CN', 'Chinese')
			  ON CONFLICT DO NOTHING;
			  ''';

  ///---- Functions --------------------------------------------------------------------------------------------
  // SELECT 'test(1) > Foo*' ~ regexp_escape2('test(1) > Foo*');
  static String fn_regexpEscape2 = r'''
      CREATE OR REPLACE FUNCTION regexp_escape2(text)
        RETURNS text
        LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS
        $func$
          SELECT regexp_replace($1, '([!$()*+.:<=>?[\\\]^{|}-])', '\\\1', 'g');
        $func$;
   ''';

  // SELECT f_like_escape('20% \ 50% low_prices');
  static String fn_likeEscape = r'''
      CREATE OR REPLACE FUNCTION like_escape(text)
        RETURNS text
        LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS
        $func$
          SELECT replace(
            replace(
              replace($1, '\', '\\')
            , '%', '\%')
            , '_', '\_');
        $func$;
   ''';

  static String fn_replaceFitnessNodeItem = r'''
    CREATE OR REPLACE PROCEDURE replaceFitnessNodeItem (in ts varchar, in data varchar, in nodeName varchar, in userId bigint, inout res int)
    language plpgsql AS $$

    --DECLARE
    declare today date;
    declare r jsonb; -- RECORD
    declare idx int :=0;
    declare cnt int :=0;

 BEGIN
    -- first insert userId, if exist this user before, occur exception
    INSERT INTO UserFitnessData (user_id, nodes_js)
        values (userId, FORMAT('{"%s": [%s]}', nodeName, data)::jsonb);

    cnt := 1;
    SELECT cnt INTO res;
 EXCEPTION WHEN unique_violation THEN
    today := ts::date;

    FOR r IN
        SELECT jsonb_array_elements(nodes_js->$3) AS arr FROM UserFitnessData WHERE user_id = userId
        LOOP
            IF (r->>'date')::date = today THEN
                UPDATE UserFitnessData
                    SET nodes_js = nodes_js #- FORMAT('{"%s", %s}', nodeName, idx)::text[]
                WHERE user_id = userId;

                idx := idx-1;
                cnt := cnt+1;

                UPDATE UserFitnessData
                    SET nodes_js = jsonb_set(UserFitnessData.nodes_js, ('{"'|| nodeName ||'"}')::text[],
                                      coalesce(UserFitnessData.nodes_js->$3, '[]'::jsonb) || data::jsonb)
                WHERE user_id = userId;
            END IF;
            idx := idx+1;
        END LOOP;

    IF cnt = 0 THEN
        UPDATE UserFitnessData
        SET nodes_js = jsonb_set(UserFitnessData.nodes_js, ('{"'|| nodeName ||'"}')::text[],
                              coalesce(UserFitnessData.nodes_js->$3, '[]'::jsonb) || data::jsonb)
        WHERE user_id = userId;

        cnt := 1;
    END IF;

    COMMIT;
    --RETURN;
    SELECT cnt INTO res;
    --res := cnt;
END;
$$;
  ''';

  static String fn_deleteFitnessNodeItemByDate = r'''
    CREATE OR REPLACE PROCEDURE deleteFitnessNodeItemByDate (in ts varchar, in nodeName varchar, in userId bigint, inout res int)
    language plpgsql AS $$

    declare today timestamp;
    declare r jsonb;
    declare idx int :=0;
    declare cnt int :=0;

BEGIN
    today := ts::timestamp;

    FOR r IN
        SELECT jsonb_array_elements(nodes_js->$2) arr FROM UserFitnessData WHERE user_id = userId
        LOOP
            IF (r->>'date')::timestamp = today THEN

                UPDATE UserFitnessData
                    SET nodes_js = nodes_js #- FORMAT('{"%s", %s}', nodeName, idx)::text[]
                WHERE user_id = userId;

                idx := idx-1;
                cnt := cnt+1;
            END IF;
            
            idx := idx+1;
        END LOOP;

    COMMIT;
    res := cnt;
END; $$;
  ''';

  static String fn_deleteFitnessNodeItemByKey = r'''
    CREATE OR REPLACE PROCEDURE deleteFitnessNodeItemByKey(in key varchar, in val varchar, in nodeName varchar, in userId bigint, inout res int)
    language plpgsql
    AS $$
        declare r jsonb;
        declare idx int :=0;
        declare cnt int :=0;
    
        BEGIN
            FOR r IN
                SELECT jsonb_array_elements(nodes_js->$3) arr FROM UserFitnessData WHERE user_id = userId
                LOOP
    
                    IF (r->>$1)::text = val THEN
    
                        UPDATE UserFitnessData
                        SET nodes_js = nodes_js #- FORMAT('{"%s", %s}', nodeName, idx)::text[] WHERE user_id = userId;
    
                        idx := idx-1;
                        cnt := cnt+1;
                    END IF;
                    idx := idx+1;
            END LOOP;
    
            COMMIT;
            res := cnt;
    END $$;
  ''';
}
