
class AdminCommands {
  AdminCommands._();

  static final _admList = <String>[
    'getTrainerUsers',
    'GetChatsForManager',
    //'CheckNewFoodMaterialName'
  ];

  static bool isAdminCommand(String request){
    return _admList.contains(request);
  }
}