import 'package:dio/dio.dart';
import 'package:kazumi/request/config/danmaku_service_config.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';
import 'package:kazumi/utils/dandan_credentials.dart';
import 'package:kazumi/utils/http_headers.dart';
import 'package:kazumi/utils/crypto.dart';

class DanmakuClient {
  DanmakuClient({Dio? dio, this.config = const DanmakuServiceConfig()})
    : _dio = dio;

  static final DanmakuClient instance = DanmakuClient();
  final DanmakuServiceConfig config;
  final Dio? _dio;

  Future<dynamic> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic> headers = const {},
    CancelToken? cancelToken,
  }) => _request(
    'GET',
    url,
    queryParameters: queryParameters,
    headers: headers,
    cancelToken: cancelToken,
  );

  Future<dynamic> post(String url, {required Map<String, dynamic> data}) =>
      _request('POST', url, data: data);

  Future<dynamic> _request(
    String method,
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? data,
    Map<String, dynamic> headers = const {},
    CancelToken? cancelToken,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final uri = Uri.parse(url);
    final selfHosted = config.owns(uri);
    if (!selfHosted &&
        (config.isSelfHosted || uri.origin != 'https://api.dandanplay.net')) {
      throw const FormatException('弹幕请求地址与已配置的服务不一致');
    }
    final requestHeaders = <String, dynamic>{
      'user-agent': getRandomUA(),
      'referer': '',
      if (!selfHosted) ...{
        'X-Auth': 1,
        'X-AppId': dandanCredentials['id'],
        'X-Timestamp': timestamp,
        'X-Signature': generateDandanSignature(uri.path, timestamp),
      },
      ...headers,
    };
    if (selfHosted) {
      requestHeaders.removeWhere(
        (name, _) => const {
          'x-appid',
          'x-signature',
          'x-timestamp',
          'x-auth',
        }.contains(name.toLowerCase()),
      );
    }

    try {
      final response = await (_dio ?? DioFactory.apiDio).request(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: requestHeaders,
          receiveTimeout: selfHosted ? const Duration(seconds: 120) : null,
          extra: {if (selfHosted) 'sensitiveUrl': true},
        ),
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }
}
