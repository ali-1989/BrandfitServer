import 'package:assistance_kit/api/helpers/listHelper.dart';
import 'package:assistance_kit/database/psql2.dart';
import 'package:assistance_kit/dateSection/ADateStructure.dart';
import 'package:brandfit_server/database/dbNames.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/queryFiltering.dart';

class QueryList {
  QueryList._();

  static String advancedUsers_q1(List<int> ids){
    var q = '''
    SELECT 
       t1.user_id, t1.user_type, t1.birthdate, t1.name,
       t1.family, t1.register_date, t1.sex, t1.is_deleted,
       t2.user_name,
       t3.phone_code, t3.mobile_number,
        t4.blocker_user_id, t4.block_date, t4.extra_js AS block_extra_js,
       t5.image_path AS profile_image_uri,
       t6.user_name as blocker_user_name,
       t7.last_touch, t7.is_any_login as is_login
    FROM Users AS t1
         INNER JOIN UserNameId AS t2 
             ON t1.user_id = t2.user_id
         LEFT JOIN MobileNumber AS t3 
             ON t1.user_id = t3.user_id AND t1.user_type = t3.user_type
         LEFT JOIN UserBlockList AS t4 
             ON t1.user_id = t4.user_id
         LEFT JOIN UserImages AS t5
                ON t1.user_id = t5.user_id AND t5.type = 1
         LEFT JOIN UserNameId AS t6
                ON t4.blocker_user_id = t6.user_id
         LEFT JOIN
            (SELECT DISTINCT ON (user_id) bool_or(is_login) OVER (PARTITION BY user_id) as is_any_login,
                                   last_touch, user_id
            FROM UserConnections ORDER BY user_id, last_touch DESC NULLS LAST) AS t7
                ON t1.user_id = t7.user_id
         

  WHERE (@searchIds) AND (@searchFilter)
  ;
    ''';
  //ORDER BY @orderBy LIMIT x

    var searchIds = 't1.user_id IN(${ListHelper.listToSequence(ids)})';
    var search = 'true';
    //var orderBy = 'register_date DESC NULLS LAST';

    q = q.replaceFirst(RegExp('@searchIds'), searchIds);
    q = q.replaceFirst(RegExp('@searchFilter'), search);
    //q = q.replaceFirst(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String simpleUsers_q1(FilterRequest fq){
    var q = '''
    SELECT t1.user_id, t1.user_type, t1.birthdate, t1.name, t1.family, t1.register_date
        ,t1.sex, t1.is_deleted, t2.user_name, t3.phone_code, t3.mobile_number
        ,t4.blocker_user_id, t4.block_date, t4.extra_js AS block_extra_js,t7.user_name as blocker_user_name,
        t5.last_touch, t5.is_any_login as is_login, t6.image_path AS profile_image_uri
    FROM Users AS t1
     INNER JOIN UserNameId AS t2 ON t1.user_id = t2.user_id
     LEFT JOIN MobileNumber AS t3 ON t1.user_id = t3.user_id AND t1.user_type = t3.user_type
     LEFT JOIN UserBlockList AS t4 ON t1.user_id = t4.user_id
     LEFT JOIN
        (SELECT DISTINCT ON (user_id) bool_or(is_login) OVER (PARTITION BY user_id) as is_any_login, last_touch, user_id
            FROM UserConnections ORDER BY user_id, last_touch DESC NULLS LAST) AS t5
        ON t1.user_id = t5.user_id
     LEFT JOIN UserImages AS t6 ON t1.user_id = t6.user_id AND t6.type = 1
     LEFT JOIN UserNameId AS t7 ON t4.blocker_user_id = t7.user_id
     
    WHERE t1.user_type != 2 AND (@searchAndFilter)
      ORDER BY @orderBy 
    LIMIT x OFFSET x;
    ''';

    var search = 'true';
    var orderBy = 'register_date DESC NULLS LAST';

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey  == SearchKeys.userNameKey){
          search = ' t2.user_name Like $value';
        }
        else if(se.searchKey == SearchKeys.name) {
          search = ' name ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.family) {
          search = ' family ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.mobile) {
          search = ' mobile_number Like $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byGender){
          if (fi.value == FilterKeys.maleOp) {
            search += ' AND sex = 1';
          }
          else if (fi.value == FilterKeys.femaleOp) {
            search += ' AND sex = 2';
          }
        }

        if(fi.key == FilterKeys.byBlocked){
          if(fi.value == 'blocked') {
            search += ' AND blocker_user_id IS NOT null';
          }
          else {
            search += ' AND blocker_user_id IS null';
          }
        }

        if(fi.key == FilterKeys.byDeleted){
          if(fi.value == 'deleted') {
            search += ' AND is_deleted = true';
          }
          else {
            search += ' AND is_deleted = false';
          }
        }

