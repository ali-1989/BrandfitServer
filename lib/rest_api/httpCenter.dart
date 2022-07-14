import 'dart:async';
import 'dart:convert' as system_convert;
import 'dart:io';
import 'dart:typed_data';
import 'package:assistance_kit/api/converter.dart';
import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/api/helpers/listHelper.dart';
import 'package:assistance_kit/api/helpers/urlHelper.dart';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;

class HttpCenter {
	HttpCenter._();

	static String baseUri = '';
	static String? proxyUri;

	static BaseOptions _getOptions(){
		return BaseOptions(
			connectTimeout: 32000,
		);
	}

	static ItemResponse send(HttpItem item, {Duration? timeout}){
		var itemRes = ItemResponse();
		Dio dio;

		try {
			if(timeout == null) {
			  dio = Dio(_getOptions());
			} else {
				var bo = _getOptions();
				bo.connectTimeout = timeout.inMilliseconds;
				dio = Dio(bo);
			}

			//dio.options.baseUrl = baseUri;
			var uri = item.fullUri?? (baseUri + (item.pathSection?? ''));
			uri = resolveUri(uri)!;

			///... add proxy
			if(proxyUri != null || item.proxyAddress != null) {
				(dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
					client.findProxy = (uri) {
						return 'PROXY ${item.proxyAddress?? proxyUri}';
					};

					client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
				};
			}

			dio.interceptors.add(
					InterceptorsWrapper(
							onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
								options.headers['Connection'] = 'close';
								itemRes.requestOptions = options;
								//prin(options.uri); full url

								return handler.next(options);
								//return handler.resolve(response);
								//return handler.reject(dioError);
							},
							 onResponse: (Response<dynamic> res, ResponseInterceptorHandler handler) {
								itemRes._response = res;
								itemRes.isOk = !(res is Error || res is Exception || res.statusCode != 200 || res.data == null);

								handler.next(res);
							},
							onError: (DioError err, ErrorInterceptorHandler handler) async{
								var ro = RequestOptions(path: uri);
								var er = DioError(requestOptions: ro, error: err.error,);

								Response res = Response<DioError>(requestOptions: ro, data: er);
								itemRes._response = res;
								err.response = res;

								//handler.next(err);
								handler.resolve(res);
							}
					)
			);

			var cancelToken = CancelToken();
			itemRes.dio = dio;
			itemRes.canceller = cancelToken;

			itemRes._future = dio.request(
				uri,
				cancelToken: cancelToken,
				options: item.options,
				queryParameters: item.uriQueries,
				data: item.body,
				onReceiveProgress: item.onReceiveProgress,
				onSendProgress: item.onSendProgress,
			)
					.timeout(Duration(milliseconds: dio.options.connectTimeout + 2000), onTimeout: () async{

						var ro = RequestOptions(path: uri);
						Response res = Response<DioError>(requestOptions: ro, data: DioError(requestOptions: ro));
						itemRes._response = res;
						return res;
						//bad: throw DioError(requestOptions: RequestOptions(path: uri));
						//return Future.error(DioError(requestOptions: RequestOptions(path: uri)));
			});
		}
		catch (e) {
			itemRes._future = Future.error(e);
		}

