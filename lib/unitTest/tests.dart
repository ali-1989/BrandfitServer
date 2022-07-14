import 'dart:io';
import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/api/logger/logger.dart';
import 'package:assistance_kit/shellAssistance.dart';
import 'package:brandfit_server/rest_api/httpCenter.dart';

class RegisterTest {
  RegisterTest._();

  static void testRegister(){
    var js = <String, dynamic>{};
    js['Request'] = 'RegisterNewUser';
    //js['Type'] = 'SimpleUser';
    js['Name'] = 'TestR';
    js['Family'] = 'TestF';
    js['MobileNumber'] = '091۳9277303';
    js['CountryCode'] = '+95';
    js['UserName'] = 'Utest3';
    js['Password'] = 'tt1234';
    //js['Sex'] = 1;
    //js['BirthDate'] = DateHelper.getTimestampAsUtc();

    var item = HttpItem();
    item.method = 'POST';
    item.fullUri = 'http://192.168.43.60:6060/register';
    item.setBodyJson(js);

    var fu = HttpCenter.send(item);

    fu.future.then((value) {
      Logger.L.logToScreen(value.toString());
    });
  }

  static void testVerify(String code){
    var js = <String, dynamic>{};
    js['Request'] = 'VerifyNewUser';
    js['Type'] = 'SimpleUser';
    js['Code'] = code;
    js['MobileNumber'] = '913927703';
    js['CountryCode'] = '+98';

    var item = HttpItem();
    item.method = 'POST';
    item.fullUri = 'http://192.168.1.104:6060/register';
    item.setBodyJson(js);

    var fu = HttpCenter.send(item);

    fu.future.then((value) {

      Logger.L.logToScreen(value.toString());
    });
  }

  static void resendVerify(){
    var js = <String, dynamic>{};
    js['Request'] = 'ResendVerifyCode';
    js['Type'] = 'SimpleUser';
    js['MobileNumber'] = '913927703';
    js['CountryCode'] = '+97';

    var item = HttpItem();
    item.method = 'POST';
    item.fullUri = 'http://192.168.43.60:6060/register';
    item.setBodyJson(js);

    var fu = HttpCenter.send(item);

    fu.future.then((value) {
      Logger.L.logToScreen(value.toString());
    });
  }

  static void restorePassword(){
    var js = <String, dynamic>{};
    js['Request'] = 'RestorePassword';
    js['Type'] = 'SimpleUser';
    js['MobileNumber'] = '913927703';
    js['CountryCode'] = '+98';

    var item = HttpItem();
    item.method = 'POST';
    item.fullUri = 'http://192.168.43.60:6060/register';
    item.setBodyJson(js);

    var fu = HttpCenter.send(item);

    fu.future.then((value) {
      Logger.L.logToScreen(value.toString());
    });
  }

  static void login(){
    var js = <String, dynamic>{};
    //js['UserName'] = 'Utest';
    js['UserName'] = '0913927703';
    js['HashPassword'] = 'e52f38cec6b7f1fa077c9269053b9369';
    js['DeviceId'] = 'a1000000000002';
    js['TimeZoneOffset'] = '64000000';
    js['CountryIso'] = 'IR';
    js['LanguageIso'] = 'fa';
    js['Model'] = 'Sum';
    js['Brand'] = 'Ali';
    js['API'] = 'aPi';
    js['DeviceType'] = 'LapTop';
    js['AppName'] = 'Brandfit';

    var item = HttpItem();
    item.method = 'POST';
    item.fullUri = 'http://192.168.1.104:6060/login';
    item.setBodyJson(js);

    var fu = HttpCenter.send(item);

    fu.future.then((value) {
      Logger.L.logToScreen(value.toString());
    });
  }

  static void webSocketConnect() async{

    var ws = await WebSocket.connect('ws://192.168.1.104:6065/ws');

    var js = <String, dynamic>{}..['message'] = 'Hi i am webSocket';
    js['DeviceId'] = 'ggh45557';
    js['Users'] = [2];
    ws.add(JsonHelper.mapToJson(js));

    ws.listen((event) {
      Logger.L.logToScreen(event);
    });
  }

  static void downloadTest(){
    var item = HttpItem();
    item.method = 'GET';
    item.fullUri = 'http://192.168.43.60:6060/testImg.jpg';

    var fu = HttpCenter.send(item);

    fu.future.then((value) {
      Logger.L.logToScreen('Downloading...');
      Logger.L.logToScreen('${fu.response?.headers}');
    });
  }

  // ipconfig | findstr /i "Gateway"   ,   Linux: ip route | grep default
  static void getGateway(){
    ShellAssistance.shell('ipconfig', [], runInShell: true).then((process) {
      //stdout.write(process.stdout);
      //stdout.write(process.exitCode);
      //Logger.L.logToScreen(process.exitCode);
      var text = process.stdout as String;
      var lines = text.split(RegExp(r'\n'));

      for(var line in lines){
        if(line.indexOf(RegExp(r'Default Gateway')) > 0){
          var start = line.indexOf(RegExp(r'((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.|\b|$)){4}'));

          if(start > -1){
            Logger.L.logToScreen(line.substring(start));
          }
        }
      }
    });
  }
}