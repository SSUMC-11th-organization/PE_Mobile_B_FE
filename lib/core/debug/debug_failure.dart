import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 쓰기(POST/PATCH/DELETE) 요청에 주입할 실패 종류
enum WriteFailure {
  none('끔 (정상 요청)'),
  network('네트워크 오류 (응답 없음)'),
  c400('400 COMMON400'),
  c403('403 COMMON403'),
  c404('404 COMMON404'),
  c409('409 COMMON409');

  const WriteFailure(this.label);
  final String label;

  int? get status => switch (this) {
        c400 => 400,
        c403 => 403,
        c404 => 404,
        c409 => 409,
        _ => null,
      };

  String? get message => switch (this) {
        c400 => '별점은 5점 이하여야 합니다.',
        c403 => '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
        c404 => '존재하지 않는 평점입니다.',
        c409 => '이미 이 영화에 평점을 남기셨습니다.',
        _ => null,
      };
}

/// 디버그 전용 실패 주입 설정. 앱 전체에서 하나만 사용합니다.
class DebugFailureSettings extends ChangeNotifier {
  DebugFailureSettings._();
  static final instance = DebugFailureSettings._();

  WriteFailure writeFailure = WriteFailure.none;
  bool failRatingsGet = false; // GET /v6/members/{id}/ratings 실패
  bool slow = false; // 모든 요청 1.5초 지연 (로딩·연타 방지 확인용)

  void update(void Function() change) {
    change();
    notifyListeners();
  }

  void reset() => update(() {
        writeFailure = WriteFailure.none;
        failRatingsGet = false;
        slow = false;
      });
}

/// MovieLog Dio에 붙여 실제 서버 호출 전에 요청을 가로채 실패시킵니다.
class DebugFailureInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final s = DebugFailureSettings.instance;
    if (s.slow) await Future<void>.delayed(const Duration(milliseconds: 1500));

    if (options.method == 'GET') {
      if (s.failRatingsGet && options.path.endsWith('/ratings')) {
        return handler.reject(_network(options), true);
      }
    } else if (s.writeFailure == WriteFailure.network) {
      return handler.reject(_network(options), true);
    } else if (s.writeFailure.status != null) {
      final f = s.writeFailure;
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: f.status,
            data: {
              'isSuccess': false,
              'code': 'COMMON${f.status}',
              'message': f.message,
              'result': null,
            },
          ),
        ),
        true,
      );
    }
    handler.next(options);
  }

  DioException _network(RequestOptions options) => DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: '[디버그] 주입된 네트워크 오류',
      );
}
