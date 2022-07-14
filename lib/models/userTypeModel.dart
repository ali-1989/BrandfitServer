
class UserTypeModel {
  static const UserType simpleUser = UserType.simpleUser;
  static const UserType trainerUser = UserType.trainerUser; //'TrainerUser';
  static const UserType managerUser = UserType.managerUser; //'ManagerUser';
  static const String brandfitApp = 'Brandfit';
  static const String brandfitManagerApp = 'Brandfit Manager';
  static const String brandfitTrainerApp = 'Brandfit Trainer';

  UserTypeModel();

  static UserType getUserTypeByAppName(String? appName) {
    if(appName == brandfitApp) {
      return simpleUser;
    }

    if(appName == brandfitManagerApp) {
      return trainerUser;
    }

    if(appName == brandfitTrainerApp) {
      return managerUser;
    }

    return simpleUser;
  }

  static int getUserTypeNumByType(UserType? type) {
    if(type == null || type == simpleUser) {
      return 1;
    }

    if(type == trainerUser) {
      return 2;
    }

    if(type == managerUser) {
      return 3;
    }

    return 0;
  }

  static int getUserTypeNumByAppName(String? appName) {
    if(appName == brandfitApp) {
      return 1;
    }

    if(appName == brandfitTrainerApp) {
      return 2;
    }

    if(appName == brandfitManagerApp) {
      return 3;
    }

    return 0;
  }
}
///====================================================================================
enum UserType {
  managerUser,
  trainerUser,
  simpleUser,
}

extension UserTypeExtention on UserType {
  UserType getByName(String s){
    try {
      return UserType.values.firstWhere((element) => element.name == s);
    }
    catch (e){
      return UserType.simpleUser;
    }
  }
}