
import 'package:assistance_kit/api/generator.dart';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:brandfit_server/keys.dart';

class NodeDataModel {
  NodeDataModel(): id = Generator.generateName(14);

  late String id;
  DateTime? utcDate;
  double? value;
  String? description;
  //------------- local
  double x = 0;

  NodeDataModel.fromMap(Map? map){
    if(map == null){
      return;
    }

    id = map[Keys.id]?? Generator.generateName(14);
    utcDate = DateHelper.tsToSystemDate(map[Keys.date]); //is utc
    value = map[Keys.value];
    description = map[Keys.description];
  }

  Map toMap(){
    final map = {};

    map[Keys.id] = id;
    map[Keys.date] = DateHelper.toTimestampNullable(utcDate);
    map[Keys.value] = value;
    map[Keys.description] = description;

    return map;
  }

  @override
  String toString() {
    return '$value  date:$utcDate';
  }

  static void sort(List<NodeDataModel> list, {bool asc = true}){
    list.sort((NodeDataModel p1, NodeDataModel p2){
      final d1 = p1.utcDate;
      final d2 = p2.utcDate;

      if(d1 == null){
        return asc? -1: 1;
      }

      if(d2 == null){
        return asc? 1: -1;
      }

      return asc? d2.compareTo(d1) : d1.compareTo(d2);
    });
  }
}