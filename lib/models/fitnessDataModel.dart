

import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:brandfit_server/models/enums.dart';
import 'package:brandfit_server/models/nodeDataModel.dart';
import 'package:brandfit_server/models/photoDataModel.dart';

///---------------------------------------------------------------------------------------------
class FitnessDataModel {
  Map<NodeNames, List<NodeDataModel>> _kv = {};

  List<PhotoDataModel> sidePhotoNodes = [];
  List<PhotoDataModel> frontPhotoNodes = [];
  List<PhotoDataModel> backPhotoNodes = [];

  FitnessDataModel();

  FitnessDataModel.fromMap(Map? map){
    if(map == null){
      return;
    }

    final sp = JsonHelper.fetchListFromMap<Map<String, dynamic>>(map, NodeNames.side_photo.name)?? [];
    final fp = JsonHelper.fetchListFromMap<Map<String, dynamic>>(map, NodeNames.front_photo.name)?? [];
    final bp = JsonHelper.fetchListFromMap<Map<String, dynamic>>(map, NodeNames.back_photo.name)?? [];

    frontPhotoNodes = _toPhotoNodes(fp);
    backPhotoNodes = _toPhotoNodes(bp);
    sidePhotoNodes = _toPhotoNodes(sp);

    for(var n in NodeNames.values){
      if(n.name.contains(RegExp('photo'))){
        continue;
      }

      final map2 = JsonHelper.fetchListFromMap<Map<String, dynamic>>(map, n.name)?? [];
      _kv[n] = _toDataNodes(map2);
    }
  }

  Map toMap(){
    final map = {};

    map[NodeNames.front_photo.name] = frontPhotoNodes.map((e) => e.toMap()).toList();
    map[NodeNames.back_photo.name] = backPhotoNodes.map((e) => e.toMap()).toList();
    map[NodeNames.side_photo.name] = sidePhotoNodes.map((e) => e.toMap()).toList();

    for(var itm in _kv.entries){
      map[itm.key.name] = itm.value.map((e) => e.toMap()).toList();
    }
    return map;
  }

  void matchBy(FitnessDataModel other){
    _kv = other._kv;
    frontPhotoNodes = other.frontPhotoNodes;
    backPhotoNodes = other.backPhotoNodes;
    sidePhotoNodes = other.sidePhotoNodes;
  }

  PhotoDataModel? findFrontPhotoByUri(String uri){
    for(var f in frontPhotoNodes){
      if(f.uri == uri){
        return f;
      }
    }
  }

  PhotoDataModel? findBackPhotoByUri(String uri){
    for(var f in backPhotoNodes){
      if(f.uri == uri){
        return f;
      }
    }
  }

  PhotoDataModel? findSidePhotoByUri(String uri){
    for(var f in sidePhotoNodes){
      if(f.uri == uri){
        return f;
      }
    }
  }

  List<NodeDataModel>? getNodes(NodeNames nodeName){
    for(var itr in _kv.entries){
      if(itr.key == nodeName){
        return itr.value;
      }
    }
  }

  double? get height {
    final heightNodes = getNodes(NodeNames.height_node);

    if(heightNodes == null || heightNodes.isEmpty) {
      return null;
    }

    return heightNodes.last.value;
  }

  void setHeight(double h) {
    final heightNodes = getNodes(NodeNames.height_node);
    final n = NodeDataModel()..utcDate = DateHelper.getNowToUtc()..value = h;

    if(heightNodes == null || heightNodes.isEmpty) {

      _kv[NodeNames.height_node] = [n];
    }
    else {
      var findToday = false;
      late NodeDataModel tNode;

      for(var i in heightNodes) {
        if (DateHelper.isToday(i.utcDate!)) {
          findToday = true;
          tNode = i;
          break;
        }
      }

      if(findToday){
        tNode.value = h;
      }
      else {
        heightNodes.add(n);
      }
    }
  }

