import 'package:assistance_kit/api/helpers/jsonHelper.dart';

class HealthConditionModel {
  String? illDescription;
  String? illMedications;
  List<String> illList = [];

  HealthConditionModel();

  HealthConditionModel.fromMap(Map? map){
    if(map == null){
      return;
    }

    illDescription = map['ill_description'];
    illMedications = map['ill_medications'];

    var iList = map['ill_list']?? [];

    if(iList is! List<String>) {
      iList = JsonHelper.jsonToList<String>(iList);
    }

    illList = iList;
  }

  Map toMap(){
    final map = {};

    map['ill_description'] = illDescription;
    map['ill_medications'] = illMedications;
    map['ill_list'] = JsonHelper.listToJson(illList);

    return map;
  }

  void matchBy(HealthConditionModel other){
    illDescription = other.illDescription;
    illMedications = other.illMedications;
    illList = other.illList;
  }

}