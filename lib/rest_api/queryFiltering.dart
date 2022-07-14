
import 'package:assistance_kit/api/converter.dart';
import 'package:collection/collection.dart';
import 'package:brandfit_server/keys.dart';

class FilterRequest {
  static int maxLimit = 500;
  List<QuerySortingModel> querySortingList = [];
  List<QuerySearchingModel> querySearchingList = [];
  List<QueryFilteringModel> queryFilteringList = [];
  int limit = 100;
  int? offset;
  dynamic lastCase;
  //-------------------- local
  List<SortingViewModel> sortingViewList = [];
  List<SearchingViewModel> searchingViewList = [];
  List<FilteringViewModel> filterViewList = [];
  String? selectedSearchKey;
  String? _selectedSortKey;

  FilterRequest();

  FilterRequest.fromMap(Map? map){
    if(map == null){
      return;
    }

    final sortList = Converter.correctList<Map>(map['sorting_list']) ?? <Map>[];
    final searchList = Converter.correctList<Map>(map['search_list']) ?? <Map>[];
    final filterList = Converter.correctList<Map>(map['filter_list']) ?? <Map>[];

    querySortingList = sortList.map((elm) => QuerySortingModel.fromMap(elm)).toList();
    querySearchingList = searchList.map((elm) => QuerySearchingModel.fromMap(elm)).toList();
    queryFilteringList = filterList.map((elm) => QueryFilteringModel.fromMap(elm)).toList();
    limit = map['limit']?? maxLimit;
    offset = map['offset'];
    lastCase = map['last_case'];

    if(limit > maxLimit){
      limit = maxLimit;
    }
  }

  Map<String, dynamic> toMap(){
    final map = <String, dynamic>{};

    final qsList = <QuerySortingModel>[];
    final qseList = <QuerySearchingModel>[];
    final qfList = <QueryFilteringModel>[];

    for(final s in sortingViewList){
      if(s.mustUseForQuery || s.getTranslateKey() == _selectedSortKey){
        final q = QuerySortingModel();
        q.key = s.key;
        q.isASC = s.isASC;
        q.order = q.order;

        qsList.add(q);
      }
    }

    for(final s in searchingViewList){
      if(s.text != null){
        final q = QuerySearchingModel();
        q.searchKey = s.key;
        q.text = s.text!;

        qseList.add(q);
      }
    }

    for(final s in filterViewList){
      if(s.selectedValue != null || s.selectedV1 != null || s.selectedList.isNotEmpty){
        final q = QueryFilteringModel();
        q.key = s.key;
        q.value = s.selectedValue;
        q.valueList.addAll(s.selectedList.toSet().toList());
        q.v1 = s.selectedV1;
        q.v2 = s.selectedV2;

        qfList.add(q);
      }
    }

    map['sorting_list'] = qsList.map((e) => e.toMap()).toList();
    map['search_list'] = qseList.map((e) => e.toMap()).toList();
    map['filter_list'] = qfList.map((e) => e.toMap()).toList();
    map['limit'] = limit;
    map['offset'] = offset;
    map['last_case'] = lastCase;

    return map;
  }

  List<Map<String, dynamic>> toMapFiltering(){
    final qfList = <QueryFilteringModel>[];

    for(final s in filterViewList){
      if(s.selectedValue != null || s.selectedV1 != null || s.selectedList.isNotEmpty){
        final q = QueryFilteringModel();
        q.key = s.key;
        q.value = s.selectedValue;
        q.valueList.addAll(s.selectedList.toSet().toList());
        q.v1 = s.selectedV1;
        q.v2 = s.selectedV2;

        qfList.add(q);
      }
    }

    return qfList.map((e) => e.toMap()).toList();
  }

  bool showBadge({bool onlyHasView = true}){
    for(final s in filterViewList){
      if(s.hasNotView && onlyHasView){
        continue;
      }

      if(s.selectedValue != null || s.selectedV1 != null || s.selectedList.isNotEmpty){
        return true;
      }
    }

    return false;
  }

  SortingViewModel? getSortViewSelected(){
    try{
      return sortingViewList.firstWhere((element) => element.getTranslateKey() == _selectedSortKey);
    }
    catch (e){
      return null;
    }
  }

