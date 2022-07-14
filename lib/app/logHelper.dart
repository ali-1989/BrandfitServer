import 'package:brandfit_server/publicAccess.dart';

class LogHelper {
  LogHelper._();

  static void logUserCrash(Map<String, dynamic> js, String user) {
    List? jar = js['ArrayList'];

    if (jar != null && jar.isNotEmpty) {
      PublicAccess.logger.logToAll('================================ Crash Report: ' + user + '\n');

      for (var i = 0; i < jar.length; i++) {
        var item = jar.elementAt(i);
        PublicAccess.logger.logToAll('> ${item['Text']}');
      }

      PublicAccess.logger.logToAll('======================================\n');
    }
  }

  static void logUserDeviceInfo(Map<String, dynamic> js, String user) {
    PublicAccess.logger.logToAll('======================================Device Info: ' + user + '\n');
    PublicAccess.logger.logToAll('> ' + js.toString());
    PublicAccess.logger.logToAll('======================================\n');
  }
}