		return itemRes;
	}

	static ItemResponse download(HttpItem item, String savePath, {Duration? timeout}){
		var itemRes = ItemResponse();
		Dio dio;

		try {
			var bo = _getOptions();
			bo.connectTimeout = timeout != null ? timeout.inMilliseconds: 32000;
			dio = Dio();

			var uri = item.fullUri?? (baseUri + (item.pathSection?? ''));
			uri = resolveUri(uri)!;

			if(proxyUri != null || item.proxyAddress != null) {
				(dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
					client.findProxy = (uri) {
						return 'PROXY ${item.proxyAddress?? proxyUri}';
					};

					client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
				};
			}

			dio.interceptors.add(
					InterceptorsWrapper(
							onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
								options.headers['Connection'] = 'close';
								itemRes.requestOptions = options;

								handler.next(options);
							},
							onResponse: (Response<dynamic> res, ResponseInterceptorHandler handler) {
								itemRes._response = res;

								itemRes.isOk = !(res is Error || res is Exception
										|| (res.statusCode != 200 && res.statusCode != 206) || res.data == null);

								handler.next(res);
							},
							onError: (DioError err, ErrorInterceptorHandler handler) {
								var ro = RequestOptions(path: uri);
								Response res = Response<ResponseBody>(requestOptions: ro, data: ResponseBody.fromString('$err', 404));
								itemRes._response = res;
								err.response = res;

								//return handler.next(err); reject(err)  < this take log error
								handler.resolve(res);
						})
			);

			var cancelToken = CancelToken();
			itemRes.dio = dio;
			itemRes.canceller = cancelToken;

			itemRes._future = dio.download(
					uri,
					savePath,
				cancelToken: cancelToken,
				options: item.options,
				queryParameters: item.uriQueries,
				data: item.body,
				onReceiveProgress: item.onReceiveProgress,
			);
		}
		catch (e) {
			itemRes._future = Future.error(e);
		}

		return itemRes;
	}

	// https://stackoverflow.com/questions/56638826/downloading-progress-in-darthttp
	static ItemResponse getHeaders(HttpItem item ,{Duration? timeout}){
		var itemRes = ItemResponse();

		try {
			//HttpClient g = HttpClient();  this is used in dio

			final client = http.Client();
			//final HttpClient client = HttpClient(); client.openUrl(request.method, Uri.parse(uri))

			var uri = item.fullUri?? (baseUri + (item.pathSection?? ''));
			uri = resolveUri(uri)!;
			http.BaseRequest request = http.Request(item.method?? 'GET', Uri.parse(uri));
			request.persistentConnection = false;
			request.headers['Range'] = 'bytes=0-'; // > Content-Range: bytes 0-1023/146515

			Future<http.StreamedResponse?> send = client.send(request);

			send = send
					.timeout(timeout?? Duration(seconds: 26),)
					.catchError((e){ // TimeoutException
						return null;
						//client.close();
					});

			itemRes._future = send.then((http.StreamedResponse? response) {
				if(response == null || response is Error) {
					return null;//Response<http.StreamedResponse>(data: null, requestOptions: RequestOptions(path: uri));
				}

				//Map headers = response.headers;
				itemRes.isOk = true;

				client.close();
				return Response<http.StreamedResponse>(data: response, requestOptions: RequestOptions(path: uri));
				/*
				int received = 0;
				int length = response.contentLength;

				StreamSubscription listen;
				listen = response.stream.listen((List<int> bytes) {
					received += bytes.length;

					if(received > 200) {
						client.close();
						listen.cancel();
					}
				},
				onDone: (){
					client.close();
					listen.cancel();
				},
				onError: (e){
					client.close();
					listen.cancel();
				},
				cancelOnError: true
				);*/
			});
		}
		catch (e) {
			itemRes._future = Future.error(e);
		}

		return itemRes;
	}
	///=====================================================================================================
	static void cancelAndClose(ItemResponse? request, {String passTag = 'my'}) {
		if(request != null){
			if(!(request.canceller?.isCancelled?? true)) {
			  request.canceller!.cancel(passTag);
			}

			request.dio?.close();
		}
	}

	static String? resolveUri(String? uri) {
		if(uri == null) {
		  return null;
		}

		//return uri.replaceAll(RegExp('/{2,}'), "/").replaceFirst(':\/', ':\/\/');
		return uri.replaceAll(RegExp('(?<!:)(/{2,})'), '/');
	}
}
///========================================================================================================
class ItemResponse {
	late Future<Response?> _future;
	Response? _response;
	RequestOptions? requestOptions;
	CancelToken? canceller;
	Dio? dio;
	bool isOk = false;
	Map<String, dynamic>? parts;

	ItemResponse(){
		_future = Future((){});
	}

	Future<Response?> get future => _future;
	Response? get response => _response;

	Map<String, dynamic>? getJson(){
		if(_response == null) {
		  return null;
		}

		String receive = _response?.data;
		return JsonHelper.jsonToMap(receive);
	}

	Map<String, dynamic>? getJsonPart(){
		var parts = getParts();

		if(parts == null) {
		  return getJson();
		}

		List<int>? receive = parts['Json'];

		if(receive == null) {
		  return null;
		}

		return JsonHelper.jsonToMap(Converter.bytesToStringUtf8(receive));
	}

	dynamic getPart(String name){
		var parts = getParts();

		if(parts == null) {
		  return null;
		}

		return parts[name];
	}

	Map<String, dynamic>? getParts(){
		if(parts != null) {
		  return parts;
		}

		List<int> bytes = _response?.data;

		if(bytes[0] == 13 && bytes[1] == 10 && bytes[2] == 10 && bytes[3] == 10){
			parts = _reFactorBytes(bytes);
			_response?.data = null;
			return parts;
		}

		return null;
	}

