import 'package:dio/dio.dart';

/// 워크북 자체 백엔드(/v5)용 Client. TMDB Client와는 baseUrl·헤더가 달라 분리한다.
Dio createMovieLogClient() {
  return Dio(
    BaseOptions(
      baseUrl: 'https://workbook.devnoco.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
}
