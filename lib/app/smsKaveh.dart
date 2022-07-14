import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:brandfit_server/rest_api/httpCenter.dart';
import 'package:dio/dio.dart';

class Kaveh {
  Kaveh._();

  static String apiKey = '4D57474F596E425570704F64584661726B45587457344665565A784B424C68686C775577413473675758773D';
  static String smsUrl = 'https://api.kavenegar.com/v1/{API-KEY}/sms/send.json';
  static String verifyUrl = 'https://api.kavenegar.com/v1/{API-KEY}/verify/lookup.json';

  static void init(){
    smsUrl = smsUrl.replaceFirst(RegExp(r'\{API-KEY\}'), apiKey);
    verifyUrl = verifyUrl.replaceFirst(RegExp(r'\{API-KEY\}'), apiKey);
  }

  static Future sendOtpPost(String receiver, String token) async{
    var js = {
      'receptor': receiver,
      'token': token,
      'template': 'verify',
    };

    var httpItem = HttpItem();
    httpItem.method = 'POST';
    httpItem.fullUri = verifyUrl;
    httpItem.setBody(JsonHelper.mapToJson(js));

    var res = HttpCenter.send(httpItem);

    return res.future.then((value){
      if(value != null) {
        if (value.data is DioError) {
          return false;
        }
        else {
          Map<String, dynamic> js = JsonHelper.jsonToMap(value.data)!;
          var result = js['return'];
          var status = result['status'];

          return 200 == ((status is num) ? status : int.parse(status));
        }
      }
      else {
        return false;
      }
    });
  }

  static Future sendOtpGet(String receiver, String token) async{
    var js = {
      'receptor': receiver,
      'token': token,
      'template': 'verify',
    };

    var httpItem = HttpItem();
    httpItem.method = 'GET';
    httpItem.fullUri = verifyUrl;
    httpItem.addUriQueryMap(js);

    var res = HttpCenter.send(httpItem);

    return res.future.then((value){
      if(value != null) {
        if (value.data is DioError) {
          return false;
        }
        else {
          Map<String, dynamic> js = JsonHelper.jsonToMap(value.data)!;
          var result = js['return'];
          var status = result['status'];

          return 200 == ((status is num) ? status : int.parse(status));
        }
      }
      else {
        return false;
      }
    });
  }

  static Future sendSmsGet(String receiver, String text) async{
    var js = {
      'receptor': receiver,
      'message': text,
    };

    var httpItem = HttpItem();
    httpItem.method = 'GET';
    httpItem.fullUri = smsUrl;
    httpItem.addUriQueryMap(js);

    var res = HttpCenter.send(httpItem);

    return res.future.then((value){
      if(value != null) {
        if (value.data is DioError) {
          return false;
        }
        else {
          var js = JsonHelper.jsonToMap<String, dynamic>(value.data)!;
          var result = js['return'];
          var status = result['status'];

          return 200 == ((status is num) ? status : int.parse(status));
        }
      }
      else {
        return false;
      }
    });
  }

  static Future sendSmsPost(String receiver, String text) async{
    var js = {
      'receptor': receiver,
      'message': text,
    };

    var httpItem = HttpItem();
    httpItem.method = 'POST';
    httpItem.fullUri = smsUrl;
    httpItem.setBodyJson(js);

    var res = HttpCenter.send(httpItem);

    return res.future.then((value){
      if(value != null) {
        if (value.data is DioError) {
          return false;
        }
        else {
          Map<String, dynamic> js = JsonHelper.jsonToMap(value.data)!;
          var result = js['return'];
          var status = result['status'];

          return 200 == ((status is num) ? status : int.parse(status));
        }
      }
      else {
        return false;
      }
    });
  }
}