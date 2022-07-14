import 'package:assistance_kit/api/helpers/clone.dart';

/// https://github.com/ustims/DartORM

// sample: CourseDbModel $ UserPlaceDbModel
abstract class DbModel {

  DbModel();

  DbModel.fromMap(Map<String, dynamic> map, {bool lowerKeys = false}){
    if(lowerKeys){
      var clone = Clone.mapDeepCopy(map);

      clone.forEach((key, val) {
        map[key.toLowerCase()] = map.remove(key);
        }
      );
    }
  }

  Map<String, dynamic> toMap(){
    throw Exception('no implement');
  }
}