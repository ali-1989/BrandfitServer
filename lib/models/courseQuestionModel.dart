import 'dart:io';

import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:brandfit_server/app/pathNs.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/models/enums.dart';
import 'package:brandfit_server/models/photoDataModel.dart';
import 'package:brandfit_server/publicAccess.dart';

class CourseQuestionModel {
  CourseQuestionModel();

  late double height;
  late double weight;
  late int sex;
  late DateTime birthdate;
  late String illDescription;
  late String illMedications;
  late List<String> illList;
  String? jobType;
  String? noneWorkActivity;
  String? sportTypeDescription;
  String? goalOfBuy;
  late int sleepHoursAtNight;
  late int sleepHoursAtDay;
  late int exerciseHours;
  String? exerciseTimesDescription;
  String? gymToolsDescription;
  String? homeToolsDescription;
  String? dietDescription;
  String? harmDescription;
  String? sportsRecordsDescription;
  String? exercisePlaceType;
  String? gymToolsType;

  List<PhotoDataModel> experimentPhotos = [];
  List<PhotoDataModel> bodyPhotos = [];
  List<PhotoDataModel> bodyAnalysisPhotos = [];
  PhotoDataModel? cardPhoto;

  CourseQuestionModel.fromMap(Map map){
    final List? experimentPhoto = map[NodeNames.experiment_photo.name];
    final List? bodyPhoto = map[NodeNames.body_photo.name];
    final List? bodyAnalysisPhoto = map[NodeNames.body_analysis_photo.name];
    final Map? payPhoto = map['card_photo'];

    if(payPhoto != null){
      cardPhoto = PhotoDataModel.fromMap(payPhoto);
    }

    if(experimentPhoto != null){
      for(var p in experimentPhoto){
        final ph = PhotoDataModel.fromMap(p);
        experimentPhotos.add(ph);
      }
    }

    if(bodyPhoto != null){
      for(var p in bodyPhoto){
        final ph = PhotoDataModel.fromMap(p);
        bodyPhotos.add(ph);
      }
    }

    if(bodyAnalysisPhoto != null){
      for(var p in bodyAnalysisPhoto){
        final ph = PhotoDataModel.fromMap(p);
        bodyAnalysisPhotos.add(ph);
      }
    }

    height = map['height'];
    weight = map['weight'];
    sex = map[Keys.sex];
    birthdate = DateHelper.tsToSystemDate(map['birthdate'])?? DateHelper.getNow();
    illDescription = map['ill_description'];
    illMedications = map['ill_medications'];
    illList = JsonHelper.jsonToList<String>(map['ill_list'])?? [];
    jobType = map['job_type'];
    sportTypeDescription = map['sport_type_description'];
    noneWorkActivity = map['none_work_activity'];
    sleepHoursAtNight = map['sleep_hours_at_night'];
    sleepHoursAtDay = map['sleep_hours_at_day'];
    exerciseHours = map['exercise_hours'];
    goalOfBuy = map['goal_of_buy'];
    exerciseTimesDescription = map['exercise_times_description'];
    exercisePlaceType = map['exercise_place_type'];
    gymToolsType = map['gym_tools_type'];
    gymToolsDescription = map['gym_tools_description'];
    homeToolsDescription = map['home_tools_description'];
    harmDescription = map['harm_description'];
    sportsRecordsDescription = map['sports_records_description'];
    dietDescription = map['diet_description'];
  }

  Map toMap(){
    final map = {};

    map['height'] = height;
    map['weight'] = weight;
    map['sex'] = sex;
    map['birthdate'] = DateHelper.toTimestampNullable(birthdate);
    map['ill_list'] = illList;
    map['exercise_hours'] = exerciseHours;
    map['sleep_hours_at_night'] = sleepHoursAtNight;
    map['sleep_hours_at_day'] = sleepHoursAtDay;
    map['none_work_activity'] = noneWorkActivity;
    map['sport_type_description'] = sportTypeDescription;
    map['job_type'] = jobType;
    map['ill_medications'] = illMedications;
    map['ill_description'] = illDescription;
    map['goal_of_buy'] = goalOfBuy;
    map['exercise_times_description'] = exerciseTimesDescription;
    map['exercise_place_type'] = exercisePlaceType;
    map['gym_tools_type'] = gymToolsType;
    map['gym_tools_description'] = gymToolsDescription;
    map['home_tools_description'] = homeToolsDescription;
    map['harm_description'] = harmDescription;
    map['sports_records_description'] = sportsRecordsDescription;
    map['diet_description'] = dietDescription;
    map[NodeNames.experiment_photo.name] = experimentPhotos.map((e) => e.toMap()).toList();
    map[NodeNames.body_analysis_photo.name] = bodyAnalysisPhotos.map((e) => e.toMap()).toList();
    map[NodeNames.body_photo.name] = bodyPhotos.map((e) => e.toMap()).toList();
    map['card_photo'] = cardPhoto?.toMap();

    return map;
  }

  void addPhoto(String path, NodeNames nodeName){
    final ph = PhotoDataModel();

    ph.path = path;
    ph.utcDate = DateHelper.getNowToUtc();

    if(nodeName == NodeNames.experiment_photo) {
      experimentPhotos.add(ph);
      PhotoDataModel.sort(experimentPhotos, asc: false);
    }
    else if(nodeName == NodeNames.body_photo) {
      bodyPhotos.add(ph);
      PhotoDataModel.sort(bodyPhotos, asc: false);
    }
    else if(nodeName == NodeNames.body_analysis_photo) {
      bodyAnalysisPhotos.add(ph);
      PhotoDataModel.sort(bodyAnalysisPhotos, asc: false);
    }
  }

  void deletePhoto(PhotoDataModel ph, NodeNames nodeName){
    if(nodeName == NodeNames.experiment_photo) {
      experimentPhotos.removeWhere((element) => element == ph);
    }
    else if(nodeName == NodeNames.body_photo) {
      bodyPhotos.removeWhere((element) => element == ph);
    }
    else if(nodeName == NodeNames.body_analysis_photo) {
      bodyAnalysisPhotos.removeWhere((element) => element == ph);
    }
  }

  void deletePhotoByDate(DateTime dt, NodeNames nodeName){
    if(nodeName == NodeNames.experiment_photo) {
      experimentPhotos.removeWhere((element) => element.utcDate == dt);
    }
    else if(nodeName == NodeNames.body_photo) {
      bodyPhotos.removeWhere((element) => element.utcDate == dt);
    }
    else if(nodeName == NodeNames.body_analysis_photo) {
      bodyAnalysisPhotos.removeWhere((element) => element.utcDate == dt);
    }
  }
  
  void updatePhotoPathUrl(File file, String id){
    PhotoDataModel? ph;
    
    try {
      ph = experimentPhotos.firstWhere((element) => element.id == id);
    }
    catch (e){}
    
    if(ph == null){
      try {
        ph = bodyAnalysisPhotos.firstWhere((element) => element.id == id);
      }
      catch (e){}
    }

    if(ph == null){
      try {
        ph = bodyPhotos.firstWhere((element) => element.id == id);
      }
      catch (e){}
    }

    if(ph == null && cardPhoto != null){
      ph = cardPhoto;
    }

    if(ph != null){
      ph.path = '';
      ph.uri = PathsNs.genUrlDomainFromFilePath(PublicAccess.domain, PathsNs.getCurrentPath(), file.path);
    }
  }
}
///=======================================================================================
enum ExercisePlaceType {
  workAtGyn,
  workAtHome,
}

enum GymToolsType {
  little,
  half,
  high,
}