	Map<String, dynamic> _reFactorBytes(List<int> bytes){
		var res = <String, dynamic>{};
		late List<int> partSplitter;
		late List<int> nameSplitter;
		var idx = 0;

		for(var i = 5; i < bytes.length; i++){
			if(bytes[i] == 13 && bytes[i+1] == 10 && bytes[i+2] == 10 && bytes[i+3] == 10) {
				partSplitter = ListHelper.slice(bytes, 4, i - 4);
				idx = i+4;
				break;
			}
		}

		for(var i = idx+1; i < bytes.length; i++){
			if(bytes[i] == 13 && bytes[i+1] == 10 && bytes[i+2] == 10 && bytes[i+3] == 10) {
				nameSplitter = ListHelper.slice(bytes, idx, i - idx);
				idx = i+4;
				break;
			}
		}

		var p = idx;
		var n = idx;

		while(true){
			p = ListHelper.indexOf(bytes, partSplitter, start: p);

			if(p > -1) {
				p += partSplitter.length;

				n = ListHelper.indexOf(bytes, nameSplitter, start: p);

				if(n > -1) {
					var nameBytes = ListHelper.slice(bytes, p, n-p);
					var name = String.fromCharCodes(nameBytes);
					var lenIndex = n + nameSplitter.length;
					var lenBytes = ListHelper.slice(bytes, lenIndex, 4);
					var len = Int8List.fromList(lenBytes).buffer.asByteData().getInt32(0, Endian.big);
					res[name] = ListHelper.slice(bytes, lenIndex+4, len);
					p += len;
				}
			}
			else {
			  break;
			}
		}

		return res;
	}

	bool isError(){
		return _response is Error || _response is Exception;
	}

	Response emptyError = Response<ResponseBody>(
			requestOptions: RequestOptions(path: ''), data: null);//ResponseBody.fromString('non', 404)
}
///========================================================================================================
class HttpItem {
	HttpItem();

	String? fullUri;
	String? _pathSection;
	String? proxyAddress;
	Map<String, dynamic> uriQueries = {};
	dynamic body;
	ProgressCallback? onSendProgress;
	ProgressCallback? onReceiveProgress;
	Options options = Options(
		method: 'GET',
		receiveDataWhenStatusError: true,
		responseType: ResponseType.plain,
		//sendTimeout: ,
		//receiveTimeout: ,
	);

	String? get method => options.method;
	set method (m) {options.method = m;}

	String? get pathSection => _pathSection;
	set pathSection (p) {
		if(p.toString().startsWith(RegExp('^/?http.*', caseSensitive: false))) {
		  fullUri = UrlHelper.resolveUri(p);
		} else {
		  _pathSection = p;
		}
	}

	void addUriQuery(String key, dynamic value){
		uriQueries[key] = value;
	}

	void addUriQueryMap(Map<String, dynamic> map){
		for(var kv in map.entries) {
		  uriQueries[kv.key] = kv.value;
		}
	}

	/// response receive chunk chunk,  Response<ResponseBody> Stream<Uint8List>
	void setResponseIsStream(){
		options.responseType = ResponseType.stream;
	}

	/// response not convert to string, is List<int>
	void setResponseIsBytes(){
		options.responseType = ResponseType.bytes;
	}

	void setResponseIsPlain(){
		options.responseType = ResponseType.plain;
	}

	void setBody(String value){
		body = value;
	}

	void setBodyJson(Map js){
		body = system_convert.json.encode(js);
	}

	void addBodyField(String key, String value){
		if(body is! FormData) {
		  body = FormData();
		}

		(body as FormData).fields.add(MapEntry(key, value));
	}

	void addBodyFile(String partName, String fileName, File file){
		if(body is! FormData) {
		  body = FormData();
		}

		var m = MultipartFile.fromFileSync(file.path, filename: fileName, contentType: MediaType.parse('application/octet-stream'));
		(body as FormData).files.add(MapEntry(partName, m));
	}

	void addBodyBytes(String partName, String dataName, List<int> bytes){
		if(body is! FormData) {
		  body = FormData();
		}

		var m = MultipartFile.fromBytes(bytes, filename: dataName, contentType: MediaType.parse('application/octet-stream'));
		(body as FormData).files.add(MapEntry(partName, m));
	}
}