  double? get weight {
    final weightNodes = getNodes(NodeNames.weight_node);

    if(weightNodes == null || weightNodes.isEmpty) {
      return null;
    }

    return weightNodes.last.value;
  }

  void setWeight(double h) {
    final weightNodes = getNodes(NodeNames.weight_node);
    final n = NodeDataModel()..utcDate = DateHelper.getNowToUtc()..value = h;

    if(weightNodes == null || weightNodes.isEmpty) {
      _kv[NodeNames.weight_node] = [n];
    }
    else {
      var findToday = false;
      late NodeDataModel tNode;

      for(var i in weightNodes) {
        if (DateHelper.isToday(i.utcDate!)) {
          findToday = true;
          tNode = i;
          break;
        }
      }

      if(findToday){
        tNode.value = h;
      }
      else {
        weightNodes.add(n);
      }
    }
  }

  List<NodeDataModel> _toDataNodes(List<Map>? list){
    final nodes = <NodeDataModel>[];

    if(list != null && list.isNotEmpty){
      for(var k in list){
        final dot = NodeDataModel.fromMap(k);
        nodes.add(dot);
      }
    }

    return nodes;
  }

  List<PhotoDataModel> _toPhotoNodes(List<Map>? list){
    final nodes = <PhotoDataModel>[];

    if(list != null && list.isNotEmpty){
      for(var k in list){
        final ph = PhotoDataModel.fromMap(k);

        nodes.add(ph);
      }
    }

    PhotoDataModel.sort(nodes, asc: false);

    return nodes;
  }

  static double getMinValueForKey(NodeNames key){
    // ignore: missing_enum_constant_in_switch
    switch(key){
      case NodeNames.weight_node:
        return 20;
      case NodeNames.height_node:
        return 50;
      case NodeNames.chest_node:
        return 10;
      case NodeNames.neck_node:
        return 8;
      case NodeNames.abdominal_node:
        return 12;
      case NodeNames.right_arm_node:
        return 8;
      case NodeNames.right_contracted_arm_node:
        return 8;
      case NodeNames.left_arm_node:
        return 8;
      case NodeNames.left_contracted_arm_node:
        return 8;
      case NodeNames.right_wrist_node:
        return 8;
      case NodeNames.left_wrist_node:
        return 8;
      case NodeNames.waist_node:
        return 12;
      case NodeNames.hip_node:
        return 12;
      case NodeNames.right_thigh_node:
        return 10;
      case NodeNames.left_thigh_node:
        return 10;
      case NodeNames.right_ankle_node:
        return 6;
      case NodeNames.left_ankle_node:
        return 6;
    }

    return 1;
  }

  static double getMaxValueForKey(NodeNames key){
    // ignore: missing_enum_constant_in_switch
    switch(key){
      case NodeNames.weight_node:
        return 140;
      case NodeNames.height_node:
        return 220;
      case NodeNames.chest_node:
        return 50;
      case NodeNames.neck_node:
        return 40;
      case NodeNames.abdominal_node:
        return 70;
      case NodeNames.right_arm_node:
        return 40;
      case NodeNames.right_contracted_arm_node:
        return 40;
      case NodeNames.left_arm_node:
        return 40;
      case NodeNames.left_contracted_arm_node:
        return 40;
      case NodeNames.right_wrist_node:
        return 25;
      case NodeNames.left_wrist_node:
        return 25;
      case NodeNames.waist_node:
        return 50;
      case NodeNames.hip_node:
        return 50;
      case NodeNames.right_thigh_node:
        return 50;
      case NodeNames.left_thigh_node:
        return 50;
      case NodeNames.right_ankle_node:
        return 40;
      case NodeNames.left_ankle_node:
        return 40;
    }

    return 1;
  }
}

/*
    final node = Deeply.getMapFromList([currentNodeName], user.fitnessStatusJs!, 'uri', uri);
    final String? date = node['date'];

    Deeply.insertToListMap([currentNodeName], user.fitnessStatusJs?? {}, 'date', date, <String, dynamic>{'path': f.path});
   */