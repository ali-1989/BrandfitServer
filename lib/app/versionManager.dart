import 'dart:io';
import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:brandfit_server/app/pathNs.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/wsServerNs.dart';
import 'package:postgresql2/postgresql.dart';


class VersionManager {
  static String apkDirDomain = '';

  static void fetchAppVersion() async {
    apkDirDomain = PathsNs.getAppsFilesUrl();

    var q = '''with w1 as (SELECT tag, max(version_code) as max FROM ${DbNames.T_AppVersions} 
          WHERE visible IS true AND is_deprecate is false GROUP BY tag),
      w2 as (select * from w1 as j1 inner join ${DbNames.T_AppVersions} as j2 
      on j1.tag = j2.tag and j1.max = j2.version_code)
        select * from w2;''';

    var cursor = await PublicAccess.psql2.queryCall(q);

    if (cursor != null && cursor.isNotEmpty) {
      await PublicAccess.psql2.truncateTableCascade(DbNames.T_AppVersions);

      for (var i = 0; i < cursor.length; i++) {
        var row = cursor.elementAt(i).toMap();

        String appName = row['apk_name'];
        String versionName = row['version_name'];
        String forKey = row['tag'];
        String change = row['change_note'];
        int versionCode = row['version_code']?? 0;
        String isRestrict = row['is_restrict']?? 'false';
        String isDeprecate = row['is_deprecate']?? 'false';

        await PublicAccess.psql2.execution('''INSERT INTO ${DbNames.T_AppVersions} 
          VALUES('$appName','$versionName',$versionCode,$isRestrict,'$forKey',$isDeprecate,'$change');''');
        // ignore: unawaited_futures
        PublicAccess.logInDebug('''## Updated  LastAppVersion: $forKey , versionName: $versionName  isRestrict: $isRestrict''');
      }
    }
  }

  static Future<bool> checkCanContinueByVersion_SendNewVersionIfNeed(WebSocket ws, int version, String? forKey) async {
    if (version < 0) {
      return false;
    }

    var restrict = true;
    List<Row>? t;

    if(forKey != null) {
      var q = '''SELECT * FROM ${DbNames.T_AppVersions} WHERE tag = '$forKey' AND version_code > $version;''';
      t = await PublicAccess.psql2.queryCall(q);
    }
    else {
      var q = '''SELECT * FROM ${DbNames.T_AppVersions} WHERE version_code > $version;''';
      t = await PublicAccess.psql2.queryCall(q);
    }

    if (t != null && t.isNotEmpty) {
      var row = t.first.toMap();
      restrict = row['is_restrict'];

      var versionInfo = <String, dynamic>{};
      versionInfo[Keys.command] = 'SetNewAppVersion';
      versionInfo['link'] = apkDirDomain + row['apk_name'];
      versionInfo['new_version_name'] = apkDirDomain + row['version_name'];
      versionInfo['new_version_code'] = apkDirDomain + row['version_code'];
      versionInfo['change_note'] = apkDirDomain + row['change_note'];
      versionInfo['support_link'] = '09139277303';
      versionInfo['restrict'] = restrict;

      restrict = !restrict;
      WsServerNs.sendData(ws, JsonHelper.mapToJson(versionInfo));
    }

    return restrict;
  }

  static Future<bool> hasNewVersion(int version, String forKey) async{
    var cursor = await PublicAccess.psql2.queryCall('''
    SELECT * FROM ${DbNames.T_AppVersions} WHERE tag = '$forKey' AND version_code > $version''');
    return cursor != null && cursor.isNotEmpty;
  }
}