
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:brandfit_server/database/models/userNotifier.dart';
import 'package:brandfit_server/rest_api/wsMessenger.dart';

class UserNotifierCenter {
  UserNotifierCenter._();

  static Future acceptRequest(int receiverId, Map description) async {
    final notify = UserNotifierModel();
    notify.user_id = receiverId;
    notify.batch = NotifiersBatch.courseAnswer.name;
    notify.descriptionJs = description;
    notify.title = 'درخواست شما از طرف مربی پذیرفته شد';
    notify.titleTranslateKey = 'notify_acceptRequestByTrainer';
    notify.register_date = DateHelper.getNowTimestampToUtc();

    notify.id = await UserNotifierModel.insertModel(notify);

    return WsMessenger.sendCourseRequestAnswerNotifier(receiverId, notify);
  }

  static Future rejectRequest(int receiverId, Map description) async {
    final notify = UserNotifierModel();
    notify.user_id = receiverId;
    notify.batch = NotifiersBatch.courseAnswer.name;
    notify.descriptionJs = description;
    notify.title = 'درخواست شما از طرف مربی رد شد';
    notify.titleTranslateKey = 'notify_rejectRequestByTrainer';
    notify.register_date = DateHelper.getNowTimestampToUtc();

    notify.id = await UserNotifierModel.insertModel(notify);

    return WsMessenger.sendCourseRequestAnswerNotifier(receiverId, notify);
  }

  static Future requestCourse(int receiverId, Map description, Map courseBuy) async {
    final notify = UserNotifierModel();
    notify.user_id = receiverId;
    notify.batch = NotifiersBatch.courseRequest.name;
    notify.descriptionJs = description;
    notify.title = 'درخواست دوره';
    notify.titleTranslateKey = 'notify_requestCourseByPupil';
    notify.register_date = DateHelper.getNowTimestampToUtc();

    notify.id = await UserNotifierModel.insertModel(notify);

    return WsMessenger.sendNewCourseRequestNotifier(receiverId, notify, courseBuy);
  }

  static Future sendProgram(int receiverId, Map description) async {
    final notify = UserNotifierModel();
    notify.user_id = receiverId;
    notify.batch = NotifiersBatch.programs.name;
    notify.descriptionJs = description;
    notify.title = 'یک برنامه ی جدید ارسال شده';
    notify.titleTranslateKey = 'notify_newProgramIsSend';
    notify.register_date = DateHelper.getNowTimestampToUtc();

    notify.id = await UserNotifierModel.insertModel(notify);

    return WsMessenger.sendNewProgramNotifier(receiverId, notify);
  }
}