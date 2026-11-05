import 'package:dio/dio.dart';

/// MovieLog 자체 백엔드(워크북 서버)용 Client. TMDB와 baseUrl·헤더가 달라 Client를 분리
Dio createMovieLogClient() {
  return Dio(
    BaseOptions(
      baseUrl: 'https://workbook.devnoco.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
}