  SortingViewModel getSortViewSelectedForce(){
    try{
      return sortingViewList.firstWhere((element) => element.getTranslateKey() == _selectedSortKey);
    }
    catch (e){
      return sortingViewList.first;
    }
  }

  SortingViewModel? getSortViewFor(String key, bool isAsc){
    try{
      return sortingViewList.firstWhere((element) => element.key == key && element.isASC == isAsc);
    }
    catch (e){
      return null;
    }
  }

  QuerySortingModel? getSortFor(String key){
    try{
      return querySortingList.firstWhere((element) => element.key == key);
    }
    catch (e){
      return null;
    }
  }

  bool isSortFor(String key){
    for(final sKv in querySortingList){
      if(sKv.key == key){
        return true;
      }
    }

    return false;
  }

  SearchingViewModel? getSearchViewFor(String key){
    try{
      return searchingViewList.firstWhere((element) => element.key == key);
    }
    catch (e){
      return null;
    }
  }

  SearchingViewModel getSearchSelectedForce(){
    try{
      return searchingViewList.firstWhere((element) => element.key == selectedSearchKey);
    }
    catch (e){
      return searchingViewList.first;
    }
  }

  bool setTextToSelectedSearch(String? text, {bool clearOthers = true}){
    if(text != null && text.isEmpty){
      text = null;
    }

    if(text == getSearchSelectedForce().text){
      return false;
    }

    if(clearOthers) {
      for (final element in searchingViewList) {
        element._text = null;
      }
    }

    getSearchSelectedForce()._text = text;
    return true;
  }

  bool isSearchFor(String key){
    return querySearchingList.any((elm) => elm.searchKey == key);
  }

  FilteringViewModel? getFilterViewFor(String key){
    try{
      return filterViewList.firstWhere((element) => element.key == key);
    }
    catch (e){
      return null;
    }
  }

  void addSortView(String key, {bool isAsc = true, bool isDefault = false}){
    var ex = getSortViewFor(key, isAsc);

    if(ex == null){
      ex = SortingViewModel();
      ex.key = key;
      ex.isASC = isAsc;

      sortingViewList.add(ex);
    }
    else {
      ex.isASC = isAsc;
    }

    if(isDefault){
      _selectedSortKey = ex.getTranslateKey();
    }
    else {
      if(_selectedSortKey == ex.getTranslateKey()){
        _selectedSortKey = null;
      }
    }
  }

  void removeSortView(String key){
    sortingViewList.removeWhere((element) => element.key == key);
  }

  /// use in server before use sort
  void sortSortingList(){
    int sorter(QuerySortingModel o1, QuerySortingModel o2){
      if(o1.order == o2.order){
        return 0;
      }

      if(o1.order < o2.order){
        return 1;
      }

      return -1;
    }

    querySortingList.sort(sorter);
  }

  void addSearchView(String key){
    var ex = getSearchViewFor(key);

    if(ex == null){
      ex = SearchingViewModel();
      ex.key = key;

      searchingViewList.add(ex);
    }
  }

  void removeSearchView(String key){
    searchingViewList.removeWhere((element) => element.key == key);
  }

  void addFilterView(FilteringViewModel model){
    var ex = getFilterViewFor(model.key);

    if(ex == null){
      filterViewList.add(model);
    }
  }

  void removeFilterView(String key){
    filterViewList.removeWhere((element) => element.key == key);
  }

  bool deepEquals(Map s1, Map s2){
    return DeepCollectionEquality.unordered().equals(s1, s2);
  }
}
///=========================================================================================
class SortingViewModel {
  late String key;
  int order = 0;
  bool isASC = true;
  bool mustUseForQuery = false;

  SortingViewModel();

  String getTranslateKey(){
    return '${key}_${isASC? 'asc': 'desc'}';
  }
}

class QuerySortingModel {
  late String key;
  int order = 0;
  bool isASC = true;

  QuerySortingModel();

  QuerySortingModel.fromMap(Map map){
    key = map[Keys.key];
    order = map['order']?? 0;
    isASC = map['is_asc']?? true;
  }

