// TMDB JSON 값 변환 헬퍼 — null이거나 타입이 예상과 달라도 앱이 죽지 않게 기본값으로 처리

// int/double/String 숫자 모두 int로 (예: 7 / 7.0 / "7")
int parseInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? fallback;
  }
  return fallback;
}

// vote_average처럼 int(8)로 올 수도, double(8.2)로 올 수도 있는 값을 double로
double parseDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

String parseString(Object? value, {String fallback = ''}) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

// poster_path처럼 null/빈 문자열이면 "없음"인 값
String? parseNullableString(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return value;
}

bool parseBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  return fallback;
}

// genre_ids처럼 숫자 배열 — 숫자가 아닌 항목은 버림
List<int> parseIntList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<num>().map((e) => e.toInt()).toList();
}

// results / genres처럼 객체 배열 — Map이 아닌 항목은 버림
List<T> parseObjectList<T>(
  Object? value,
  T Function(Map<String, dynamic> json) fromJson,
) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().map(fromJson).toList();
}