        if(fi.key == FilterKeys.byAge){
          int min = fi.v1;
          int max = fi.v2;
          var maxDate = GregorianDate();
          var minDate = GregorianDate();

          maxDate = maxDate.moveYear(-max, true);
          minDate = minDate.moveYear(-min, true);
          final u = maxDate.format('YYYY-MM-DD', 'en');
          final d = minDate.format('YYYY-MM-DD', 'en');

          search += ''' AND (birthdate < '$d'::date AND birthdate > '$u'::date) ''';
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'register_date';
          }
          else {
            orderBy = 'register_date DESC NULLS LAST';
          }
        }

        else if(so.key == SortKeys.ageKey){
          if(so.isASC){
            orderBy = 'birthdate';
          }
          else {
            orderBy = 'birthdate DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchAndFilter'), search);
    q = q.replaceFirst(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String users_q1(FilterRequest fq){
    var q = '''
    SELECT t1.user_id
    FROM Users AS t1
             INNER JOIN UserNameId AS t2
                 ON t1.user_id = t2.user_id
             LEFT JOIN MobileNumber AS t3
                 ON t1.user_id = t3.user_id AND t1.user_type = t3.user_type
    
    WHERE t1.user_type != 3 AND (@searchFilter)
    ORDER BY @orderBy
    LIMIT x;
    ''';

    var search = 'true';
    var orderBy = 'register_date DESC NULLS LAST';

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.global){
          search = ' name ILIKE $value OR family ILIKE $value '
              'OR user_name ILIKE $value OR mobile_number ILIKE $value ';
        }
      }
    }

    /*if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byGender){
          if (fi.value == FilterKeys.maleOp) {
            search += ' AND sex = 1';
          }
          else if (fi.value == FilterKeys.femaleOp) {
            search += ' AND sex = 2';
          }
        }
      }
    }*/

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'register_date NULLS LAST';
          }
          else {
            orderBy = 'register_date DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), search);
    q = q.replaceFirst(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String userNotifiers_q1(FilterRequest fq, int userId){
    var q = '''
    SELECT * FROM userNotifier WHERE (@searchAndFilter)
      ORDER BY @orderBy 
    LIMIT x;
    ''';

    var search = 'user_id = $userId';
    var orderBy = 'register_date DESC NULLS LAST';

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title Like $value';
        }
        else if(se.searchKey == SearchKeys.descriptionKey) {
          search += ' AND description Like $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byGender){
          if (fi.value == FilterKeys.maleOp) {
            search += ' AND sex = 1';
          }
          else if (fi.value == FilterKeys.femaleOp) {
            search += ' AND sex = 2';
          }
        }

        if(fi.key == FilterKeys.byDeleted){
          if(fi.value == 'deleted') {
            search += ' AND is_deleted = true';
          }
          else {
            search += ' AND is_deleted = false';
          }
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'register_date';
          }
          else {
            orderBy = 'register_date DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchAndFilter'), search);
    q = q.replaceFirst(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String course_q1(FilterRequest fq, int userId){
    var q = '''
    With c1 AS
         (SELECT id, title, description, creator_user_id, currency_js,
                 price, creation_date, has_food_program,
                 has_exercise_program, start_date, finish_date,
                 is_block, block_js, duration_day,
                 is_private_show, image_path as image_uri
          FROM Course
          WHERE (@search)
          OFFSET x LIMIT x)


  SELECT * FROM c1 ORDER BY @orderBy;
    ''';

    var search = 'creator_user_id = $userId';
    var orderBy = 'creation_date NULLS last';

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.descriptionKey) {
          search += ' AND description ILIKE $value';
        }
      }
    }

    /*if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byPrice){
        }

        if(fi.key == FilterKeys.byBlocked){
          if(fi.value == 'blocked') {
            search += ' AND is_block = true';
          }
          else {
            search += ' AND is_block = false';
          }
        }

        if(fi.key == FilterKeys.byExerciseMode){
          search += ' AND has_exercise_program = true';
        }

        if(fi.key == FilterKeys.byFoodMode){
          search += ' AND has_food_program = true';
        }
      }
    }*/

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'creation_date NULLS LAST';
          }
          else {
            orderBy = 'creation_date DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst(RegExp('@search'), '$search');
    q = q.replaceFirst(RegExp('@orderBy'), '$orderBy');


    return q;
  }

  static String course_q2A(FilterRequest fq, int userId){
    var q = '''
          SELECT id, title, description, creator_user_id, currency_js,
             price, creation_date, has_food_program,
             has_exercise_program, start_date, finish_date,
             is_block, block_js, duration_day,
             is_private_show, image_path as image_uri,
             t2.user_name
      FROM Course AS t1
               INNER JOIN UserNameId AS t2
                   ON t1.creator_user_id = t2.user_id
      WHERE (@search)
      ORDER BY @orderBy
      LIMIT x
    ''';

    var search = 'is_private_show = false';
    var orderBy = 'creation_date NULLS last';

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.userNameKey) {
          search += ' AND user_name ILike $value';
        }
        else if(se.searchKey == SearchKeys.descriptionKey) {
          search += ' AND description ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title ILIKE $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byPrice){
        }

        if(fi.key == FilterKeys.byBlocked){
          if(fi.value == 'blocked') {
            search += ' AND is_block = true';
          }
          else {
            search += ' AND is_block = false';
          }
        }

        if(fi.key == FilterKeys.byExerciseMode){
          search += ' AND has_exercise_program = true';
        }

        if(fi.key == FilterKeys.byFoodMode){
          search += ' AND has_food_program = true';
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'creation_date NULLS LAST';
          }
          else {
            orderBy = 'creation_date DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst(RegExp('@search'), '$search');
    q = q.replaceFirst(RegExp('@orderBy'), '$orderBy');

    return q;
  }

  static String course_q2B(FilterRequest fq, int userId){
    var q1 = '''
        SELECT id, title, description, creator_user_id, currency_js,
           price, creation_date, has_food_program,
           has_exercise_program, start_date, finish_date,
           is_block, block_js,
           is_private_show, image_path as image_uri,
           t2.user_name
    FROM Course as t1
             LEFT JOIN UserNameId AS t2
                 ON t1.creator_user_id = t2.user_id
    WHERE (@search)
    ORDER BY @orderBy
    LIMIT x;
    ''';

    var search = 'is_private_show = false';
    var orderBy = 'creation_date NULLS last';

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.descriptionKey) {
          search += ' AND description ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title ILIKE $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byPrice){
        }

        if(fi.key == FilterKeys.byBlocked){
          if(fi.value == 'blocked') {
            search += ' AND is_block = true';
          }
          else {
            search += ' AND is_block = false';
          }
        }

        if(fi.key == FilterKeys.byExerciseMode){
          search += ' AND has_exercise_program = true';
        }

        if(fi.key == FilterKeys.byFoodMode){
          search += ' AND has_food_program = true';
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'creation_date';
          }
          else {
            orderBy = 'creation_date DESC NULLS LAST';
          }
        }
      }
    }

    q1 = q1.replaceFirst(RegExp('@search'), '$search');
    q1 = q1.replaceFirst(RegExp('@orderBy'), '$orderBy');

    return q1;
  }

  static String course_q3A(FilterRequest fq, int userId){
    var q1 = '''
  SELECT
       t1.id, t1.title, t1.description, t1.creator_user_id,
       t1.currency_js, t1.price, t1.creation_date,
       t1.has_food_program, t1.has_exercise_program,
       t1.start_date, t1.finish_date,
       t1.is_block, t1.block_js, t1.duration_day,
       t1.is_private_show, t1.image_path as image_uri,

       t2.user_name

  FROM Course AS t1
          INNER JOIN usernameid AS t2
               ON t1.creator_user_id = t2.user_id
           INNER JOIN trainerdata AS t3
               ON t1.creator_user_id = t3.user_id
  
      WHERE (@searchFilter)
          AND t3.broadcast_course
          AND NOT EXISTS(SELECT id FROM courserequest WHERE course_id = t1.id AND requester_user_id = @filter)
      ORDER BY @orderBy
  LIMIT x;
  ''';

    var search = 'is_private_show = false AND is_block = false';
    var orderBy = 'creation_date DESC NULLS last';

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.descriptionKey) {
          search += ' AND description ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title ILIKE $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byPrice){
        }

        if(fi.key == FilterKeys.byBlocked){
          if(fi.value == 'blocked') {
            search += ' AND is_block = true';
          }
          else {
            search += ' AND is_block = false';
          }
        }

        if(fi.key == FilterKeys.byExerciseMode){
          search += ' AND has_exercise_program = true';
        }

        if(fi.key == FilterKeys.byFoodMode){
          search += ' AND has_food_program = true';
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'creation_date';
          }
          else {
            orderBy = 'creation_date DESC NULLS LAST';
          }
        }
      }
    }

    q1 = q1.replaceFirst(RegExp('@searchFilter'), '$search');
    q1 = q1.replaceFirst(RegExp('@orderBy'), '$orderBy');
    q1 = q1.replaceFirst(RegExp('@filter'), '$userId');

    return q1;
  }

  static String course_q3B(FilterRequest fq, int userId){
    var q1 = '''
  SELECT
       t1.id, t1.title, t1.description, t1.creator_user_id,
       t1.currency_js, t1.price, t1.creation_date,
       t1.has_food_program, t1.has_exercise_program,
       t1.start_date, t1.finish_date,
       t1.is_block, t1.block_js, t1.duration_day,
       t1.is_private_show, t1.image_path as image_uri,

       t2.user_name
       
  FROM Course AS t1
           INNER JOIN usernameid AS t2
               ON t1.creator_user_id = t2.user_id
  
      WHERE (@searchFilter)
          AND NOT EXISTS(SELECT id FROM courserequest WHERE course_id = t1.id AND requester_user_id = @filter)
      ORDER BY @orderBy
  LIMIT x;
  ''';

    /*var q2 = '''
    With c1 AS
         (SELECT id, title, description, creator_user_id, currency_js,
                 price, creation_date, has_food_program,
                 has_exercise_program, start_date, finish_date,
                 is_block, block_js,
                 is_private_show, image_path as image_uri
          FROM Course
          WHERE (@search)
          ORDER BY @orderBy
          LIMIT x),

  c2 AS (SELECT t1.*, t2.user_name FROM c1 AS t1
            LEFT JOIN UserNameId AS t2 ON t1.creator_user_id = t2.user_id)


  SELECT * FROM c2 ORDER BY @orderBy;
    ''';*/

    var search = 'is_private_show = false AND is_block = false';
    var orderBy = 'creation_date DESC NULLS last';

    if(fq.querySearchingList.isNotEmpty){
      //var value;

      for(final se in fq.querySearchingList){
        //value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.userNameKey) {
          search += " AND user_name = '${se.text}'";
        }
        /*else if(se.searchKey == SearchKeys.descriptionKey) {
          search += ' AND description ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title ILIKE $value';
        }*/
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byPrice){
        }

        if(fi.key == FilterKeys.byBlocked){
          if(fi.value == 'blocked') {
            search += ' AND is_block = true';
          }
          else {
            search += ' AND is_block = false';
          }
        }

        if(fi.key == FilterKeys.byExerciseMode){
          search += ' AND has_exercise_program = true';
        }

        if(fi.key == FilterKeys.byFoodMode){
          search += ' AND has_food_program = true';
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'creation_date';
          }
          else {
            orderBy = 'creation_date DESC NULLS LAST';
          }
        }
      }
    }

    q1 = q1.replaceFirst(RegExp('@searchFilter'), '$search');
    q1 = q1.replaceFirst(RegExp('@orderBy'), '$orderBy');
    q1 = q1.replaceFirst(RegExp('@filter'), '$userId');

    return q1;
  }

  static String course_q4(int courseId){
    var q = '''
  SELECT EXISTS(
    SELECT * FROM courserequest
    WHERE course_id = $courseId
       )
  ''';

    return q;
  }

  static String request_q1(FilterRequest fq, int userId){
    var q = '''
    SELECT
       t1.id, t1.course_id, t1.requester_user_id,
       t1.amount_paid, t1.user_card_number, t1.tracking_code,
       t1.answer_js, t1.answer_date,
       t1.request_date, t1.pay_date, t1.support_expire_date,
       
       t2.title, t2.start_date, t2.finish_date, t2.creation_date,
       t2.currency_js, t2.price,
       t2.creator_user_id, t2.duration_day,
       t2.has_exercise_program, t2.has_food_program,
       t2.description, t2.image_path as image_url,
       
       t3.user_name as pupil_user_name
    FROM courseRequest AS t1
    JOIN course AS t2
    ON t1.course_id = t2.id
    JOIN usernameid AS t3
    ON t1.requester_user_id = t3.user_id

  WHERE (@searchFilter)
  ORDER BY @orderBy
  LIMIT x;
    ''';

    var search = 'creator_user_id = $userId';
    var orderBy = 'request_date DESC NULLS LAST';

    if(fq.lastCase != null){
      var sign = '<';

      if(fq.getSortFor(SortKeys.registrationKey)?.isASC?? false){
        sign = '<';
      }

      search += " AND request_date $sign '${fq.lastCase}'::timestamp";
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.userNameKey) {
          search += ' AND (t3.user_name ILike $value OR t4.user_name ILike $value)';
        }
        else if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title ILike $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      final opList = <String>[];

      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.pendingRequestOp){
          if (fi.value == FilterKeys.pendingRequestOp) {
            opList.add('pending');
          }
        }

        else if(fi.key == FilterKeys.acceptedRequestOp){
          if (fi.value == FilterKeys.acceptedRequestOp) {
            opList.add('accepted');
          }
        }

        else if(fi.key == FilterKeys.rejectedRequestOp){
          if (fi.value == FilterKeys.rejectedRequestOp) {
            opList.add('rejected');
          }
        }
      }

      if(opList.contains('pending') && opList.contains('accepted') && opList.contains('rejected')){
        //search2 = 'true';
      }
      else {
        if(opList.contains('pending') && opList.contains('accepted')){
          search += " AND (answer_date IS NULL OR (answer_js->'accept')::boolean = true)";
        }
        else if(opList.contains('rejected') && opList.contains('accepted')){
          search += " AND ((answer_js->'reject')::boolean = true OR (answer_js->'accept')::boolean = true)";
        }
        else if(opList.contains('rejected') && opList.contains('pending')){
          search += " AND (answer_date IS NULL OR (answer_js->'reject')::boolean = true)";
        }
        else if(opList.contains('pending')){
          search += ' AND answer_date IS NULL';
        }
        else if(opList.contains('rejected')){
          search += " AND (answer_date IS NOT NULL AND (answer_js->'reject')::boolean = true)";
        }
        else if(opList.contains('accepted')){
          search += " AND (answer_date IS NOT NULL AND (answer_js->'accept')::boolean = true)";
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'request_date NULLS LAST';
          }
          else {
            orderBy = 'request_date DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), search);
    q = q.replaceFirst(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String request_q2(int courseId, int requester){
    var q = '''
    SELECT
       t1.id, t1.course_id, t1.requester_user_id,
       t1.amount_paid, t1.user_card_number, t1.tracking_code,
       t1.answer_js, t1.answer_date,
       t1.request_date, t1.pay_date, t1.support_expire_date,
       
       t2.title, t2.start_date, t2.finish_date, t2.creation_date,
       t2.currency_js, t2.price,
       t2.creator_user_id, t2.duration_day,
       t2.has_exercise_program, t2.has_food_program,
       t2.description, t2.image_path as image_url
       
    FROM courseRequest AS t1
    JOIN course AS t2
    ON t1.course_id = t2.id

  WHERE (@searchFilter);
    ''';

    final search = 't2.id = $courseId AND requester_user_id = $requester';

    q = q.replaceFirst(RegExp('@searchFilter'), search);

    return q;
  }

  static String request_q3(int pupilId, int trainerId){
    var q = '''
    SELECT
    t1.id, t1.course_id, t1.requester_user_id,
    t1.amount_paid, t1.user_card_number, t1.tracking_code,
    t1.answer_js, t1.answer_date,
    t1.request_date, t1.pay_date, t1.support_expire_date,

    t2.title, t2.start_date, t2.finish_date, t2.creation_date,
    t2.currency_js, t2.price,
    t2.creator_user_id, t2.duration_day,
    t2.has_exercise_program, t2.has_food_program,
    t2.description, t2.image_path as image_url

    FROM courserequest AS t1
    JOIN course AS t2
         ON t2.id = t1.course_id

WHERE 
      t1.requester_user_id = $pupilId
    AND creator_user_id = $trainerId
    AND is_block = FALSE 
    AND t1.answer_date IS NOT NULL AND (answer_js->'accept')::bool = true;
  ''';

    return q;
  }

  static String request_q4(FilterRequest fq, int userId){
    var q = '''  
      SELECT
       t1.id, t1.course_id, t1.requester_user_id,
       t1.amount_paid, t1.user_card_number,
       t1.answer_js, t1.answer_date, t1.support_expire_date,
       t1.tracking_code, t1.request_date, t1.pay_date,
       t2.title, t2.start_date, t2.creation_date, t2.currency_js,
       t2.price, t2.creator_user_id, t2.duration_day,
       t2.has_exercise_program, t2.has_food_program,
       t3.user_name as trainer_user_name,
       t4.user_name as pupil_user_name
    FROM courseRequest AS t1
    JOIN course AS t2
    ON t1.course_id = t2.id
    LEFT JOIN usernameid AS t3
    ON t2.creator_user_id = t3.user_id
    LEFT JOIN usernameid AS t4
         ON t1.requester_user_id = t4.user_id
      
      WHERE (@searchFilter)
      ORDER BY @orderBy
      LIMIT x;
    ''';

    var search = 'true';
    var orderBy = 'request_date DESC NULLS LAST';

    if(fq.lastCase != null){
      var sign = '<';

      if(fq.getSortFor(SortKeys.registrationKey)?.isASC?? false){
        sign = '<';
      }

      search = " request_date $sign '${fq.lastCase}'::timestamp";
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.userNameKey) {
          search += ' AND (t3.user_name ILike $value OR t4.user_name ILike $value)';
        }
        else if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title ILike $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      final opList = <String>[];

      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.pendingRequestOp){
          if (fi.value == FilterKeys.pendingRequestOp) {
            opList.add('pending');
          }
        }

        else if(fi.key == FilterKeys.acceptedRequestOp){
          if (fi.value == FilterKeys.acceptedRequestOp) {
            opList.add('accepted');
          }
        }

        else if(fi.key == FilterKeys.rejectedRequestOp){
          if (fi.value == FilterKeys.rejectedRequestOp) {
            opList.add('rejected');
          }
        }
      }

      if(opList.contains('pending') && opList.contains('accepted') && opList.contains('rejected')){
        //no thing
      }
      else {
        if(opList.contains('pending') && opList.contains('accepted')){
          search += " AND (answer_date IS NULL OR (answer_js->'accept')::boolean = true)";
        }
        else if(opList.contains('rejected') && opList.contains('accepted')){
          search += " AND ((answer_js->'reject')::boolean = true OR (answer_js->'accept')::boolean = true)";
        }
        else if(opList.contains('rejected') && opList.contains('pending')){
          search += " AND (answer_date IS NULL OR (answer_js->'reject')::boolean = true)";
        }
        else if(opList.contains('pending')){
          search += ' AND answer_date IS NULL';
        }
        else if(opList.contains('rejected')){
          search += " AND (answer_date IS NOT NULL AND (answer_js->'reject')::boolean = true)";
        }
        else if(opList.contains('accepted')){
          search += " AND (answer_date IS NOT NULL AND (answer_js->'accept')::boolean = true)";
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'request_date NULLS LAST';
          }
          else {
            orderBy = 'request_date DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), search);
    q = q.replaceFirst(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String ticket_q1(FilterRequest fq, int userId){
    var q = '''
    With c1 AS
         (SELECT id, title, start_date, starter_user_id, type,
                 is_close, is_deleted
          FROM ticket
            WHERE (@searchFilter)
             ORDER BY @orderBy
             LIMIT x
             ),
     c2 AS
         (SELECT t1.*, t2.last_message_ts
          FROM C1 AS t1 LEFT JOIN seenticketmessage AS t2
                ON t1.id = t2.ticket_id AND t2.user_id = @userId
         )

    SELECT * FROM c2 ORDER BY @orderBy;
    ''';

    var search = 'starter_user_id = $userId';
    var orderBy = 'start_date DESC NULLS LAST';

    if(fq.lastCase != null){
      search += " AND creation_date < '${fq.lastCase}'::timestamp";
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title LIKE $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byGender){
          if (fi.value == FilterKeys.maleOp) {
            search += ' AND sex = 1';
          }
          else if (fi.value == FilterKeys.femaleOp) {
            search += ' AND sex = 2';
          }
        }

        if(fi.key == FilterKeys.byDeleted){
          if(fi.value == 'deleted') {
            search += ' AND is_deleted = true';
          }
          else {
            search += ' AND is_deleted = false';
          }
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'start_date';
          }
          else {
            orderBy = 'start_date DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst('@userId', '$userId');
    q = q.replaceFirst('@searchFilter', search);
    q = q.replaceAll(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String ticket_q2(FilterRequest fq, int userId){
    /*var q = '''
    SELECT id, title, start_date, starter_user_id, type,
       is_deleted, is_close, message_id,
       ticket_id, server_receive_ts, user_send_ts, user_id,
    CASE WHEN user_id = ${PublicAccess.adminUserId} THEN last_message_ts END AS last_message_ts
    FROM ticketsformanager1
    WHERE (@searchFilter)
    ORDER BY COALESCE(server_receive_ts, start_date) DESC NULLS LAST
    LIMIT x;
    ''';*/

    var q = '''
    WITH C1 AS(
      SELECT id, title, start_date, starter_user_id, type,
             is_deleted, is_close, message_id,
             ticket_id, server_receive_ts, user_send_ts
      FROM ticketsformanager1
      WHERE (@searchFilter)
      ORDER BY COALESCE(server_receive_ts, start_date) DESC NULLS LAST
      LIMIT x),
      C2 AS
          (SELECT t1.*, t2.last_message_ts, t2.user_id
                FROM C1 AS t1 LEFT JOIN seenticketmessage AS t2
                        ON t1.ticket_id = t2.ticket_id AND t2.user_id = @admin 
               )
      
      SELECT * FROM C2
      ORDER BY COALESCE(server_receive_ts, start_date) DESC NULLS LAST;
    ''';

    var search = 'true';
    //var orderBy = 'start_date DESC NULLS LAST';

    if(fq.lastCase != null){
      search = " COALESCE(server_receive_ts, start_date) < '${fq.lastCase}'::timestamp";
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title LIKE $value';
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), search);
    q = q.replaceFirst(RegExp('@admin'), '${PublicAccess.adminUserId}');
    //q = q.replaceAll(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String ticket_q3(FilterRequest fq, int userId){
    var q = '''
    WITH C1 AS(
      SELECT id, title, start_date, starter_user_id, type,
             is_deleted, is_close, message_id,
             ticket_id, server_receive_ts, user_send_ts
      FROM ticketsformanager2
      WHERE (@searchFilter)
      ORDER BY COALESCE(server_receive_ts, start_date) DESC NULLS LAST
      LIMIT 10),
      C2 AS
          (SELECT t1.*, t2.last_message_ts, t2.user_id
                FROM C1 AS t1 LEFT JOIN seenticketmessage AS t2
                        ON t1.ticket_id = t2.ticket_id
                  WHERE t2.user_id = @admin
               )
      
      SELECT * FROM C2
      ORDER BY COALESCE(server_receive_ts, start_date) DESC NULLS LAST;
    ''';

    var search = 'true';
    //var orderBy = 'start_date DESC NULLS LAST';

    if(fq.lastCase != null){
      search += " AND COALESCE(server_receive_ts, start_date) < '${fq.lastCase}'::timestamp";
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title LIKE $value';
        }
        else if(se.searchKey == SearchKeys.userNameKey) {
          search += ' AND user_name LIKE $value';
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), search);
    //q = q.replaceAll(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String ticketMessage_q1(FilterRequest fq, int userId, List<int> ids, bool withDeleted){
    var q = '''
    With c1 AS
         (SELECT * FROM ticketmessage
             WHERE @con1 (@searchFilter)
         ORDER BY @orderBy
             LIMIT 100
         )

  SELECT * FROM c1;
    ''';

    if(withDeleted){
      q = q.replaceFirst('@con1', ' ');
    }
    else {
      q = q.replaceFirst('@con1', '(is_deleted = false) AND ');
    }

    var search = 'ticket_id IN (${Psql2.listToSequence(ids)})';
    var orderBy = 'server_receive_ts DESC NULLS LAST';

    if(fq.lastCase != null){
      search += ' AND id > ${fq.lastCase}';
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title LIKE $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byGender){
          if (fi.value == FilterKeys.maleOp) {
            search += ' AND sex = 1';
          }
          else if (fi.value == FilterKeys.femaleOp) {
            search += ' AND sex = 2';
          }
        }

        if(fi.key == FilterKeys.byDeleted){
          if(fi.value == 'deleted') {
            search += ' AND is_deleted = true';
          }
          else {
            search += ' AND is_deleted = false';
          }
        }
      }
    }


    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'start_date';
          }
          else {
            orderBy = 'start_date DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), search);
    q = q.replaceFirst(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String ticketMessage_q2(FilterRequest fq, int ticketId, bool withDeleted){
    var q = '''
    With c1 AS
         (SELECT id, ticket_id, media_id, reply_id, message_type,
                 sender_user_id, is_deleted, is_edited, user_send_ts,
                 server_receive_ts, receive_ts, seen_ts,
                 message_text, extra_js, cover_data
          FROM ticketmessage
          WHERE @con1 (@searchFilter)
          ORDER BY @orderBy
            limit x
         )

  SELECT * FROM c1 ORDER BY @orderBy;
    ''';

    if(withDeleted){
      q = q.replaceFirst('@con1', ' ');
    }
    else {
      q = q.replaceFirst('@con1', '(is_deleted = false) AND ');
    }

    var search = 'ticket_id = $ticketId';
    var orderBy = 'server_receive_ts DESC NULLS LAST';

    if(fq.lastCase != null){
      search += " AND server_receive_ts < '${fq.lastCase}'::timestamp";
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title LIKE $value';
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), search);
    q = q.replaceAll(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String chat_q1(FilterRequest fq, int userId){
    var q = '''
    With c1 AS
         (With c1 AS
                   (SELECT id, title, creator_user_id, creation_date, type,
                           is_deleted, state_key, logo_path as logo_url, description,
                           CASE WHEN state_key = 1 THEN TRUE ELSE FALSE END AS is_close
                    FROM conversation
                    WHERE (is_deleted = FALSE) AND (@searchFilter)
                    ORDER BY @orderBy
                   ),
               c2 AS
                   (SELECT t1.*
                    FROM C1 AS t1 JOIN usertoconversation AS t2
                                       ON t1.id = t2.conversation_id
                    WHERE t2.user_id = @userId

                   ),
               c3 AS
                   (SELECT t1.*, t2.last_message_ts
                    FROM C2 AS t1 LEFT JOIN seenconversationmessage AS t2
                                            ON t1.id = t2.conversation_id AND t2.user_id = @userId
                   )

          SELECT * FROM c3 LIMIT x
         ),
    c2 AS
         (SELECT t1.*, t2.user_id as receiver_id
          FROM C1 AS t1 LEFT JOIN usertoconversation AS t2
                 ON t1.id = t2.conversation_id
             WHERE t2.user_id != @userId
         )

  SELECT * FROM c2;
    ''';

    var search = 'true';
    var orderBy = 'creation_date DESC NULLS LAST';

    if(fq.lastCase != null){
      search = " creation_date < '${fq.lastCase}'::timestamp";
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title LIKE $value';
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), search);
    q = q.replaceAll(RegExp('@userId'), '$userId');
    q = q.replaceAll(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String chat_q2(FilterRequest fq, int userId){
    var q = '''
    With c1 AS
         (With c1 AS
                   (SELECT id, title, creator_user_id, creation_date, type,
                           is_deleted, state_key, logo_path as logo_url, description,
                           CASE WHEN state_key = 1 THEN TRUE ELSE FALSE END AS is_close
                    FROM conversation
                    WHERE (is_deleted = FALSE) AND (@searchFilter)
                    ORDER BY @orderBy
                   ),
               c2 AS
                   (SELECT t1.*
                    FROM C1 AS t1 JOIN usertoconversation AS t2
                                       ON t1.id = t2.conversation_id
                    WHERE t2.user_id = @userId

                   ),
               c3 AS
                   (SELECT t1.*, t2.last_message_ts
                    FROM C2 AS t1 LEFT JOIN seenconversationmessage AS t2
                                            ON t1.id = t2.conversation_id AND t2.user_id = @userId
                   )

          SELECT * FROM c3 LIMIT x
         ),
    c2 AS
         (SELECT t1.*, t2.user_id as receiver_id
          FROM C1 AS t1 LEFT JOIN usertoconversation AS t2
                 ON t1.id = t2.conversation_id
             WHERE t2.user_id != @userId
         )

  SELECT * FROM c2;
    ''';

    var search = 'true';
    var orderBy = 'creation_date DESC NULLS LAST';

    if(fq.lastCase != null){
      var sign = '<';

      if(fq.getSortFor(SortKeys.registrationKey)?.isASC?? false){
        sign = '<';
      }

      search = " creation_date $sign '${fq.lastCase}'::timestamp";
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title LIKE $value';
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), search);
    q = q.replaceAll(RegExp('@userId'), '$userId');
    q = q.replaceAll(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String chat_q3(FilterRequest fq){
    var q = '''
    SELECT t1.id, t1.title, t1.creator_user_id, t1.creation_date, t1.type,
           t1.is_deleted, t1.state_key, t1.logo_path as logo_url, t1.description,
           t2.members,
           t3.server_receive_ts,
           CASE WHEN t1.state_key = 1 THEN TRUE ELSE FALSE END AS is_close
    FROM conversation AS t1
             JOIN conversations_members_view AS t2
                  ON t1.id = t2.conversation_id
             LEFT JOIN (
                 SELECT conversation_id, max(server_receive_ts) as server_receive_ts
                        FROM conversationmessage WHERE is_deleted = FALSE GROUP BY conversation_id
                 ) AS t3
                       ON t1.id = t3.conversation_id
    WHERE (@searchFilter)
    ORDER BY creation_date DESC
    LIMIT x;
    ''';

    var search = 'true';
    //var orderBy = 'creation_date DESC NULLS LAST';

    if(fq.lastCase != null){
      var sign = '<';

      if(fq.getSortFor(SortKeys.registrationKey)?.isASC?? false){
        sign = '<';
      }

      search = " creation_date $sign '${fq.lastCase}'::timestamp";
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title LIKE $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      final userIds = [];

      for(final fi in fq.queryFilteringList) {
        if (fi.key == FilterKeys.byPupilUser) {
          for(final ui in fi.valueList){
            userIds.add(ui);
          }
        }

        if (fi.key == FilterKeys.byTrainerUser) {
          for(final ui in fi.valueList){
            userIds.add(ui);
          }
        }
      }

      if(userIds.isNotEmpty){
        search += ' AND t2.members && array[${ListHelper.listToSequence(userIds)}]::bigint[]';
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), search);
    //q = q.replaceAll(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String chatMessage_q1(int userId, List<int> ids, bool withDeleted){
    //todo: change fn ,use query no fn  | and for ticketMessage
    var q = '''
      select * from fetchTopConversationMessage('@list', 100);
    ''';

    q = q.replaceFirst('@list', '${Psql2.listToSequenceNum(ids)}');

    /*if(withDeleted){
      q = q.replaceFirst('@con1', ' ');
    }
    else {
      q = q.replaceFirst('@con1', '(is_deleted = false) AND ');
    }

    var search = 'conversation_id IN (${Psql2.listToSequence(ids)})';
    var orderBy = 'server_receive_ts DESC NULLS LAST';

    if(fq.lastCase != null){
      var sign = '>';

      if(fq.isSortFor(SortKeys.latestRegistrationKey)){
        sign = '<';
      }

      search += ' AND id < ${fq.lastCase}';
    }

    if(fq.searchText.isNotEmpty && fq.searchScopes.isNotEmpty){
      final key = fq.searchScopes[0];
      final value = '\$token\$%${fq.searchText}%\$token\$';

      if(key == SearchKeys.titleKey) {
        search += ' AND title Like $value';
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      final byGender = fq.filterJs[FilterKeys.byGender];
      final byDeleted = fq.filterJs[FilterKeys.byDeleted];

      if (byGender != null) {
        final value = byGender['value'];

        if (value == FilterKeys.maleOp) {
          search += ' AND sex = 1';
        }
        else if (value == FilterKeys.femaleOp) {
          search += ' AND sex = 2';
        }
      }

      if(byDeleted != null){
        final value = byDeleted['value'];

        if(value == 'deleted') {
          search += ' AND is_deleted = true';
        }
        else {
          search += ' AND is_deleted = false';
        }
      }
    }

    if(fq.sortBy.isNotEmpty){
      if(fq.isSortFor(SortKeys.latestRegistrationKey)){
        orderBy = 'start_date DESC NULLS LAST';
      }
      else if(key.key == SortKeys.oldestRegistrationKey){
        orderBy = 'start_date';
      }
    }*/

    //q = q.replaceFirst(RegExp('@searchFilter'), search);
    //q = q.replaceFirst(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String foodMaterial_q1(FilterRequest fq){
    var q = '''
    With c1 AS
         (SELECT id, title, alternatives, type, register_date, creator_id,
                 fundamentals_js, measure_js, language, can_show, path AS image_uri
          FROM FoodMaterial
          WHERE (@searchFilter)
          ORDER BY @orderBy
          LIMIT x
         ),
       c2 AS
         (SELECT t1.*, t2.translates FROM c1 AS t1
           LEFT JOIN
                    (select link_id, jsonb_object_agg(language, title) AS translates
                     FROM FoodMaterialTranslate GROUP BY link_id) AS t2
                 ON (t1.id = t2.link_id)
         )

  SELECT * FROM c2;
    ''';

    var search = 'TRUE';
    var orderBy = 'register_date NULLS LAST';

    if(fq.lastCase != null){
      var sign = '>';

      if(!(fq.getSortFor(SortKeys.registrationKey)?.isASC?? true)){
        sign = '<';
      }

      search += " AND register_date $sign '${fq.lastCase}'::timestamp";
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search = "(title ILIKE $value OR array_to_string(alternatives, ',') ILIKE $value)";
        }
        else if(fq.isSearchFor(SearchKeys.sameWordKey)) {
          search = " alternatives @> ARRAY['${se.text}']";
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){

        if(fi.key == FilterKeys.byType){
          var t = '';

          if (fi.value == FilterKeys.matterOp || fi.valueList.contains(FilterKeys.matterOp)) {
            t += "'matter'";
          }

          if (fi.value == FilterKeys.herbalTeaOp || fi.valueList.contains(FilterKeys.herbalTeaOp)) {
            t += ",'herbal_tea'";
          }

          if (fi.value == FilterKeys.complementOp || fi.valueList.contains(FilterKeys.complementOp)) {
            t += ",'complement'";
          }

          t = t.replaceFirst(RegExp(r','), '');

          search += ' AND type IN($t)';
        }
        else if(fi.key == FilterKeys.byVisibleState){
          if (fi.value == FilterKeys.isVisibleOp) {
            search += ' AND can_show = true';
          }
          else if (fi.value == FilterKeys.isNotVisibleOp) {
            search += ' AND can_show = false';
          }
        }
      }
    }
    /*else {
      search += ' AND type = matter';
    }*/

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'register_date';
          }
          else {
            orderBy = 'register_date DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst('@searchFilter', search);
    q = q.replaceAll(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String foodMaterial_q2(FilterRequest fq, Set<int> ids){
    var q = '''
    With c1 AS
         (SELECT id, title, alternatives, type, register_date,
                 fundamentals_js, language, can_show, measure_js, path AS image_uri
          FROM FoodMaterial
          WHERE id in(#ids)),
     c2 AS
         (SELECT t1.*, t2.translates FROM c1 AS t1
           LEFT JOIN
                    (select link_id, jsonb_object_agg(language, title) AS translates
                     FROM FoodMaterialTranslate GROUP BY link_id) AS t2
                ON (t1.id = t2.link_id))

  SELECT * FROM c2;
    ''';

    q = q.replaceFirst(RegExp('#ids'), Psql2.listToSequence(ids));//smpl: list

    return q;
  }

  static String foodMaterial_q3(int id){
    var q = '''
    SELECT * FROM FoodMaterial
          WHERE id = $id AND (
                      type NOT LIKE 'matter' OR
                      (SELECT ARRAY(SELECT jsonb_array_elements(fundamentals_js) ->> 'key') @>
                                    array ['calories', 'fat', 'protein', 'carbohydrate'])
              );
    ''';

    return q;
  }

  static String foodMaterial_q4(int matId){
    var q = '''
    SELECT EXISTS (
    SELECT * FROM programsuggestion
        WHERE (SELECT ARRAY(SELECT (jsonb_array_elements(materials_js) -> 'material_id')::INT)) @> ARRAY[$matId]
    );

    ''';

    return q;
  }

  static String foodProgram_q1(FilterRequest fq, int userId){
    var q = '''
    With c1 AS(
        SELECT id, creator_id, title, register_date, can_show, calories, days
          FROM FoodProgram
          WHERE (@searchFilter)
          ORDER BY @orderBy
          LIMIT x
         )

    SELECT * FROM c1;
    ''';

    var search = 'creator_id = $userId';
    var orderBy = 'register_date DESC NULLS LAST';

    if(fq.lastCase != null){
      var sign = '>';

      if(!(fq.getSortFor(SortKeys.registrationKey)?.isASC?? true)){
        sign = '<';
      }

      search += " AND register_date $sign '${fq.lastCase}'::timestamp";
    }

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title ILIKE $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byType){
          var t = '';

          if (fi.valueList.contains(FilterKeys.matterOp)) {
            t += "'matter'";
          }

          if (fi.valueList.contains(FilterKeys.herbalTeaOp)) {
            t += ",'herbal_tea'";
          }

          if (fi.valueList.contains(FilterKeys.complementOp)) {
            t += ",'complement'";
          }

          t = t.replaceFirst(RegExp(r'$,'), '');

          search += ' AND type IN($t)';
        }
      }
    }
    /*else {
      search += ' AND type = matter';
    }*/

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'register_date';
          }
          else {
            orderBy = 'register_date DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst('@searchFilter', search);
    q = q.replaceAll(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String foodProgram_q2(int requestId, bool pending){
    var q = '''
    With c1 AS(
      SELECT
         id, trainer_id, title, register_date, cron_date, send_date,
           pupil_see_date, can_show, p_c_l, request_id
      FROM FoodProgram
      WHERE request_id = #rId AND (#filter)
      ORDER BY register_date DESC
  )
  
  SELECT * FROM c1;
    ''';

    var filter = 'TRUE';

    if(!pending){
      filter = 'send_date IS NOT NULL';
    }

    q = q.replaceFirst('#rId', '$requestId');
    q = q.replaceFirst('#filter', '$filter');

    return q;
  }

  static String foodProgram_q3(int userId, int programId, int dayOrdering){
    return '''
              INSERT INTO foodProgramTree (parent_id, program_id, type_lkp, title, is_base, ordering)
                      VALUES (null, $programId, 1, null, false, $dayOrdering) RETURNING id;
          ''';
  }

  static String foodProgram_q4(int userId, int dayId, int programId, String? mealName, int mealOrdering){
    return """
              INSERT INTO foodProgramTree (parent_id, program_id, type_lkp, title, is_base, ordering)
                      VALUES ($dayId, $programId, 2, '$mealName', false, $mealOrdering) RETURNING id;
          """;
  }

  static String foodProgram_q5(int userId, int mealId, int programId, String? sugName, bool isBase, int sugOrdering){
    return """
              INSERT INTO foodProgramTree (parent_id, program_id, type_lkp, title, is_base, ordering)
                      VALUES ($mealId, $programId, 3, ${sugName == null? null: "'$sugName'"}, $isBase, $sugOrdering) RETURNING id;
          """;
  }

  static String foodProgram_q6(int userId, int sugTreeId, int programId, String? matJs){
    return '''
              INSERT INTO ProgramSuggestion (program_id, program_tree_id, materials_js)
                      VALUES ($programId, $sugTreeId, ${matJs == null? null : "'$matJs'::JSONB"});
          ''';
  }

  static String foodProgram_q7(int programId, int parentId){
    return '''
       WITH l1 AS (
          SELECT * FROM foodprogramtree
              WHERE program_id = $programId AND parent_id = $parentId AND type_lkp = 2
          )
      
      SELECT id, title, ordering FROM l1;
          ''';
  }

  static String foodProgram_q8(int programId){
    return '''
       WITH l1 AS (
          SELECT * FROM foodprogramtree
              WHERE program_id = $programId AND type_lkp = 1
          )
      
      SELECT id, title, ordering FROM l1;
          ''';
  }

  static String foodProgram_q9(int programId){
    return '''
       UPDATE foodprogram SET
            send_date = (now() at time zone 'utc'),
            cron_date = CASE WHEN
                cron_date IS NULL THEN NULL
                WHEN cron_date > (now() at time zone 'utc') THEN NULL
                ELSE cron_date END
          WHERE id = $programId RETURNING send_date, cron_date, request_id;
          ''';
  }

  static String foodSuggestion_q1(int parentId){
    return '''
       WITH l1 AS (
          SELECT * FROM foodprogramtree
              WHERE parent_id = $parentId AND type_lkp = 3
          )
      
      SELECT 
        T1.id, T1.title, T1.ordering, T1.is_base,
        
        T2.materials_js as materials,
        T2.used_materials_js as used_materials
        
         FROM l1 AS T1
          JOIN programsuggestion AS T2
              ON T1.id = T2.program_tree_id;
          ''';
  }

  static String foodSuggestion_q2(int userId, int programId){
    return '''
       WITH l1 AS (
          SELECT * FROM foodprogramtree
              WHERE program_id = $programId AND type_lkp = 3
          )
      
      SELECT T1.id, T1.title, T1.ordering, T1.is_base, T2.materials_js as materials FROM l1 AS T1
          JOIN programsuggestion AS T2
              ON T1.id = T2.program_tree_id;
          ''';
  }

  // *** best sample
  static String trainerPupil_q1(FilterRequest fq, int userId){
    var q = '''  
  WITH C1 AS (
         SELECT
             t1.id, t1.duration_day,
                t2.requester_user_id, t2.answer_date,
                t4.user_name,
                t5.mobile_number
          
         FROM course AS T1
                JOIN courseRequest AS T2
                    ON T1.id = T2.course_id
                JOIN Users AS T3
                    ON T2.requester_user_id = T3.user_id
                JOIN usernameid AS T4
                    ON T2.requester_user_id = T4.user_id
                JOIN mobilenumber AS T5
                    ON T2.requester_user_id = T5.user_id
      
         WHERE
               t1.creator_user_id = $userId 
          AND
               T2.answer_date is NOT NULL AND (answer_js->'accept')::bool = true
          AND (@search1)
          AND (@searchUser)
          AND (@searchUserName)
          AND (@searchMobile)
         ORDER BY answer_date DESC
         LIMIT x
     ),
     C2 AS (
         SELECT
             DISTINCT ON(requester_user_id)
             requester_user_id as user_id,
             MAX(answer_date) OVER (PARTITION BY requester_user_id) as answer_date
         FROM C1
     )
SELECT * FROM C2;

    '''; // FROM C3 ORDER BY answer_date

    /*
    old:
    JOIN (
        SELECT min(send_date) AS min_send_date, request_id
        FROM foodprogram
        GROUP BY request_id) AS T6
    ON T2.id = T6.request_id

    var search1 = "min_send_date is null OR ((min_send_date + (duration_day || ' day')::interval) >= now())";

   */

    var search1 = '(support_expire_date IS NULL OR support_expire_date >= now())';
    var searchUserTb = 'true';
    var searchUserNameTb = 'true';
    var searchMobileTb = 'true';

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.userNameKey) {
          searchUserNameTb = ' user_name Like $value';
        }
        else if(se.searchKey == SearchKeys.family) {
          searchUserTb = ' family Like $value';
        }
        else if(se.searchKey == SearchKeys.mobile) {
          searchMobileTb = ' mobile_number Like $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byGender){
          if (fi.value == FilterKeys.maleOp) {
            searchUserTb += ' AND sex = 1';
          }
          else if (fi.value == FilterKeys.femaleOp) {
            searchUserTb += ' AND sex = 2';
          }
        }

        if(fi.key == FilterKeys.byInActivePupilMode){
          if (fi.value == FilterKeys.byInActivePupilMode) {
            search1 = '(support_expire_date IS NOT NULL AND support_expire_date < now())';
          }
        }
      }
    }

    q = q.replaceFirst(RegExp('@search1'), search1);
    q = q.replaceFirst(RegExp('@searchUser'), searchUserTb);
    q = q.replaceFirst(RegExp('@searchUserName'), searchUserNameTb);
    q = q.replaceFirst(RegExp('@searchMobile'), searchMobileTb);
    //q = q.replaceFirst(RegExp('@orderBy'), orderBy);

    return q;
  }

  static String updateChatMessageSeen(int conversationId, int userId, String ts){
    var q = '''
      UPDATE #tb
        SET seen_ts = '#ts'::timestamp,
            receive_ts = CASE
                 WHEN receive_ts IS NULL THEN '#ts'::timestamp
                 ELSE receive_ts
                END
    WHERE conversation_id = #conversationId AND sender_user_id != #userId;
    ''';

    q = q.replaceFirst(RegExp('#tb'), DbNames.T_ConversationMessage);
    q = q.replaceFirst(RegExp('#conversationId'), '$conversationId');
    q = q.replaceFirst(RegExp('#userId'), '$userId');
    q = q.replaceAll(RegExp('#ts'), ts);

    return q;
  }

  static String updateTicketMessageSeen(int ticketId, int userId, String ts){
    var q = '''
      UPDATE #tb
        SET seen_ts = '#ts'::timestamp,
            receive_ts = CASE
                 WHEN receive_ts IS NULL THEN '#ts'::timestamp
                 ELSE receive_ts
                END
    WHERE ticket_id = #ticketId AND sender_user_id != #userId;
    ''';

    q = q.replaceFirst(RegExp('#tb'), DbNames.T_TicketMessage);
    q = q.replaceFirst(RegExp('#ticketId'), '$ticketId');
    q = q.replaceFirst(RegExp('#userId'), '$userId');
    q = q.replaceAll(RegExp('#ts'), ts);

    return q;
  }

  static String getChatUsersByIds(){
    final q = '''
    With c1 AS
         (SELECT user_id, user_name FROM usernameid
             WHERE user_id in (@list)
         ),
     c2 AS
         (SELECT t1.image_path as profile_image_uri, t2.* FROM userimages AS t1
             RIGHT JOIN c1 AS t2
             ON t1.user_id = t2.user_id AND t1.type = 1
         ),
     c3 AS
         (SELECT DISTINCT ON(t1.user_id) t1.is_login, t1.last_touch, t2.* FROM userconnections AS t1
             RIGHT JOIN c2 AS t2
             ON t1.user_id = t2.user_id
             order by t1.user_id, is_login DESC
         )

  SELECT * FROM c3;
    ''';

    return q;
  }

  static String getMediasByIds(){
    //, screenshot_path as screenshot_uri
    final q = '''
    With c1 AS
         (SELECT id, message_type, group_id, extension,
                 name, width, height, volume, duration,
                 screenshot_js, extra_js, path as uri
            FROM mediamessagedata
             WHERE id in (@list)
         )

  SELECT * FROM c1;
    ''';

    return q;
  }

  static String request_course_q1(FilterRequest fq, int userId){
    var q = '''
    SELECT
    t1.id as request_id, t1.course_id, t1.requester_user_id,
    t1.answer_js, t1.answer_date,
    t1.request_date, t1.pay_date, t1.support_expire_date,

    t2.id, t2.title, t2.description, t2.duration_day,
    t2.has_food_program, t2.has_exercise_program,
    t2.currency_js, t2.price,
    t2.tags, t2.creation_date, t2.image_path as image_uri,
    t2.creator_user_id,

    (CASE WHEN
        EXISTS(SELECT id FROM foodprogram
            WHERE request_id = T1.id AND send_date IS NOT NULL)
        THEN TRUE ELSE FALSE END) AS is_send_program


FROM courseRequest AS t1
         JOIN course AS t2
              ON t1.course_id = t2.id
    WHERE (@searchFilter)
    ORDER BY @orderBy
    LIMIT x; 
    ''';

    var search = 'requester_user_id = $userId';
    var orderBy = 'pay_date NULLS last';

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey == SearchKeys.titleKey) {
          search += ' AND title ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.descriptionKey) {
          search += ' AND description ILIKE $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byPrice){
        }

        if(fi.key == FilterKeys.byBlocked){
          if(fi.value == 'blocked') {
            search += ' AND is_block = true';
          }
          else {
            search += ' AND is_block = false';
          }
        }

        if(fi.key == FilterKeys.byExerciseMode){
          search += ' AND has_exercise_program = true';
        }

        if(fi.key == FilterKeys.byFoodMode){
          search += ' AND has_food_program = true';
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'creation_date';
          }
          else {
            orderBy = 'creation_date DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst(RegExp('@searchFilter'), '$search');
    q = q.replaceFirst(RegExp('@orderBy'), '$orderBy');

    return q;
  }

  static String searchOnTrainerUsers(FilterRequest fq){
    var q = '''
    SELECT 
        t1.user_id, t1.user_type, t1.birthdate, t1.name, t1.family, t1.register_date,
           t1.sex, t1.is_deleted,
           t2.user_name,
           t3.phone_code, t3.mobile_number,
           t4.blocker_user_id, t4.block_date, t4.extra_js AS block_extra_js,
           t5.last_touch, t5.is_any_login as is_login,
           t6.image_path AS profile_image_uri,
           t7.user_name as blocker_user_name,
           t8.broadcast_course, t8.is_exercise, t8.is_food, t8.rank
    
    FROM Users AS t1
             INNER JOIN UserNameId AS t2 ON t1.user_id = t2.user_id
             LEFT JOIN MobileNumber AS t3 ON t1.user_id = t3.user_id AND t1.user_type = t3.user_type
             LEFT JOIN UserBlockList AS t4 ON t1.user_id = t4.user_id
             LEFT JOIN
         (SELECT DISTINCT ON (user_id) bool_or(is_login) OVER (PARTITION BY user_id) as is_any_login, *
          FROM UserConnections ORDER BY user_id, last_touch DESC NULLS LAST) AS t5
         ON t1.user_id = t5.user_id
             LEFT JOIN UserImages AS t6 ON t1.user_id = t6.user_id AND t6.type = 1
             LEFT JOIN UserNameId AS t7 ON t4.blocker_user_id = t7.user_id
             LEFT JOIN trainerdata AS t8 ON t1.user_id = t8.user_id
    
    WHERE t1.user_type = 2 AND (@search)
      ORDER BY @orderBy 
    LIMIT x;
    ''';

    var search = 'TRUE';
    var orderBy = '';

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey  == SearchKeys.userNameKey){
          search = ' t2.user_name Like $value';
        }
        else if(se.searchKey == SearchKeys.name) {
          search = ' name ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.family) {
          search = ' family ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.mobile) {
          search = ' mobile_number Like $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byGender){
          if (fi.value == FilterKeys.maleOp) {
            search += ' AND sex = 1';
          }
          else if (fi.value == FilterKeys.femaleOp) {
            search += ' AND sex = 2';
          }
        }

        if(fi.key == FilterKeys.byBlocked){
          if(fi.value == 'blocked') {
            search += ' AND blocker_user_id IS NOT null';
          }
          else {
            search += ' AND blocker_user_id IS null';
          }
        }

        if(fi.key == FilterKeys.byDeleted){
          if(fi.value == 'deleted') {
            search += ' AND is_deleted = true';
          }
          else {
            search += ' AND is_deleted = false';
          }
        }

        if(fi.key == FilterKeys.byAge){
          int min = fi.v1;
          int max = fi.v2;
          var maxDate = GregorianDate();
          var minDate = GregorianDate();

          maxDate = maxDate.moveYear(-max, true);
          minDate = minDate.moveYear(-min, true);
          final u = maxDate.format('YYYY-MM-DD', 'en');
          final d = minDate.format('YYYY-MM-DD', 'en');

          search += ''' AND (birthdate < '$d'::date AND birthdate > '$u'::date) ''';
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'register_date';
          }
          else {
            orderBy = 'register_date DESC NULLS LAST';
          }
        }

        else if(so.key == SortKeys.ageKey){
          if(so.isASC){
            orderBy = 'birthdate';
          }
          else {
            orderBy = 'birthdate DESC NULLS LAST';
          }
        }
      }
    }

    q = q.replaceFirst(RegExp('Users'), '${DbNames.T_Users}');
    q = q.replaceFirst(RegExp('UserNameId'), '${DbNames.T_UserNameId}');
    q = q.replaceFirst(RegExp('UserNameId'), '${DbNames.T_UserNameId}');//exist 2
    q = q.replaceFirst(RegExp('MobileNumber'), '${DbNames.T_MobileNumber}');
    q = q.replaceFirst(RegExp('UserBlockList'), '${DbNames.T_UserBlockList}');
    q = q.replaceFirst(RegExp('UserConnections'), '${DbNames.T_UserConnections}');
    q = q.replaceFirst(RegExp('UserImages'), '${DbNames.T_UserImages}');
    q = q.replaceFirst(RegExp('@search'), '$search');
    q = q.replaceFirst(RegExp('@orderBy'), '$orderBy');

    return q;
  }

  static String searchOnTrainerUsers2(FilterRequest fq){
    var q = '''
    SELECT
    t1.user_id, t1.user_name,

    t2.image_path as image_uri,

    t3.name, t3.family, t3.sex, t3.birthdate,

    t4.bio,
    t5.course_count,
    T6.bio_images

    FROM usernameid AS t1
         LEFT JOIN userimages AS t2
            ON t1.user_id = t2.user_id
         JOIN users AS t3
    ON t1.user_id = t3.user_id
         JOIN trainerdata AS t4
    ON t1.user_id = t4.user_id
         LEFT JOIN (
             SELECT DISTINCT ON (creator_user_id)
                    count(creator_user_id) OVER (PARTITION BY creator_user_id) as course_count,

                 * FROM course
             WHERE is_block = false AND is_private_show = false
        ) AS t5
                   ON t1.user_id = t5.creator_user_id
        LEFT JOIN (
            SELECT user_id, array_agg(image_path) as bio_images FROM userimages
            WHERE type = 3 AND user_id = 100
            group by user_id
        ) as t6
        ON t1.user_id = t6.user_id

  WHERE (@searchFilter)
    AND t3.user_type = 2
    AND (T2.type = 1 OR t2.type IS NULL)
    
    LIMIT x;
    ''';//ORDER BY @orderBy

    var search = "user_name = ''";
    var orderBy = '';

    if(fq.querySearchingList.isNotEmpty){
      for(final se in fq.querySearchingList){
        if(se.searchKey == SearchKeys.userNameKey) {
          search = " user_name = '${se.text}'";
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {

    }

    if(fq.querySortingList.isNotEmpty){

    }

    q = q.replaceFirst(RegExp('@searchFilter'), '$search');
    q = q.replaceFirst(RegExp('@orderBy'), '$orderBy');

    return q;
  }

  static String getAdvertisingListForUser(){
    final q = '''
    SELECT id, title, type, order_num, register_date,
       start_show_date, finish_show_date, click_link, path as image_uri
    FROM advertising

    WHERE can_show = true
      AND (start_show_date is null OR start_show_date <= (now() at time zone 'utc'))
      AND (finish_show_date is null OR finish_show_date > (now() at time zone 'utc'))
      AND (type is null OR type = '' OR type LIKE 'user')
    ORDER BY order_num NULLS last, start_show_date;
    ''';

    return q;
  }

  static String getAdvertisingList(FilterRequest fq){
    var q = '''SELECT t1.id, title, tag, type, can_show, creator_id,
       order_num, register_date, start_show_date,
       finish_show_date, click_link, path as image_uri, t2.user_name
    FROM advertising AS t1
    LEFT JOIN UserNameId AS t2 ON t1.creator_id = t2.user_id
     
    WHERE (@search)
      ORDER BY @orderBy 
    LIMIT x;
    ''';

    var search = 'TRUE';
    var orderBy = '';

    if(fq.querySearchingList.isNotEmpty){
      var value;

      for(final se in fq.querySearchingList){
        value = '\$token\$%${se.text}%\$token\$';

        if(se.searchKey  == SearchKeys.userNameKey){
          search = ' user_name Like $value';
        }
        else if(se.searchKey == SearchKeys.titleKey) {
          search = ' title ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.tagKey) {
          search = ' tag ILIKE $value';
        }
        else if(se.searchKey == SearchKeys.typeKey) {
          search = ' type Like $value';
        }
      }
    }

    if(fq.queryFilteringList.isNotEmpty) {
      for(final fi in fq.queryFilteringList){
        if(fi.key == FilterKeys.byVisibleState){
          if (fi.value == FilterKeys.isVisibleOp) {
            search += ' AND can_show = true';
          }
          else if (fi.value == FilterKeys.isNotVisibleOp) {
            search += ' AND can_show = false';
          }
        }
      }
    }

    if(fq.querySortingList.isNotEmpty){
      for(final so in fq.querySortingList){
        if(so.key == SortKeys.registrationKey){
          if(so.isASC){
            orderBy = 'register_date';
          }
          else {
            orderBy = 'register_date DESC NULLS LAST';
          }
        }

        else if(so.key == SortKeys.showDateKey){
          if(so.isASC){
            orderBy = 'start_show_date NULLS LAST';
          }
          else {
            orderBy = 'start_show_date DESC NULLS LAST';
          }
        }

        else if(so.key == SortKeys.orderNumberKey){
          if(so.isASC){
            orderBy = 'order_num NULLS LAST';
          }
          else {
            orderBy = 'order_num DESC NULLS LAST';
          }
        }
      }
    }


    q = q.replaceFirst(RegExp('@search'), '$search');
    q = q.replaceFirst(RegExp('@orderBy'), '$orderBy');

    return q;
  }

}