  Map<String, dynamic> toMap(){
    final map = <String, dynamic>{};

    map[Keys.key] = key;
    map['order'] = order;
    map['is_asc'] = isASC;

    return map;
  }
}
///=========================================================================================
class SearchingViewModel {
  late String key;
  String? _text;

  String? get text => _text;

  /*set text (String? txt){
    _text = txt;
  }*/

  SearchingViewModel();
}

class QuerySearchingModel {
  late String searchKey;
  late String text;

  QuerySearchingModel();

  QuerySearchingModel.fromMap(Map map){
    text = map['text'];
    searchKey = map['search_key'];
  }

  Map<String, dynamic> toMap(){
    final map = <String, dynamic>{};

    map['text'] = text;
    map['search_key'] = searchKey;

    return map;
  }
}
///=========================================================================================
enum FilterType {
  string,
  checkbox,
  radio,
  range,
}
//-----------------------------------------------------------------------
class FilterSubViewModel {
  late String key;
  dynamic value;
  dynamic v1;
  dynamic v2;
}
//-----------------------------------------------------------------------
class FilteringViewModel {
  late String key;
  FilterType type = FilterType.checkbox;
  List<FilterSubViewModel> subViews = [];

  bool hasNotView = false;
  final selectedList = [];
  dynamic selectedValue;
  dynamic selectedV1;
  dynamic selectedV2;

  void clear(){
    selectedValue = null;
    selectedV1 = null;
    selectedV2 = null;
  }
}
//-----------------------------------------------------------------------
class QueryFilteringModel {
  late String key;
  final valueList = [];
  dynamic value;
  dynamic v1;
  dynamic v2;

  QueryFilteringModel();

  QueryFilteringModel.fromMap(Map map){
    key = map['key'];
    value = map['value'];
    valueList.addAll(Converter.correctList(map['value_list'])?? []);
    v1 = map['v1'];
    v2 = map['v2'];
  }

  Map<String, dynamic> toMap(){
    final map = <String, dynamic>{};

    map['key'] = key;
    map['value'] = value;
    map['value_list'] = valueList;
    map['v1'] = v1;
    map['v2'] = v2;

    return map;
  }
}
///=============== Keys ====================================================================
class SortKeys {
  SortKeys._();

  static const registrationKey = 'registration';
  static const showDateKey = 'show_date';
  static const messageDateKey = 'message_date';
  static const orderNumberKey = 'order_number';
  static const ageKey = 'age';
}

class SearchKeys {
  SearchKeys._();

  static const global = 'global';
  static const userNameKey = 'user_name';
  static const name = 'name';
  static const family = 'family';
  static const mobile = 'mobile';
  static const titleKey = 'title';
  static const descriptionKey = 'description';
  static const contentKey = 'content';
  static const tagKey = 'tag';
  static const typeKey = 'type';
  static const sameWordKey = 'same_words';
}

class FilterKeys {
  FilterKeys._();

  static const byVisibleState = 'by_visible_capability';
  static const byType = 'by_type';
  static const byGender = 'by_gender';
  static const byBlocked = 'by_blocked';
  static const byDeleted = 'by_deleted';
  static const byClosed = 'by_closed';
  static const byAge = 'by_age';
  static const byPrice = 'by_price';
  static const byExerciseMode = 'by_exercise_has';
  static const byFoodMode = 'by_food_has';
  static const byInActivePupilMode = 'by_in_active_pupil';
  static const byTrainerUser = 'by_pupil_user';
  static const byPupilUser = 'by_trainer_user';

  static const isVisibleOp = 'is_visible';
  static const isNotVisibleOp = 'is_not_visible';

  static const maleOp = 'male';
  static const femaleOp = 'female';

  static const blockedOp = 'blocked';
  static const noneBlockedOp = 'none_blocked';

  static const deletedOp = 'deleted';
  static const noneDeletedOp = 'none_deleted';

  static const closedOp = 'closed';
  static const noneCloseOp = 'none_closed';

  static const matterOp = 'matter_type';
  static const complementOp = 'complement_type';
  static const herbalTeaOp = 'herbal_tea_type';

  static const pendingRequestOp = 'pending_request';
  static const acceptedRequestOp = 'accepted_request';
  static const rejectedRequestOp = 'rejected_request';
}
