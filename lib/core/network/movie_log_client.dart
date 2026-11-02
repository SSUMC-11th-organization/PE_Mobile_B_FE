import 'package:dio/dio.dart';

// 워크북 서버(회원 중복 확인 등) 전용 Dio — TMDB용 TmdbClient와는 별개
Dio createMovieLogClient() => Dio(
      BaseOptions(
        baseUrl: 'https://workbook.devnoco.com',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
