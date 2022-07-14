import 'dart:io';
import 'package:alfred/alfred.dart';
import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/database/psql.dart';
import 'package:assistance_kit/database/psql2.dart';
import 'package:assistance_kit/api/helpers/textHelper.dart';
import 'package:assistance_kit/api/logger/logger.dart';
import 'package:brandfit_server/app/smsKaveh.dart';
import 'package:brandfit_server/app/pathNs.dart';
import 'package:brandfit_server/constants.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/rest_api/httpCenter.dart';
import 'package:translator/translator.dart';

class PublicAccess {
  PublicAccess._();

  static bool isDebugMode = true;
  static late Alfred server;
  static late Alfred wsServer;
  static late Psql psql;
  static late Psql2 psql2;
  static Map<WebSocket, String> webSockets = <WebSocket, String>{};
  static String verifyHackCode = '68073';
  static String domain = 'http://31.216.62.79:6060';
  //static String domain = 'http://192.168.1.102:6060';
  static late Logger logger;
  static final translator = GoogleTranslator(client: ClientType.extensionGT);
  static final developerNum = '09139277303';
  static int systemUserId = 90;
  static int adminUserId = 89;
  static int supportPercent = 20;
  static List<String> avoidForLimitedUser = ['is_deleted', 'register_date', 'user_type'];

  static void logInDebug(dynamic txt) {
    if(isDebugMode) {
      PublicAccess.logger.logToAll(txt);
    }
  }

  static void logTemp(dynamic txt) {
    if(isDebugMode) {
      PublicAccess.logger.logToAll(txt);
    }
  }

  static String getVerifySmsText() {
    return '${Constants.appName} code:\n';
  }

  static Future<dynamic> loadAssets(String name, {bool asString = true}) async {
    var path = PathsNs.getAssetsDir() + Platform.pathSeparator + name;

    var file = File(path);
    var exist = await file.exists();

    if(exist){
      if(asString) {
        return file.readAsString();
      }
      else {
        return file.readAsBytes();
      }
    }
  }

  //   https://detectlanguage.com/
  static Future<String> detectLanguage(String text) {
    var req = HttpItem();
    req.fullUri = 'https://ws.detectlanguage.com/0.2/detect';
    req.options.headers ??= {};
    req.options.headers!['Content-Type'] = 'application/json';
    req.options.headers!['Authorization'] = 'Bearer 8f9e191c8ee073607f9356975d92282e';
    req.method = 'POST';
    req.body = JsonHelper.mapToJson({'q': text});

    var result = HttpCenter.send(req);

    return result.future.then((value){
      if(result.isError()){
        return 'en';
      }

      if(result.isOk && value != null){
        var js = result.getJson();

        Map? map = js!['data'];
        List list = map?['detections']?? [];

        return list[0]?['language']?? '-';
      }

      return '--';
    });
  }

  static void insertEncodedPathToJunkFile(String path) {
    psql2.insertIgnore(DbNames.T_CandidateToDelete, ['path'], [path]);
  }

  static void sendReportToDeveloper(String report) {
    try {
      report = TextHelper.subByCharCountSafe(report, 120);
      Kaveh.sendSmsGet(report, developerNum);
    }
    catch (e) {
      //Main.logToAll("!!! sendReportToDeveloper: " + e.toString(), true);
    }
  }
}