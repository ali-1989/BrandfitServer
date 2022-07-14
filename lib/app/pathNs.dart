import 'dart:io';
import 'package:assistance_kit/api/helpers/pathHelper.dart';
import 'package:assistance_kit/api/helpers/urlHelper.dart';
import 'package:brandfit_server/publicAccess.dart';

class PathsNs {
  PathsNs._();

  static late String _executePath;
  static late String _currentPath;

  static void init(){
    //  Platform.script.path : /G:/Programming/DartProjects/BrandfitServer/bin/run.dart
    _executePath = PathHelper.normalize(Platform.script.path.toString())!;
    _executePath = PathHelper.getParentDirPath(_executePath);

    _currentPath = PathHelper.gstCurrentPath();
    createDirectories();
  }

  static void createDirectories(){
    var dir = Directory(getLogPath());
    dir.create(recursive: true);

    dir = Directory(getUploadFileDir());
    dir.create(recursive: true);

    dir = Directory(getAppsFilesDir());
    dir.create(recursive: true);

    dir = Directory(getChatFileDir());
    dir.create(recursive: true);

    dir = Directory(getAssetsDir());
    dir.create(recursive: true);

    dir = Directory(getTempDir());
    dir.create(recursive: true);

    dir = Directory(getBackupPath());
    dir.create(recursive: true);
  }

  static String getExecutePath(){
    return _executePath;
  }

  static String getCurrentPath(){
    return _currentPath;
  }

  static String getLogPath(){
    return getCurrentPath() + PathHelper.getSeparator() + 'Logs';
  }

  static String getBackupPath(){
    return getCurrentPath() + PathHelper.getSeparator() + 'Backups';
  }

  static String getFilesDir() {
    return getCurrentPath() + PathHelper.getSeparator() + 'FilesCellar';
  }

  static String getFilesDirSafe() {
    var s = getFilesDir();
    var t = File(s);

    if (!t.existsSync()) {
      t.createSync(recursive: true);
    }

    return s;
  }

  static String getChatFileDir() {
    return getCurrentPath() + PathHelper.getSeparator() + 'ChatFiles';
  }

  static String getAssetsDir() {
    return getCurrentPath() + PathHelper.getSeparator() + 'assets';
  }

  static String getUploadFileDir() {
    return getCurrentPath() + PathHelper.getSeparator() + 'UploadedFiles';
  }

  static String getTempDir() {
    return getCurrentPath() + PathHelper.getSeparator() + 'Temp';
  }

  static String getAppsFilesDir() {
    return getCurrentPath() + PathHelper.getSeparator() + 'Apps';
  }

  static String getAppsFilesUrl() {
    return PublicAccess.domain + '/Apps';
  }
  ///=========================================================================================
  static String uriToPath(String uri) {
    uri = uri.replaceFirst(RegExp('${PublicAccess.domain}'), '');
    uri = PathHelper.gstCurrentPath() + '/$uri';

    return PathHelper.normalize(uri)!;
  }

  static String? encodeFilePathForDataBaseRelative(String path) {
    var res = removeBasePathFromLocalPath(_currentPath, path);
    return UrlHelper.encodeUrl(res?? '');
  }

  static String? encodeFilePathForDataBase(String? path) {
    if(path == null){
      return null;
    }

    var res = addBasePathToLocalPath(path);
    return UrlHelper.encodeUrl(res?? '');
  }

  static String? addBasePathToLocalPath(String relativePath) {
    if(PathHelper.isStartBy(relativePath, _currentPath)) {
      return relativePath;
    }

    return PathHelper.normalize(_currentPath + PathHelper.getSeparator() + relativePath);
  }

  static String? removeBasePathFromLocalPath(String workPath, String filePath) {
    try {
      final p = PathHelper.getSeparator() + PathHelper.removeIfStartBy(filePath, workPath);
      return PathHelper.normalize(p);
    }
    catch (e) {
      return null;
    }
  }

  // domain: is same [http://192.168.20.140:1012]
  static String? genUrlDomainFromFilePath(String domain, String workPath, String filePath) {
    try {
      return UrlHelper.resolveUrl(domain + '/' + PathHelper.removeIfStartBy(filePath, workPath));
    }
    catch (e) {
      return null;
    }
  }

  static String? genUrlFromFilePathNoDomain(String workPath, String filePath) {
    try {
      return UrlHelper.resolveUrl('/' + PathHelper.removeIfStartBy(filePath, workPath));
    }
    catch (e) {
      return null;
    }
  }

  // genUrlFromLocalPathByDecoding(PublicAccess.ServerDomain, PathsNs.getCurrentPath(), path);
  static String? genUrlDomainFromLocalPathByDecoding(String domain, String startPath, String filePath) {
    try {
      var relate = PathHelper.removeIfStartBy(UrlHelper.decodeUrl(filePath), startPath);
      var uri = '$domain/$relate';
      return UrlHelper.resolveUrl(uri);
    }
    catch (e) {
      return null;
    }
  }

  static String? genUrlFromLocalPathByDecodingNoDomain(String removePath, String? filePath) {
    try {
      var de = UrlHelper.decodeUrl(filePath);

      return UrlHelper.resolveUrl('/' + PathHelper.removeIfStartBy(de, removePath));
    } catch (e) {
      return null;
    }
  }

  static String? removeDomain(String url) {
    try {
      final reg = RegExp('^http[s]?:\/\/.+?\/');
      return url.replaceFirst(reg, '');
    }
    catch (e) {
      return null;
    }
  }


}