import 'package:dio/dio.dart';
import 'package:kazumi/services/logging/logger.dart';

class DioLoggerInterceptor extends Interceptor {
  static const _startedAtExtraKey = '_kazumiStartedAt';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtExtraKey] = DateTime.now();
    KazumiLogger().d('HTTP: --> ${options.method} ${_url(options)}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final elapsed = _elapsed(response.requestOptions);
    KazumiLogger().d(
      'HTTP: <-- ${response.statusCode} '
      '${response.requestOptions.method} ${_url(response.requestOptions)}'
      '${elapsed == null ? '' : ' ${elapsed}ms'}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final elapsed = _elapsed(err.requestOptions);
    final statusCode = err.response?.statusCode;
    final status = statusCode == null ? err.type.name : statusCode.toString();
    KazumiLogger().w(
      'HTTP: <-- $status ${err.requestOptions.method} ${_url(err.requestOptions)}'
      '${elapsed == null ? '' : ' ${elapsed}ms'}',
      error: err.requestOptions.extra['sensitiveUrl'] == true
          ? err.type.name
          : err.message,
    );
    handler.next(err);
  }

  String _url(RequestOptions options) => options.extra['sensitiveUrl'] == true
      ? '${options.uri.origin}/[private-danmaku]'
      : options.uri.toString();

  int? _elapsed(RequestOptions options) {
    final startedAt = options.extra[_startedAtExtraKey];
    if (startedAt is! DateTime) {
      return null;
    }
    return DateTime.now().difference(startedAt).inMilliseconds;
  }
}
