
class QuerySelector {
  final _queries = <String>[];

  QuerySelector({
  List<String>? queries,
  }){
    if(queries != null) {
      _queries.addAll(queries);
    }
  }

  void setQueries(List<String> queries){
    _queries.clear();
    _queries.addAll(queries);
  }

  void addQueries(List<String> queries){
    _queries.addAll(queries);
  }

  void addQuery(String query){
    _queries.add(query);
  }

  String generate(int queryIdx, Map replace){
    var q = _queries[queryIdx];

    for(var kv in replace.entries){
      q = q.replaceFirst(RegExp(kv.key), '${kv.value}');
    }

    return q;
  }
}