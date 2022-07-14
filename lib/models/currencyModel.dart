class CurrencyModel {
  static late Map<String, dynamic> countries;

  String? currencyName;
  String? currencyCode;
  String? currencySymbol;
  String? countryIso;

  CurrencyModel();

  CurrencyModel.fromMap(Map map){
    currencyName = map['currency_name'];
    currencySymbol = map['currency_symbol'];
    currencyCode = map['currency_code'];
    countryIso = map['country_iso'];
  }

  Map<String, dynamic> toMap(){
    return {
      'country_iso': countryIso,
      'currency_name': currencyName,
      'currency_symbol': currencySymbol,
      'currency_code': currencyCode,
    };
  }

  static CurrencyModel getCurrencyModelByIso(String countryIso) {
    var res = CurrencyModel();

    for(var itm in countries.entries){
      if(itm.value['iso'] == countryIso){
        res.countryIso = countryIso;
        res.currencyCode = itm.value['currencyCode'];
        res.currencyName = itm.value['currencyName'];
        res.currencySymbol = itm.value['currencySymbol'];

        return res;
      }
    }

    return res;
  }
}