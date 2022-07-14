
import 'package:brandfit_server/keys.dart';

class CountryModel {
  static late Map<String, dynamic> countries;

  String? countryName;
  String? countryPhoneCode;
  String? countryIso;

  CountryModel();

  CountryModel.fromMap(Map map){
    countryName = map['country_name'];
    countryIso = map[Keys.countryIso];
    countryPhoneCode = map[Keys.phoneCode];
  }

  Map<String, dynamic> toMap(){
    return {
      'country_name': countryName,
      Keys.countryIso: countryIso,
      Keys.phoneCode: countryPhoneCode,
    };
  }

  static String getCountryCodeByIso(String iso) {
    for(var itm in countries.entries){
      if(itm.value['iso'] == iso){
        return itm.value['phoneCode'];//dont change case
      }
    }

    return '';
  }

  static String getCountryIsoByPhoneCode(String phoneCode) {
    for(var itm in countries.entries){
      if(itm.value['phoneCode'] == phoneCode){
        return itm.value['iso'];
      }
    }

    return '';
  }

  static CountryModel getCountryModelByIso(String iso) {
    var res = CountryModel();

    for(var itm in countries.entries){
      if(itm.value['iso'] == iso){
        res.countryIso = itm.value['iso'];
        res.countryPhoneCode = itm.value['phoneCode'];
        res.countryName = itm.value['officialName'];

        return res;
      }
    }

    return res;
  }

}
