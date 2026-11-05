import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/rating_dto.dart';

void main() {
  group('RatingDto.fromJson', () {
    final json = <String, dynamic>{
      'ratingId': 12,
      'movieId': 550,
      'score': 5,
      'comment': '최고의 영화!',
      'createdAt': '2026-09-06T12:14:03.000Z',
      'updatedAt': '2026-09-06T12:14:03.000Z',
    };

    test('모든 필드를 파싱하고 updatedAt 같은 추가 필드는 무시한다', () {
      final dto = RatingDto.fromJson(json);

      expect(dto.ratingId, 12);
      expect(dto.movieId, 550);
      expect(dto.score, 5);
      expect(dto.comment, '최고의 영화!');
      expect(dto.createdAt, DateTime.utc(2026, 9, 6, 12, 14, 3));
      expect(dto.createdAt.isUtc, isTrue);
    });

    test('comment가 null이면 null로 파싱한다', () {
      final dto = RatingDto.fromJson({...json, 'comment': null});

      expect(dto.comment, isNull);
      expect(dto.ratingId, 12);
    });
  });
}
