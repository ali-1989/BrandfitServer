import 'dart:async';
import 'dart:io';
import 'package:alfred/alfred.dart';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:brandfit_server/app/pathNs.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/fileHandler.dart';
import 'package:brandfit_server/rest_api/getDataResponse.dart';
import 'package:brandfit_server/rest_api/loginResponse.dart';
import 'package:brandfit_server/rest_api/managementResponse.dart';
import 'package:brandfit_server/rest_api/registerResponse.dart';
import 'package:brandfit_server/rest_api/setDataResponse.dart';
import 'package:assistance_kit/extensions.dart';

class ServerNs {
  static final _publicCategories = <String, RegExp>{};

  static Alfred prepareServer(){
    var server = Alfred(logLevel: LogType.info);

    // before all:
    //server.all('/*', (req, res) {
    //   PublicAccess.logInDebug('====== method: ${req.method}, uri: ${req.uri}');
    //});


    server.all('/*', (req, res) {
        res.headers.add('Access-Control-Allow-Origin', '*');
        res.headers.add('Access-Control-Allow-Methods', 'POST, GET, OPTIONS, PUT, DELETE, HEAD');
      }
    );

    server.post('/register', RegisterResponse.register);
    server.post('/login', LoginResponse.login); //(.html)?
    server.post('/get-data', GetDataResponse.response);
    server.post('/set-data', SetDataResponse.response);
    server.post('/management', ManagementResponse.response);
    server.all('/echo', echoResponse);
    server.all('/page/*', FileHandler.response);
    server.all('/*\.*', FileHandler.response);
    server.all('/*', FileHandler.response);

    server.logWriter = (fn, type){
      var res = fn.call();

      if(type == LogType.info){
        if(res?.startsWith(RegExp('(GET|POST|PUT|OPTION)\.*'))?? false) {
          PublicAccess.logInDebug(res);
        }
      }
      else if(type == LogType.error){
        PublicAccess.logInDebug(res);
      }

      if((res is String) && res == 'Response sent to client') {
        PublicAccess.logInDebug('>>>>>>>>>>>>>>>>>>>>>>>>>>> $res');
      }
    };

    server.onInternalError = (HttpRequest req, HttpResponse res){
      PublicAccess.logger.logToAll('>>> Internal Error: ${req.method}, ${req.uri}');

      //get error: res.statusCode = HttpStatus.internalServerError;// 500
      return {'message': 'Internal Error, not handled'};
    };

    server.onNotFound = (HttpRequest req, HttpResponse res) {
      PublicAccess.logger.logToAll('>>> Error [NotFound] uri: ${req.uri} ');

      res.statusCode = HttpStatus.notFound;// 404
      return {'message': 'not found'};
    };

    _publicCategories['videos'] = RegExp(r'.*?\.(mp4|m4v|m4p|avi|flv|mkv|mov|qt|wmv|3gp|webm|mpg|mpeg|mp2)', caseSensitive: false);
    _publicCategories['audios'] = RegExp(r'.*?\.(mp3|m4a|ogg|oga|wav|wma|amr|pcm|aac|aax|aiff|alac|au|rm|tta)', caseSensitive: false);
    _publicCategories['images'] = RegExp(r'.*?\.(jpg|jpeg|gif|webp|tiff?|bmp|png|ico|svg|tmb|cov)', caseSensitive: false);
    _publicCategories['documents'] = RegExp(r'.*?\.(txt|pdf|doc\w?|rtf|xlsx?|pptx?|epub)', caseSensitive: false);
    _publicCategories['executable'] = RegExp(r'.*?\.(exe|apk|jar|ipa|ipsw|bat)', caseSensitive: false);
    _publicCategories['zip'] = RegExp(r'.*?\.(zip\w?|rar|7z|tar.{0,6}|cab|iso|gz|ar?|zz?)', caseSensitive: false);

    return server;
    //await server.listen(6060);
  }
  ///------------------------------------------------------------------------------------------------
  static FutureOr echoResponse(HttpRequest req, HttpResponse res) async {
    if(req.method.toLowerCase() == 'get'){
      return 'Echo: ${req.uri}';
    }

    return 'Echo: ${(await req.body)}';
  }
  ///------------------------------------------------------------------------------------------------
  static Future<File?> uploadFile(HttpRequest req, Map body, String paramName, [String? newFileName]) async {
    var upFile = body[paramName];

    if(upFile == null){
      return null;
    }

    var uploadedFile = upFile as HttpBodyFileUpload;
    var fileBytes = (uploadedFile.content as List<int>);

    var fileName = uploadedFile.filename;
    var file = getSaveFile(req, newFileName?? fileName);

    await file.create(recursive: true);
    await file.writeAsBytes(fileBytes);

    return file;
  }
  ///------------------------------------------------------------------------------------------------
  static File getSaveFile(HttpRequest req, String fileName){

    var find = _publicCategories.entries.firstWhereSafe((element) {
      return element.value.hasMatch(fileName);
    });

    var base;
    var today = DateHelper.todayUtcDirectoryName();

    if(req.store.get(Keys.isChat) != null) {
      base = PathsNs.getChatFileDir() + Platform.pathSeparator + today + Platform.pathSeparator;
    }
    else {
      base = PathsNs.getUploadFileDir() + Platform.pathSeparator + today + Platform.pathSeparator;
    }

    if(find != null) {
      var res = File(base + find.key + Platform.pathSeparator + fileName);
      return res;
    }

    var res = File(base + 'notDetected' + Platform.pathSeparator + fileName);
    return res;
  }
}