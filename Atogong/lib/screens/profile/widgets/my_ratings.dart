import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/services/movielog_api_service.dart';

/// 유저별 평점 조회 API(GET /members/{memberId}/ratings) 연동.
/// 로그인은 7주차라 지금은 시드 데이터의 memberId 1을 고정으로 조회
class MyRatings extends StatefulWidget {
  const MyRatings({super.key, this.memberId = 1});

  final int memberId;

  @override
  State<MyRatings> createState() => _MyRatingsState();
}

class _MyRatingsState extends State<MyRatings> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<MovieLogApiService>().fetchRatings(widget.memberId);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '내 평점',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              final message = snapshot.error is DioException
                  ? '서버에 연결할 수 없습니다.'
                  : '평점을 불러오지 못했습니다.';
              return Text(message, style: textTheme.bodyMedium);
            }
            final ratings = snapshot.data ?? const [];
            if (ratings.isEmpty) {
              return Text('아직 남긴 평점이 없습니다.', style: textTheme.bodyMedium);
            }
            return Column(
              children: [
                for (final rating in ratings)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(
                      '★ ${rating['score']}',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    title: Text('TMDB movieId ${rating['movieId']}'),
                    subtitle: Text(rating['comment'] as String? ?? ''),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
