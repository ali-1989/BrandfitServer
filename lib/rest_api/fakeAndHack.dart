import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/dateSection/dateHelper.dart';
import 'package:brandfit_server/database/models/request.dart';
import 'package:brandfit_server/database/models/userNameId.dart';
import 'package:brandfit_server/database/models/userNotifier.dart';
import 'package:brandfit_server/keys.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/httpCodes.dart';
import 'package:brandfit_server/rest_api/loginResponse.dart';
import 'package:brandfit_server/rest_api/wsMessenger.dart';
import 'package:brandfit_server/rest_api/wsServerNs.dart';

class FakeAndHack {
  FakeAndHack._();

  static Future<Map> hackLogin(int userId) async {
    return await LoginResponse.loginUser({}, userId, 'myToken');
  }

  static Future<Map> hackUserNotifier(int id, int userId) async {
    final ms = WsMessenger.generateWsMessage(section: HttpCodes.sec_courseData, command: HttpCodes.com_notifyCourseRequestAnswer);
    ms[Keys.data] = {
      'id':id,
      'user_id': userId,
      'is_seen':false,
      'register_date': '2022-01-26 10:50:12.123',
      'title': 'درخواست شما رد شد',
      'description_js': {'cause': 'اطلاعات ارسالی ناقص است', 'trainer_name': 'ali', 'course_name': 'دوره'}
    };

    // ignore: unawaited_futures
    WsServerNs.sendToUser(userId, JsonHelper.mapToJson(ms));
    return {Keys.result: Keys.ok};
  }

  static Future<Map> hackTrainerNotifier(int requesterId, int courseId, int trainerId) async {
    final courseBuy = await RequestModelDb.getRequestDataBy(requesterId, courseId);
    final userName = await UserNameModelDb.getUserNameByUserId (requesterId);

    final notify = UserNotifierModel();
    notify.user_id = trainerId;
    notify.batch = NotifiersBatch.courseRequest.name;
    notify.descriptionJs = {'user_name': userName, 'course_name': courseBuy['title'],};
    notify.title = 'درخواست دوره';
    notify.register_date = DateHelper.getNowTimestampToUtc();

    //await UserNotifierModel.insertModel(notify);

    // ignore: unawaited_futures
    WsMessenger.sendNewCourseRequestNotifier(trainerId, notify, courseBuy);
    return {Keys.result: Keys.ok};
  }

  static void simulate_addTicket(int starterId, {int count = 4}){
    for(var i=1; i <= count; i++) {
      var q = '''
      INSERT INTO ticket (title, starter_user_id) VALUES ('TEST $i', $starterId);
    ''';

      PublicAccess.psql2.queryCall(q);
    }
  }

  static void simulate_addTicketWithMessage(int starterId, int senderId, {int count = 4}) async {
    for(var i=1; i <= count; i++) {
      var q = '''
      INSERT INTO ticket (title, starter_user_id) VALUES ('TEST $i', $starterId) RETURNING id;
    ''';

      var res = await PublicAccess.psql2.queryCall(q);
      var ticketId = res?[0].toList()[0]?? 1;

      for(var j=1; j <= 4; j++) {
        q = '''
      INSERT INTO ticketmessage
       (ticket_id, message_type, message_text, sender_user_id, user_send_ts, server_receive_ts)
        values ($ticketId, 1, 'hello ticket $j', $senderId, (now() at time zone 'utc'),
            (now() at time zone 'utc') + (floor(random() * 10) || ' day')::interval);
    ''';

        await PublicAccess.psql2.queryCall(q);
      }
    }
  }

  static void simulate_addTicketMessage(int senderId, {required List<int> ticketIds, int count = 4}) async {
    for(var ticketId in ticketIds){
      for(var i=1; i <= count; i++) {
        var q = '''
        INSERT INTO ticketmessage
         (ticket_id, message_type, message_text, sender_user_id, user_send_ts, server_receive_ts)
          values ($ticketId, 1, 'hello ticket $i', $senderId, (now() at time zone 'utc'),
              (now() at time zone 'utc') + (floor(random() * 10) || ' day')::interval);
      ''';

        await PublicAccess.psql2.queryCall(q);
      }
    }
  }
}