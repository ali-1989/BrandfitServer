import 'package:brandfit_server/keys.dart';

// ignore_for_file: non_constant_identifier_names

class HttpCodes {
  HttpCodes._();

  static Map<String, dynamic> generateResultOk() {
    var res = <String, dynamic>{};
    res[Keys.result] = Keys.ok;

    return res;
  }

  static Map<String, dynamic> generateResultJson(String result) {
    var res = <String, dynamic>{};
    res[Keys.result] = result;

    return res;
  }

  static Map<String, dynamic> generateJsonError(int causeCode, {String? cause}) {
    var res = <String, dynamic>{};
    res[Keys.result] = Keys.error;
    res[Keys.causeCode] = causeCode;
    res[Keys.cause] = cause;

    return res;
  }
  ///=======================================================================================================
  static int error_requestKeyNotFound = 10;
  static int error_requestNotDefined = 15;
  static int error_userIsBlocked = 20;
  static int error_userNotFound = 25;
  static int error_parametersNotCorrect = 30;
  static int error_databaseError = 35;
  static int error_internalError = 40;
  static int error_isNotJson = 45;
  static int error_dataNotExist = 50;
  static int error_tokenNotCorrect = 55;
  static int error_existThis = 60;
  static int error_canNotAccess = 65;
  static int error_operationCannotBePerformed = 70;
  static int error_notUpload = 75;
  static int error_userNamePassIncorrect = 80;
  static int error_userMessage = 85;
  static int error_translateMessage = 86;
  static int error_spacialError = 90;

  //static int Error_userNotManager = 777;
  //------------ sections -----------------------------------------------------
  static const sec_command = 'command';
  static const sec_userData = 'UserData';
  static const sec_ticketData = 'TicketData';
  static const sec_chatData = 'ChatData';
  static const sec_courseData = 'CourseData';
  //------------ commands -----------------------------------------------------
  static const com_forceLogOff = 'ForceLogOff';
  static const com_forceLogOffAll = 'ForceLogOffAll';
  static const com_talkMeWho = 'TalkMeWho';
  static const com_sendDeviceInfo = 'SendDeviceInfo';
  static const com_userSeen = 'UserSeen';
  static const com_serverMessage = 'ServerMessage';
  static const com_newMessage = 'NewMessage';
  static const com_delMessage = 'DeleteMessage';
  static const com_newCourseBuyRequest = 'NewCourseBuyRequest';
  static const com_selfSeen = 'SelfSeen';
  static const com_updateProfileSettings = 'UpdateProfileSettings';
  static const com_notifyCourseRequestAnswer = 'notifyCourseRequestAnswer';
  static const com_notifyNewCourseRequest = 'notifyNewCourseRequest';
  static const com_notifyNewProgram = 'notifyNewProgram';
}